# DESIGN.md

Architecture, scope, layout, and technical gotchas for `turbo86/`. See [CLAUDE.md](CLAUDE.md) for development conventions on top of these.

`turbo86` is the native execution client for x86.mov. A browser frontend streams mov-only i386 machine code over a WebSocket; turbo86 writes those bytes into a 32-bit child process and lets the host CPU run them directly — **no translation, no JIT, no interpretation**. Linux i386 syscalls issued by the guest are intercepted via `ptrace` and bridged back to the frontend as JSON events.

Companion to [`movie86`](../movie86/): movie86 is the in-browser interpreter ("watch the recording"); turbo86 is the native runner ("run it on the actual CPU stage"). The two engines share a canonical guest-state schema (`proto.Context`) so a session can be handed off in either direction at a stop boundary.

## Architecture

```
+------------------+   ws://    +----------------------+ ptrace +-------------------+
| browser frontend |<---------->| turbo86 host (amd64) |<------>| stub child (i386) |
|  - compiles to   |  JSON      |  - WS server         |        |  - mmap RWX       |
|    mov           |  events    |  - ptrace driver     |        |  - PTRACE_TRACEME |
|  - streams bytes |            |  - syscall bridge    |        |  - runs guest mov |
+------------------+            +----------------------+        +-------------------+
```

- **Host**: amd64 Linux, single Go binary (`GOOS=linux GOARCH=amd64`).
- **Stub**: tiny i386 ELF (hand-assembled, no libc / no Go runtime). Embedded into the host binary via `//go:embed`. Spawned per session via `memfd_create` + `execve`. Sets up an RWX mmap region for guest code + a stack region, then stops itself with `PTRACE_TRACEME` + `raise(SIGSTOP)`, waiting for the host to inject code and set EIP.
- **Memory transfer**: `/proc/PID/mem` (faster than `PTRACE_POKEDATA` for bulk writes).
- **Syscall interception**: `PTRACE_SYSCALL` with entry+exit stop pairs. The bridge classifies each syscall as:
  - **Emulate** (`write`, `exit`): suppress the kernel call (set `orig_eax = -1` at entry), emit the Outbound event, overwrite `eax` with the synthetic return value at exit. Kernel never executes the original syscall.
  - **Passthrough** (`rt_sigaction`, `rt_sigreturn`, `rt_sigprocmask`): let the kernel run the syscall natively (host mode). The runner shepherds the entry/exit stops past; no event is emitted. In **trap mode** the runner intercepts these syscalls before the bridge and emulates them in-process (handler addr stored in `r.handlers`, signal-stack popped on rt_sigreturn).
  - **Fault** / **Exit**: terminal — emit the corresponding event and end the session.
- **Signal stops**: split three ways.
  - Plain SIGTRAP is reserved for tracer-owned int3 traps (future library-call bridging); unexpected → Fault.
  - Forwardable signals (SIGILL, SIGSEGV, SIGBUS, SIGFPE, SIGPIPE, SIGUSR1, SIGUSR2): in **host mode** delivered to the guest via the next `PTRACE_SYSCALL` so the kernel-registered handler runs (movfuscator's `mov cs, ax` → SIGILL → installed handler pattern). In **trap mode** the runner looks up the handler in `r.handlers`, saves the pre-signal regs on `r.signalRegs`, sets `EIP = handler addr` directly, and resumes without delivering the signal to the kernel.
  - Other signals (job-control, …) surface as `Paused`. Before forwarding/redirect, the runner snapshots regs + sparse memory; if the kernel kills the child (no handler) in host mode, that snapshot rides along on the `Paused`.
- **Execution mode**: per-session policy chosen via `proto.Start.Mode` / `proto.LoadContext.Mode` — `"host"` (default; kernel handles signals) or `"trap"` (turbo86 handles signals). The same guest program should produce the same Outbound event stream under either mode — that's the migration-parity doctrine the [signal-dispatch parity test](runner/sigaction_test.go) enforces.

## Scope

**In scope:**
- Streaming `Code{offset, bytes}` writes into guest memory.
- `Start{entry, stack_top}` to begin execution.
- `LoadContext{context}` to resume from a Context handed off by another engine (the receive side of bidirectional engine migration).
- `Stop` Inbound to cancel a running session without dropping the WebSocket.
- Syscalls: `exit(1)` → `Exit` event; `write(4)` with fd ∈ {1, 2} → `Stdout` / `Stderr` event.
- Any other syscall: `Fault` event + session end (non-recoverable from a peer engine's POV).
- Synchronous signal stops → `Paused` event with regs + sparse memory snapshot (recoverable; peer engine may resume via `LoadContext`).
- WebSocket server (`./turbo86 --addr 127.0.0.1:1234`).
- amd64 Linux host only.

**Not in scope (yet):**
- Library-call bridging (canvas, arbitrary RPC). Needs a separate trap mechanism (replace call target with `int3`, or use a sentinel address-range trap). The plain-SIGTRAP path in the runner is already reserved for this.
- `stdin` / `read(3)`. Needs a half-duplex bridge (host pauses guest, awaits `Stdin` from frontend, resumes).
- Windows host. Would need a different execution path (Wine? QEMU-user? in-process JIT?). movie86 (the interpreter) remains the always-portable path.
- Loading full linked ELFs server-side. The frontend's job: parse the ELF, stream `Code` messages for each segment, then issue `Start{entry}`.
- Real movfuscator binary completion. Investigated empirically with the runtime built (`make setup && make build-native` in `movfuscator-wasm/`) and a real-sigaction stubs.s linked in: the binary loads, runs, and locks into the upstream master_loop dispatch trick. The SIGILL handler is `master_loop = _start0` which re-runs `main` from the top on each `mov cs, ax`; without a termination signal we know how to provide from our stubs, it loops indefinitely (movie86 hits the same wall from the other side). Env-gated investigation test at [`runner/movfuscator_elf_test.go`](runner/movfuscator_elf_test.go) documents the observation. Fully completing a real movfuscator binary is a movfuscator-runtime-side problem — turbo86's wiring (rt_sigaction passthrough + SIGILL forward) is working.

## Layout

- [`proto/`](proto/) — wire-protocol types + JSON marshal/unmarshal. Platform-agnostic. **Inbound**: `Code`, `Start`, `LoadContext`, `Stop`. **Outbound**: `Stdout`, `Stderr`, `Exit`, `Fault`, `Paused`. Migration schema: `Context{Regs, Regions[]}`, `Regs{Eax..Edi, Esp, Eip, Eflags}`, `MemRegion{Addr, Bytes}`. `Mode` selects between `"host"` and `"trap"` execution policies.
- [`bridge/`](bridge/) — pure-function `HandleSyscall(SyscallArgs, GuestMemory) → Result{Event, Return, Action}`. Analogue of movie86's `SysHost` trait. Decides per syscall what Outbound event to emit and whether the runner should Resume / Exit / Fault / Passthrough. Passthrough syscalls return `Event: nil` and let the kernel actually execute the call.
- [`runner/`](runner/) — ptrace driver. `//go:build linux`. Long-lived `Runner` with `New` / `WriteCode` / `Run` / `RunWithMode` / `RunWithContext` / `RunWithContextAndMode` / `Close` lifecycle. An internal tracer goroutine pins itself to one OS thread (does all ptrace ops); `WriteCode` writes via `/proc/PID/mem` and is safe from any goroutine, before OR after `Run` — the streaming primitive. `Close()` sends SIGKILL to the child, unblocking the tracer's wait4 even for no-syscall tight loops. `snapshotMemory` produces the sparse `MemRegion[]` carried by Paused.
- [`server/`](server/) — WebSocket handler (`Handler() http.Handler`). Two-phase: pre-run reads inbound for Code + Start/LoadContext + Stop, post-run spawns a reader goroutine for streaming Code + Stop while forwarding events on the main goroutine. The reader's `defer r.Close()` is the link between WS disconnect and runner shutdown.
- [`stub/`](stub/) — `_stub.s` (i386 GAS source, leading `_` so Go ignores it) + `Makefile` + the built `stub` binary. `stub.go` exposes the embedded bytes via `//go:embed`.
- [`cmd/turbo86/`](cmd/turbo86/) — main entry. `--addr` flag, `http.ListenAndServe`.

## Things future Claude shouldn't relearn

- **The host is amd64, the guest is i386.** A 64-bit process can `ptrace` a 32-bit child fine on Linux, but the stdlib's `syscall.PtraceGetRegs` uses the 64-bit `user_regs_struct` layout, which does NOT match what the kernel writes for an i386 tracee — most fields come back zero. Use `PTRACE_GETREGSET`/`SETREGSET` with `NT_PRSTATUS` and a 68-byte `regs32` struct mirroring the kernel's `struct pt_regs`. [`runner/runner.go`](runner/runner.go) does this.

- **`/proc/PID/mem` reads/writes need the child stopped.** ptrace stops imply that, but a freshly attached child that hasn't yet received a stop signal can race. Always `waitpid` for the stop before writing.

- **`PTRACE_SYSCALL` with entry/exit stop pairs is the mode**, not `PTRACE_SYSEMU`. SYSEMU is cheaper (one stop per syscall) but only supports skip-the-kernel-syscall semantics — it can't pass calls through to the kernel, which is needed for `rt_sigaction`/`rt_sigreturn`. The runner's `syscallPending` flag distinguishes entry from exit; emulate sets `orig_eax = -1` at entry and overwrites `eax` at exit, passthrough leaves both alone.

- **i386 sigaction needs a valid restorer.** `NR_rt_sigaction` (174) does NOT have a kernel-default sa_restorer on i386 — without `SA_RESTORER + sa_restorer = &trampoline`, the handler's return address is whatever was in the sigframe (usually zero), and the handler crashes on return. Our [sigaction E2E test](runner/sigaction_test.go) builds a tiny `mov eax, 173; int 0x80` restorer at a known address; movfuscator's libc-style crt0 emits its own via glibc.

- **Plain SIGTRAP is reserved.** The runner Faults on it. The future int3-breakpoint mechanism for library-call bridging will own SIGTRAP exclusively; do not start forwarding SIGTRAP to the guest as part of any signal-passthrough work.

- **The stub MUST NOT be linked at `0x08048000`.** The conventional i386 ELF base is also where the guest code region lives. `mmap MAP_FIXED` at that address from inside the stub overwrites the stub's own code → next instruction segfaults. The Makefile uses `-Ttext-segment=0x40000000` to keep them apart.

- **The guest stack mmap MUST NOT collide with the stub's own kernel-allocated stack.** Linux puts the stub's stack near `~0xBFFFFFF0`. The stub maps the guest stack at `0x70000000..0x70200000`, well below. If you ever want the guest stack at a higher address, check `/proc/PID/maps` of the running stub first.

- **`Code` after `Start` is allowed but not synchronized with guest execution.** Post-Start writes go through `runner.WriteCode` (a plain `/proc/PID/mem` write), not through ptrace. The frontend is responsible for arranging that streamed code lands at addresses the guest hasn't reached yet.

- **The runner's `eventsCh` is unbuffered.** This keeps the tracer goroutine in lockstep with the consumer: the tracer can't run ahead, finish the session, and tear down `/proc/PID/mem` before the consumer has read the events it sent. If you change this to buffered, the streaming test starts flaking because mid-session `WriteCode` hits a closed fd.

- **Paused vs Fault** are semantically distinct. Paused = "recoverable boundary, peer engine may resume via LoadContext" (signals, future "unsupported feature" stops). Fault = "non-recoverable, give up" (unsupported syscall numbers, host-side ptrace errors). Don't merge them.

- **The Go runtime's `SysProcAttr{Ptrace: true}`** issues `PTRACE_TRACEME` in the child between fork and execve, so the child stops at execve. Our stub additionally calls `PTRACE_TRACEME` in `_start` — harmless, the duplicate is tolerated, and it keeps the stub self-contained (works even if a caller doesn't set the Go flag).

- **ptrace must come from the same OS thread that started the child.** The runner has an internal tracer goroutine that `runtime.LockOSThread()`s and never unlocks; the OS thread is destroyed with the goroutine. Public methods like `WriteCode` (which uses `/proc/PID/mem`, not ptrace) are safe to call from any goroutine, but everything that touches ptrace stays on that pinned thread.

- **Sparse memory snapshot at Paused.** `snapshotMemory` reads the stub's mmap'd regions (16 MiB code + 2 MiB stack) but emits only the non-zero 4 KiB pages, merging adjacent runs. For a freshly-faulted guest this collapses ~18 MiB into a few KiB on the wire.

- **Trap-mode signal dispatch pushes a restorer trampoline.** At session start in trap mode, the runner writes a 7-byte `mov eax, 173; int 0x80` trampoline at `0x09040000` (near the end of the 16 MiB code region). At signal time, the runner pushes that address onto the guest stack before redirecting EIP into the handler — so a normally-returning handler `ret`s into the trampoline, which then invokes `rt_sigreturn` (which the runner intercepts and restores from `r.signalRegs`). Without this push, exit-from-handler works but a returning handler `ret`s to garbage, diverging from host mode.

- **The WebSocket Accept does NOT set `InsecureSkipVerify`.** Turning it on would disable the browser Origin check, letting any visited web page open `ws://127.0.0.1:<port>` and drive the runner (cross-site RCE — this endpoint accepts and executes arbitrary guest bytes natively). coder/websocket's default Origin check passes when no Origin header is sent (the test client's case) and requires Origin to match Host otherwise. The browser frontend (movie86/wasm at `https://x86.mov` or a CF Pages preview) is always cross-origin to the loopback `ws://127.0.0.1:1234`, so a default-only build rejects every browser handshake. `server.Handler(originPatterns)` takes an allow-list of host patterns (filepath.Match against the Origin URL's host, port-aware); `cmd/turbo86`'s `--allow-origin` flag is the wire — defaults to `x86.mov`, `*.x86-mov.pages.dev`, `localhost(:*)`, `127.0.0.1(:*)` so a stock `./turbo86` works with prod, every PR preview, and `make serve` without extra config. Override with a tighter list for hardened deploys; pass `--allow-origin=""` to get the original strict default back. Tests pass `nil` and dial without an `Origin` header so they stay in the strict path. Never reach for `InsecureSkipVerify`.

- **Per-session structured logging.** `server.handleSession` emits a
  log line for every connection (`connect`), each Inbound type
  (`inbound Code`, `inbound LoadContext`, `inbound Pause`, …), each
  *terminal* Outbound type (`outbound Exit`, `outbound Fault`,
  `outbound Paused`), an aggregate events summary
  (`events: total=… stdout=… stderr=…`), and a final `session end`
  with a duration. All lines are tagged with an 8-hex random
  `[session-id]` prefix so concurrent sessions can be grep'd apart.
  Stdout/Stderr content is intentionally NOT logged — only byte
  counts surface in the summary. Two reasons: noise (a chatty guest
  would dominate the log), and the "operator logs aren't a covert
  data channel" principle (the guest is untrusted code; making it
  trivially loggable encourages users to leak data through the
  server logs). Origin-rejected handshakes also log (with remote +
  Origin) because the silent 403 is the most opaque failure mode.

- **`PTRACE_O_EXITKILL` is set alongside TRACESYSGOOD.** If the turbo86 host process crashes or is killed (any reason), the kernel sends `SIGKILL` to the tracee. Without this, an orphaned guest keeps running with no bridge in front of it — it's executing untrusted bytes, so anything it does (open files, exec other binaries, …) would run as the server user with no filtering. EXITKILL closes that window.

- **Disposition tracking optimizes the host-mode signal snapshot.** Capturing the 18 MiB sparse memory snapshot on every forwardable signal is fine for one-shot faults but ruinous for movfuscator-style guests that fire SIGILL on every dispatched instruction. The runner sniffs `rt_sigaction` calls (in both host and trap modes — `r.handlers` is the shared "known disposition" map) and skips the snapshot when the signal has a registered handler (the kernel will dispatch into it, the child stays alive, the snapshot would be discarded anyway). The snapshot is still taken when no handler is registered, since then the child will probably die and the post-Signaled Paused needs the regs/regions captured before forward.

- **`rt_sigaction` in trap mode honors `oldact`.** A non-NULL `oldact` argument gets the previous disposition written as a kernel `struct k_sigaction` (20 bytes on i386: sa_handler / sa_flags / sa_restorer / sa_mask[2]) — matching the byte count the kernel writes in host mode. Writing the userspace 140-byte layout here would clobber adjacent guest memory and diverge from host mode. We only track sa_handler in trap mode; sa_flags / sa_restorer / sa_mask stay zero. Without this oldact write, programs that swap+restore handlers (or sample the current handler) silently see SIG_DFL where the real kernel would return the prior value, breaking the host/trap parity doctrine.

- **Interrupting a no-syscall tight loop.** A guest in `jmp $` makes no syscalls and never signals; the tracer's wait4 would block forever. `Runner.Close()` sends SIGKILL to the child, which wakes wait4 (returning Signaled). The session ends with a `Paused{Signal: SIGKILL}`. This is the kill-switch for runaway guests; the server reader goroutine has a `defer r.Close()` so a WS disconnect triggers it automatically, and the `Stop` Inbound message is the polite caller-initiated form.

## Mov-only ABI page

`int 0x10` / `int 0x80` を介さずに **magic page への `mov` だけで host call を発火する** dispatch 仕組み。movie86 (wasm + cli) と byte-for-byte で対応する契約。

- **ABI base = `0x1FFE_0000`、size = 1 ページ (`0x1000`)**。stub の static guestRegions (`[0x08048000, 0x09048000)` + `[0x70000000, 0x70200000)`) と意図的に重ねず、guest がここに書くと自動で SIGSEGV になるよう unmapped で保つ。
- **call 番号は page 内 offset**。現在の slot:

  | offset | call           | trigger / args                                                 |
  |--------|----------------|----------------------------------------------------------------|
  | `0x010`| set_video_mode | `mov [ABI+0x010], al`、al = mode (BIOS `int 0x10/AH=0` 相当)   |
  | `0x020`| mmap_request   | `mov [ABI+0x020], eax`、eax = addr (page-aligned, low 12 bits = pages-1)、stub の address space を ptrace 経由で動的拡張 |
  | `0x080`| write          | `mov [ABI+0x080], eax` (eax = SYS_write marker)、ebx=fd / ecx=buf / edx=len、handler は `regs.Eax = bytes_written` で返す |
  | `0x0FE`| exit           | `mov [ABI+0x0FE], eax`、eax = exit code、`Outbound{Exit}` 発火して session 終了 |

- **decode は `A2`/`A3` の絶対アドレス mov 限定**。`classifyAbi` は SIGSEGV stop 時に EIP の 5 bytes を `/proc/PID/mem` で読み、`A2 imm32` (`mov [imm32], al`) または `A3 imm32` (`mov [imm32], eax`) の imm32 が ABI page なら call として認識。register-indirect mov 等の他形式は誤判定しないよう真の SIGSEGV パスに落とす。
- **ptrace-injected syscall** はトランポリン `trapTrampolineAddr + 5` (= `CD 80`) を流用。SIGSEGV stop 中の child の regs/EIP を一時的に書き換えて `PTRACE_SYSCALL` を 2 回 (entry stop + exit stop) drive、戻り値を読んで元の regs を復元。trap-mode 用 trampoline を **mode 問わず常時** 書くことで host mode でも inject 可能 (`runner.go` bootstrap)。
- **mmap_request は `r.extraRegions` で管理**。snapshot 時に static guestRegions と一緒に walk され、Paused に乗る。soft cap は `mmapMaxRegions = 32`。
- **LoadContext で region が static map 外なら自動 mmap**。受信側 turbo86 は LoadContext 適用前に各 region の addr range を `regionFitsStaticGuest` で判定、外側なら `mmapRegionForLoadContext` で injectSyscall 経由に拡張してから `/proc/PID/mem` に write。wasm Vm の snapshot に `.fb13h` 等の FB region が含まれていても受け取れる。
- **host/trap mode parity**。runner が ABI page を奪うのは signal-dispatch policy の前段なので、Host/Trap どちらでも同一の event stream を出す。`TestRunOnce_AbiSetVideoMode_TrapMode` で構造的に pin。
- **proto.VideoMode** Outbound (`{type: "video_mode", mode: N}`) を新設。`set_video_mode` の発火を frontend に通知。`Exit` / `Stdout` / `Stderr` は既存型を再利用。
- **設計の動機**: int 0x10 は Linux カーネルが userspace IDT に持たず SIGSEGV になる (turbo86 では即 Fault)、int 0x80 は narrative 上 "everything is a mov" を破る。両方を mov に統一すると movfuscator-style "kernel との接点も mov 経由" になり、後付けの BIOS 経路や syscall も同じ枠で扱える。詳細は [#28](https://github.com/sksat/x86.mov/issues/28) を参照。

## CI

[`.github/workflows/turbo86.yaml`](../.github/workflows/turbo86.yaml) at the repo root. Runs on push/PR to `mov`: `gofmt -l .`, `go vet ./...`, `go test -v ./...`, `go build ./cmd/turbo86`, and a stub-from-source rebuild check. Actions pinned to `vMAJOR.MINOR.PATCH`.
