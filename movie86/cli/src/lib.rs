//! `movie86` CLI library half — the same `run_elf` entry point the bin
//! target uses, exposed so integration tests can drive it directly
//! without spawning a subprocess.

use std::io::{self, Write};

use movie86_core::elf::{flatten_into_region, parse, ElfError};
use movie86_core::syscall::{SyscallArgs, SyscallResult, SysHost};
use movie86_core::{Cpu, Fault, Memory};

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
            4 => {
                let fd = args.ebx;
                let buf = args.ecx;
                let count = args.edx as usize;
                let mut data = vec![0u8; count];
                mem.read_bytes(buf, &mut data)?;
                let n = match fd {
                    1 => io::stdout().write(&data),
                    2 => io::stderr().write(&data),
                    _ => return Err(Fault::UnknownSyscall(4)),
                }
                .map_err(|_| Fault::UnknownSyscall(4))?;
                Ok(SyscallResult::Return(u32::try_from(n).unwrap_or(u32::MAX)))
            }
            _ => Err(Fault::UnknownSyscall(args.eax)),
        }
    }
}

/// Load `bytes` as an ELF32 i386 executable, run it, and report the
/// outcome. Syscalls go through [`StdHost`] (stdio + exit).
#[must_use]
pub fn run_elf(bytes: &[u8]) -> RunOutcome {
    let elf = match parse(bytes) {
        Ok(e) => e,
        Err(e) => return RunOutcome::LoadError(e),
    };
    let mut mem = match flatten_into_region(&elf) {
        Ok(m) => m,
        Err(e) => return RunOutcome::LoadError(e),
    };
    let mut cpu = Cpu::new(elf.entry);
    let mut host = StdHost;
    loop {
        match cpu.step(&mut mem, &mut host) {
            Ok(()) => {}
            Err(Fault::Exit(status)) => return RunOutcome::Exit(status),
            Err(e) => return RunOutcome::Fault(e),
        }
    }
}
