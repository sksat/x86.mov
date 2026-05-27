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
			events = r.Run(m.Entry, m.StackTop)
		case proto.LoadContext:
			events = r.RunWithContext(m.Context)
		default:
			return fmt.Errorf("unexpected inbound %T before Start/LoadContext", msg)
		}
	}

	// Phase 2: post-run. A side goroutine accepts streaming Code; the
	// main goroutine forwards events. Either side ending tears the
	// session down (defer r.Close() + deferred ws.CloseNow()).
	readDone := make(chan error, 1)
	go func() {
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
