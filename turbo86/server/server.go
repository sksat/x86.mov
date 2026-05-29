//go:build linux

// Package server exposes turbo86 over a WebSocket. One connection = one
// guest session. Code messages can stream in before AND after Start /
// LoadContext — pre-run writes set up initial code, post-run writes
// populate code the running guest will reach later (the streaming use
// case modelling "send context, load it, then keep streaming bytes").
package server

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"time"

	"github.com/coder/websocket"

	"github.com/sksat/x86.mov/turbo86/proto"
	"github.com/sksat/x86.mov/turbo86/runner"
	"github.com/sksat/x86.mov/turbo86/stub"
)

// sessionLogger wraps `*log.Logger` with a short per-connection id so
// concurrent sessions can be traced in the interleaved log output.
// Format is `[<id>] <event>: <details>` — line-oriented, grep-friendly,
// no JSON ceremony. Useful for deployments where someone is staring at
// `journalctl -f` while a frontend drives turbo86.
//
// The default global logger is fine; callers can inject a different
// `*log.Logger` for tests via `Handler(... , WithLogger(l))`. We
// don't ship that option yet because the standard logger is what
// `cmd/turbo86` already uses for the listening-address line.
type sessionLogger struct {
	id     string
	logger *log.Logger
}

func newSessionLogger(logger *log.Logger) *sessionLogger {
	if logger == nil {
		logger = log.Default()
	}
	return &sessionLogger{id: newSessionID(), logger: logger}
}

func (l *sessionLogger) logf(format string, args ...any) {
	l.logger.Printf("[%s] "+format, append([]any{l.id}, args...)...)
}

// 8 hex chars (4 bytes of randomness) is enough to disambiguate every
// session within a single log file, while staying compact in the
// log lines. crypto/rand because /proc/sys/kernel/random/uuid is
// linux-specific and overkill for a process-local correlation id.
func newSessionID() string {
	var b [4]byte
	if _, err := io.ReadFull(rand.Reader, b[:]); err != nil {
		return "????????"
	}
	return hex.EncodeToString(b[:])
}

// Handler returns an http.Handler that upgrades GET requests to
// WebSocket and runs a guest session per connection.
//
// `originPatterns` extends the default Origin == Host check with
// additional allow-listed Origin host patterns (filepath.Match syntax
// against the Origin URL's `Host`, including port for non-default
// ports). Pass `nil` to keep the strict default — used by the in-
// process tests where the dial client doesn't send Origin at all, and
// keeps the policy locked down by default for new callers.
//
// The browser frontend (movie86/wasm) is served from a different
// origin than the loopback turbo86 listener (`https://x86.mov` or
// `https://*.x86-mov.pages.dev` vs. `ws://127.0.0.1:1234`), so a
// production deploy MUST pass the frontend origin pattern here — the
// default would refuse the upgrade. cmd/turbo86/main.go wires this
// through a `--allow-origin` flag.
func Handler(originPatterns []string) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		serve(w, r, originPatterns)
	})
}

func serve(w http.ResponseWriter, r *http.Request, originPatterns []string) {
	// Defaults from coder/websocket: if the client sends an Origin
	// header, it must match the Host or one of `OriginPatterns`.
	// Tests using github.com/coder/websocket don't set Origin, so they
	// pass; browser cross-origin attempts only pass when Origin host
	// is in `originPatterns`. This endpoint accepts arbitrary guest
	// bytes and runs them natively, so we deliberately do NOT set
	// InsecureSkipVerify — turning it on would let any web page open
	// ws://127.0.0.1:1234 and drive turbo86 (cross-site RCE).
	var opts *websocket.AcceptOptions
	if len(originPatterns) > 0 {
		opts = &websocket.AcceptOptions{OriginPatterns: originPatterns}
	}
	ws, err := websocket.Accept(w, r, opts)
	if err != nil {
		// Log the failure too — silent 403s are the most confusing
		// case for new deploys (frontend says "WebSocket error" with
		// no detail; without server logs you have nothing to grep).
		log.Printf("websocket accept failed (origin=%q remote=%s): %v",
			r.Header.Get("Origin"), r.RemoteAddr, err)
		return
	}
	defer ws.CloseNow()

	// Raise the per-frame read cap above coder/websocket's 32 KiB default.
	// LoadContext frames are dominated by base64-encoded `Bytes` arrays;
	// the bundled `canvas_mandelbrot*.elf` examples ship code regions of
	// ~0.9 MiB (llvm-mov pipeline) up to ~6.6 MiB (movfuscator pipeline),
	// so leaving the default in place silently caps every non-trivial
	// browser handover at the wire layer (StatusMessageTooBig 1009).
	// 16 MiB matches the stub's RWX code region — a snapshot whose code
	// section is bigger than the stub's mapping wouldn't fit in the
	// guest anyway, so the cap mirrors the actual address space.
	ws.SetReadLimit(16 << 20)

	slog := newSessionLogger(nil)
	slog.logf("connect: remote=%s origin=%q",
		r.RemoteAddr, r.Header.Get("Origin"))
	start := time.Now()

	err = handleSession(r.Context(), ws, slog)
	dur := time.Since(start)
	switch {
	case err == nil:
		slog.logf("session end: ok dur=%s", dur.Round(time.Millisecond))
	case errors.Is(err, context.Canceled):
		slog.logf("session end: canceled dur=%s", dur.Round(time.Millisecond))
	default:
		slog.logf("session end: error dur=%s: %v", dur.Round(time.Millisecond), err)
		ws.Close(websocket.StatusInternalError, truncate(err.Error(), 120))
		return
	}
	ws.Close(websocket.StatusNormalClosure, "")
}

// handleSession drives one guest session end-to-end:
//  1. New Runner.
//  2. Read inbound. Code → WriteCode. Start / LoadContext → kick off
//     the syscall loop and obtain the events channel.
//  3. While events flow, spawn a side goroutine that continues reading
//     inbound and applies post-run Code messages via WriteCode (the
//     streaming case).
//  4. When the events channel closes (Exit / Paused / Fault), tear down.
//
// All structural events (Inbound type, runner kickoff, Outbound type,
// session end) get logged through `slog` so an operator can grep for
// a session id and reconstruct the wire trace.
func handleSession(ctx context.Context, ws *websocket.Conn, slog *sessionLogger) error {
	r, err := runner.New(stub.Bytes)
	if err != nil {
		return fmt.Errorf("create runner: %w", err)
	}
	defer r.Close()
	slog.logf("runner: ready (stub spawned, /proc/PID/mem open)")

	// Phase 1: pre-run setup — Code messages then Start/LoadContext.
	var events <-chan proto.Outbound
	for events == nil {
		msg, err := readInbound(ctx, ws)
		if err != nil {
			return err
		}
		switch m := msg.(type) {
		case proto.Code:
			slog.logf("inbound Code: offset=%#x size=%d", m.Offset, len(m.Bytes))
			if err := r.WriteCode(m.Offset, m.Bytes); err != nil {
				return fmt.Errorf("write code: %w", err)
			}
		case proto.Start:
			mode := m.Mode
			if mode == "" {
				mode = proto.ModeHost
			}
			slog.logf("inbound Start: entry=%#x stack_top=%#x mode=%s",
				m.Entry, m.StackTop, mode)
			events = r.RunWithMode(m.Entry, m.StackTop, mode)
		case proto.LoadContext:
			mode := m.Mode
			if mode == "" {
				mode = proto.ModeHost
			}
			var totalBytes int
			for _, region := range m.Context.Regions {
				totalBytes += len(region.Bytes)
			}
			slog.logf("inbound LoadContext: mode=%s eip=%#x esp=%#x regions=%d total_bytes=%d",
				mode, m.Context.Regs.Eip, m.Context.Regs.Esp,
				len(m.Context.Regions), totalBytes)
			events = r.RunWithContextAndMode(m.Context, mode)
		case proto.Stop:
			slog.logf("inbound Stop (pre-run abort)")
			return nil
		default:
			return fmt.Errorf("unexpected inbound %T before Start/LoadContext", msg)
		}
	}

	// Phase 2: post-run. A side goroutine accepts streaming Code; the
	// main goroutine forwards events. Either side ending tears the
	// session down. CRITICAL: the reader goroutine MUST call r.Close()
	// when it exits — otherwise a guest in a tight loop (no syscalls,
	// no signals) leaves the tracer blocked in wait4 forever, the
	// events channel never closes, and the main loop hangs. Close()
	// sends SIGKILL to the child, which unblocks wait4 → Paused →
	// channel close → main exits.
	readDone := make(chan error, 1)
	go func() {
		defer r.Close()
		for {
			msg, err := readInbound(ctx, ws)
			if err != nil {
				readDone <- err
				return
			}
			switch m := msg.(type) {
			case proto.Code:
				slog.logf("inbound Code (post-start): offset=%#x size=%d",
					m.Offset, len(m.Bytes))
				if err := r.WriteCode(m.Offset, m.Bytes); err != nil {
					readDone <- fmt.Errorf("write code (post-start): %w", err)
					return
				}
			case proto.Stop:
				slog.logf("inbound Stop (post-start): kill guest")
				readDone <- nil
				return
			case proto.Pause:
				slog.logf("inbound Pause: SIGSTOP -> guest")
				if err := r.Pause(); err != nil {
					readDone <- fmt.Errorf("pause: %w", err)
					return
				}
			default:
				readDone <- fmt.Errorf("unexpected inbound %T after Start/LoadContext", msg)
				return
			}
		}
	}()

	var (
		eventCount      int
		stdoutBytes     int
		stderrBytes     int
		emittedTerminal bool
	)
	for ev := range events {
		eventCount++
		// Per-event log line. Stdout/Stderr content is summarized as
		// a byte count (not logged literally) — keeps the operator
		// log free of guest-program data, both for noise and for
		// the "logs are not a covert channel for guest bytes"
		// principle. Terminal events (Exit / Fault / Paused) get
		// the full reason / regs.eip / signal because those are
		// what a deploy operator actually needs when investigating.
		switch v := ev.(type) {
		case proto.Stdout:
			stdoutBytes += len(v.Bytes)
		case proto.Stderr:
			stderrBytes += len(v.Bytes)
		case proto.Exit:
			slog.logf("outbound Exit: code=%d", v.Code)
			emittedTerminal = true
		case proto.Fault:
			slog.logf("outbound Fault: %s", v.Reason)
			emittedTerminal = true
		case proto.Paused:
			slog.logf("outbound Paused: signal=%d eip=%#x regions=%d reason=%q",
				v.Signal, v.Regs.Eip, len(v.Regions), v.Reason)
			emittedTerminal = true
		}
		data, err := proto.MarshalOutbound(ev)
		if err != nil {
			return fmt.Errorf("marshal outbound: %w", err)
		}
		if err := ws.Write(ctx, websocket.MessageText, data); err != nil {
			return fmt.Errorf("write outbound: %w", err)
		}
	}
	// Aggregate summary so the operator gets a tidy footer per
	// session instead of having to count Stdout chunks themselves.
	slog.logf("events: total=%d stdout=%dB stderr=%dB terminal=%v",
		eventCount, stdoutBytes, stderrBytes, emittedTerminal)
	// Session ended naturally. The reader goroutine is still blocked
	// in ws.Read; ws.CloseNow (deferred in serve) will unblock it, and
	// its readDone send is dropped (the channel is buffered).
	return nil
}

func readInbound(ctx context.Context, ws *websocket.Conn) (proto.Inbound, error) {
	_, data, err := ws.Read(ctx)
	if err != nil {
		return nil, fmt.Errorf("read inbound: %w", err)
	}
	msg, err := proto.UnmarshalInbound(data)
	if err != nil {
		return nil, fmt.Errorf("parse inbound: %w", err)
	}
	return msg, nil
}

func truncate(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n]
}
