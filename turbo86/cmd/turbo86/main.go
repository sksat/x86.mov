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

	"github.com/sksat/x86.mov/turbo86/server"
)

func main() {
	addr := flag.String("addr", "127.0.0.1:1234", "listen address for the WebSocket server")
	flag.Parse()

	http.Handle("/", server.Handler())
	log.Printf("turbo86 listening on ws://%s/", *addr)
	if err := http.ListenAndServe(*addr, nil); err != nil {
		log.Fatalf("listen: %v", err)
	}
}
