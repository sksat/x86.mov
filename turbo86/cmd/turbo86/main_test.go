//go:build linux

package main

import (
	"reflect"
	"strings"
	"testing"
)

// TestSecurityBanner pins the startup warning. turbo86 executes
// untrusted guest machine code natively on the host CPU (see
// DESIGN.md threat model), so the banner has to scream that loudly
// enough that nobody runs a stock build outside a sandbox by
// accident. We assert intent, not the exact ASCII art: a non-empty
// multi-line banner that names the danger ("SUPER INSECURE"), the
// reason (untrusted code runs natively), and the mitigation (sandbox
// only).
func TestSecurityBanner(t *testing.T) {
	lines := securityBanner()
	if len(lines) == 0 {
		t.Fatal("securityBanner() returned no lines")
	}
	joined := strings.ToLower(strings.Join(lines, "\n"))
	for _, want := range []string{"super insecure", "remote code execution", "untrusted", "nativ", "sandbox"} {
		if !strings.Contains(joined, want) {
			t.Errorf("securityBanner() missing %q; got:\n%s", want, strings.Join(lines, "\n"))
		}
	}
}

// TestColorize covers the TTY-only red policy. The function is pure
// (takes an explicit enabled flag) so the I/O-bound TTY probe stays
// out of the unit test. Disabled must return the lines untouched —
// that's the bytes that land in a redirected log file; enabled wraps
// each non-empty line in bold-red ANSI and resets, so escape codes
// never leak across a line and a terminal renders the whole banner
// red.
func TestColorize(t *testing.T) {
	in := []string{"a", "b"}

	if got := colorize(in, false); !reflect.DeepEqual(got, in) {
		t.Errorf("colorize(_, false) = %#v, want unchanged %#v", got, in)
	}

	got := colorize(in, true)
	if len(got) != len(in) {
		t.Fatalf("colorize(_, true) returned %d lines, want %d", len(got), len(in))
	}
	for i, line := range got {
		if !strings.HasPrefix(line, "\x1b[1;31m") || !strings.HasSuffix(line, "\x1b[0m") {
			t.Errorf("line %d not wrapped in bold-red+reset: %q", i, line)
		}
		if !strings.Contains(line, in[i]) {
			t.Errorf("line %d lost its text %q: %q", i, in[i], line)
		}
	}
}

func TestParseOriginPatterns(t *testing.T) {
	cases := []struct {
		name string
		in   string
		want []string
	}{
		{"empty string is nil (strict default)", "", nil},
		{"single pattern", "x86.mov", []string{"x86.mov"}},
		{"trims whitespace", "  x86.mov , *.x86-mov.pages.dev ",
			[]string{"x86.mov", "*.x86-mov.pages.dev"}},
		{"drops empty entries from trailing/double commas",
			"x86.mov,,localhost:*,",
			[]string{"x86.mov", "localhost:*"}},
		// All-whitespace / all-empty input collapses to nil so
		// `server.Handler(nil)` sees the strict default rather than
		// an empty-but-non-nil slice — they behave the same in the
		// server path today, but a future "len > 0" branch shouldn't
		// trip on whitespace from a misconfigured CLI flag.
		{"all-empty entries collapse to nil", ",,,", nil},
	}
	for _, tc := range cases {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			got := parseOriginPatterns(tc.in)
			if !reflect.DeepEqual(got, tc.want) {
				t.Errorf("parseOriginPatterns(%q) = %#v, want %#v", tc.in, got, tc.want)
			}
		})
	}
}

// TestDefaultAllowedOrigins_ParsesIntoExpectedSet pins the default
// allow-list against a typo in the constant. Reading the constant
// directly is enough — the goal is "we ship the deploys we said we
// would" not "this exact list, no more no less".
func TestDefaultAllowedOrigins_ParsesIntoExpectedSet(t *testing.T) {
	got := parseOriginPatterns(DefaultAllowedOrigins)
	want := []string{
		"x86.mov",
		"*.x86-mov.pages.dev",
		"localhost",
		"localhost:*",
		"127.0.0.1",
		"127.0.0.1:*",
	}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("DefaultAllowedOrigins:\n  got:  %#v\n  want: %#v", got, want)
	}
}
