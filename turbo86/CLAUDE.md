# CLAUDE.md

Development conventions for working inside `turbo86/`, on top of the repo-level [CLAUDE.md](../CLAUDE.md) (notably TDD). The architecture, scope, layout, and technical gotchas live in [DESIGN.md](DESIGN.md) — read that first when changing anything non-trivial.

## TDD additions specific to turbo86

The repo-wide rule is "failing test first, implementation second, golden updates in the same commit." Turbo86-specific bits to keep in mind:

- **Wire-protocol additions update the round-trip tests in [`proto/proto_test.go`](proto/proto_test.go) in the same commit.** Both `MarshalInbound` and `UnmarshalInbound` (or the Outbound siblings) must round-trip the new variant before the runner / server learn about it.
- **Integration tests for ptrace behaviour live behind `//go:build linux`.** They drive hand-assembled mov programs through the runner (see [`runner/sigaction_test.go`](runner/sigaction_test.go) for a worked example). Hand-assembling small i386 fragments is the norm — there's no compiler in the test path.
- **Two-mode parity.** When a behaviour involves signals or sigaction, the test should be table-driven over `[proto.ModeHost, proto.ModeTrap]` — both policies have to produce the same observable event stream (this is the migration-parity doctrine, see DESIGN.md).
- **Adding a bridge syscall**: bridge unit test (`bridge/bridge_test.go`) for the syscall→event translation, plus a runner-level integration test if the new syscall has interesting interaction with the ptrace state machine (passthrough vs emulate vs fault).
- **Adding a mov-only ABI call**: pick an unused offset on the ABI page (`abiBase + 0xNN`, see [DESIGN.md](DESIGN.md)). Mirror the constant on the movie86 side (`movie86::abi_host::CALL_*`) **in the same PR** so the cross-engine contract stays in lockstep. TDD shape: failing `runner/abi_test.go` test that drives a hand-assembled `mov [abiBase+0xNN], al/eax` fixture → wire up `classifyAbi` (decode) + `dispatchAbi` (handler) → green. New `proto.Outbound` types (e.g. `VideoMode`) get a round-trip test in `proto/proto_test.go` too.

## Build notes

- `go test ./...` / `go build ./cmd/turbo86` need nothing beyond the standard Go toolchain.
- The embedded i386 stub is the only non-Go artifact. Rebuild via `cd stub && make` — needs binutils with `as --32` and `ld -m elf_i386` (both stock on most Linux distros). The built `stub` binary is committed alongside the source so `//go:embed` always finds it.
- The optional movfuscator E2E fixture under `runner/testdata/` requires the upstream movfuscator runtime materialized first; see [its Makefile](runner/testdata/Makefile).
