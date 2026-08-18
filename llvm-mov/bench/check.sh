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
#   - The "total ELF (bytes)" row (host CRT / libc / rust-std sizes).
#   - Every reference column (movfuscator, clang/rustc -O0..-O3).
#
# What is left is the llvm-mov column's .text / .rodata size, mov count
# / total and non-mov mnemonic set — the numbers our backend actually
# controls. Divergence there is either a real codegen change (intended:
# update the baseline) or a silent regression (unintended: investigate).
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
#   - Every *reference* column: movfuscator and clang/rustc -O0..-O3.
#     These are external data points for context, and none of them is
#     reproducible across hosts. The host's gas/ld minor version moves
#     the movfuscator number (Debian 13 vs ubuntu-24.04 give 10221108
#     vs 10221148 for the same return42 fixture); a different build of
#     the same clang release moves the reference columns (Arch vs
#     apt.llvm.org clang-22 disagree on whether a `nop` is emitted).
#     None of that is anything llvm-mov did.
#
#     An earlier version of this script kept the clang columns, on the
#     grounds that clang is pinned to clang-22 in CI. That holds
#     between CI runs but not between a contributor's machine and CI,
#     which is where the baseline is actually written — so the gate
#     failed for everyone whose distro differed from whoever last ran
#     `make bench`.
#
#   - The `total ELF (bytes)` row, for the same reason one level up:
#     it is dominated by the host's CRT / libc / rust-std, not by our
#     output. The `.text size` and `.rodata size` rows already measure
#     our contribution exactly, and they stay in the comparison.
#
# The sed picks out 7-column table rows
# `| metric | llvm-mov | movfuscator | clang -O0 | -O1 | -O2 | -O3 |`
# and replaces cells 3..7 with a single `<reference>`. Header and
# separator rows get the same treatment, so before/after still match
# exactly when only the reference columns drift.
#
# What keeps the llvm-mov column itself reproducible across hosts is
# `examples/rust/rust-toolchain.toml`: a dep that doesn't round-trip
# through llvm-mov-llc is linked from rustc's own objects, so rustc's
# version would otherwise leak into the `.text` we measure.
strip_volatile() {
    grep -vE '^Generated [0-9]|^\| wall-clock runtime|^\| total ELF' "$1" \
        | sed -E 's/^(\|[^|]*\|[^|]*\|).*$/\1 <reference> |/'
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
