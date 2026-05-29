//go:build linux

package server_test

import (
	"bytes"
	"context"
	"log"
	"net/http"
	"net/http/httptest"
	"reflect"
	"regexp"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/coder/websocket"

	"github.com/sksat/x86.mov/turbo86/proto"
	"github.com/sksat/x86.mov/turbo86/server"
)

// TestE2E_ExitFortyTwo_OverWebSocket is the headline end-to-end test:
// a mock client connects to the server, streams the same exit(42) byte
// sequence the runner tests use, and reads the resulting Exit{42} event
// back over the wire. Exercises proto + runner + stub + server in one
// pass.
func TestE2E_ExitFortyTwo_OverWebSocket(t *testing.T) {
	srv := httptest.NewServer(server.Handler(nil))
	defer srv.Close()

	wsURL := "ws" + strings.TrimPrefix(srv.URL, "http")

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	ws, _, err := websocket.Dial(ctx, wsURL, nil)
	if err != nil {
		t.Fatalf("Dial: %v", err)
	}
	defer ws.CloseNow()

	const entry uint32 = 0x08048000
	//   B8 01 00 00 00         mov eax, 1
	//   BB 2A 00 00 00         mov ebx, 42
	//   CD 80                  int 0x80
	exit42 := []byte{
		0xB8, 0x01, 0x00, 0x00, 0x00,
		0xBB, 0x2A, 0x00, 0x00, 0x00,
		0xCD, 0x80,
	}

	sendInbound(t, ctx, ws, proto.Code{Offset: entry, Bytes: exit42})
	sendInbound(t, ctx, ws, proto.Start{Entry: entry, StackTop: 0x701FFFF0})

	got := readAllEvents(t, ctx, ws)
	want := []proto.Outbound{proto.Exit{Code: 42}}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("events:\n  got:  %#v\n  want: %#v", got, want)
	}
}

// TestE2E_LoadContext_OverWebSocket exercises the migration receive
// path through the WS: a client hands a Context (regs preloaded for
// SYS_exit with status 42) and a single int 0x80 instruction, and the
// session exits as 42 without the guest code ever touching eax/ebx.
func TestE2E_LoadContext_OverWebSocket(t *testing.T) {
	srv := httptest.NewServer(server.Handler(nil))
	defer srv.Close()

	wsURL := "ws" + strings.TrimPrefix(srv.URL, "http")
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	ws, _, err := websocket.Dial(ctx, wsURL, nil)
	if err != nil {
		t.Fatalf("Dial: %v", err)
	}
	defer ws.CloseNow()

	const entry uint32 = 0x08048000
	sendInbound(t, ctx, ws, proto.LoadContext{Context: proto.Context{
		Regs: proto.Regs{
			Eax: 1, Ebx: 42, Esp: 0x701FFFF0, Eip: entry,
		},
		Regions: []proto.MemRegion{
			{Addr: entry, Bytes: []byte{0xCD, 0x80}},
		},
	}})

	got := readAllEvents(t, ctx, ws)
	want := []proto.Outbound{proto.Exit{Code: 42}}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("events:\n  got:  %#v\n  want: %#v", got, want)
	}
}

// TestE2E_PostStartCodeStreaming exercises the streaming case: after
// Start, the client keeps sending Code messages while the guest is
// running. The server must apply them via runner.WriteCode without
// disrupting the in-flight syscall loop. Demonstrates the underlying
// streaming primitive end-to-end over the wire.
//
// Guest: write(1, "A", 1); exit(42)  (two syscalls).
// Sequence: Code + Code(data) + Start → recv Stdout("A") → Code(post-
// Start, unused address) → recv Exit{42}.
func TestE2E_PostStartCodeStreaming(t *testing.T) {
	srv := httptest.NewServer(server.Handler(nil))
	defer srv.Close()

	wsURL := "ws" + strings.TrimPrefix(srv.URL, "http")
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	ws, _, err := websocket.Dial(ctx, wsURL, nil)
	if err != nil {
		t.Fatalf("Dial: %v", err)
	}
	defer ws.CloseNow()

	const entry uint32 = 0x08048000
	const aAddr uint32 = 0x08048100
	const lateAddr uint32 = 0x08049000

	program := []byte{
		0xB8, 0x04, 0x00, 0x00, 0x00, // mov eax, 4    (SYS_write)
		0xBB, 0x01, 0x00, 0x00, 0x00, // mov ebx, 1    (stdout)
		0xB9, 0x00, 0x81, 0x04, 0x08, // mov ecx, aAddr
		0xBA, 0x01, 0x00, 0x00, 0x00, // mov edx, 1    (len)
		0xCD, 0x80, // int 0x80
		0xB8, 0x01, 0x00, 0x00, 0x00, // mov eax, 1    (SYS_exit)
		0xBB, 0x2A, 0x00, 0x00, 0x00, // mov ebx, 42
		0xCD, 0x80, // int 0x80
	}

	sendInbound(t, ctx, ws, proto.Code{Offset: entry, Bytes: program})
	sendInbound(t, ctx, ws, proto.Code{Offset: aAddr, Bytes: []byte("A")})
	sendInbound(t, ctx, ws, proto.Start{Entry: entry, StackTop: 0x701FFFF0})

	// First event: Stdout("A"). Reaching this means the server has
	// processed the write syscall stop and is between syscalls.
	first := readNextEvent(t, ctx, ws)
	if want := (proto.Stdout{Bytes: []byte("A")}); !reflect.DeepEqual(first, want) {
		t.Fatalf("first event: got %#v want %#v", first, want)
	}

	// Mid-session streaming Code. Bytes content irrelevant — the test
	// is "does the server accept Code after Start without disrupting
	// the in-flight session".
	sendInbound(t, ctx, ws, proto.Code{Offset: lateAddr, Bytes: []byte{0x90, 0x90}})

	// Drain remaining events; expect Exit{42}.
	rest := readAllEvents(t, ctx, ws)
	wantRest := []proto.Outbound{proto.Exit{Code: 42}}
	if !reflect.DeepEqual(rest, wantRest) {
		t.Errorf("remaining events: got %#v want %#v", rest, wantRest)
	}
}

// TestE2E_StopMessageInterruptsTightLoop is the graceful version of the
// disconnect test: the client wants to cancel a runaway guest without
// dropping the WebSocket. Sends Stop after letting the loop spin
// briefly, then reads the resulting Paused(SIGKILL).
func TestE2E_StopMessageInterruptsTightLoop(t *testing.T) {
	srv := httptest.NewServer(server.Handler(nil))
	defer srv.Close()

	wsURL := "ws" + strings.TrimPrefix(srv.URL, "http")
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	ws, _, err := websocket.Dial(ctx, wsURL, nil)
	if err != nil {
		t.Fatalf("Dial: %v", err)
	}
	defer ws.CloseNow()

	const entry uint32 = 0x08048000
	sendInbound(t, ctx, ws, proto.Code{Offset: entry, Bytes: []byte{0xEB, 0xFE}}) // jmp $
	sendInbound(t, ctx, ws, proto.Start{Entry: entry, StackTop: 0x701FFFF0})

	// Let the guest enter the loop. Reader goroutine on the server is
	// blocked on ws.Read at this point; tracer is blocked in wait4.
	time.Sleep(50 * time.Millisecond)

	// Graceful stop request — no disconnect.
	sendInbound(t, ctx, ws, proto.Stop{})

	got := readAllEvents(t, ctx, ws)
	if len(got) == 0 {
		t.Fatal("expected at least one event after Stop, got none")
	}
	paused, ok := got[len(got)-1].(proto.Paused)
	if !ok {
		t.Fatalf("final event: got %T %#v, want proto.Paused", got[len(got)-1], got[len(got)-1])
	}
	if paused.Signal != 9 { // SIGKILL
		t.Errorf("Paused.Signal: got %d, want 9 (SIGKILL)", paused.Signal)
	}
}

// TestE2E_PauseMessageEmitsPausedWithContext exercises the engine-handoff
// trigger over the WS: client sends Pause while the guest spins, server
// translates it to Runner.Pause (SIGSTOP), tracer emits a Paused
// carrying the canonical Context (Regs + sparse Regions), the session
// ends and the WS closes normally. A peer engine would then load the
// Context via its own resume path; this test stops at "the WS round
// trip works".
func TestE2E_PauseMessageEmitsPausedWithContext(t *testing.T) {
	srv := httptest.NewServer(server.Handler(nil))
	defer srv.Close()

	wsURL := "ws" + strings.TrimPrefix(srv.URL, "http")
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	ws, _, err := websocket.Dial(ctx, wsURL, nil)
	if err != nil {
		t.Fatalf("Dial: %v", err)
	}
	defer ws.CloseNow()

	const entry uint32 = 0x08048000
	sendInbound(t, ctx, ws, proto.Code{Offset: entry, Bytes: []byte{0xEB, 0xFE}}) // jmp $
	sendInbound(t, ctx, ws, proto.Start{Entry: entry, StackTop: 0x701FFFF0})

	// Let the guest enter the loop so we're exercising the
	// "no-syscall tight loop interrupted by Pause" path.
	time.Sleep(50 * time.Millisecond)

	sendInbound(t, ctx, ws, proto.Pause{})

	got := readAllEvents(t, ctx, ws)
	if len(got) == 0 {
		t.Fatal("expected at least one event after Pause, got none")
	}
	paused, ok := got[len(got)-1].(proto.Paused)
	if !ok {
		t.Fatalf("final event: got %T %#v, want proto.Paused", got[len(got)-1], got[len(got)-1])
	}
	// SIGSTOP = 19 on Linux.
	if paused.Signal != 19 {
		t.Errorf("Paused.Signal: got %d, want 19 (SIGSTOP from Pause)", paused.Signal)
	}
	if paused.Regs.Eip != entry {
		t.Errorf("Paused.Regs.Eip: got %#x, want %#x (the jmp instruction)",
			paused.Regs.Eip, entry)
	}
	// The stack-top scaffold (argc/argv/envp written by the runner)
	// guarantees at least one non-zero page in the sparse snapshot.
	if len(paused.Regions) == 0 {
		t.Error("Paused.Regions: expected at least one non-zero region in the handoff Context")
	}
}

// TestE2E_ClientDisconnectStopsTightLoop verifies that closing the WS
// connection while the guest is in a no-syscall tight loop tears the
// session down. Without the reader goroutine's `defer r.Close()`, a
// runaway guest would leave the handler blocked on the events channel
// forever — and httptest.Server.Close() would hang waiting for it.
func TestE2E_ClientDisconnectStopsTightLoop(t *testing.T) {
	srv := httptest.NewServer(server.Handler(nil))

	wsURL := "ws" + strings.TrimPrefix(srv.URL, "http")
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	ws, _, err := websocket.Dial(ctx, wsURL, nil)
	if err != nil {
		t.Fatalf("Dial: %v", err)
	}

	const entry uint32 = 0x08048000
	// jmp short -2: infinite loop with no syscalls. The runner has
	// no natural stop point — it's stuck in wait4 until something
	// from outside (Close → SIGKILL) wakes it up.
	sendInbound(t, ctx, ws, proto.Code{Offset: entry, Bytes: []byte{0xEB, 0xFE}})
	sendInbound(t, ctx, ws, proto.Start{Entry: entry, StackTop: 0x701FFFF0})

	// Let the guest spin briefly.
	time.Sleep(50 * time.Millisecond)

	// Disconnect. The reader goroutine should see ws.Read fail, call
	// r.Close, the runner kills the child, the loop exits.
	_ = ws.CloseNow()

	// srv.Close blocks until all handlers return. If the bug is back,
	// this hangs forever.
	done := make(chan struct{})
	go func() {
		srv.Close()
		close(done)
	}()
	select {
	case <-done:
		// Server cleaned up — pass.
	case <-time.After(3 * time.Second):
		t.Fatal("server did not return after client disconnect — runner stuck in tight loop?")
	}
}

// readNextEvent reads exactly one outbound frame.
func readNextEvent(t *testing.T, ctx context.Context, ws *websocket.Conn) proto.Outbound {
	t.Helper()
	_, data, err := ws.Read(ctx)
	if err != nil {
		t.Fatalf("read frame: %v", err)
	}
	msg, err := proto.UnmarshalOutbound(data)
	if err != nil {
		t.Fatalf("parse frame %q: %v", data, err)
	}
	return msg
}

func sendInbound(t *testing.T, ctx context.Context, ws *websocket.Conn, msg proto.Inbound) {
	t.Helper()
	data, err := proto.MarshalInbound(msg)
	if err != nil {
		t.Fatalf("marshal %T: %v", msg, err)
	}
	if err := ws.Write(ctx, websocket.MessageText, data); err != nil {
		t.Fatalf("write %T: %v", msg, err)
	}
}

// TestE2E_LogsAreCoherentForOneSession is the structural test for the
// session-logging surface. A LoadContext → Exit{42} session should
// produce: connect, runner ready, inbound LoadContext, outbound Exit,
// events summary, session end ok — all tagged with the same 8-hex
// session id. Stdout/Stderr content stays out of the log (only
// byte counts) by design — guests should not be able to leak data
// into operator logs.
func TestE2E_LogsAreCoherentForOneSession(t *testing.T) {
	var buf safeBuffer
	prev := log.Default().Writer()
	log.Default().SetOutput(&buf)
	defer log.Default().SetOutput(prev)

	srv := httptest.NewServer(server.Handler(nil))
	defer srv.Close()
	wsURL := "ws" + strings.TrimPrefix(srv.URL, "http")
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	ws, _, err := websocket.Dial(ctx, wsURL, nil)
	if err != nil {
		t.Fatalf("Dial: %v", err)
	}
	defer ws.CloseNow()

	const entry uint32 = 0x08048000
	sendInbound(t, ctx, ws, proto.LoadContext{Context: proto.Context{
		Regs: proto.Regs{Eax: 1, Ebx: 42, Esp: 0x701FFFF0, Eip: entry},
		Regions: []proto.MemRegion{
			{Addr: entry, Bytes: []byte{0xCD, 0x80}},
		},
	}})
	// Drain — gives the handleSession event-forwarding loop a chance
	// to emit the Exit event before we tear the connection down.
	if got := readAllEvents(t, ctx, ws); len(got) != 1 {
		t.Fatalf("events: got %d, want 1", len(got))
	}
	// Closing the WS unblocks the reader goroutine's ws.Read so the
	// final "session end" log line gets emitted before we assert.
	_ = ws.Close(websocket.StatusNormalClosure, "")

	// A short wait covers the goroutine-scheduling tail; without it
	// the "session end" log line can race the assertion below.
	deadline := time.Now().Add(500 * time.Millisecond)
	for time.Now().Before(deadline) {
		if strings.Contains(buf.String(), "session end") {
			break
		}
		time.Sleep(10 * time.Millisecond)
	}

	logText := buf.String()

	// All session log lines must share a single 8-hex session id.
	ids := regexp.MustCompile(`\[([0-9a-f]{8})\]`).FindAllStringSubmatch(logText, -1)
	if len(ids) == 0 {
		t.Fatalf("expected at least one [session-id] log line, got:\n%s", logText)
	}
	first := ids[0][1]
	for _, m := range ids {
		if m[1] != first {
			t.Errorf("multiple session ids in one session log: %q vs %q", first, m[1])
			break
		}
	}

	for _, want := range []string{
		"connect: remote=",
		"runner: ready",
		"inbound LoadContext: mode=host",
		"eip=0x8048000",
		"outbound Exit: code=42",
		"events: total=1",
		"session end: ok",
	} {
		if !strings.Contains(logText, want) {
			t.Errorf("log missing %q\nfull log:\n%s", want, logText)
		}
	}

	// Stdout content must NOT leak into the log — guests shouldn't be
	// able to push data into the operator's transcript. This program
	// emits no stdout so we just sanity-check the counter format.
	if !strings.Contains(logText, "stdout=0B") {
		t.Errorf("log should include `stdout=0B` summary, got:\n%s", logText)
	}
}

// TestHandler_RejectsCrossOriginWithoutAllowList pins the security
// boundary: with `Handler(nil)` (no allow list configured) and a
// browser-like cross-origin handshake (Origin set, mismatching Host),
// the upgrade MUST fail. This is the "any visited page can drive
// local turbo86 over ws://127.0.0.1" attack surface — the default
// coder/websocket Origin == Host policy is what protects us, and a
// regression here silently re-opens the cross-site RCE described in
// DESIGN.md.
func TestHandler_RejectsCrossOriginWithoutAllowList(t *testing.T) {
	srv := httptest.NewServer(server.Handler(nil))
	defer srv.Close()
	wsURL := "ws" + strings.TrimPrefix(srv.URL, "http")
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	_, resp, err := websocket.Dial(ctx, wsURL, &websocket.DialOptions{
		HTTPHeader: http.Header{"Origin": []string{"https://attacker.example"}},
	})
	if err == nil {
		t.Fatal("expected handshake rejection, got success")
	}
	if resp != nil && resp.StatusCode != http.StatusForbidden {
		t.Errorf("expected HTTP 403, got %d", resp.StatusCode)
	}
}

// TestHandler_AcceptsPatternMatchedOrigin verifies the allow-list path
// works: a wildcard pattern matches a typical CF Pages preview Origin
// (head-ref slug subdomain), and the resulting session runs cleanly to
// completion. Uses the LoadContext path (no separate Start needed) so
// the test is short and stays focused on the handshake.
func TestHandler_AcceptsPatternMatchedOrigin(t *testing.T) {
	srv := httptest.NewServer(server.Handler([]string{
		"x86.mov",
		"*.x86-mov.pages.dev",
	}))
	defer srv.Close()
	wsURL := "ws" + strings.TrimPrefix(srv.URL, "http")
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	ws, _, err := websocket.Dial(ctx, wsURL, &websocket.DialOptions{
		HTTPHeader: http.Header{"Origin": []string{"https://my-branch.x86-mov.pages.dev"}},
	})
	if err != nil {
		t.Fatalf("expected handshake success, got: %v", err)
	}
	defer ws.CloseNow()

	const entry uint32 = 0x08048000
	sendInbound(t, ctx, ws, proto.LoadContext{Context: proto.Context{
		Regs: proto.Regs{Eax: 1, Ebx: 7, Esp: 0x701FFFF0, Eip: entry},
		Regions: []proto.MemRegion{
			{Addr: entry, Bytes: []byte{0xCD, 0x80}},
		},
	}})
	got := readAllEvents(t, ctx, ws)
	want := []proto.Outbound{proto.Exit{Code: 7}}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("events:\n  got:  %#v\n  want: %#v", got, want)
	}
}

// TestHandler_RejectsOriginOutsideAllowList completes the security
// triangle: even with an allow list configured, an Origin that doesn't
// match any pattern is still rejected. Otherwise a typo in the
// `--allow-origin` flag could accidentally widen the door.
func TestHandler_RejectsOriginOutsideAllowList(t *testing.T) {
	srv := httptest.NewServer(server.Handler([]string{"x86.mov"}))
	defer srv.Close()
	wsURL := "ws" + strings.TrimPrefix(srv.URL, "http")
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	_, resp, err := websocket.Dial(ctx, wsURL, &websocket.DialOptions{
		HTTPHeader: http.Header{"Origin": []string{"https://evil.example"}},
	})
	if err == nil {
		t.Fatal("expected handshake rejection, got success")
	}
	if resp != nil && resp.StatusCode != http.StatusForbidden {
		t.Errorf("expected HTTP 403, got %d", resp.StatusCode)
	}
}

// safeBuffer is a `bytes.Buffer` guarded by a mutex so the test's
// reader goroutine and the server's logger goroutine don't race on
// `Write` / `String`. The stdlib `bytes.Buffer` isn't safe for
// concurrent use.
type safeBuffer struct {
	mu  sync.Mutex
	buf bytes.Buffer
}

func (b *safeBuffer) Write(p []byte) (int, error) {
	b.mu.Lock()
	defer b.mu.Unlock()
	return b.buf.Write(p)
}

func (b *safeBuffer) String() string {
	b.mu.Lock()
	defer b.mu.Unlock()
	return b.buf.String()
}

// readAllEvents reads frames until the server closes the connection
// (normal closure = end of session) or the context expires. Returns
// the collected Outbound events in order.
func readAllEvents(t *testing.T, ctx context.Context, ws *websocket.Conn) []proto.Outbound {
	t.Helper()
	var events []proto.Outbound
	for {
		_, data, err := ws.Read(ctx)
		if err != nil {
			// Normal closure (status 1000) is the expected session-end signal.
			closeErr := websocket.CloseStatus(err)
			if closeErr == websocket.StatusNormalClosure || closeErr == -1 {
				return events
			}
			t.Fatalf("read frame: %v (close=%d)", err, closeErr)
		}
		msg, err := proto.UnmarshalOutbound(data)
		if err != nil {
			t.Fatalf("parse frame %q: %v", data, err)
		}
		events = append(events, msg)
	}
}
