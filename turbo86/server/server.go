//go:build linux

// Package server exposes turbo86 over a WebSocket. One connection = one
// guest session. v1 buffer-then-run: the client sends Code messages
// (optionally) and either Start (fresh) or LoadContext (resume from
// another engine), the server invokes the runner, then streams the
// resulting events back as JSON text frames and closes.
//
// Streaming-while-running (Code arriving mid-execution, multi-session
// per connection) is deferred to the streaming-Runner refactor.
package server

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"runtime"

	"github.com/coder/websocket"

	"github.com/sksat/x86.mov/turbo86/proto"
	"github.com/sksat/x86.mov/turbo86/runner"
	"github.com/sksat/x86.mov/turbo86/stub"
)

// Handler returns an http.Handler that upgrades GET requests to
// WebSocket and runs a guest session per connection.
func Handler() http.Handler {
	return http.HandlerFunc(serve)
}

func serve(w http.ResponseWriter, r *http.Request) {
	ws, err := websocket.Accept(w, r, &websocket.AcceptOptions{
		// Allow tests / local clients on different ports.
		InsecureSkipVerify: true,
	})
	if err != nil {
		return
	}
	defer ws.CloseNow()

	// All ptrace operations the runner issues target the OS thread that
	// did the exec.Cmd.Start(). Pin a dedicated goroutine to a thread
	// and never unlock — the thread is torn down when the goroutine
	// exits, which is exactly the lifetime we want.
	done := make(chan error, 1)
	go func() {
		runtime.LockOSThread()
		done <- handleSession(r.Context(), ws)
	}()

	if err := <-done; err != nil && !errors.Is(err, context.Canceled) {
		ws.Close(websocket.StatusInternalError, truncate(err.Error(), 120))
		return
	}
	ws.Close(websocket.StatusNormalClosure, "")
}

// handleSession reads Inbound messages until the run kicks off, drives
// the runner to completion, and writes the Outbound events out. Each
// connection is single-use: after the run ends, this returns and the
// connection closes.
func handleSession(ctx context.Context, ws *websocket.Conn) error {
	code := make(map[uint32][]byte)

	for {
		_, data, err := ws.Read(ctx)
		if err != nil {
			return fmt.Errorf("read inbound: %w", err)
		}
		msg, err := proto.UnmarshalInbound(data)
		if err != nil {
			return fmt.Errorf("parse inbound: %w", err)
		}

		switch m := msg.(type) {
		case proto.Code:
			// Later Code messages at the same offset replace earlier
			// ones — fine for v1's buffer-then-run semantics.
			code[m.Offset] = m.Bytes

		case proto.Start:
			events, err := runner.RunOnce(stub.Bytes, code, m.Entry, m.StackTop)
			if err != nil {
				return fmt.Errorf("RunOnce: %w", err)
			}
			return writeEvents(ctx, ws, events)

		case proto.LoadContext:
			events, err := runner.RunWithContext(stub.Bytes, m.Context)
			if err != nil {
				return fmt.Errorf("RunWithContext: %w", err)
			}
			return writeEvents(ctx, ws, events)

		default:
			return fmt.Errorf("unexpected inbound message %T before Start/LoadContext", msg)
		}
	}
}

func writeEvents(ctx context.Context, ws *websocket.Conn, events []proto.Outbound) error {
	for _, ev := range events {
		data, err := proto.MarshalOutbound(ev)
		if err != nil {
			return fmt.Errorf("marshal outbound: %w", err)
		}
		if err := ws.Write(ctx, websocket.MessageText, data); err != nil {
			return fmt.Errorf("write outbound: %w", err)
		}
	}
	return nil
}

func truncate(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n]
}
