//! `movie86` CLI library half — the same `run_elf` entry point the bin
//! target uses, exposed so integration tests can drive it directly
//! without spawning a subprocess.

use std::io::{self, Write};

use movie86_core::elf::{flatten_into_region, parse, ElfError};
use movie86_core::syscall::{SysHost, SyscallArgs, SyscallResult};
use movie86_core::{Cpu, Fault, Memory};

#[cfg(test)]
mod tests;

/// What happened when running an ELF.
#[derive(Debug)]
pub enum RunOutcome {
    /// Guest called `exit(status)`. Carries the raw status register.
    Exit(u32),
    /// CPU hit a fault other than Exit — e.g. unknown opcode, unmapped
    /// address, unsupported syscall.
    Fault(Fault),
    /// ELF could not be loaded (bad magic, wrong machine, etc.).
    LoadError(ElfError),
}

impl RunOutcome {
    /// Map an outcome to a `std::process::exit` status code.
    ///
    /// Exit syscalls produce the low 8 bits of the status (Linux
    /// convention). Other faults return 1.
    #[must_use]
    pub fn process_exit_code(&self) -> i32 {
        match self {
            Self::Exit(status) => i32::from((status & 0xff) as u8),
            Self::Fault(_) | Self::LoadError(_) => 1,
        }
    }
}

/// Host that wires Linux i386 syscalls to the surrounding process:
/// `write` goes to the matching stdio stream, `exit` raises
/// [`Fault::Exit`]. Anything else traps with [`Fault::UnknownSyscall`].
#[derive(Debug, Default)]
pub struct StdHost;

impl SysHost for StdHost {
    fn syscall(
        &mut self,
        args: &SyscallArgs,
        mem: &mut dyn Memory,
    ) -> Result<SyscallResult, Fault> {
        match args.eax {
            // exit(status)  →  ebx is the status.
            1 => Err(Fault::Exit(args.ebx)),
            // write(fd, buf, count) → ssize_t
            4 => write_syscall(args, mem),
            _ => Err(Fault::UnknownSyscall(args.eax)),
        }
    }
}

/// Linux i386 `write(fd, buf, count)`.
///
/// Streams the guest buffer in 4 KiB chunks via a stack-allocated
/// scratch so a `write(_, _, 0xffff_ffff)` from a hostile guest can't
/// OOM the host. Host I/O failures return a Linux-style negative errno
/// in EAX (not [`Fault::UnknownSyscall`]) so pipelines like
/// `movie86 prog | head` behave the way the guest expects.
fn write_syscall(args: &SyscallArgs, mem: &mut dyn Memory) -> Result<SyscallResult, Fault> {
    const CHUNK: usize = 4096;
    let fd = args.ebx;
    let mut addr = args.ecx;
    let mut remaining = args.edx as usize;
    let mut written: u32 = 0;
    let mut scratch = [0u8; CHUNK];

    while remaining > 0 {
        let this = remaining.min(CHUNK);
        let slice = &mut scratch[..this];
        mem.read_bytes(addr, slice)?;
        let n_res = match fd {
            1 => io::stdout().write(slice),
            2 => io::stderr().write(slice),
            _ => {
                // Bad-fd in Linux is EBADF (9). Return -EBADF if no
                // bytes have been written yet; otherwise return the
                // partial count (matches glibc behaviour).
                if written == 0 {
                    return Ok(SyscallResult::Return(errno_to_eax(9)));
                }
                return Ok(SyscallResult::Return(written));
            }
        };
        match n_res {
            Ok(0) => break, // EOF / nothing more to write
            Ok(n) => {
                let n_u32 = u32::try_from(n).unwrap_or(u32::MAX);
                written = written.saturating_add(n_u32);
                addr = addr.wrapping_add(n_u32);
                remaining = remaining.saturating_sub(n);
                if n < this {
                    break; // short host write — propagate as a short syscall return
                }
            }
            Err(e) => {
                if written > 0 {
                    return Ok(SyscallResult::Return(written));
                }
                let errno = match e.kind() {
                    io::ErrorKind::BrokenPipe => 32, // EPIPE
                    _ => 5,                          // EIO
                };
                return Ok(SyscallResult::Return(errno_to_eax(errno)));
            }
        }
    }
    Ok(SyscallResult::Return(written))
}

/// Linux's ssize_t-returning syscalls use the convention "negative
/// values are -errno". Encode a positive errno into the EAX bit
/// pattern the guest will see (i.e. `-errno as u32`).
fn errno_to_eax(errno: u32) -> u32 {
    // Two's complement of errno, computed without an `as i32` cast.
    u32::MAX - errno + 1
}

/// Load `bytes` as an ELF32 i386 executable, run it, and report the
/// outcome. Syscalls go through [`StdHost`] (stdio + exit).
#[must_use]
pub fn run_elf(bytes: &[u8]) -> RunOutcome {
    let mut host = StdHost;
    run_elf_with_host(bytes, &mut host)
}

/// Same as [`run_elf`] but with a caller-supplied host. Lets integration
/// tests substitute a recording host (capture stdout, assert no syscall
/// happens, etc.) without spawning a subprocess.
pub fn run_elf_with_host<H: SysHost>(bytes: &[u8], host: &mut H) -> RunOutcome {
    let elf = match parse(bytes) {
        Ok(e) => e,
        Err(e) => return RunOutcome::LoadError(e),
    };
    let mut mem = match flatten_into_region(&elf) {
        Ok(m) => m,
        Err(e) => return RunOutcome::LoadError(e),
    };
    let mut cpu = Cpu::new(elf.entry);
    loop {
        match cpu.step(&mut mem, host) {
            Ok(()) => {}
            Err(Fault::Exit(status)) => return RunOutcome::Exit(status),
            Err(e) => return RunOutcome::Fault(e),
        }
    }
}
