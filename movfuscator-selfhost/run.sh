#!/usr/bin/env bash
# movfuscator self-host survey.
#
# Question: can the mov-only compiler (rcc + M/o/Vfuscator backend) compile
# *its own* C source through the mov pipeline?
#
# This subproject reuses the sibling movfuscator-wasm toolchain (its wasm
# cpp/rcc/as and its vendored movfuscator sources) and drives every translation
# unit of rcc through it:
#   1. wasm cpp  → .i   (lcc's own preprocessor)
#   2. wasm rcc  → .s   (rcc -target=x86/mov, the mov backend)
#   3. wasm as   → .o
# A unit counts as PASS only when the mov backend prints
# "M/o/Vfuscation complete." AND `as` produces an object. NB: on failure the
# backend still emits a partial .s and exits 0, so a non-empty .s is NOT a
# success signal — the completion banner is the only honest gate.

set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
wasm="$here/../movfuscator-wasm"
vendor="$wasm/vendor/movfuscator"
src="$vendor/lcc/src"
bld="$vendor/build"          # lburg-generated backend .c live here
cppjs="$wasm/build/cpp.js"
rccjs="$wasm/build/rcc.js"
asjs="$wasm/build/as.js"
patch="$here/patches/movfuscator-selfhost-c89.patch"

for required in "$cppjs" "$rccjs" "$asjs"; do
    if [ ! -f "$required" ]; then
        echo "FAIL: $required missing; build the sibling toolchain first:" >&2
        echo "  (cd $wasm && make build-wasm build-wasm-as)" >&2
        exit 1
    fi
done
if [ ! -d "$src" ]; then
    echo "FAIL: $src missing; fetch the sibling vendor first:" >&2
    echo "  (cd $wasm && make setup)" >&2
    exit 1
fi

# Apply the self-host C89 patch to the vendored backend source (idempotent).
# It clears the two easy walls (mid-block externs + SA_NODEFER); behaviour is
# neutral for rcc so the prebuilt toolchain stays valid.
if [ -f "$patch" ]; then
    if git -C "$vendor" apply --check -R "$patch" 2>/dev/null; then
        :   # already applied
    elif git -C "$vendor" apply --check "$patch" 2>/dev/null; then
        git -C "$vendor" apply "$patch"
        echo "applied $(basename "$patch")"
    else
        echo "warn: $(basename "$patch") neither applies nor is already applied" >&2
    fi
fi

# The translation units that form rcc (mirrors the native makefile's RCCOBJS +
# backend EXTRAOBJS). Front-end units are committed lcc/src/*.c; the per-arch
# backend selectors are lburg-generated into vendor/build/*.c.
FRONT=(
    alloc bind bytecode dag decl enode error event expr gen init inits input
    lex list main null output prof profio simp stab stmt string symbolic sym
    trace tree types
)
GENBACK=(alpha mips sparc x86 x86linux dagcheck mov)

# Known holdout: mov.c (#includes the M/o/Vfuscator backend movfuscator.c).
# The backend source is written for gcc/C99 and trips lcc's stricter C89
# front-end. The patch above already clears the first two walls (mid-block
# `extern` declarations hoisted to file scope; SA_NODEFER provided directly so
# the strict-ANSI header shape suffices). The remaining wall is structural:
# movfuscator.c forward-declares the lburg tables as `static short *_nts[];`
# etc. (incomplete arrays, completed later in the generated mov.c), and lcc's
# front-end rejects `static` incomplete-array tentative definitions outright.
# Clearing it needs an lcc front-end leniency change + a rebuilt wasm rcc, so
# it stays XFAIL until the toolchain is rebuilt. Every other translation unit
# of rcc compiles mov-only cleanly.
XFAIL=(mov)

# Same predefined macros / include order as the native lcc driver, plus the lcc
# src + build dirs so the compiler's own c.h and the lburg tables are found.
# The __STRICT_ANSI__/_POSIX_SOURCE pair keeps glibc's headers in their ANSI
# shape — lcc's front-end cannot parse the GNU-extension declarations that
# _GNU_SOURCE would expose.
#
# NB: __LCC__ is deliberately NOT defined. lcc's own c.h is the only consumer
# of __LCC__ in the tree, using it to `#define __STDC__` — which lcc's own cpp
# rejects as redefining a reserved builtin. The native build never hits this
# (rcc is built with gcc; lcc-cpp only preprocesses user code that never
# includes c.h). Dropping __LCC__ skips that block.
CPP_FLAGS=(
    -U__GNUC__ -D_POSIX_SOURCE -D__STRICT_ANSI__
    -Dunix -Di386 -Dlinux
    -D__unix__ -D__i386__ -D__linux__
    -D__signed__=signed
    -I"$src" -I"$bld" -I"$vendor/movfuscator"
    -I"$vendor/build/include" -I"$vendor/build/gcc/include" -I/usr/include
)

is_xfail() { local u; for u in "${XFAIL[@]}"; do [ "$u" = "$1" ] && return 0; done; return 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

pass=0; fail=0; xfail=0; xpass=0
run_unit() {
    local name="$1" c="$2"
    local i="$tmp/$name.i" s="$tmp/$name.s" o="$tmp/$name.o"
    local ok=0 reason=""

    if node "$cppjs" "${CPP_FLAGS[@]}" "$c" "$i" >"$tmp/$name.cpp.out" 2>&1; then
        local rcc_out
        rcc_out="$(node "$rccjs" -target=x86/mov "$i" "$s" 2>&1)"
        if echo "$rcc_out" | grep -q 'M/o/Vfuscation complete'; then
            if node "$asjs" --32 -o "$o" "$s" >"$tmp/$name.as.out" 2>&1 && [ -s "$o" ]; then
                ok=1
            else
                reason="as failed"
            fi
        else
            reason="$(echo "$rcc_out" | grep -E '\.c:[0-9]+:' | grep -v warning \
                      | sed -E 's#^.*/([a-z0-9_]+\.c):#\1:#' | sort -u | head -1)"
            [ -n "$reason" ] || reason="mov backend reported failure"
        fi
    else
        reason="cpp: $(grep -v 'Unknown preprocessor control warning' "$tmp/$name.cpp.out" | head -1)"
    fi

    if is_xfail "$name"; then
        if [ "$ok" = 1 ]; then echo "XPASS $name (expected to fail but compiled!)"; xpass=$((xpass+1));
        else echo "XFAIL $name — $reason"; xfail=$((xfail+1)); fi
    else
        if [ "$ok" = 1 ]; then
            echo "PASS  $name (.s $(wc -l < "$s") lines, mov $(grep -cE '^[[:space:]]*mov' "$s"), .o $(wc -c < "$o") b)"
            pass=$((pass+1))
        else
            echo "FAIL  $name — $reason"; fail=$((fail+1))
        fi
    fi
}

for name in "${FRONT[@]}";   do run_unit "$name" "$src/$name.c"; done
for name in "${GENBACK[@]}"; do run_unit "$name" "$bld/$name.c"; done

total=$(( ${#FRONT[@]} + ${#GENBACK[@]} ))
echo
echo "movfuscator self-host: $pass/$total units mov-only compiled (PASS $pass, FAIL $fail, XFAIL $xfail, XPASS $xpass)"
# Gate: every non-xfail unit must compile, and no xfail may unexpectedly pass
# without us updating the list.
[ "$fail" -eq 0 ] && [ "$xpass" -eq 0 ]
