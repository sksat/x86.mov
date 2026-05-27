# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this directory.

`turbo86` is the native execution client for x86.mov. A browser frontend streams mov-only i386 machine code over a WebSocket; turbo86 writes those bytes into a 32-bit child process and lets the host CPU run them directly — **no translation, no JIT, no interpretation**. Linux i386 syscalls issued by the guest are intercepted via `ptrace` and bridged back to the frontend as JSON events.

Companion to [`movie86`](../movie86/): movie86 is the in-browser interpreter ("watch the recording"); turbo86 is the native runner ("run it on the actual CPU stage").

## Architecture (v1)

```
+------------------+   ws://    +----------------------+ ptrace +-------------------+
| browser frontend |<---------->| turbo86 host (amd64) |<------>| stub child (i386) |
|  - compiles to   |  JSON      |  - WS server         |        |  - mmap RWX       |
|    mov           |  events    |  - ptrace driver     |        |  - PTRACE_TRACEME |
|  - streams bytes |            |  - syscall bridge    |        |  - runs guest mov |
+------------------+            +----------------------+        +-------------------+
```

- **Host**: amd64 Linux, single Go binary (cross-compile target: `GOOS=linux GOARCH=amd64`).
- **Stub**: tiny i386 ELF (hand-assembled, no libc / no Go runtime). Embedded into the host binary via `//go:embed`. Spawned once per session via `memfd_create` + `execve`. Sets up an RWX mmap region and stops itself with `PTRACE_TRACEME` + `raise(SIGSTOP)`, waiting for the host to inject code and set EIP.
- **Memory transfer**: `/proc/PID/mem` (faster than `PTRACE_POKEDATA` for streamed bytes).
- **Syscall interception**: `PTRACE_SYSCALL` stops on entry. The host reads child registers, translates the call into an Outbound event (`write(1)` → `Stdout`, etc.), suppresses the actual syscall by setting `orig_eax = -1`, writes the synthetic return value into `eax`, and continues.

## Scope (v1)

**In scope:**
- Streaming `Code{offset, bytes}` writes into guest memory.
- `Start{entry, stack_top}` to begin execution.
- Syscalls: `exit(1)` → `Exit` event; `write(4)` with fd ∈ {1, 2} → `Stdout` / `Stderr` event.
- Any other syscall: `Fault` event + session end. Don't silently allow — same principle as movie86's `PanicHost`.
- amd64 Linux host only.

**Not in scope (yet):**
- Library-call bridging (canvas, arbitrary RPC). Needs a separate trap mechanism (replace call target with `int3`, or use a sentinel address-range trap). Deferred until protocol/runner stabilizes.
- `stdin` / `read(3)`. Needs a half-duplex bridge (host pauses guest, awaits `Stdin` from frontend, resumes).
- Windows host. Would need a different execution path (Wine? QEMU-user? in-process JIT?). Open question — see [movie86](../movie86/) for the always-portable interpreter alternative.
- Loading full linked ELFs server-side. The frontend's job: parse the ELF, stream `Code` messages for each segment, then issue `Start{entry}`. Keeps the host minimal.

## TDD style

Matches the repo convention:
- New behaviour starts with a failing test, then implementation.
- Wire-protocol additions update the round-trip tests in [`proto/proto_test.go`](proto/proto_test.go) in the same commit.
- Integration tests for ptrace behaviour live behind a `linux` build tag and drive a tiny hand-assembled mov program through the runner.

## Layout

- [`proto/`](proto/) — wire-protocol types + JSON marshal/unmarshal. Platform-agnostic. **Implemented.**
- `runner/` — ptrace driver + syscall bridge. `//go:build linux`. *(planned)*
- `server/` — WebSocket server. Platform-agnostic. *(planned)*
- `stub/` — i386 assembly source + Makefile producing the embedded ELF. *(planned)*
- `cmd/turbo86/` — main entry. *(planned)*

## Things future Claude shouldn't relearn

- **The host is amd64, the guest is i386.** A 64-bit process can `ptrace` a 32-bit child fine on Linux, but `user_regs_struct` differs by arch — use `PTRACE_GETREGSET` with `NT_PRSTATUS` so the right size comes back. Don't paper over this with `PTRACE_GETREGS`.
- **`/proc/PID/mem` writes need the child stopped.** ptrace stops imply that, but a freshly attached child that hasn't yet received a stop-signal can race. Always `waitpid` for the stop signal before writing.
- **`Code` after `Start` is allowed but not synchronized.** v1 doesn't pause execution to apply post-Start writes — the frontend is responsible for sending all needed code before `Start` unless it understands what races it's accepting.
