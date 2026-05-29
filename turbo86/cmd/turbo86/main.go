//go:build linux

// turbo86 is the native execution client for x86.mov. A frontend opens
// a WebSocket to this server, streams mov-only i386 machine code, then
// either Starts a fresh session or LoadContext's an in-flight one. The
// host CPU executes the bytes directly; syscalls are intercepted via
// ptrace and bridged back as JSON events.
package main

import (
	"flag"
	"log"
	"net/http"
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

	http.Handle("/", server.Handler(patterns))
	log.Printf("turbo86 listening on ws://%s/ (allow-origin=%q)", *addr, *allowOrigin)
	if err := http.ListenAndServe(*addr, nil); err != nil {
		log.Fatalf("listen: %v", err)
	}
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
