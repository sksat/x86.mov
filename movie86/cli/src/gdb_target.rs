// `#[inline(always)]` on the IDET enabler methods is the gdbstub
// crate's documented idiom — without it LLVM can fail to DCE nested
// extension impls, bloating the binary. Clippy's pedantic lint is
// wrong for this trait surface.
#![allow(clippy::inline_always)]

//! GDB Remote Serial Protocol (RSP) server — `movie86 --gdb-listen ADDR`.
//!
//! Lets the user attach gdb to a running movie86 instance and drive it
//! interactively: `info registers`, `x/i $eip`, `b *0x...`, `c` / `s`,
//! Ctrl-C → halt, etc. Built on the [`gdbstub`] crate — smart-friend's
//! review pinned that rolling our own RSP is much more than the
//! obvious 400 LOC once you handle ACK / partial reads / Ctrl-C /
//! target.xml / GDB quirks.
//!
//! Design notes:
//!
//! - **Separate from `run_elf_with_debug`.** Gdb owns the run/stop
//!   state machine — folding that into the existing tight `loop {
//!   cpu.step(); ... }` would couple transport to execution.
//!   Bootstrap (ELF load, esp, signal handlers, libc stubs) is the
//!   only thing shared with the non-gdb path, kept inline for now.
//!
//! - **i386 target description**: we ship the stock `X86_SSE` one
//!   from `gdbstub_arch` so the user doesn't need `set arch i386` —
//!   `target remote :1234` is enough.
//!
//! - **EFLAGS**: returned as 0 since movie86 has no flags register
//!   today. The register-file shape stays stable because gdb expects
//!   it; writing a non-zero EFLAGS via `set $eflags = X` is a silent
//!   no-op for now.
//!
//! - **Breakpoints**: stub-side tracking, not int3 byte-rewrites.
//!   Behaves as an "execution breakpoint at this eip" — fine for
//!   movie86 since we don't decode `int3`.
//!
//! - **Single-step**: one `Cpu::step()` per `s`. Faults map to gdb
//!   signals (`Fault::Unmapped` → SIGSEGV, decode failures → SIGILL,
//!   etc.). Guest `exit(n)` → gdb `W` packet with the low byte.

use std::io;
use std::net::{SocketAddr, TcpListener};

use gdbstub::common::Signal as GdbSignal;
use gdbstub::conn::{Connection, ConnectionExt};
use gdbstub::stub::{run_blocking, DisconnectReason, GdbStub, SingleThreadStopReason};
use gdbstub::target::ext::base::singlethread::{
    SingleThreadBase, SingleThreadResume, SingleThreadResumeOps, SingleThreadSingleStep,
    SingleThreadSingleStepOps,
};
use gdbstub::target::ext::breakpoints::{
    Breakpoints, BreakpointsOps, SwBreakpoint, SwBreakpointOps,
};
use gdbstub::target::{self, Target, TargetError, TargetResult};
use gdbstub_arch::x86::reg::X86CoreRegs;
use gdbstub_arch::x86::X86_SSE;

use movie86::elf::{flatten_with_stack, parse, ElfError};
use movie86::libc_host::LibcHost;
use movie86::{Cpu, Fault, FlatMemory, Memory, Reg32, Signal};

use crate::{StdHost, DEFAULT_STACK_SIZE};

/// What the user asked the target to do between gdb commands.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ExecMode {
    /// `s` from gdb — execute exactly one `Cpu::step()`.
    Step,
    /// `c` from gdb — run until a breakpoint, fault, exit, or Ctrl-C.
    Continue,
}

/// Why `GdbTarget::run` returned.
#[derive(Debug)]
pub enum RunEvent {
    /// Single-step completed without faulting.
    DoneStep,
    /// `eip` matched a registered software breakpoint before stepping.
    Break,
    /// Guest invoked `exit(status)`.
    Exit(u32),
    /// Step returned a non-Exit fault (mapped to gdb signals later).
    Fault(Fault),
    /// `c` was interrupted by gdb sending us a byte (typically Ctrl-C).
    IncomingData,
}

/// The gdbstub Target for movie86. Owns the CPU + memory + syscall
/// host + the breakpoint set + the current exec mode.
#[allow(missing_debug_implementations)] // StdHost.libc_stubs is debug, FlatMemory is debug, but Cpu... fine since not user-facing
pub struct GdbTarget {
    pub cpu: Cpu,
    pub mem: FlatMemory,
    pub host: StdHost,
    /// Stub-side breakpoint set. Checked before each step in
    /// `ExecMode::Continue`; not patched into guest memory as int3.
    pub breakpoints: Vec<u32>,
    pub exec_mode: ExecMode,
}

impl GdbTarget {
    /// Drive the CPU until the next "interesting" event. Called from
    /// the gdb event loop between protocol packets.
    ///
    /// `poll_incoming` returns `true` when gdb sent us an unsolicited
    /// byte during the run — the standard way Ctrl-C interrupts a
    /// continuation. We check it cheaply between steps so a continue
    /// loop isn't blind to the user.
    pub fn run(&mut self, mut poll_incoming: impl FnMut() -> bool) -> RunEvent {
        match self.exec_mode {
            ExecMode::Step => match self.cpu.step(&mut self.mem, &mut self.host) {
                Ok(()) => RunEvent::DoneStep,
                Err(Fault::Exit(s)) => RunEvent::Exit(s),
                Err(e) => RunEvent::Fault(e),
            },
            ExecMode::Continue => loop {
                if self.breakpoints.contains(&self.cpu.eip) {
                    return RunEvent::Break;
                }
                if poll_incoming() {
                    return RunEvent::IncomingData;
                }
                match self.cpu.step(&mut self.mem, &mut self.host) {
                    Ok(()) => {}
                    Err(Fault::Exit(s)) => return RunEvent::Exit(s),
                    Err(e) => return RunEvent::Fault(e),
                }
            },
        }
    }
}

impl Target for GdbTarget {
    type Arch = X86_SSE;
    type Error = &'static str;

    #[inline(always)]
    fn base_ops(&mut self) -> target::ext::base::BaseOps<'_, Self::Arch, Self::Error> {
        target::ext::base::BaseOps::SingleThread(self)
    }

    #[inline(always)]
    fn support_breakpoints(&mut self) -> Option<BreakpointsOps<'_, Self>> {
        Some(self)
    }
}

impl SingleThreadBase for GdbTarget {
    fn read_registers(&mut self, regs: &mut X86CoreRegs) -> TargetResult<(), Self> {
        regs.eax = self.cpu.reg(Reg32::Eax);
        regs.ecx = self.cpu.reg(Reg32::Ecx);
        regs.edx = self.cpu.reg(Reg32::Edx);
        regs.ebx = self.cpu.reg(Reg32::Ebx);
        regs.esp = self.cpu.reg(Reg32::Esp);
        regs.ebp = self.cpu.reg(Reg32::Ebp);
        regs.esi = self.cpu.reg(Reg32::Esi);
        regs.edi = self.cpu.reg(Reg32::Edi);
        regs.eip = self.cpu.eip;
        // movie86 has no flags register today (no cmp/jcc). Returning 0
        // keeps the register-file shape stable for gdb; the field is
        // documented as "best-effort placeholder".
        regs.eflags = 0;
        // segments / st (FPU) / xmm (SSE) / mxcsr also unmodeled —
        // X86CoreRegs::Default zeros them. We leave the slots as
        // whatever gdb passed in (typically defaults).
        Ok(())
    }

    fn write_registers(&mut self, regs: &X86CoreRegs) -> TargetResult<(), Self> {
        self.cpu.set_reg(Reg32::Eax, regs.eax);
        self.cpu.set_reg(Reg32::Ecx, regs.ecx);
        self.cpu.set_reg(Reg32::Edx, regs.edx);
        self.cpu.set_reg(Reg32::Ebx, regs.ebx);
        self.cpu.set_reg(Reg32::Esp, regs.esp);
        self.cpu.set_reg(Reg32::Ebp, regs.ebp);
        self.cpu.set_reg(Reg32::Esi, regs.esi);
        self.cpu.set_reg(Reg32::Edi, regs.edi);
        self.cpu.eip = regs.eip;
        // eflags / segments / FPU / SSE: silently dropped (unmodeled).
        Ok(())
    }

    fn read_addrs(&mut self, start_addr: u32, data: &mut [u8]) -> TargetResult<usize, Self> {
        // gdb often probes with `m` past the live mapping (e.g. `x/i`
        // beyond the last loaded page). Return a short count when we
        // hit unmapped — gdb handles that gracefully and shows
        // "Cannot access memory" for the missing tail.
        let mut n: usize = 0;
        for d in data.iter_mut() {
            let addr = start_addr.wrapping_add(u32::try_from(n).unwrap_or(u32::MAX));
            match self.mem.read_u8(addr) {
                Ok(b) => {
                    *d = b;
                    n = n.saturating_add(1);
                }
                Err(_) => break,
            }
        }
        Ok(n)
    }

    fn write_addrs(&mut self, start_addr: u32, data: &[u8]) -> TargetResult<(), Self> {
        for (i, &b) in data.iter().enumerate() {
            let addr = start_addr.wrapping_add(u32::try_from(i).unwrap_or(u32::MAX));
            self.mem
                .write_u8(addr, b)
                .map_err(|_| TargetError::NonFatal)?;
        }
        Ok(())
    }

    #[inline(always)]
    fn support_resume(&mut self) -> Option<SingleThreadResumeOps<'_, Self>> {
        Some(self)
    }
}

impl SingleThreadResume for GdbTarget {
    fn resume(&mut self, signal: Option<GdbSignal>) -> Result<(), Self::Error> {
        // movie86 doesn't model guest signal injection. gdb `c <sig>`
        // is uncommon for movfuscator workflows; reject loudly.
        if signal.is_some() {
            return Err("signal injection (continue with signal) not supported");
        }
        self.exec_mode = ExecMode::Continue;
        Ok(())
    }

    #[inline(always)]
    fn support_single_step(&mut self) -> Option<SingleThreadSingleStepOps<'_, Self>> {
        Some(self)
    }
}

impl SingleThreadSingleStep for GdbTarget {
    fn step(&mut self, signal: Option<GdbSignal>) -> Result<(), Self::Error> {
        if signal.is_some() {
            return Err("signal injection (step with signal) not supported");
        }
        self.exec_mode = ExecMode::Step;
        Ok(())
    }
}

impl Breakpoints for GdbTarget {
    #[inline(always)]
    fn support_sw_breakpoint(&mut self) -> Option<SwBreakpointOps<'_, Self>> {
        Some(self)
    }
}

impl SwBreakpoint for GdbTarget {
    fn add_sw_breakpoint(&mut self, addr: u32, _kind: usize) -> TargetResult<bool, Self> {
        if !self.breakpoints.contains(&addr) {
            self.breakpoints.push(addr);
        }
        Ok(true)
    }

    fn remove_sw_breakpoint(&mut self, addr: u32, _kind: usize) -> TargetResult<bool, Self> {
        let before = self.breakpoints.len();
        self.breakpoints.retain(|&a| a != addr);
        Ok(self.breakpoints.len() != before)
    }
}

/// Translate a movie86 [`Fault`] (except `Exit`, which is its own
/// path) into the gdb signal we report to the client.
fn fault_to_signal(f: Fault) -> GdbSignal {
    match f {
        Fault::Unmapped(_) => GdbSignal::SIGSEGV,
        Fault::UnknownOpcode(_) | Fault::UnsupportedInterrupt(_) | Fault::DecodeTruncated => {
            GdbSignal::SIGILL
        }
        Fault::UnimplementedMov | Fault::UnknownSyscall(_) | Fault::UnsupportedAbiCall(_) => {
            GdbSignal::SIGSYS
        }
        // The signum payload carries the actual guest signal that
        // fired without a handler — preserve it so gdb shows the
        // right reason. `Signal::Segv` (11) → SIGSEGV, `Signal::Ill`
        // (4) → SIGILL. Anything else falls back to SIGTRAP (we
        // shouldn't be raising other signal numbers today).
        Fault::SignalHandlerUnregistered(n) => match n {
            n if n == Signal::Segv as u32 => GdbSignal::SIGSEGV,
            n if n == Signal::Ill as u32 => GdbSignal::SIGILL,
            _ => GdbSignal::SIGTRAP,
        },
        // Exit is handled before we get here — but be defensive.
        Fault::Exit(_) => GdbSignal::SIGTERM,
    }
}

/// `BlockingEventLoop` glue between movie86's run-step model and
/// gdbstub's "pump until next stop" model. Translates [`RunEvent`]s
/// to [`SingleThreadStopReason`]s.
enum MovieGdbEventLoop {}

impl run_blocking::BlockingEventLoop for MovieGdbEventLoop {
    type Target = GdbTarget;
    type Connection = Box<dyn ConnectionExt<Error = io::Error>>;
    type StopReason = SingleThreadStopReason<u32>;

    #[allow(clippy::type_complexity)]
    fn wait_for_stop_reason(
        target: &mut GdbTarget,
        conn: &mut Self::Connection,
    ) -> Result<
        run_blocking::Event<SingleThreadStopReason<u32>>,
        run_blocking::WaitForStopReasonError<
            <GdbTarget as Target>::Error,
            <Self::Connection as Connection>::Error,
        >,
    > {
        // Cheap nonblocking peek so a `c` loop can be interrupted by
        // gdb (typically Ctrl-C). The closure runs once per step.
        // True if gdb sent us a byte during the run (Ctrl-C → SIGINT)
        // OR the peek itself errored — treat connection trouble as
        // "incoming" so the loop surrenders and the outer error path
        // gets to handle it instead of spinning on a broken socket.
        let poll_incoming_data = || matches!(conn.peek(), Ok(Some(_)) | Err(_));

        match target.run(poll_incoming_data) {
            RunEvent::IncomingData => {
                let byte = conn
                    .read()
                    .map_err(run_blocking::WaitForStopReasonError::Connection)?;
                Ok(run_blocking::Event::IncomingData(byte))
            }
            RunEvent::DoneStep => Ok(run_blocking::Event::TargetStopped(
                SingleThreadStopReason::DoneStep,
            )),
            RunEvent::Break => Ok(run_blocking::Event::TargetStopped(
                SingleThreadStopReason::SwBreak(()),
            )),
            RunEvent::Exit(status) => {
                // gdb's W packet takes a single-byte exit code (Linux
                // convention). Match how RunOutcome::process_exit_code
                // truncates.
                let lo = u8::try_from(status & 0xff).unwrap_or(0xff);
                Ok(run_blocking::Event::TargetStopped(
                    SingleThreadStopReason::Exited(lo),
                ))
            }
            RunEvent::Fault(f) => Ok(run_blocking::Event::TargetStopped(
                SingleThreadStopReason::Signal(fault_to_signal(f)),
            )),
        }
    }

    fn on_interrupt(
        _target: &mut GdbTarget,
    ) -> Result<Option<SingleThreadStopReason<u32>>, <GdbTarget as Target>::Error> {
        // `run` returned IncomingData → gdbstub reads the Ctrl-C byte
        // → calls this. Report SIGINT and stop.
        Ok(Some(SingleThreadStopReason::Signal(GdbSignal::SIGINT)))
    }
}

/// Errors from [`run_elf_with_gdb`].
#[derive(Debug)]
pub enum GdbRunError {
    Load(ElfError),
    Io(io::Error),
    /// `gdbstub` itself errored. The string is the formatted error;
    /// callers typically just `eprintln!` it.
    Stub(String),
}

impl std::fmt::Display for GdbRunError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Load(e) => write!(f, "load error: {e:?}"),
            Self::Io(e) => write!(f, "io error: {e}"),
            Self::Stub(s) => write!(f, "gdbstub error: {s}"),
        }
    }
}

impl std::error::Error for GdbRunError {}

impl From<io::Error> for GdbRunError {
    fn from(e: io::Error) -> Self {
        Self::Io(e)
    }
}

/// Load an ELF and run it under a gdb stub listening on `listen`.
///
/// Blocks until gdb connects, then drives the RSP protocol until the
/// gdb client disconnects, the guest exits, or a fatal stub error.
pub fn run_elf_with_gdb(bytes: &[u8], listen: SocketAddr) -> Result<DisconnectReason, GdbRunError> {
    // Shared bootstrap with run_elf_with_debug — parse, flatten, wire
    // signal handlers from .symtab, scan libc stubs.
    let elf = parse(bytes).map_err(GdbRunError::Load)?;
    let (mem, esp_initial) =
        flatten_with_stack(&elf, DEFAULT_STACK_SIZE).map_err(GdbRunError::Load)?;
    let mut cpu = Cpu::new(elf.entry);
    cpu.set_reg(Reg32::Esp, esp_initial);
    if let Some(addr) = elf.find_symbol("dispatch") {
        cpu.set_signal_handler(Signal::Segv, addr);
    }
    if let Some(addr) = elf.find_symbol("master_loop") {
        cpu.set_signal_handler(Signal::Ill, addr);
    }
    let mut host = StdHost::default();
    host.scan_libc_stubs(&elf, &mem);

    let mut target = GdbTarget {
        cpu,
        mem,
        host,
        breakpoints: Vec::new(),
        // Default to Continue so the very first `wait_for_stop_reason`
        // call from gdbstub (issued before any user `c`) hangs in the
        // run loop waiting for a packet or breakpoint, not no-ops out
        // of a single Step.
        exec_mode: ExecMode::Continue,
    };

    let listener = TcpListener::bind(listen)?;
    let bound = listener.local_addr()?;
    eprintln!("movie86: waiting for gdb on {bound}");
    eprintln!("  in gdb: target remote {bound}");
    let (stream, peer) = listener.accept()?;
    eprintln!("movie86: gdb attached from {peer}");

    let conn: Box<dyn ConnectionExt<Error = io::Error>> = Box::new(stream);
    let stub = GdbStub::new(conn);
    stub.run_blocking::<MovieGdbEventLoop>(&mut target)
        .map_err(|e| GdbRunError::Stub(format!("{e:?}")))
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Build a `GdbTarget` with a tiny program at `0x1000` — `mov
    /// eax, 42; int 0x80` (`SYS_exit`). Useful for unit-testing the
    /// trait impls without a real gdb client.
    fn make_target() -> GdbTarget {
        let mut mem = FlatMemory::new_zeroed(0x1000, 0x100);
        // mov eax, 1   (SYS_exit)
        mem.write_bytes(0x1000, &[0xb8, 0x01, 0x00, 0x00, 0x00])
            .unwrap();
        // mov ebx, 42
        mem.write_bytes(0x1005, &[0xbb, 0x2a, 0x00, 0x00, 0x00])
            .unwrap();
        // int 0x80
        mem.write_bytes(0x100a, &[0xcd, 0x80]).unwrap();
        let mut cpu = Cpu::new(0x1000);
        cpu.set_reg(Reg32::Esp, 0x1100);
        GdbTarget {
            cpu,
            mem,
            host: StdHost::default(),
            breakpoints: Vec::new(),
            exec_mode: ExecMode::Continue,
        }
    }

    #[test]
    fn read_registers_mirrors_cpu_state() {
        let mut t = make_target();
        t.cpu.set_reg(Reg32::Eax, 0xdead_beef);
        t.cpu.set_reg(Reg32::Esp, 0xcafe_0000);
        t.cpu.eip = 0x0804_8000;
        let mut regs = X86CoreRegs::default();
        SingleThreadBase::read_registers(&mut t, &mut regs)
            .ok()
            .unwrap();
        assert_eq!(regs.eax, 0xdead_beef);
        assert_eq!(regs.esp, 0xcafe_0000);
        assert_eq!(regs.eip, 0x0804_8000);
        // EFLAGS is the documented placeholder — must NOT leak guest
        // garbage. Always 0 until we model flags.
        assert_eq!(regs.eflags, 0);
    }

    #[test]
    fn write_registers_drops_eflags_and_segments() {
        // gdb's `set $eflags = 0x202` should not be reflected back as
        // a change in movie86 state — we silently drop unmodeled
        // register writes. Verified by writing EFLAGS and re-reading.
        let mut t = make_target();
        let regs = X86CoreRegs {
            eax: 7,
            eip: 0x0804_8001,
            eflags: 0x202,
            ..X86CoreRegs::default()
        };
        SingleThreadBase::write_registers(&mut t, &regs)
            .ok()
            .unwrap();
        assert_eq!(t.cpu.reg(Reg32::Eax), 7);
        assert_eq!(t.cpu.eip, 0x0804_8001);
        // No place for eflags to land — read it back, still 0.
        let mut got = X86CoreRegs::default();
        SingleThreadBase::read_registers(&mut t, &mut got)
            .ok()
            .unwrap();
        assert_eq!(got.eflags, 0);
    }

    #[test]
    fn read_addrs_short_counts_at_unmapped_boundary() {
        // Region is 0x100 bytes from 0x1000; reading from 0x10f8 for
        // 0x20 bytes should return n=8 (the bytes inside the map)
        // rather than panicking or returning a fault.
        let mut t = make_target();
        let mut buf = [0xffu8; 0x20];
        let n = SingleThreadBase::read_addrs(&mut t, 0x10f8, &mut buf)
            .ok()
            .unwrap();
        assert_eq!(n, 8, "should short-count at the end of the map");
    }

    #[test]
    fn sw_breakpoint_add_remove_idempotent() {
        let mut t = make_target();
        assert!(SwBreakpoint::add_sw_breakpoint(&mut t, 0x1005, 0)
            .ok()
            .unwrap());
        // Adding the same addr twice doesn't duplicate (idempotent set).
        assert!(SwBreakpoint::add_sw_breakpoint(&mut t, 0x1005, 0)
            .ok()
            .unwrap());
        assert_eq!(t.breakpoints, vec![0x1005]);
        // Removing returns true (we found something), then false.
        assert!(SwBreakpoint::remove_sw_breakpoint(&mut t, 0x1005, 0)
            .ok()
            .unwrap());
        assert!(!SwBreakpoint::remove_sw_breakpoint(&mut t, 0x1005, 0)
            .ok()
            .unwrap());
    }

    #[test]
    fn continue_run_stops_at_breakpoint_before_executing_it() {
        // Hits the breakpoint check BEFORE stepping, so eip remains
        // *at* the breakpoint address — same semantic as gdb's classic
        // "stopped at PC = breakpoint" model.
        let mut t = make_target();
        SwBreakpoint::add_sw_breakpoint(&mut t, 0x1005, 0)
            .ok()
            .unwrap();
        t.exec_mode = ExecMode::Continue;
        // step 0x1000 (mov eax,1) → eip=0x1005, hit breakpoint, stop.
        let ev = t.run(|| false);
        assert!(matches!(ev, RunEvent::Break), "got {ev:?}");
        assert_eq!(t.cpu.eip, 0x1005);
    }

    #[test]
    fn continue_run_terminates_on_guest_exit() {
        // Default exec_mode is Continue; the program does SYS_exit(42).
        let mut t = make_target();
        let ev = t.run(|| false);
        match ev {
            RunEvent::Exit(42) => {}
            other => panic!("expected Exit(42), got {other:?}"),
        }
    }

    #[test]
    fn single_step_advances_exactly_one_instruction() {
        let mut t = make_target();
        t.exec_mode = ExecMode::Step;
        let ev = t.run(|| false);
        assert!(matches!(ev, RunEvent::DoneStep), "got {ev:?}");
        assert_eq!(
            t.cpu.eip, 0x1005,
            "eip should advance by 5 bytes (mov eax, 1)"
        );
    }

    #[test]
    fn continue_run_returns_incoming_data_when_poll_signals_it() {
        // If gdb signals "I have data for you" we must surrender the
        // run loop ASAP so Ctrl-C is responsive.
        let mut t = make_target();
        let ev = t.run(|| true);
        assert!(matches!(ev, RunEvent::IncomingData), "got {ev:?}");
        // eip didn't advance.
        assert_eq!(t.cpu.eip, 0x1000);
    }

    #[test]
    fn fault_maps_to_gdb_signal_we_expect() {
        // Sanity for the fault → gdb signal table. Not exhaustive —
        // just pins the cases we care about for movfuscator workflows.
        assert_eq!(fault_to_signal(Fault::Unmapped(0)), GdbSignal::SIGSEGV);
        assert_eq!(fault_to_signal(Fault::UnknownOpcode(0)), GdbSignal::SIGILL);
        assert_eq!(
            fault_to_signal(Fault::UnsupportedInterrupt(0x03)),
            GdbSignal::SIGILL,
        );
        assert_eq!(
            fault_to_signal(Fault::UnknownSyscall(999)),
            GdbSignal::SIGSYS
        );
    }

    #[test]
    fn signal_handler_unregistered_preserves_guest_signum() {
        // Regression for codex P2-1: the signum payload was being
        // dropped — every unregistered-handler fault reported SIGTRAP.
        // Now we honor `Signal::Segv` (11) → SIGSEGV and `Signal::Ill`
        // (4) → SIGILL so an ELF that lacks the dispatch / master_loop
        // symbols still gets a faithful stop reason in gdb.
        assert_eq!(
            fault_to_signal(Fault::SignalHandlerUnregistered(Signal::Segv as u32)),
            GdbSignal::SIGSEGV,
        );
        assert_eq!(
            fault_to_signal(Fault::SignalHandlerUnregistered(Signal::Ill as u32)),
            GdbSignal::SIGILL,
        );
        // Unknown signum → SIGTRAP (defensive default; movie86 doesn't
        // raise other signal numbers today).
        assert_eq!(
            fault_to_signal(Fault::SignalHandlerUnregistered(999)),
            GdbSignal::SIGTRAP,
        );
    }
}
