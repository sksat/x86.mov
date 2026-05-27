# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this directory.

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
- **Syscall interception**: `PTRACE_SYSEMU` stops the child *before* each syscall executes. The host reads child registers, translates the call into an Outbound event (`write(1)` → `Stdout`, etc.), sets the synthetic return value into `eax`, and resumes. The kernel does NOT execute the original syscall.
- **Signal stops** (SIGSEGV / SIGILL / …): surface as a `Paused` Outbound event carrying the regs + a sparse memory snapshot, then the session ends. movie86 can pick the session up via `LoadContext` (e.g., to handle the movfuscator SIGSEGV-dispatch trick in software).

## Scope

**In scope:**
- Streaming `Code{offset, bytes}` writes into guest memory.
- `Start{entry, stack_top}` to begin execution.
- `LoadContext{context}` to resume from a Context handed off by another engine (the receive side of bidirectional engine migration).
- Syscalls: `exit(1)` → `Exit` event; `write(4)` with fd ∈ {1, 2} → `Stdout` / `Stderr` event.
- Any other syscall: `Fault` event + session end (non-recoverable from a peer engine's POV).
- Synchronous signal stops → `Paused` event with regs + sparse memory snapshot (recoverable; peer engine may resume via `LoadContext`).
- WebSocket server (`./turbo86 --addr 127.0.0.1:1234`).
- amd64 Linux host only.

**Not in scope (yet):**
- Streaming additional `Code` while the guest is executing. v1 is buffer-then-run; a streaming Runner is the planned follow-up.
- Library-call bridging (canvas, arbitrary RPC). Needs a separate trap mechanism (replace call target with `int3`, or use a sentinel address-range trap).
- `stdin` / `read(3)`. Needs a half-duplex bridge (host pauses guest, awaits `Stdin` from frontend, resumes).
- Windows host. Would need a different execution path (Wine? QEMU-user? in-process JIT?). movie86 (the interpreter) remains the always-portable path.
- Loading full linked ELFs server-side. The frontend's job: parse the ELF, stream `Code` messages for each segment, then issue `Start{entry}`.
- Syscall passthrough for `sigaction`. Required to fully run an unmodified movfuscator binary (the `mov cs, ax` SIGILL dispatch trick depends on the guest's own signal handler being installed). Currently blocks the real-movfuscator E2E from completing; the test [`runner/movfuscator_test.go`](runner/movfuscator_test.go) only validates "stream + early Paused, no host crash".

## TDD style

Matches the repo convention:
- New behaviour starts with a failing test, then implementation.
- Wire-protocol additions update the round-trip tests in [`proto/proto_test.go`](proto/proto_test.go) in the same commit.
- Integration tests for ptrace behaviour live behind `//go:build linux` and drive hand-assembled mov programs through the runner.

## Layout

- [`proto/`](proto/) — wire-protocol types + JSON marshal/unmarshal. Platform-agnostic. **Inbound**: `Code`, `Start`, `LoadContext`. **Outbound**: `Stdout`, `Stderr`, `Exit`, `Fault`, `Paused`. Migration schema: `Context{Regs, Regions[]}`, `Regs{Eax..Edi, Esp, Eip, Eflags}`, `MemRegion{Addr, Bytes}`.
- [`bridge/`](bridge/) — pure-function `HandleSyscall(SyscallArgs, GuestMemory) → Result{Event, Return, Action}`. Analogue of movie86's `SysHost` trait. Decides per syscall what Outbound event to emit and whether the runner should Resume / Exit / Fault.
- [`runner/`](runner/) — ptrace driver. `//go:build linux`. `RunOnce` (fresh) and `RunWithContext` (resume from `proto.Context`) share `runWithStub`: spawn stub, drive to SIGSTOP, inject code, set regs, run the syscall-bridge loop. `snapshotMemory` produces the sparse `MemRegion[]` carried by Paused.
- [`server/`](server/) — WebSocket handler (`Handler() http.Handler`). One connection = one session, buffer-then-run.
- [`stub/`](stub/) — `_stub.s` (i386 GAS source, leading `_` so Go ignores it) + `Makefile` + the built `stub` binary. `stub.go` exposes the embedded bytes via `//go:embed`.
- [`cmd/turbo86/`](cmd/turbo86/) — main entry. `--addr` flag, `http.ListenAndServe`.

## Things future Claude shouldn't relearn

- **The host is amd64, the guest is i386.** A 64-bit process can `ptrace` a 32-bit child fine on Linux, but the stdlib's `syscall.PtraceGetRegs` uses the 64-bit `user_regs_struct` layout, which does NOT match what the kernel writes for an i386 tracee — most fields come back zero. Use `PTRACE_GETREGSET`/`SETREGSET` with `NT_PRSTATUS` and a 68-byte `regs32` struct mirroring the kernel's `struct pt_regs`. [`runner/runner.go`](runner/runner.go) does this.

- **`/proc/PID/mem` reads/writes need the child stopped.** ptrace stops imply that, but a freshly attached child that hasn't yet received a stop signal can race. Always `waitpid` for the stop before writing.

- **`PTRACE_SYSEMU` (request 31) skips the kernel syscall entirely** — the tracer is fully responsible for setting `eax` to the synthetic return value. Cleaner than `PTRACE_SYSCALL` for our bridging use case (one stop per syscall, no need to suppress with `orig_eax = -1`).

- **The stub MUST NOT be linked at `0x08048000`.** The conventional i386 ELF base is also where the guest code region lives. `mmap MAP_FIXED` at that address from inside the stub overwrites the stub's own code → next instruction segfaults. The Makefile uses `-Ttext-segment=0x40000000` to keep them apart.

- **The guest stack mmap MUST NOT collide with the stub's own kernel-allocated stack.** Linux puts the stub's stack near `~0xBFFFFFF0`. The stub maps the guest stack at `0x70000000..0x70200000`, well below. If you ever want the guest stack at a higher address, check `/proc/PID/maps` of the running stub first.

- **`Code` after `Start` is allowed but not synchronized.** v1 doesn't pause execution to apply post-Start writes — the frontend is responsible for sending all needed code before `Start` unless it understands what races it's accepting.

- **Paused vs Fault** are semantically distinct. Paused = "recoverable boundary, peer engine may resume via LoadContext" (signals, future "unsupported feature" stops). Fault = "non-recoverable, give up" (unsupported syscall numbers, host-side ptrace errors). Don't merge them.

- **The Go runtime's `SysProcAttr{Ptrace: true}`** issues `PTRACE_TRACEME` in the child between fork and execve, so the child stops at execve. Our stub additionally calls `PTRACE_TRACEME` in `_start` — harmless, the duplicate is tolerated, and it keeps the stub self-contained (works even if a caller doesn't set the Go flag).

- **ptrace must come from the same OS thread that started the child.** The runner requires callers to `runtime.LockOSThread()` before invoking `RunOnce` / `RunWithContext`; the WebSocket server does this in a per-connection goroutine and never unlocks (the thread is destroyed with the goroutine).

- **Sparse memory snapshot at Paused.** `snapshotMemory` reads the stub's mmap'd regions (16 MiB code + 2 MiB stack) but emits only the non-zero 4 KiB pages, merging adjacent runs. For a freshly-faulted guest this collapses ~18 MiB into a few KiB on the wire.

## CI

[`.github/workflows/turbo86.yaml`](../.github/workflows/turbo86.yaml) at the repo root. Runs on push/PR to `mov`: `gofmt -l .`, `go vet ./...`, `go test -v ./...`, `go build ./cmd/turbo86`, and a stub-from-source rebuild check. Actions pinned to `vMAJOR.MINOR.PATCH`.
