//! `movie86` CLI library half — the same `run_elf` entry point the bin
//! target uses, exposed so integration tests can drive it directly
//! without spawning a subprocess.

use std::io::{self, Write};

use movie86_core::elf::{flatten_with_stack, parse, ElfError};
use movie86_core::syscall::{SysHost, SyscallArgs, SyscallResult};
use movie86_core::{Cpu, Fault, Memory, Reg32, Signal};

/// Stack size reserved by the CLI for every program. 64 KiB is enough
/// for any hand-assembled fixture we run today and well within the
/// host's tolerance even when stacked on top of a movfuscator binary's
/// already-large segment range.
const DEFAULT_STACK_SIZE: u32 = 64 * 1024;

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
    // Bad-fd is reported by Linux without ever dereferencing the user
    // buffer. Mirror that here so a guest that probes invalid FDs
    // (write(99, NULL, len)) sees -EBADF instead of an unmapped-memory
    // fault from our pre-read.
    if fd != 1 && fd != 2 {
        return Ok(SyscallResult::Return(errno_to_eax(9)));
    }
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
            _ => unreachable!("fd checked at top of write_syscall"),
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
    run_elf_with_debug(bytes, host, &DebugConfig::default())
}

/// Configuration for the debugger-driven run path. All fields default
/// to "off"; setting any of them enables that diagnostic.
#[derive(Debug, Default, Clone)]
pub struct DebugConfig {
    /// Print `eip + GPRs` before each `step()`.
    pub trace: bool,
    /// Stop and report when `eip` first equals this address.
    pub break_at: Option<u32>,
    /// Stop after this many successful instructions.
    pub max_steps: Option<u64>,
    /// Print a message any time the `u32` at one of these guest
    /// addresses changes value (write detection by sampling — catches
    /// any kind of mov, jmp-self-modifying-code, syscall, etc.).
    pub watch_u32: Vec<u32>,
    /// Dump the current `u32` values at these guest addresses whenever
    /// execution stops at `break_at`.
    pub dump_u32: Vec<u32>,
}

/// Reason the debug-driven run stopped *short* of the guest exiting on
/// its own. Embedded inside [`RunOutcome::Fault`] when surfaced.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DebugStop {
    /// Caller-supplied `break_at` address was reached.
    Break(u32),
    /// `max_steps` was reached without the guest exiting.
    MaxSteps(u64),
}

/// Like [`run_elf_with_host`] but also accepts a `DebugConfig`. This
/// is the entry the `movie86 --watch ...` CLI uses, exposed for tests.
pub fn run_elf_with_debug<H: SysHost>(bytes: &[u8], host: &mut H, cfg: &DebugConfig) -> RunOutcome {
    let elf = match parse(bytes) {
        Ok(e) => e,
        Err(e) => return RunOutcome::LoadError(e),
    };
    let (mut mem, esp_initial) = match flatten_with_stack(&elf, DEFAULT_STACK_SIZE) {
        Ok(pair) => pair,
        Err(e) => return RunOutcome::LoadError(e),
    };
    let mut cpu = Cpu::new(elf.entry);
    cpu.set_reg(Reg32::Esp, esp_initial);
    // movfuscator's runtime installs `dispatch` (SIGSEGV) and
    // `master_loop` (SIGILL) handlers via sigaction. We don't run a
    // real sigaction stub, so we wire the handlers up directly from
    // the ELF's symbol table — same end effect for a static link.
    if let Some(addr) = elf.find_symbol("dispatch") {
        cpu.set_signal_handler(Signal::Segv, addr);
    }
    if let Some(addr) = elf.find_symbol("master_loop") {
        cpu.set_signal_handler(Signal::Ill, addr);
    }
    // Per-instruction tracing is gated on the DebugConfig (or the
    // legacy MOVIE86_TRACE env var) so the hot path costs at most an
    // integer load in the common case.
    let trace = cfg.trace || std::env::var_os("MOVIE86_TRACE").is_some();
    // Snapshot the watched addresses' current values; we sample after
    // each step and report deltas.
    let mut watch_state: Vec<u32> = cfg
        .watch_u32
        .iter()
        .map(|&a| mem.read_u32(a).unwrap_or(0))
        .collect();
    let mut step_count: u64 = 0;
    loop {
        if cfg.break_at == Some(cpu.eip) {
            eprintln!(
                "movie86: --break-at hit eip={:#010x} (after {step_count} steps)",
                cpu.eip
            );
            eprintln!(
                "movie86: regs eax={:#010x} ebx={:#010x} ecx={:#010x} edx={:#010x} esp={:#010x}",
                cpu.reg(Reg32::Eax),
                cpu.reg(Reg32::Ebx),
                cpu.reg(Reg32::Ecx),
                cpu.reg(Reg32::Edx),
                cpu.reg(Reg32::Esp),
            );
            for &addr in &cfg.dump_u32 {
                match mem.read_u32(addr) {
                    Ok(v) => eprintln!("movie86: dump {addr:#010x} = {v:#010x}"),
                    Err(f) => eprintln!("movie86: dump {addr:#010x} faulted: {f:?}"),
                }
            }
            return RunOutcome::Fault(Fault::Unmapped(cpu.eip)); // borrow Unmapped as a "stopped" signal; the CLI prints DebugStop separately
        }
        if let Some(max) = cfg.max_steps {
            if step_count >= max {
                eprintln!(
                    "movie86: --max-steps {max} reached at eip={:#010x}",
                    cpu.eip
                );
                return RunOutcome::Fault(Fault::Unmapped(cpu.eip));
            }
        }
        if trace {
            eprintln!(
                "[{step_count:>6}] eip={:08x} eax={:08x} ebx={:08x} ecx={:08x} edx={:08x} esp={:08x}",
                cpu.eip,
                cpu.reg(Reg32::Eax),
                cpu.reg(Reg32::Ebx),
                cpu.reg(Reg32::Ecx),
                cpu.reg(Reg32::Edx),
                cpu.reg(Reg32::Esp),
            );
        }
        let outcome = cpu.step(&mut mem, host);
        // Check watched addresses *after* the step so we can report
        // which instruction caused the write.
        for (i, &addr) in cfg.watch_u32.iter().enumerate() {
            let new_v = mem.read_u32(addr).unwrap_or(0);
            if new_v != watch_state[i] {
                eprintln!(
                    "[{step_count:>6}] WATCH {addr:#010x}: {:#010x} -> {:#010x}  (now eip={:#010x})",
                    watch_state[i], new_v, cpu.eip,
                );
                watch_state[i] = new_v;
            }
        }
        match outcome {
            Ok(()) => step_count += 1,
            Err(Fault::Exit(status)) => return RunOutcome::Exit(status),
            Err(e) => return RunOutcome::Fault(e),
        }
    }
}
