#!/usr/bin/env bash
# bench/check.sh — regression test against the committed baseline.
#
# Runs `bench/run.sh` into a fresh temp file, diffs the deterministic
# rows against `bench/results.md` (the committed baseline), and exits
# non-zero on any mismatch. The two intentionally-volatile pieces are
# excluded from the comparison:
#
#   - The "Generated YYYY-MM-...Z on ..." preamble line (timestamp).
#   - The "wall-clock runtime (hyperfine mean)" row (host-dependent).
#
# Everything else — total ELF size, .text / .rodata size, mov count
# / total, non-mov mnemonic set — is deterministic given the same
# toolchain (clang/as/ld/movcc versions), so any divergence is either
# a real codegen change (intended: update the baseline) or a silent
# regression (unintended: investigate).
#
# Workflow:
#
#   $ make bench           # regenerate bench/results.md locally
#   $ git diff bench/      # review numbers
#   $ git commit bench/    # commit the new baseline if intended
#   $ make bench-check     # CI: re-run and assert no drift
#
# Override the fixture set the same way as run.sh:
#
#   $ ./bench/check.sh return0 return42 sum10

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

BASELINE="$HERE/results.md"
if [ ! -f "$BASELINE" ]; then
    echo "error: baseline $BASELINE missing; run 'make bench' first." 1>&2
    exit 2
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FRESH="$TMP/results.md"

# Regenerate into a temp file (no committed-file mutation).
RESULTS_OUT="$FRESH" "$HERE/run.sh" "$@" >/dev/null

# Strip the intentionally-volatile pieces from both before comparing:
#
#   - The "Generated ..." preamble (timestamp).
#   - The "wall-clock runtime (hyperfine mean)" row (host-dependent).
#   - The movfuscator column on every data row. This is external
#     reference data — the precise number depends on the host's gas/ld
#     minor version (e.g. Debian 13 vs ubuntu-24.04 ld give 10221108
#     vs 10221148 for the same return42 fixture, a 40-byte difference
#     that isn't anything llvm-mov did). We DO care about the
#     llvm-mov column, which our backend fully controls.
#
# The sed picks out 4-piped table rows (`| col1 | col2 | col3 |`) and
# replaces col3 (the movfuscator value) with `<movfuscator>`. Header
# and separator rows get the same treatment, so before/after still
# match exactly when only movfuscator drifts.
strip_volatile() {
    grep -vE '^Generated [0-9]|^\| wall-clock runtime' "$1" \
        | sed -E 's/^(\|[^|]*\|[^|]*\|)[^|]*\|$/\1 <movfuscator> |/'
}

diff_out="$(diff -u \
    <(strip_volatile "$BASELINE") \
    <(strip_volatile "$FRESH") || true)"

if [ -z "$diff_out" ]; then
    echo "bench-check: deterministic numbers match $BASELINE."
    exit 0
fi

echo "bench-check: drift detected vs committed baseline" 1>&2
echo "" 1>&2
echo "$diff_out" 1>&2
echo "" 1>&2
echo "If this change is intentional (an optimisation, or a deliberate" 1>&2
echo "codegen shape change), regenerate the baseline:" 1>&2
echo "" 1>&2
echo "  make bench" 1>&2
echo "  git add bench/results.md" 1>&2
echo "" 1>&2
echo "and commit it alongside the implementation change. Otherwise" 1>&2
echo "investigate the silent regression." 1>&2
exit 1
