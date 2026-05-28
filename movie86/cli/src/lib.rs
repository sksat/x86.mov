//! `movie86` CLI library half — the same `run_elf` entry point the bin
//! target uses, exposed so integration tests can drive it directly
//! without spawning a subprocess.

use std::io::{self, Write};

use movie86::elf::{flatten_with_stack, parse, ElfError, LoadedElf};
use movie86::libc_host::{LibcCall, LibcHost, LibcResult};
use movie86::syscall::{SysHost, SyscallArgs, SyscallResult};
use movie86::{Cpu, Fault, Memory, Reg32, Signal};

/// Stack size reserved by the CLI for every program. 64 KiB is enough
/// for any hand-assembled fixture we run today and well within the
/// host's tolerance even when stacked on top of a movfuscator binary's
/// already-large segment range.
const DEFAULT_STACK_SIZE: u32 = 64 * 1024;

pub mod diff;
pub mod gdb_target;
pub mod logging_memory;
pub mod snapshot;

pub use diff::diff_snapshots;
pub use gdb_target::{run_elf_with_gdb, GdbRunError};
pub use logging_memory::{LoggedWrite, LoggingMemory};

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
    /// Debug-driven stop (e.g. `--break-at` hit, `--max-steps` reached).
    /// Distinct from `Fault` so callers — and the CLI's exit code —
    /// don't conflate "user asked us to stop here" with "guest crashed".
    DebugStop(DebugStop),
}

impl RunOutcome {
    /// Map an outcome to a `std::process::exit` status code.
    ///
    /// Exit syscalls produce the low 8 bits of the status (Linux
    /// convention). Faults / load errors return 1. Debug stops also
    /// return 1 — the user is asking the emulator to halt before the
    /// guest finishes, so we can't claim success.
    #[must_use]
    pub fn process_exit_code(&self) -> i32 {
        match self {
            Self::Exit(status) => i32::from((status & 0xff) as u8),
            Self::Fault(_) | Self::LoadError(_) | Self::DebugStop(_) => 1,
        }
    }
}

/// Host that wires Linux i386 syscalls to the surrounding process:
/// `write` goes to the matching stdio stream, `exit` raises
/// [`Fault::Exit`]. Anything else traps with [`Fault::UnknownSyscall`].
///
/// Also implements the host-side libc-wrapper ABI via [`LibcHost`] —
/// the table mapping trap address → wrapped function is populated by
/// [`run_elf_with_debug`] from the ELF symbol table at load time. Stub
/// addresses with no registered wrapper trap with
/// [`Fault::UnsupportedInterrupt(0x81)`] (the trait's default impl).
#[derive(Debug, Default)]
pub struct StdHost {
    /// `trap_addr` (the address of the `int 0x81` byte) → which libc
    /// wrapper to invoke. Populated by `run_elf_with_debug` from the
    /// ELF symbol table — host code never has to hand-write addresses.
    libc_stubs: std::collections::BTreeMap<u32, LibcFn>,
}

/// Identifies one of the host-implemented libc wrappers.
///
/// Kept small on purpose: each variant requires a host implementation,
/// and the smart-friend review pinned the "treat printf as guest-data
/// marshaling" boundary — we only accept functions we can implement
/// safely.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum LibcFn {
    /// `void exit(int status)` — terminates the run. The host returns
    /// [`Fault::Exit`] with the cdecl arg.
    Exit,
    /// `int sigaction(int signum, const struct sigaction *act, ...)` —
    /// records the (signum, handler) pair on the CPU so the SIGSEGV /
    /// SIGILL dispatch tricks find a target. movie86's signal model
    /// doesn't run a real signal frame; we just need the handler addr.
    Sigaction,
    /// `int printf(const char *fmt, ...)` — formatted output. Parsed
    /// on the host (a constrained `%s`/`%d`/`%c` subset, no `%n`).
    Printf,
}

impl StdHost {
    /// Register that the stub at `trap_addr` should dispatch to `fn`.
    /// Called once per intercepted symbol at ELF load time.
    pub fn register_libc_stub(&mut self, trap_addr: u32, which: LibcFn) {
        self.libc_stubs.insert(trap_addr, which);
    }
}

impl LibcHost for StdHost {
    fn libc_call(&mut self, call: &mut LibcCall<'_>) -> Result<LibcResult, Fault> {
        let which = self
            .libc_stubs
            .get(&call.trap_addr)
            .copied()
            .ok_or(Fault::UnsupportedInterrupt(0x81))?;
        match which {
            // `void exit(int status)` — cdecl arg 0 is the status.
            // Surface as Fault::Exit so the existing exit-code path
            // (run_outcome.process_exit_code) handles it the same way
            // an `int 0x80` exit does.
            LibcFn::Exit => {
                let status = call.arg_u32(0)?;
                Err(Fault::Exit(status))
            }
            // `int sigaction(int signum, const struct sigaction *act, ...)`
            // — movie86 wires dispatch / master_loop directly from the
            // ELF `.symtab` (see `run_elf_with_debug`), so this wrapper
            // just acknowledges with the "success" return value (0).
            // Matches what the previous hand-written cdecl stub did.
            LibcFn::Sigaction => Ok(LibcResult::Return(0)),
            // `int printf(const char *fmt, ...)` — parsed on the host.
            LibcFn::Printf => libc_printf(call),
        }
    }

    fn scan_libc_stubs(&mut self, elf: &LoadedElf<'_>, mem: &dyn movie86::Memory) {
        // Auto-detect: for each known function name we have a wrapper
        // for, look up its symbol in the ELF. If the first two bytes
        // are our sentinel `CD 81` (int 0x81), register the address.
        // Existing fixtures that link a real cdecl stub (`int 0x80`)
        // don't match the sentinel, so they stay unaffected.
        const NAMES: &[(&str, LibcFn)] = &[
            ("exit", LibcFn::Exit),
            ("sigaction", LibcFn::Sigaction),
            ("printf", LibcFn::Printf),
        ];
        for &(name, which) in NAMES {
            let Some(addr) = elf.find_symbol(name) else {
                continue;
            };
            let b0 = mem.read_u8(addr).ok();
            let b1 = mem.read_u8(addr.wrapping_add(1)).ok();
            if b0 == Some(0xCD) && b1 == Some(0x81) {
                self.register_libc_stub(addr, which);
            }
        }
    }
}

/// Maximum length of a guest-supplied format string or `%s` argument.
/// Bounds the scan so an unterminated string from a buggy or hostile
/// guest doesn't lock the emulator in an unbounded loop. 4 KiB is
/// generous for the demos we run and matches the host write chunk size.
const PRINTF_MAX_LEN: u32 = 4096;

/// Host-side `printf(fmt, ...)` implementation.
///
/// Per smart-friend's review, this is **deliberately not** a
/// pass-through to host `vprintf`. The format string and any `%s` arg
/// are guest data; we walk a constrained subset on the host so an
/// unmapped fmt pointer, unterminated string, or `%n` directive can't
/// turn a guest bug into a host crash or write-where.
///
/// Supported conversions: `%s`, `%d`, `%c`, `%%`. Anything else aborts
/// the printf with a `-1` return (real printf's I/O error convention).
fn libc_printf(call: &mut LibcCall<'_>) -> Result<LibcResult, Fault> {
    let fmt_ptr = call.arg_u32(0)?;
    let mut p = fmt_ptr;
    let mut scanned: u32 = 0;
    let mut next_arg_idx: usize = 1;
    let mut written: u32 = 0;
    let mut buf: Vec<u8> = Vec::with_capacity(64);

    loop {
        if scanned >= PRINTF_MAX_LEN {
            // Fmt string too long / not terminated. Flush what we have
            // and return -1 (printf's I/O-error convention).
            let _ = flush(&buf);
            return Ok(LibcResult::Return(u32::MAX));
        }
        let byte = call.mem.read_u8(p)?;
        if byte == 0 {
            break;
        }
        if byte == b'%' {
            scanned = scanned.wrapping_add(1);
            p = p.wrapping_add(1);
            let conv = call.mem.read_u8(p)?;
            match conv {
                b's' => {
                    let s_ptr = call.arg_u32(next_arg_idx)?;
                    next_arg_idx += 1;
                    written =
                        written.saturating_add(append_cstr_from_guest(&mut buf, call.mem, s_ptr)?);
                }
                b'd' => {
                    let v = call.arg_u32(next_arg_idx)?.cast_signed();
                    next_arg_idx += 1;
                    let s = v.to_string();
                    buf.extend_from_slice(s.as_bytes());
                    written = written.saturating_add(u32::try_from(s.len()).unwrap_or(u32::MAX));
                }
                b'c' => {
                    // `%c` takes an int that's truncated to a byte
                    // (C-promotion behavior).
                    let c = u8::try_from(call.arg_u32(next_arg_idx)? & 0xff).unwrap_or(0);
                    next_arg_idx += 1;
                    buf.push(c);
                    written = written.saturating_add(1);
                }
                b'%' => {
                    buf.push(b'%');
                    written = written.saturating_add(1);
                }
                // `%n` writes through a guest pointer based on bytes
                // written — a classic format-string vulnerability and
                // explicitly out of scope per smart-friend's review.
                b'n' => {
                    let _ = flush(&buf);
                    return Ok(LibcResult::Return(u32::MAX));
                }
                _ => {
                    // Unknown / unsupported conversion. Flush what we
                    // have and bail with -1.
                    let _ = flush(&buf);
                    return Ok(LibcResult::Return(u32::MAX));
                }
            }
        } else {
            buf.push(byte);
            written = written.saturating_add(1);
        }
        p = p.wrapping_add(1);
        scanned = scanned.wrapping_add(1);
    }
    // Mirror `write_syscall`'s error propagation: if stdout is closed
    // (broken pipe) or otherwise refuses the write, surface -1 in EAX
    // — the C printf I/O-error convention. Without this, a wrapped
    // printf piped into `head` would lie about how many bytes landed.
    if !flush(&buf) {
        return Ok(LibcResult::Return(u32::MAX));
    }
    Ok(LibcResult::Return(written))
}

/// Append a NUL-terminated guest string to `buf`. Bounded by
/// [`PRINTF_MAX_LEN`] so a missing NUL doesn't run forever.
fn append_cstr_from_guest(buf: &mut Vec<u8>, mem: &mut dyn Memory, ptr: u32) -> Result<u32, Fault> {
    let mut n: u32 = 0;
    loop {
        if n >= PRINTF_MAX_LEN {
            return Ok(n);
        }
        let b = mem.read_u8(ptr.wrapping_add(n))?;
        if b == 0 {
            return Ok(n);
        }
        buf.push(b);
        n = n.wrapping_add(1);
    }
}

/// Flush a `printf` accumulator to stdout. `true` on success, `false`
/// on a broken pipe / EIO so the caller can return -1 in EAX (the C
/// printf I/O-error convention). Mirrors how `write_syscall` reports
/// -EPIPE for closed stdout — without it, a wrapped printf piped into
/// `head` would lie about how many bytes landed.
#[must_use]
fn flush(buf: &[u8]) -> bool {
    io::stdout().write_all(buf).is_ok()
}

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

// `write_syscall` no longer hits any `?` paths after the P2 fix (it
// converts all memory faults into -EFAULT returns). The Result wrapper
// is kept so the signature matches `SysHost::syscall`'s and future
// I/O paths that DO need to propagate a Fault.
#[allow(clippy::unnecessary_wraps)]
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
        // Match Linux's behavior: an unmapped/unreadable buffer makes
        // `write(2)` return -EFAULT (14) in EAX, not a hard process
        // fault. Return any bytes already written instead of -EFAULT
        // if we got partway through (glibc convention).
        if mem.read_bytes(addr, slice).is_err() {
            if written > 0 {
                return Ok(SyscallResult::Return(written));
            }
            return Ok(SyscallResult::Return(errno_to_eax(14)));
        }
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
    let mut host = StdHost::default();
    run_elf_with_host(bytes, &mut host)
}

/// Same as [`run_elf`] but with a caller-supplied host. Lets integration
/// tests substitute a recording host (capture stdout, assert no syscall
/// happens, etc.) without spawning a subprocess.
pub fn run_elf_with_host<H: SysHost + LibcHost>(bytes: &[u8], host: &mut H) -> RunOutcome {
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
    /// Capture a [`Snapshot`] right after the Nth step completes and
    /// write it to the given path. Pair with `snapshot_on_stop` to
    /// compare progress between a specific step and the eventual halt.
    ///
    /// [`Snapshot`]: snapshot::Snapshot
    pub snapshot_at_step: Option<(u64, std::path::PathBuf)>,
    /// Capture a snapshot when the run halts (exit, fault, break-at,
    /// max-steps). The snapshot's `kind` field records *why* it
    /// stopped so a later `movie86 diff` can label the comparison
    /// honestly.
    pub snapshot_on_stop: Option<std::path::PathBuf>,
    /// Log every guest memory write that falls inside any of these
    /// ranges, prefixed with `(step, eip)`. Built for tracing the
    /// movfuscator dispatch state in fixtures like multi-add where
    /// PC cycling alone hides logical progress — see
    /// [`logging_memory`] for the per-write capture mechanism.
    pub log_writes_in: Vec<std::ops::Range<u32>>,
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
#[allow(clippy::too_many_lines)] // single-narrative run loop — splitting just spreads the state-machine across helpers
pub fn run_elf_with_debug<H: SysHost + LibcHost>(
    bytes: &[u8],
    host: &mut H,
    cfg: &DebugConfig,
) -> RunOutcome {
    let elf = match parse(bytes) {
        Ok(e) => e,
        Err(e) => return RunOutcome::LoadError(e),
    };
    let (inner_mem, esp_initial) = match flatten_with_stack(&elf, DEFAULT_STACK_SIZE) {
        Ok(pair) => pair,
        Err(e) => return RunOutcome::LoadError(e),
    };
    // Always wrap the flat memory in a logging adapter — `log_writes_in`
    // empty ⇒ zero-cost pass-through (one Vec::is_empty check per write).
    // Putting the wrap unconditionally on the run path keeps the trait
    // bound stable and avoids enum-dispatch downstream.
    let mut mem = LoggingMemory::new(inner_mem, cfg.log_writes_in.clone());
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
    // Let the host scan the loaded image for sentinel libc-call stubs
    // (`CD 81 ...` = `int 0x81; ret`). Default-impl is a no-op, so
    // hosts that don't care about libc wrappers skip this entirely.
    host.scan_libc_stubs(&elf, &mem);
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
    // `--snapshot-at-step 0` means "the initial state, before any step
    // has run". The loop-body capture only fires after step_count is
    // incremented, so it can never match 0 — capture once here before
    // entering the loop instead. Documented as the baseline capture
    // case in DESIGN.md.
    if let Some((target, path)) = &cfg.snapshot_at_step {
        if *target == 0 {
            write_step_snapshot(path, 0, &cpu, &mem);
        }
    }
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
            write_stop_snapshot(
                cfg,
                snapshot::SnapshotKind::Break,
                cpu.eip,
                step_count,
                &cpu,
                &mem,
            );
            return RunOutcome::DebugStop(DebugStop::Break(cpu.eip));
        }
        if let Some(max) = cfg.max_steps {
            if step_count >= max {
                eprintln!(
                    "movie86: --max-steps {max} reached at eip={:#010x}",
                    cpu.eip
                );
                write_stop_snapshot(
                    cfg,
                    snapshot::SnapshotKind::MaxSteps,
                    u32::try_from(max).unwrap_or(u32::MAX),
                    step_count,
                    &cpu,
                    &mem,
                );
                return RunOutcome::DebugStop(DebugStop::MaxSteps(max));
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
        // Drain any writes that landed in a `--log-writes-in` range
        // during this step. `eip` is *after* the step here (control
        // already advanced); that's the convention the existing
        // --watch path uses too. `step_count` is still pre-increment.
        for w in mem.drain_pending() {
            eprintln!(
                "[{step_count:>6}] write u{}@{:#010x}: {:#010x} -> {:#010x}  (eip={:#010x})",
                w.width * 8,
                w.addr,
                w.old,
                w.new,
                cpu.eip,
            );
        }
        match outcome {
            Ok(()) => {
                step_count += 1;
                // `--snapshot-at-step N` captures right after step N
                // completed (step_count is now N+1, but the user said
                // "step N", which is what we just finished).
                if let Some((target, path)) = &cfg.snapshot_at_step {
                    if step_count == *target {
                        write_step_snapshot(path, step_count, &cpu, &mem);
                    }
                }
            }
            Err(Fault::Exit(status)) => {
                write_stop_snapshot(
                    cfg,
                    snapshot::SnapshotKind::Exit,
                    status,
                    step_count,
                    &cpu,
                    &mem,
                );
                return RunOutcome::Exit(status);
            }
            Err(e) => {
                write_stop_snapshot(
                    cfg,
                    snapshot::SnapshotKind::Fault,
                    fault_detail(e),
                    step_count,
                    &cpu,
                    &mem,
                );
                return RunOutcome::Fault(e);
            }
        }
    }
}

/// Encode a [`Fault`]'s primary u32 payload for the snapshot `detail`
/// field. 0 when the variant carries none.
fn fault_detail(f: Fault) -> u32 {
    match f {
        Fault::Unmapped(a) => a,
        // Exit, UnknownSyscall, SignalHandlerUnregistered all carry
        // one u32 scalar that maps to detail directly.
        Fault::Exit(s) | Fault::UnknownSyscall(s) | Fault::SignalHandlerUnregistered(s) => s,
        Fault::UnknownOpcode(b) | Fault::UnsupportedInterrupt(b) => u32::from(b),
        Fault::DecodeTruncated | Fault::UnimplementedMov => 0,
    }
}

/// Snapshot the whole `FlatMemory`. Used by both --snapshot-at-step
/// (with kind `AfterStep`) and the stop-time captures.
fn write_step_snapshot(
    path: &std::path::Path,
    step_count: u64,
    cpu: &Cpu,
    mem: &LoggingMemory<movie86::FlatMemory>,
) {
    write_snapshot(
        path,
        snapshot::SnapshotKind::AfterStep,
        0,
        step_count,
        cpu,
        mem,
    );
}

/// Take the snapshot for whatever caused the run to stop. No-op when
/// the user didn't pass `--snapshot-on-stop`.
fn write_stop_snapshot(
    cfg: &DebugConfig,
    kind: snapshot::SnapshotKind,
    detail: u32,
    step_count: u64,
    cpu: &Cpu,
    mem: &LoggingMemory<movie86::FlatMemory>,
) {
    let Some(path) = &cfg.snapshot_on_stop else {
        return;
    };
    write_snapshot(path, kind, detail, step_count, cpu, mem);
}

fn write_snapshot(
    path: &std::path::Path,
    kind: snapshot::SnapshotKind,
    detail: u32,
    step_count: u64,
    cpu: &Cpu,
    mem: &LoggingMemory<movie86::FlatMemory>,
) {
    // u32 cast: FlatMemory's construction already rejects regions
    // larger than 4 GiB, so this can't truncate.
    let mem_len = u32::try_from(mem.len()).unwrap_or(u32::MAX);
    let snap = match snapshot::Snapshot::capture(
        kind,
        step_count,
        cpu.regs,
        cpu.eip,
        cpu.signal_handler(Signal::Segv),
        cpu.signal_handler(Signal::Ill),
        detail,
        mem,
        mem.base(),
        mem_len,
    ) {
        Ok(s) => s,
        Err(e) => {
            eprintln!("movie86: snapshot capture failed: {e}");
            return;
        }
    };
    if let Err(e) = snap.write_to_path(path) {
        eprintln!("movie86: snapshot write to {} failed: {e}", path.display());
    } else {
        eprintln!(
            "movie86: snapshot ({}) written to {} at step {step_count}",
            kind.label(),
            path.display()
        );
    }
}
