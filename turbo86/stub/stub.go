// Package stub holds the embedded i386 child-stub ELF as a byte slice.
//
// The host (turbo86) writes Bytes to a memfd and execve's it once per
// session. The stub itself sets up the guest's RWX code region + stack
// region, then self-stops via SIGSTOP so the host can stream code in
// and redirect EIP/ESP via PTRACE_SETREGS.
//
// Rebuild the binary by running `make` in this directory after editing
// stub.s. The resulting `stub` file is committed alongside the source
// so `//go:embed` always finds it without a build-time toolchain.
package stub

import _ "embed"

//go:embed stub
var Bytes []byte
