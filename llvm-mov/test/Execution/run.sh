#!/usr/bin/env bash
# Execution-test runner for stage 0+.
#
# For every <name>.ll under test/Execution/, do:
#   1. llvm-mov-llc <name>.ll -o <name>.s
#   2. as --32 <name>.s -> <name>.o
#   3. assemble a fixture-specific _start.s (see below) -> _start.o
#   4. ld -m elf_i386 -static -e _start _start.o <name>.o -> <name>.elf
#   5. ./<name>.elf, capture exit code
#   6. compare against <name>.expect (or default-to-0 when no .expect)
#
# Per-fixture `_start.s` shape:
#   - default (no <name>.callargs file present, stage 0/1):
#       `call main; mov ebx,eax; mov eax,1; int 0x80`
#   - with <name>.callargs (stage 2+):
#       first word = function name to call, rest = i32 args (cdecl push order,
#       runner reverses them).  e.g. `identity 42` produces
#       `push 42; call identity; add esp, 4; ...`.
#
# Generating _start inline rather than checking in one .s per fixture keeps
# the fixture set declarative — the runner owns the cdecl convention.
#
# Honour BUILD_DIR positional arg (passed by Makefile) so the runner finds
# the just-built llvm-mov-llc binary. Defaults to ./build.

set -euo pipefail

BUILD_DIR="${1:-build}"
DRIVER="${BUILD_DIR}/bin/llvm-mov-llc"
HERE="$(cd "$(dirname "$0")" && pwd)"

if ! [ -x "$DRIVER" ]; then
    echo "error: $DRIVER not found — build first ('make build')." 1>&2
    exit 2
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Emit a `_start.s` that performs `func(args...)` per cdecl and then
# exits via `int 0x80` with `func`'s return value in EBX. Stage 0/1
# fixtures call `func=main` with no args.
emit_start() {
    local out="$1" func="$2"; shift 2
    local args=("$@")
    local args_size=$(( ${#args[@]} * 4 ))
    {
        echo '.intel_syntax noprefix'
        echo '.section .text'
        echo '.global _start'
        echo '_start:'
        # cdecl: push args right-to-left.
        for ((i=${#args[@]}-1; i>=0; i--)); do
            echo "    push ${args[i]}"
        done
        echo "    call ${func}"
        if [ "$args_size" -gt 0 ]; then
            echo "    add esp, ${args_size}"
        fi
        echo '    mov ebx, eax       # main()/func() return → exit status'
        echo '    mov eax, 1         # __NR_exit'
        echo '    int 0x80'
    } > "$out"
}

pass=0
fail=0
fail_names=()

shopt -s nullglob
for ll in "${HERE}"/*.ll; do
    name="$(basename "${ll}" .ll)"
    expect_file="${HERE}/${name}.expect"
    callargs_file="${HERE}/${name}.callargs"
    expected_exit=0
    if [ -f "$expect_file" ]; then
        expected_exit="$(cat "$expect_file")"
    fi

    s="${WORK}/${name}.s"
    o="${WORK}/${name}.o"
    start_s="${WORK}/${name}.start.s"
    start_o="${WORK}/${name}.start.o"
    elf="${WORK}/${name}.elf"

    # Build the fixture-specific _start.
    if [ -f "$callargs_file" ]; then
        # shellcheck disable=SC2046  # word split is intentional, callargs is plain text
        emit_start "$start_s" $(cat "$callargs_file")
    else
        emit_start "$start_s" main
    fi
    if ! as --32 -o "$start_o" "$start_s" 2>"${WORK}/${name}.start.log"; then
        echo "FAIL  ${name}: as on synthesised _start failed:"
        sed 's/^/  /' "${WORK}/${name}.start.log"
        echo "  emitted _start was:"
        sed 's/^/    /' "$start_s"
        fail=$((fail + 1))
        fail_names+=("${name}")
        continue
    fi

    # -verify-machineinstrs runs LLVM's MachineVerifier after each
    # MachineFunctionPass — late-MI invariants the stage-7 legalize
    # touches (live-ins, terminator class, CFG successors, …) get
    # caught here rather than ~3 months later when codex review
    # surfaces them. Negligible runtime cost on our fixtures.
    if ! "${DRIVER}" -verify-machineinstrs "${ll}" -o "${s}" 2>"${WORK}/${name}.driver.log"; then
        echo "FAIL  ${name}: llvm-mov-llc failed:"
        sed 's/^/  /' "${WORK}/${name}.driver.log"
        fail=$((fail + 1))
        fail_names+=("${name}")
        continue
    fi

    if ! as --32 -o "${o}" "${s}" 2>"${WORK}/${name}.as.log"; then
        echo "FAIL  ${name}: as failed:"
        sed 's/^/  /' "${WORK}/${name}.as.log"
        echo "  emitted asm was:"
        sed 's/^/    /' "${s}"
        fail=$((fail + 1))
        fail_names+=("${name}")
        continue
    fi

    if ! ld -m elf_i386 -static -e _start -o "${elf}" "${start_o}" "${o}" 2>"${WORK}/${name}.ld.log"; then
        echo "FAIL  ${name}: ld failed:"
        sed 's/^/  /' "${WORK}/${name}.ld.log"
        fail=$((fail + 1))
        fail_names+=("${name}")
        continue
    fi

    # Run; capture exit code. set +e because we WANT the exit status.
    set +e
    "${elf}"
    actual_exit=$?
    set -e

    if [ "${actual_exit}" = "${expected_exit}" ]; then
        echo "PASS  ${name}  (exit ${actual_exit})"
        pass=$((pass + 1))
    else
        echo "FAIL  ${name}: expected exit ${expected_exit}, got ${actual_exit}"
        fail=$((fail + 1))
        fail_names+=("${name}")
    fi
done

echo
echo "----- ${pass} passed, ${fail} failed -----"
if [ "${fail}" -gt 0 ]; then
    printf 'failed: %s\n' "${fail_names[@]}"
    exit 1
fi
