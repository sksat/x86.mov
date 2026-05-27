#!/usr/bin/env bash
# Stage-7+ mov-only gate. For every fixture under test/MovOnly/, build it
# through the full pipeline and assert the disassembly of the linked ELF's
# .text contains only mov-family opcodes (plus the runtime-provided
# `int 0x80` in `_start.s`).
#
# At stage 7a0 the MovOnlyLegalize pass is still a no-op, so no fixture
# can pass this gate yet — the harness exits 0 with "no fixtures" instead
# of failing, and each subsequent 7-stage (7a1 ADD, 7b AND/OR/XOR, 7c
# CMP/Jcc/JMP, 7d CALL/RET) lights up the next group.
#
# The gate looks at `objdump -d -Mintel` output: any line whose mnemonic
# isn't in the whitelist counts as a violation. The whitelist:
#   - mov family: mov, movs[bw]l-style — only `mov` actually emitted today
#   - nothing else
# `_start.s`'s int 0x80 lives in a different ELF that the runner links
# alongside the fixture, but objdump-ing only the fixture object skips
# the runtime — see how we invoke objdump below.

set -euo pipefail

BUILD_DIR="${1:-build}"
DRIVER="${BUILD_DIR}/bin/llvm-mov-llc"
HERE="$(cd "$(dirname "$0")" && pwd)"

if ! [ -x "$DRIVER" ]; then
    echo "error: $DRIVER not found — run 'make build' first." 1>&2
    exit 2
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Allowed mnemonics. Stage 7's whole point is to drive this list down to
# `mov` (plus its widening cousins) and the `int 0x80` runtime escape.
#
# A fixture may opt in to additional opcodes via a per-fixture `.expect`
# side file (one mnemonic per non-empty, non-comment line). This is the
# explicit acknowledgement that "stage 7a1's legalize doesn't cover X
# yet — and that's expected". Each later 7-stage shrinks the .expect
# files of fixtures it touches; stage 7d's job is to drive them empty.
ALLOWED='mov|movabs|movzx|movsx'

# Read a per-fixture .expect file (if any) and merge its mnemonics into
# ALLOWED. Returns a regex anchored as ^(...)$ on stdout.
read_allowed_regex() {
    local expect_file="$1"
    if [ -f "${expect_file}" ]; then
        local extras
        extras="$(grep -vE '^\s*(#|$)' "${expect_file}" | awk 'NF>0{print $1}' | tr '\n' '|' | sed 's/|$//')"
        if [ -n "${extras}" ]; then
            printf '^(%s|%s)$\n' "${ALLOWED}" "${extras}"
            return
        fi
    fi
    printf '^(%s)$\n' "${ALLOWED}"
}

pass=0
fail=0
fail_names=()

shopt -s nullglob
fixtures=("${HERE}"/*.ll)
if [ "${#fixtures[@]}" -eq 0 ]; then
    echo "(no MovOnly fixtures yet — stage 7a0 ships the gate without"
    echo " any fixtures so the harness exits clean. fixtures land at"
    echo " stage 7a1 onwards.)"
    exit 0
fi

for ll in "${fixtures[@]}"; do
    name="$(basename "${ll}" .ll)"
    s="${WORK}/${name}.s"
    o="${WORK}/${name}.o"

    # Codex's stage-7a0 review (P1) flagged that build failures used to
    # report SKIP and the harness still exited 0 — that lets a regression
    # silently take a mov-only fixture offline. Now they count as FAILs.
    if ! "${DRIVER}" "${ll}" -o "${s}" 2>"${WORK}/${name}.driver.log"; then
        echo "FAIL  ${name}: llvm-mov-llc failed:"
        sed 's/^/  /' "${WORK}/${name}.driver.log"
        fail=$((fail + 1))
        fail_names+=("${name}")
        continue
    fi

    if ! as --32 -o "${o}" "${s}" 2>"${WORK}/${name}.as.log"; then
        echo "FAIL  ${name}: as failed:"
        sed 's/^/  /' "${WORK}/${name}.as.log"
        fail=$((fail + 1))
        fail_names+=("${name}")
        continue
    fi

    # objdump the .text and look for non-mov mnemonics. The awk pull
    # picks just the mnemonic column (after `addr: bytes`).
    fixture_allowed="$(read_allowed_regex "${HERE}/${name}.expect")"
    violations="$(
        objdump -d -Mintel --no-show-raw-insn "${o}" \
            | awk '/^[[:space:]]*[0-9a-f]+:/ {
                       # line shape: "  <addr>: <mnemonic> ..."
                       mnemonic = $2;
                       print mnemonic;
                   }' \
            | grep -Ev "${fixture_allowed}" \
            | sort -u || true
    )"

    if [ -z "$violations" ]; then
        echo "PASS  ${name}  (mov-only)"
        pass=$((pass + 1))
    else
        echo "FAIL  ${name}  non-mov opcodes:"
        echo "$violations" | sed 's/^/    /'
        fail=$((fail + 1))
        fail_names+=("${name}")
    fi
done

echo
echo "----- ${pass} mov-only, ${fail} failed -----"
if [ "${fail}" -gt 0 ]; then
    printf 'failed: %s\n' "${fail_names[@]}"
    exit 1
fi
