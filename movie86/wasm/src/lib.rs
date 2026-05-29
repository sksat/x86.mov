//! Browser bindings for movie86.
//!
//! Exposes a single [`run_elf`] entry point that takes ELF32 i386 bytes
//! and returns a [`RunResult`] with the guest's stdout, stderr, exit
//! code, fault label, and step count. The host implements the same
//! Linux i386 syscall subset the CLI's `StdHost` does (`write(1/2)` +
//! `exit`) and the same restricted libc-wrapper ABI (`exit`,
//! `sigaction`, `printf`) — output is buffered into `Vec<u8>` instead
//! of going to host stdout, but the semantics match byte-for-byte.

use std::collections::BTreeMap;

use movie86::bios_host::{BiosArgs, BiosHost, BiosResult};
use movie86::context::{capture_sparse_regions, Regs as CoreRegs};
use movie86::decode::decode as decode_insn;
use movie86::elf::{flatten_with_stack, parse, LoadedElf};
use movie86::libc_host::{LibcCall, LibcHost, LibcResult};
use movie86::syscall::{SysHost, SyscallArgs, SyscallResult};
use movie86::{Cpu, Fault, FlatMemory, Memory, Reg32, Signal};

use wasm_bindgen::prelude::*;

const DEFAULT_STACK_SIZE: u32 = 64 * 1024;
const DEFAULT_MAX_STEPS: u64 = 50_000_000;

/// Restricted host-side printf scan bound. Matches the CLI.
const PRINTF_MAX_LEN: u32 = 4096;

#[derive(Clone, Copy, PartialEq, Eq)]
enum LibcFn {
    Exit,
    Sigaction,
    Printf,
}

#[derive(Default)]
struct WasmHost {
    stdout: Vec<u8>,
    stderr: Vec<u8>,
    libc_stubs: BTreeMap<u32, LibcFn>,
    /// VGA-style video mode set by the guest via `int 0x10 ; AH=0`.
    /// `None` until the guest sets a mode (so the demo UI knows to
    /// show "no mode selected" rather than picking a default canvas).
    active_video_mode: Option<u8>,
}

impl SysHost for WasmHost {
    fn syscall(
        &mut self,
        args: &SyscallArgs,
        mem: &mut dyn Memory,
    ) -> Result<SyscallResult, Fault> {
        match args.eax {
            1 => Err(Fault::Exit(args.ebx)),
            4 => self.write_syscall(args, mem),
            _ => Err(Fault::UnknownSyscall(args.eax)),
        }
    }
}

impl WasmHost {
    fn write_syscall(
        &mut self,
        args: &SyscallArgs,
        mem: &mut dyn Memory,
    ) -> Result<SyscallResult, Fault> {
        const CHUNK: usize = 4096;
        let fd = args.ebx;
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
            if mem.read_bytes(addr, slice).is_err() {
                if written > 0 {
                    return Ok(SyscallResult::Return(written));
                }
                return Ok(SyscallResult::Return(errno_to_eax(14)));
            }
            let sink: &mut Vec<u8> = if fd == 1 {
                &mut self.stdout
            } else {
                &mut self.stderr
            };
            sink.extend_from_slice(slice);
            let n_u32 = u32::try_from(this).unwrap_or(u32::MAX);
            written = written.saturating_add(n_u32);
            addr = addr.wrapping_add(n_u32);
            remaining = remaining.saturating_sub(this);
        }
        Ok(SyscallResult::Return(written))
    }
}

impl LibcHost for WasmHost {
    fn libc_call(&mut self, call: &mut LibcCall<'_>) -> Result<LibcResult, Fault> {
        let which = self
            .libc_stubs
            .get(&call.trap_addr)
            .copied()
            .ok_or(Fault::UnsupportedInterrupt(0x81))?;
        match which {
            LibcFn::Exit => Err(Fault::Exit(call.arg_u32(0)?)),
            LibcFn::Sigaction => Ok(LibcResult::Return(0)),
            LibcFn::Printf => libc_printf(call, &mut self.stdout),
        }
    }

    fn scan_libc_stubs(&mut self, elf: &LoadedElf<'_>, mem: &dyn Memory) {
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
                self.libc_stubs.insert(addr, which);
            }
        }
    }
}

impl BiosHost for WasmHost {
    /// BIOS video services (`int 0x10`). Only `AH=0` (set video mode)
    /// is implemented; other subfunctions trap via the default impl.
    ///
    /// The mode number lives in `AL`. We don't validate it here — the
    /// JS side keeps the catalogue (`FRAMEBUFFER_MODES`) and just
    /// ignores any mode it doesn't recognise. Setting an unknown mode
    /// is therefore equivalent to "no canvas selected" in the demo,
    /// matching how real-mode BIOS treats unsupported mode numbers as
    /// a no-op without faulting.
    fn bios_call(&mut self, args: &BiosArgs, _mem: &mut dyn Memory) -> Result<BiosResult, Fault> {
        match args.ah() {
            0 => {
                self.active_video_mode = Some(args.al());
                // Real BIOS returns 0 in AL on success — we follow.
                Ok(BiosResult::Return(0))
            }
            _ => Err(Fault::UnsupportedInterrupt(0x10)),
        }
    }
}

/// mov-only ABI parity with turbo86. The wasm Vm catches writes to the
/// ABI page in `Cpu::step` and routes them here:
///
/// - `CALL_SET_VIDEO_MODE` — `value` (low byte) is the mode, captured
///   into `active_video_mode` the same way `int 0x10 / AH=0` already
///   does. The JS demo reads `vm.activeVideoMode` to pick which
///   canvas to render, so the two entry points produce identical
///   browser-visible behaviour.
/// - `CALL_MMAP_REQUEST` — no-op in wasm because the demo's canvas
///   ELFs declare their FB regions as PT_LOAD entries that the
///   loader already maps via `flatten_with_stack`. The guest still
///   issues the request for portability to turbo86 (where the FB
///   isn't pre-mapped); on wasm it's effectively a "we already have
///   you covered" acknowledgement. Returns Ok so the guest proceeds
///   straight to the FB write.
/// - `CALL_EXIT` — same semantics as `int 0x80 / SYS_exit`: surface
///   the value as `Fault::Exit`, which the existing run loop catches
///   and reports as the final exit status. Lets canvas examples drop
///   the trailing `int 0x80` epilogue entirely.
impl movie86::AbiHost for WasmHost {
    fn abi_call(
        &mut self,
        call_num: u16,
        value: u32,
        regs: &mut [u32; 8],
        mem: &mut dyn Memory,
    ) -> Result<(), Fault> {
        match call_num {
            movie86::CALL_SET_VIDEO_MODE => {
                self.active_video_mode = Some((value & 0xFF) as u8);
                Ok(())
            }
            movie86::CALL_MMAP_REQUEST => Ok(()),
            movie86::CALL_EXIT => Err(Fault::Exit(value)),
            movie86::CALL_WRITE => {
                let fd = regs[Reg32::Ebx as usize];
                let buf = regs[Reg32::Ecx as usize];
                let len = regs[Reg32::Edx as usize];
                let n = self.abi_write(fd, buf, len, mem);
                regs[Reg32::Eax as usize] = n;
                Ok(())
            }
            _ => Err(Fault::UnsupportedAbiCall(call_num)),
        }
    }
}

impl WasmHost {
    /// Buffered write that mirrors the existing `write_syscall` flow:
    /// stdout/stderr each get their own `Vec<u8>`, JS pulls the bytes
    /// via `drainStdout` / `drainStderr`. Bad fd → -EBADF, unreadable
    /// memory → partial count or -EFAULT (same as the int 0x80 path).
    fn abi_write(&mut self, fd: u32, buf: u32, len: u32, mem: &mut dyn Memory) -> u32 {
        const CHUNK: usize = 4096;
        if fd != 1 && fd != 2 {
            return 0u32.wrapping_sub(9);
        }
        let mut addr = buf;
        let mut remaining = len as usize;
        let mut written: u32 = 0;
        let mut scratch = [0u8; CHUNK];
        while remaining > 0 {
            let this = remaining.min(CHUNK);
            let slice = &mut scratch[..this];
            if mem.read_bytes(addr, slice).is_err() {
                if written > 0 {
                    return written;
                }
                return 0u32.wrapping_sub(14);
            }
            let sink: &mut Vec<u8> = if fd == 1 {
                &mut self.stdout
            } else {
                &mut self.stderr
            };
            sink.extend_from_slice(slice);
            let n_u32 = u32::try_from(this).unwrap_or(u32::MAX);
            written = written.saturating_add(n_u32);
            addr = addr.wrapping_add(n_u32);
            remaining = remaining.saturating_sub(this);
        }
        written
    }
}

/// Host-side `printf(fmt, ...)` — copy of `movie86-cli`'s, but writes
/// into a caller-owned buffer instead of `io::stdout()`. Same restricted
/// subset (`%s`, `%d`, `%c`, `%%`) — `%n` and unknown conversions abort
/// the call with -1, matching the CLI.
fn libc_printf(call: &mut LibcCall<'_>, out: &mut Vec<u8>) -> Result<LibcResult, Fault> {
    let fmt_ptr = call.arg_u32(0)?;
    let mut p = fmt_ptr;
    let mut scanned: u32 = 0;
    let mut next_arg_idx: usize = 1;
    let mut written: u32 = 0;
    let mut buf: Vec<u8> = Vec::with_capacity(64);

    loop {
        if scanned >= PRINTF_MAX_LEN {
            out.extend_from_slice(&buf);
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
                    let c = u8::try_from(call.arg_u32(next_arg_idx)? & 0xff).unwrap_or(0);
                    next_arg_idx += 1;
                    buf.push(c);
                    written = written.saturating_add(1);
                }
                b'%' => {
                    buf.push(b'%');
                    written = written.saturating_add(1);
                }
                // `%n` (format-string write-where) and unknown
                // conversions both abort with -1, matching the CLI.
                _ => {
                    out.extend_from_slice(&buf);
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
    out.extend_from_slice(&buf);
    Ok(LibcResult::Return(written))
}

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

/// Two's complement of `errno`, in the bit pattern Linux puts in EAX
/// for `-errno` returns. Matches the CLI's `errno_to_eax`.
fn errno_to_eax(errno: u32) -> u32 {
    u32::MAX - errno + 1
}

/// Result of one [`run_elf`] invocation, surfaced to JS.
#[wasm_bindgen]
pub struct RunResult {
    stdout_buf: Vec<u8>,
    stderr_buf: Vec<u8>,
    exit_code: i32,
    fault_label: Option<String>,
    steps: u64,
}

#[wasm_bindgen]
impl RunResult {
    #[wasm_bindgen(getter)]
    pub fn stdout(&self) -> String {
        String::from_utf8_lossy(&self.stdout_buf).into_owned()
    }

    #[wasm_bindgen(getter)]
    pub fn stderr(&self) -> String {
        String::from_utf8_lossy(&self.stderr_buf).into_owned()
    }

    #[wasm_bindgen(getter, js_name = stdoutBytes)]
    pub fn stdout_bytes(&self) -> Vec<u8> {
        self.stdout_buf.clone()
    }

    #[wasm_bindgen(getter, js_name = stderrBytes)]
    pub fn stderr_bytes(&self) -> Vec<u8> {
        self.stderr_buf.clone()
    }

    #[wasm_bindgen(getter, js_name = exitCode)]
    pub fn exit_code(&self) -> i32 {
        self.exit_code
    }

    /// `null` on clean exit, or a debug label of the [`Fault`] variant
    /// (`"Exit(0)"`, `"UnknownOpcode(0xff)"`, `"MaxSteps(50000000)"`, …).
    #[wasm_bindgen(getter)]
    pub fn fault(&self) -> Option<String> {
        self.fault_label.clone()
    }

    #[wasm_bindgen(getter)]
    pub fn steps(&self) -> u64 {
        self.steps
    }
}

/// Load `bytes` as an ELF32 i386 executable, run it under the wasm host,
/// and return a [`RunResult`]. `maxSteps` defaults to 50 000 000 — the
/// emulator otherwise runs unbounded, which would hang the browser tab
/// on a movfuscator binary in a tight master_loop.
#[wasm_bindgen(js_name = runElf)]
pub fn run_elf(bytes: &[u8], max_steps: Option<u64>) -> RunResult {
    let max = max_steps.unwrap_or(DEFAULT_MAX_STEPS);

    let elf = match parse(bytes) {
        Ok(e) => e,
        Err(e) => return RunResult::load_error(format!("{e:?}")),
    };
    let (mut mem, esp_initial) = match flatten_with_stack(&elf, DEFAULT_STACK_SIZE) {
        Ok(p) => p,
        Err(e) => return RunResult::load_error(format!("{e:?}")),
    };

    let mut cpu = Cpu::new(elf.entry);
    cpu.set_reg(Reg32::Esp, esp_initial);
    if let Some(addr) = elf.find_symbol("dispatch") {
        cpu.set_signal_handler(Signal::Segv, addr);
    }
    if let Some(addr) = elf.find_symbol("master_loop") {
        cpu.set_signal_handler(Signal::Ill, addr);
    }

    let mut host = WasmHost::default();
    host.scan_libc_stubs(&elf, &mem);

    let mut steps: u64 = 0;
    loop {
        if steps >= max {
            return RunResult {
                stdout_buf: host.stdout,
                stderr_buf: host.stderr,
                exit_code: 1,
                fault_label: Some(format!("MaxSteps({max})")),
                steps,
            };
        }
        match cpu.step(&mut mem, &mut host) {
            Ok(()) => steps += 1,
            Err(Fault::Exit(status)) => {
                return RunResult {
                    stdout_buf: host.stdout,
                    stderr_buf: host.stderr,
                    exit_code: i32::from((status & 0xff) as u8),
                    fault_label: None,
                    steps,
                };
            }
            Err(e) => {
                return RunResult {
                    stdout_buf: host.stdout,
                    stderr_buf: host.stderr,
                    exit_code: 1,
                    fault_label: Some(format!("{e:?}")),
                    steps,
                };
            }
        }
    }
}

impl RunResult {
    fn load_error(detail: String) -> Self {
        Self {
            stdout_buf: Vec::new(),
            stderr_buf: Vec::new(),
            exit_code: 2,
            fault_label: Some(format!("LoadError: {detail}")),
            steps: 0,
        }
    }
}

/// Step-driven emulator handle. JS holds one of these to drive the
/// guest one (or many) instruction at a time, sampling register /
/// memory state between batches. Created by [`Vm::new`].
///
/// Distinct from [`run_elf`] (which runs to completion) because
/// surfacing live execution state needs JS-side control over how often
/// the wasm boundary is crossed — naïve "step once per JS callback"
/// is fine when the user actually wants to watch every instruction,
/// but for a fast `Run` the demo batches thousands of steps per call
/// and only rerenders the UI on a timer.
#[wasm_bindgen]
pub struct Vm {
    cpu: Cpu,
    mem: FlatMemory,
    host: WasmHost,
    steps: u64,
    halt: Option<String>,
    exit_code: Option<i32>,
}

#[wasm_bindgen]
impl Vm {
    /// Load `bytes` as an ELF32 i386 executable and prepare it for
    /// stepwise execution. Returns a [`Vm`] on success or surfaces the
    /// load error via [`JsError`].
    #[wasm_bindgen(constructor)]
    pub fn new(bytes: &[u8]) -> Result<Vm, JsError> {
        let elf = parse(bytes).map_err(|e| JsError::new(&format!("LoadError: {e:?}")))?;
        let (mem, esp_initial) = flatten_with_stack(&elf, DEFAULT_STACK_SIZE)
            .map_err(|e| JsError::new(&format!("LoadError: {e:?}")))?;
        let mut cpu = Cpu::new(elf.entry);
        cpu.set_reg(Reg32::Esp, esp_initial);
        if let Some(addr) = elf.find_symbol("dispatch") {
            cpu.set_signal_handler(Signal::Segv, addr);
        }
        if let Some(addr) = elf.find_symbol("master_loop") {
            cpu.set_signal_handler(Signal::Ill, addr);
        }
        let mut host = WasmHost::default();
        host.scan_libc_stubs(&elf, &mem);
        Ok(Self {
            cpu,
            mem,
            host,
            steps: 0,
            halt: None,
            exit_code: None,
        })
    }

    /// Run up to `n` instructions. Returns the number of instructions
    /// actually executed (may be less than `n` if the guest halted).
    /// Once halted, further calls are no-ops returning 0.
    #[wasm_bindgen(js_name = stepN)]
    pub fn step_n(&mut self, n: u64) -> u64 {
        if self.halt.is_some() {
            return 0;
        }
        let mut ran: u64 = 0;
        while ran < n {
            match self.cpu.step(&mut self.mem, &mut self.host) {
                Ok(()) => {
                    self.steps += 1;
                    ran += 1;
                }
                Err(Fault::Exit(status)) => {
                    self.exit_code = Some(i32::from((status & 0xff) as u8));
                    self.halt = Some(format!("Exit({status})"));
                    return ran;
                }
                Err(e) => {
                    self.exit_code = Some(1);
                    self.halt = Some(format!("{e:?}"));
                    return ran;
                }
            }
        }
        ran
    }

    /// Convenience: one instruction.
    pub fn step(&mut self) -> u64 {
        self.step_n(1)
    }

    /// 8 GPRs in [`Reg32`] order: eax, ecx, edx, ebx, esp, ebp, esi, edi.
    /// Returned as a `Vec<u32>` which wasm-bindgen surfaces as a
    /// `Uint32Array` to JS.
    #[wasm_bindgen(getter)]
    pub fn regs(&self) -> Vec<u32> {
        self.cpu.regs.to_vec()
    }

    #[wasm_bindgen(getter)]
    pub fn eip(&self) -> u32 {
        self.cpu.eip
    }

    #[wasm_bindgen(getter)]
    pub fn steps(&self) -> u64 {
        self.steps
    }

    /// `null` while running, otherwise a debug label of why the guest
    /// stopped — `"Exit(0)"`, `"UnknownOpcode(0xff)"`, …
    #[wasm_bindgen(getter, js_name = haltReason)]
    pub fn halt_reason(&self) -> Option<String> {
        self.halt.clone()
    }

    /// `null` while running, otherwise the guest's exit code (low 8
    /// bits of the `exit(2)` status, or `1` for fault).
    #[wasm_bindgen(getter, js_name = exitCode)]
    pub fn exit_code(&self) -> Option<i32> {
        self.exit_code
    }

    /// Take stdout produced since the last drain. Empties the buffer
    /// so the JS side can append-without-duplication after each tick.
    #[wasm_bindgen(js_name = drainStdout)]
    pub fn drain_stdout(&mut self) -> Vec<u8> {
        core::mem::take(&mut self.host.stdout)
    }

    /// Take stderr produced since the last drain.
    #[wasm_bindgen(js_name = drainStderr)]
    pub fn drain_stderr(&mut self) -> Vec<u8> {
        core::mem::take(&mut self.host.stderr)
    }

    /// Address of the registered SIGSEGV handler (movfuscator's
    /// `dispatch`), or `None` if the loader didn't find the symbol.
    /// Real, post-load-immutable state — populated by the loader
    /// scanning the ELF symbol table.
    ///
    /// Note: we intentionally do **not** expose `eflags` or segment
    /// registers because movie86 doesn't model them. EFLAGS would be
    /// dead state (no arithmetic / no `cmp`/`jcc` in scope), and the
    /// `Cpu` struct simply has no segment-register fields — the only
    /// supported `mov sreg, ...` form is `mov cs, ax`, which is
    /// modelled as the SIGILL-dispatch trick rather than as an
    /// actual write to CS.
    #[wasm_bindgen(getter, js_name = sigsegvHandler)]
    pub fn sigsegv_handler(&self) -> Option<u32> {
        self.cpu.signal_handler(Signal::Segv)
    }

    /// Address of the registered SIGILL handler (movfuscator's
    /// `master_loop`), or `None`.
    #[wasm_bindgen(getter, js_name = sigillHandler)]
    pub fn sigill_handler(&self) -> Option<u32> {
        self.cpu.signal_handler(Signal::Ill)
    }

    /// VGA-style video mode set by the guest via `int 0x10 ; AH=0`
    /// (mode number from `AL`). `None` until the guest sets one; the
    /// demo uses this to decide which canvas to show — examples that
    /// never call `int 0x10` get no canvas, mirroring real BIOS where
    /// "no mode set yet" means there's nothing to draw.
    #[wasm_bindgen(getter, js_name = activeVideoMode)]
    pub fn active_video_mode(&self) -> Option<u8> {
        self.host.active_video_mode
    }

    #[wasm_bindgen(getter, js_name = memBase)]
    pub fn mem_base(&self) -> u32 {
        self.mem.base()
    }

    #[wasm_bindgen(getter, js_name = memLen)]
    pub fn mem_len(&self) -> u32 {
        u32::try_from(self.mem.len()).unwrap_or(u32::MAX)
    }

    /// Decode the instruction at `addr`. Returns `None` if the address
    /// is unreadable or the bytes don't form a complete instruction —
    /// the demo uses this to render a "next-N-instructions" pane with
    /// the current EIP highlighted, so a short / unmapped read at the
    /// end of the segment just stops the listing instead of crashing.
    #[wasm_bindgen(js_name = disasmAt)]
    pub fn disasm_at(&self, addr: u32) -> Option<DecodedInsn> {
        // Read up to MAX_INSN_LEN bytes. Tolerate short reads: a 1-byte
        // C3 (`ret`) at the very end of a segment is still a valid
        // instruction even though we couldn't fill 15 bytes.
        let mut buf = [0u8; 15];
        let mut n = 0usize;
        for i in 0..15u32 {
            match self.mem.read_u8(addr.wrapping_add(i)) {
                Ok(b) => {
                    buf[n] = b;
                    n += 1;
                }
                Err(_) => break,
            }
        }
        if n == 0 {
            return None;
        }
        match decode_insn(&buf[..n]) {
            Ok((insn, len)) => {
                let len_usize = len as usize;
                Some(DecodedInsn {
                    addr,
                    bytes_buf: buf[..len_usize].to_vec(),
                    text_buf: format!("{insn}"),
                    len_val: u32::from(len),
                })
            }
            Err(_) => None,
        }
    }

    /// Read up to `len` bytes starting at guest address `addr`. Bytes
    /// outside the mapped region are skipped — the returned slice can
    /// be shorter than requested. Used by the demo's memory viewer
    /// without forcing it to know the loader's mapping.
    #[wasm_bindgen(js_name = readMem)]
    pub fn read_mem(&self, addr: u32, len: u32) -> Vec<u8> {
        let base = self.mem.base();
        let mem_end = u64::from(base) + self.mem.len() as u64;
        let req_start = u64::from(addr);
        let req_end = req_start.saturating_add(u64::from(len));
        let start = req_start.max(u64::from(base));
        let end = req_end.min(mem_end);
        if end <= start {
            return Vec::new();
        }
        // Both bounds now fit in the mapped region, so the unwraps
        // below are correct: `read_bytes` only fails if a byte is
        // unmapped, which can't happen after the clamp.
        let len_usize = (end - start) as usize;
        let mut buf = vec![0u8; len_usize];
        if self.mem.read_bytes(start as u32, &mut buf).is_err() {
            return Vec::new();
        }
        buf
    }

    /// Apply `bytes` into guest memory starting at `addr`. Bytes that
    /// fall outside the Vm's mapped region are silently skipped;
    /// returns the count of bytes actually written.
    ///
    /// Used by the demo when receiving a turbo86 `MemUpdate` Outbound
    /// during a handover — the snapshot covers the wasm Vm's mapped
    /// range plus turbo86's stub regions, and we want the canvas to
    /// progressively reflect the in-flight decode without crashing on
    /// regions (e.g. the stub's stack at 0x70000000+) that the wasm
    /// Vm doesn't map.
    #[wasm_bindgen(js_name = writeMem)]
    pub fn write_mem(&mut self, addr: u32, bytes: &[u8]) -> u32 {
        let base = self.mem.base();
        let mem_end = u64::from(base) + self.mem.len() as u64;
        let req_start = u64::from(addr);
        let req_end = req_start.saturating_add(bytes.len() as u64);
        let start = req_start.max(u64::from(base));
        let end = req_end.min(mem_end);
        if end <= start {
            return 0;
        }
        let skip_head = (start - req_start) as usize;
        let take_len = (end - start) as usize;
        let slice = &bytes[skip_head..skip_head + take_len];
        if self.mem.write_bytes(start as u32, slice).is_err() {
            return 0;
        }
        take_len as u32
    }

    /// Capture the canonical migration snapshot of the current guest
    /// state: 10-word register file (GPRs + EIP + EFLAGS) and the
    /// sparse memory regions (non-zero 4 KiB pages merged into runs).
    ///
    /// The schema matches the core crate's
    /// [`movie86::context::Context`], which in turn matches turbo86's
    /// `proto.Context` byte-for-byte once JSON-encoded by the JS
    /// wrapper — so a snapshot taken here can be handed to turbo86 via
    /// `LoadContext` and resumed.
    ///
    /// The JS wrapper in `movie86.mjs` provides `snapshotContext(vm)`
    /// + `makeLoadContextMessage(ctx, mode)` on top of this; UI code
    /// should call those instead of poking the raw struct, but the
    /// struct's getters are public for tests that want field-level
    /// assertions without going through JSON.
    #[wasm_bindgen(js_name = snapshotContext)]
    pub fn snapshot_context(&self) -> ContextSnapshot {
        let regs = CoreRegs::from_cpu(&self.cpu);
        let base = self.mem.base();
        let len = u32::try_from(self.mem.len()).unwrap_or(u32::MAX);
        // `capture_sparse_regions` only faults when a read goes outside
        // the mapped extent; we ask for exactly `[base, base + len)`,
        // which by construction is inside the FlatMemory region, so the
        // unwrap can't fire.
        let regions = capture_sparse_regions(&self.mem, base, len)
            .expect("capture_sparse_regions inside FlatMemory's own extent should never fault");
        let region_addrs = regions.iter().map(|r| r.addr).collect();
        let region_bytes = regions.into_iter().map(|r| r.bytes).collect();
        ContextSnapshot {
            regs,
            region_addrs,
            region_bytes,
        }
    }

    /// Apply a `ContextSnapshot` to this Vm — write each region into
    /// guest memory, then load the register file, then clear the halt
    /// state so the Vm can resume execution. The inverse of
    /// `snapshotContext`.
    ///
    /// Used for the reverse handoff (turbo86 → movie86): a `Paused`
    /// Outbound carries Regs + Regions; the JS wrapper deserializes
    /// it, builds a `ContextSnapshot`, and calls this to "absorb" the
    /// state back into the local Vm so `Run` continues from there.
    ///
    /// Lossy semantics: regions that fall outside the local Vm's
    /// mapped extent (typically turbo86's stack region at 0x70000000+
    /// which movie86's much smaller `FlatMemory` doesn't cover) are
    /// skipped instead of erroring. The returned summary's `skipped`
    /// count lets the UI surface that — the stack-resident bits of
    /// the snapshot are lost, but everything in the code region
    /// lands, which is sufficient for resuming most movfuscator-shape
    /// programs whose hot state lives in code+regs rather than stack.
    #[wasm_bindgen(js_name = loadContext)]
    pub fn load_context(&mut self, snap: &ContextSnapshot) -> LoadContextSummary {
        let mut applied: u32 = 0;
        let mut skipped: u32 = 0;
        for (idx, &addr) in snap.region_addrs.iter().enumerate() {
            let bytes = &snap.region_bytes[idx];
            if self.mem.write_bytes(addr, bytes).is_ok() {
                applied += 1;
            } else {
                skipped += 1;
            }
        }
        snap.regs.load_into(&mut self.cpu);
        // Restoring resets halt: a snapshot was taken from a running
        // (or pre-run) Vm by definition, so clear the cached fault /
        // exit label. Step / Run can then re-evaluate from the
        // restored EIP.
        self.halt = None;
        self.exit_code = None;
        LoadContextSummary { applied, skipped }
    }
}

/// Result of [`Vm::loadContext`]: how many of the snapshot's regions
/// landed inside the Vm's mapped memory, and how many had to be
/// dropped because they were outside the mapping (e.g. turbo86 stack
/// region 0x70000000+ when restoring into a small movie86 FlatMemory).
#[wasm_bindgen]
pub struct LoadContextSummary {
    applied: u32,
    skipped: u32,
}

#[wasm_bindgen]
impl LoadContextSummary {
    #[wasm_bindgen(getter)]
    pub fn applied(&self) -> u32 {
        self.applied
    }

    #[wasm_bindgen(getter)]
    pub fn skipped(&self) -> u32 {
        self.skipped
    }
}

/// JS-visible mirror of [`movie86::context::Context`] — 10 register
/// fields plus a list of (addr, bytes) regions. Returned by
/// [`Vm::snapshotContext`]; the JS wrapper in `movie86.mjs` walks the
/// getters to assemble the wire-format `LoadContext` payload for
/// turbo86.
///
/// Parallel-array region storage (`region_addrs` + `region_bytes`)
/// keeps wasm-bindgen out of returning `Vec<exported_struct>`, which
/// would require an extra wrapper type per region with its own `free`.
/// The cost is one extra JS-side getter call per region; the snapshot
/// itself only happens at handoff time so the overhead is negligible.
#[wasm_bindgen]
#[derive(Default)]
pub struct ContextSnapshot {
    regs: CoreRegs,
    region_addrs: Vec<u32>,
    region_bytes: Vec<Vec<u8>>,
}

#[wasm_bindgen]
impl ContextSnapshot {
    /// Build an empty snapshot — all regs zero, no regions. Used by
    /// the JS wrapper when reconstructing a snapshot from a parsed
    /// `Paused` Outbound: fill the regs via `setRegs(...)`, then
    /// `addRegion(addr, bytes)` for each MemRegion, then hand it to
    /// `Vm::loadContext`.
    #[wasm_bindgen(constructor)]
    pub fn new() -> Self {
        Self {
            regs: CoreRegs::default(),
            region_addrs: Vec::new(),
            region_bytes: Vec::new(),
        }
    }

    /// Load all 10 register slots in one call. Ten positional u32
    /// arguments isn't pretty, but it avoids defining a parallel JS
    /// `WireRegs` struct just to pass it across the wasm boundary,
    /// and the call site is generated by the wrapper so the
    /// argument order isn't user-visible.
    #[wasm_bindgen(js_name = setRegs)]
    #[allow(clippy::too_many_arguments)]
    pub fn set_regs(
        &mut self,
        eax: u32,
        ebx: u32,
        ecx: u32,
        edx: u32,
        esi: u32,
        edi: u32,
        ebp: u32,
        esp: u32,
        eip: u32,
        eflags: u32,
    ) {
        self.regs = CoreRegs {
            eax,
            ebx,
            ecx,
            edx,
            esi,
            edi,
            ebp,
            esp,
            eip,
            eflags,
        };
    }

    /// Append one region. Regions are applied in the order added when
    /// passed to `Vm::loadContext`, matching turbo86's "later region
    /// wins for overlapping bytes" semantics on the receive side.
    #[wasm_bindgen(js_name = addRegion)]
    pub fn add_region(&mut self, addr: u32, bytes: Vec<u8>) {
        self.region_addrs.push(addr);
        self.region_bytes.push(bytes);
    }

    #[wasm_bindgen(getter)]
    pub fn eax(&self) -> u32 {
        self.regs.eax
    }
    #[wasm_bindgen(getter)]
    pub fn ebx(&self) -> u32 {
        self.regs.ebx
    }
    #[wasm_bindgen(getter)]
    pub fn ecx(&self) -> u32 {
        self.regs.ecx
    }
    #[wasm_bindgen(getter)]
    pub fn edx(&self) -> u32 {
        self.regs.edx
    }
    #[wasm_bindgen(getter)]
    pub fn esi(&self) -> u32 {
        self.regs.esi
    }
    #[wasm_bindgen(getter)]
    pub fn edi(&self) -> u32 {
        self.regs.edi
    }
    #[wasm_bindgen(getter)]
    pub fn ebp(&self) -> u32 {
        self.regs.ebp
    }
    #[wasm_bindgen(getter)]
    pub fn esp(&self) -> u32 {
        self.regs.esp
    }
    #[wasm_bindgen(getter)]
    pub fn eip(&self) -> u32 {
        self.regs.eip
    }
    /// Always 0 — movie86 does not model EFLAGS. The field is
    /// preserved so wire payloads match turbo86's schema byte-for-byte
    /// for the same logical state.
    #[wasm_bindgen(getter)]
    pub fn eflags(&self) -> u32 {
        self.regs.eflags
    }

    #[wasm_bindgen(getter, js_name = regionCount)]
    pub fn region_count(&self) -> usize {
        self.region_addrs.len()
    }

    /// Address of the `idx`-th sparse region, or `u32::MAX` if `idx`
    /// is out of range. JS callers check `regionCount` first; the
    /// sentinel is only here so wasm-bindgen doesn't have to surface
    /// an `Option<u32>` (which would become `number | undefined` and
    /// invite a "missed undefined" bug in the JS wrapper).
    #[wasm_bindgen(js_name = regionAddrAt)]
    pub fn region_addr_at(&self, idx: usize) -> u32 {
        self.region_addrs.get(idx).copied().unwrap_or(u32::MAX)
    }

    /// Bytes of the `idx`-th sparse region. Returns an empty `Vec`
    /// when `idx` is out of range — same defensive shape as
    /// `regionAddrAt`.
    #[wasm_bindgen(js_name = regionBytesAt)]
    pub fn region_bytes_at(&self, idx: usize) -> Vec<u8> {
        self.region_bytes.get(idx).cloned().unwrap_or_default()
    }
}

/// One row of disassembly: address, the bytes that decoded, the
/// decoded-instruction debug form, and the instruction length so the
/// JS caller can walk to the next instruction without re-asking us.
#[wasm_bindgen]
pub struct DecodedInsn {
    addr: u32,
    bytes_buf: Vec<u8>,
    text_buf: String,
    len_val: u32,
}

#[wasm_bindgen]
impl DecodedInsn {
    #[wasm_bindgen(getter)]
    pub fn addr(&self) -> u32 {
        self.addr
    }

    #[wasm_bindgen(getter)]
    pub fn bytes(&self) -> Vec<u8> {
        self.bytes_buf.clone()
    }

    /// Symbolic form of the decoded instruction in AT&T (gas) syntax,
    /// e.g. `movl $0x2a, %ebx` for `mov ebx, 42`. Matches the flavour
    /// of `.s` files emitted by movfuscator and llvm-mov-llc so the
    /// disassembly pane reads the same way as the source asm. Jumps
    /// and calls render their displacement as a signed offset
    /// (`jmp +0x40`, `call -0x5`) — `Insn::Display` doesn't know the
    /// instruction's own EIP, so resolving absolute targets is a job
    /// for a higher layer that does.
    #[wasm_bindgen(getter)]
    pub fn text(&self) -> String {
        self.text_buf.clone()
    }

    #[wasm_bindgen(getter, js_name = len)]
    pub fn insn_len(&self) -> u32 {
        self.len_val
    }
}
