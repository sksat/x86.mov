//go:build linux

// turbo86 is the native execution client for x86.mov. A frontend opens
// a WebSocket to this server, streams mov-only i386 machine code, then
// either Starts a fresh session or LoadContext's an in-flight one. The
// host CPU executes the bytes directly; syscalls are intercepted via
// ptrace and bridged back as JSON events.
package main

import (
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"

	"github.com/sksat/x86.mov/turbo86/server"
)

// DefaultAllowedOrigins lists the Origin hosts the WebSocket handshake
// accepts out of the box, so a stock `./turbo86` works with the
// production movie86/wasm frontend, a PR's CF Pages preview, and
// local dev tooling without extra config.
//
//   - `x86.mov`                  — the production movie86/wasm frontend
//   - `*.x86-mov.pages.dev`      — Cloudflare Pages preview deploys per
//     PR (`<head-ref>.x86-mov.pages.dev`, see `.github/workflows/deploy.yaml`)
//   - `localhost`, `localhost:*` — `make serve` and dev tooling
//   - `127.0.0.1`, `127.0.0.1:*` — same, IP form
//
// Patterns use filepath.Match semantics on the Origin URL's host
// (including port for non-default ports). Override with
// `--allow-origin=...`; empty string falls back to the strict default
// (Origin == Host only — equivalent to pre-flag behavior, the test
// harnesses' dial path).
const DefaultAllowedOrigins = "x86.mov,*.x86-mov.pages.dev,localhost,localhost:*,127.0.0.1,127.0.0.1:*"

func main() {
	addr := flag.String("addr", "127.0.0.1:1234", "listen address for the WebSocket server")
	allowOrigin := flag.String(
		"allow-origin", DefaultAllowedOrigins,
		"comma-separated Origin host patterns (filepath.Match against "+
			"Origin URL host; empty = strict Origin == Host)",
	)
	flag.Parse()

	patterns := parseOriginPatterns(*allowOrigin)

	// Banner goes straight to stderr (not through log) so the
	// per-line date/time prefix doesn't eat ~20 columns and wrap the
	// art on narrow terminals. log still owns the "listening" line.
	for _, line := range colorize(securityBanner(), isTerminal(os.Stderr)) {
		fmt.Fprintln(os.Stderr, line)
	}

	http.Handle("/", server.Handler(patterns))
	log.Printf("turbo86 listening on ws://%s/ (allow-origin=%q)", *addr, *allowOrigin)
	if err := http.ListenAndServe(*addr, nil); err != nil {
		log.Fatalf("listen: %v", err)
	}
}

// securityBanner returns the lines printed at startup. turbo86 hands
// untrusted guest machine code straight to the host CPU and only
// bridges syscalls via ptrace — there is no real sandbox in the
// process itself (see DESIGN.md's threat model and PTRACE_O_EXITKILL
// note). The banner exists so an operator can't miss that a stock
// build must run in a disposable / isolated environment, never on a
// box that matters. Returned as discrete lines so main() logs each
// with a timestamp and the test can assert intent without pinning the
// exact ASCII art.
func securityBanner() []string {
	return []string{
		"============================================================",
		"  turbo86 — *** SUPER INSECURE ***",
		"  REMOTE CODE EXECUTION PLATFORM",
		"  Runs UNTRUSTED guest machine code NATIVELY on this",
		"  host's CPU as YOU. No in-process sandbox; syscalls",
		"  are only ptrace-bridged.",
		"  Run ONLY in a disposable / sandboxed environment.",
		"============================================================",
	}
}

// colorize wraps each non-empty banner line in bold-red ANSI when
// enabled, resetting at the end of every line so an escape never
// bleeds past its own line (log.Print prepends a timestamp, so the
// reset has to be per-line, not once at the very end). When disabled
// it returns the input untouched — that's exactly the bytes we want
// in a redirected log file or a pipe, with no escape soup. The
// caller decides "enabled" via isTerminal; keeping that probe out of
// here makes the wrapping unit-testable.
func colorize(lines []string, enabled bool) []string {
	if !enabled {
		return lines
	}
	const (
		boldRed = "\x1b[1;31m"
		reset   = "\x1b[0m"
	)
	out := make([]string, len(lines))
	for i, line := range lines {
		if line == "" {
			out[i] = line
			continue
		}
		out[i] = boldRed + line + reset
	}
	return out
}

// isTerminal reports whether f is attached to a terminal, so the
// banner only emits ANSI color when a human is actually watching.
// Using the file's mode (a character device) keeps this dependency-
// free — pipes and regular files (`> log`, `| tee`) report false and
// stay color-clean, which is the case that matters for logs.
func isTerminal(f *os.File) bool {
	fi, err := f.Stat()
	if err != nil {
		return false
	}
	return fi.Mode()&os.ModeCharDevice != 0
}

// parseOriginPatterns splits a comma-separated pattern list, trimming
// whitespace and dropping empty entries. Empty input returns nil so
// `server.Handler(nil)` falls back to the strict Origin == Host
// default.
func parseOriginPatterns(s string) []string {
	if s == "" {
		return nil
	}
	parts := strings.Split(s, ",")
	out := make([]string, 0, len(parts))
	for _, p := range parts {
		p = strings.TrimSpace(p)
		if p != "" {
			out = append(out, p)
		}
	}
	if len(out) == 0 {
		return nil
	}
	return out
}
