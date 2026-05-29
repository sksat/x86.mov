//go:build linux

// Package server exposes turbo86 over a WebSocket. One connection = one
// guest session. Code messages can stream in before AND after Start /
// LoadContext — pre-run writes set up initial code, post-run writes
// populate code the running guest will reach later (the streaming use
// case modelling "send context, load it, then keep streaming bytes").
package server

import (
	"context"
	"errors"
	"fmt"
	"net/http"

	"github.com/coder/websocket"

	"github.com/sksat/x86.mov/turbo86/proto"
	"github.com/sksat/x86.mov/turbo86/runner"
	"github.com/sksat/x86.mov/turbo86/stub"
)

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
		return
	}
	defer ws.CloseNow()

	if err := handleSession(r.Context(), ws); err != nil && !errors.Is(err, context.Canceled) {
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
func handleSession(ctx context.Context, ws *websocket.Conn) error {
	r, err := runner.New(stub.Bytes)
	if err != nil {
		return fmt.Errorf("create runner: %w", err)
	}
	defer r.Close()

	// Phase 1: pre-run setup — Code messages then Start/LoadContext.
	var events <-chan proto.Outbound
	for events == nil {
		msg, err := readInbound(ctx, ws)
		if err != nil {
			return err
		}
		switch m := msg.(type) {
		case proto.Code:
			if err := r.WriteCode(m.Offset, m.Bytes); err != nil {
				return fmt.Errorf("write code: %w", err)
			}
		case proto.Start:
			mode := m.Mode
			if mode == "" {
				mode = proto.ModeHost
			}
			events = r.RunWithMode(m.Entry, m.StackTop, mode)
		case proto.LoadContext:
			mode := m.Mode
			if mode == "" {
				mode = proto.ModeHost
			}
			events = r.RunWithContextAndMode(m.Context, mode)
		case proto.Stop:
			// Pre-run abort: never started; just clean up.
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
				if err := r.WriteCode(m.Offset, m.Bytes); err != nil {
					readDone <- fmt.Errorf("write code (post-start): %w", err)
					return
				}
			case proto.Stop:
				// Caller-requested termination. The defer r.Close()
				// above does the actual work (SIGKILL → tracer's wait4
				// returns Signaled → Paused → events channel close).
				readDone <- nil
				return
			case proto.Pause:
				// Caller-requested cooperative pause for engine
				// handoff. Pause sends SIGSTOP to the child; the
				// tracer's non-forwardable signal path emits a
				// Paused (carrying regs + sparse Regions) and
				// returns, closing the events channel. The main
				// goroutine forwards the Paused, then this reader
				// loop is unblocked by the WS close from serve's
				// defer. No `return` here — keep accepting Code /
				// Stop until the tracer ends the session.
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

	for ev := range events {
		data, err := proto.MarshalOutbound(ev)
		if err != nil {
			return fmt.Errorf("marshal outbound: %w", err)
		}
		if err := ws.Write(ctx, websocket.MessageText, data); err != nil {
			return fmt.Errorf("write outbound: %w", err)
		}
	}
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
