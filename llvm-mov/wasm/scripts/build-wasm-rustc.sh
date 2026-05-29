#!/usr/bin/env bash
# Build a self-hosted `rustc.wasm` from bjorn3/rust's
# compile_rustc_for_wasm20 branch (Rust 1.96, edition 2024 capable)
# and populate the cache layout the `lib/rustc-driver.mjs` driver
# expects for the `'self-bjorn3-wasm20'` row in `RUSTC_VERSIONS`.
#
# Why this script exists:
#   The default rubrc-v0.2.0 artefact ships sysroots only for
#   wasm32-wasip1 and x86_64-unknown-linux-gnu. Neither matches the
#   i386 ABI / data layout that `llvm-mov-llc` accepts, so its IR
#   can't be fed downstream. This build adds an i686-unknown-linux-gnu
#   sysroot, which is the gating piece for the full
#   `.rs ─→ .ll ─→ .s ─→ ELF32` path.
#
# Output layout (the driver consumes this directly):
#   build/rustc-cache/self-bjorn3-wasm20/dist/
#     bin/rustc.wasm
#     lib/rustlib/i686-unknown-linux-gnu/lib/*.rlib + self-contained/
#     lib/rustlib/x86_64-unknown-linux-gnu/lib/...   (optional)
#     lib/rustlib/wasm32-wasip1/lib/...               (optional)
#
# Resource footprint:
#   - Wall-clock: ~hours on a 4–8 core box (Rust + wasm cross is slow).
#   - Disk: vendor/ source tree ~3 GB; install dir ~200 MB.
#   - Memory: 8 GB+ recommended for the wasm-targeted bootstrap.
#
# Quirks worth knowing (mirrors of what the build-wasm-llvm.sh script
# does for the C path — same operating model, different upstream):
#
# - **Vendored, never imported.** The `vendor/` directory is gitignored.
#   `git clone` happens here, pinned at the bjorn3 branch SHA below.
#   Don't edit vendor files in place; convert any change to a patch
#   under `patches/wasm-rustc/` so it survives `make distclean`.
# - **wasi-sdk-22 is mandatory** and pinned. Later wasi-sdk releases
#   ship Clang versions that have drifted from what the bjorn3 patches
#   target; bumping is a separate investigation.
# - **`./x.py install`** is the only build entry point. Don't try to
#   shortcut to `./x.py build rustc` — the install step also stages
#   the sysroots into the dist tree, which is what the driver needs.
# - **Linker stays as wasm-ld** (from wasi-sdk-22); the bjorn3 patch
#   wires it through `WASI_CLANG_WRAPPER_LINKER`.

set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"           # llvm-mov/wasm/
vendor="$root/vendor"
cache="$root/build/rustc-cache/self-bjorn3-wasm20"

# Pinned upstream — bjorn3's compile_rustc_for_wasm20 branch HEAD at
# the time this script was written. When updating, also update the
# `rustVersion` field in RUSTC_VERSIONS to match the new src/version.
RUST_REPO="https://github.com/bjorn3/rust"
RUST_BRANCH="compile_rustc_for_wasm20"
RUST_PINNED_SHA="3b6974e6ee565cadd42d3ff3d8aa5dfacf5b1fb6"   # repo tip 2024-09-26; bump deliberately
WASI_SDK_VERSION="22"
WASI_SDK_URL="https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-${WASI_SDK_VERSION}/wasi-sdk-${WASI_SDK_VERSION}.0-linux.tar.gz"

# Targets to install sysroots for. i686-unknown-linux-gnu is the only
# one that's gating downstream; the others are conveniences.
TARGETS=(
    "i686-unknown-linux-gnu"
    "x86_64-unknown-linux-gnu"
    "wasm32-wasip1"
)

mkdir -p "$vendor" "$cache"

# ── 1. Fetch bjorn3/rust at the pinned SHA ──────────────────────────
rust_src="$vendor/rust"
if [ ! -d "$rust_src/.git" ]; then
    echo "==> cloning $RUST_REPO at $RUST_BRANCH"
    git clone --branch "$RUST_BRANCH" --depth 1 "$RUST_REPO" "$rust_src"
    ( cd "$rust_src" && git fetch --depth 1 origin "$RUST_PINNED_SHA" && git checkout "$RUST_PINNED_SHA" )
else
    echo "==> vendor/rust already present; assuming pinned SHA $RUST_PINNED_SHA"
fi

# ── 2. Stage wasi-sdk-22 ─────────────────────────────────────────────
wasi_sdk="$vendor/wasi-sdk-${WASI_SDK_VERSION}.0"
if [ ! -d "$wasi_sdk" ]; then
    echo "==> fetching wasi-sdk-${WASI_SDK_VERSION}"
    tarball="$vendor/wasi-sdk-${WASI_SDK_VERSION}.0-linux.tar.gz"
    curl -sLo "$tarball" "$WASI_SDK_URL"
    tar -xzf "$tarball" -C "$vendor"
    rm "$tarball"
fi

# ── 3. Apply local patches (none yet — placeholder hook) ─────────────
patch_dir="$root/patches/wasm-rustc"
if [ -d "$patch_dir" ]; then
    for p in "$patch_dir"/*.patch; do
        [ -f "$p" ] || continue
        echo "==> applying $(basename "$p")"
        ( cd "$rust_src" && git apply --check "$p" 2>/dev/null && git apply "$p" )
    done
fi

# ── 4. Build + install via ./x.py ────────────────────────────────────
install_dir="$cache/dist"
mkdir -p "$install_dir"

# wrapper_linker_clang++.sh — wraps wasi-sdk's clang++ as the linker
# the bjorn3 patches expect. Mirrors the example in rust_wasm's
# rustc_llvm/comment.txt.
linker_wrapper="$cache/wrapper_linker_clang++.sh"
cat > "$linker_wrapper" <<EOF
#!/usr/bin/env bash
exec "$wasi_sdk/bin/clang++" "\$@"
EOF
chmod +x "$linker_wrapper"

# config.toml — bootstrap shape:
#   build = the box we're invoking x.py from (this dev machine).
#   host  = where the produced rustc will *run*. We want it to run in
#           WASI, so wasm32-wasip1-threads.
#   target = which targets the produced rustc can *codegen for*. The
#           load-bearing one is i686-unknown-linux-gnu (the gating
#           sysroot for the mov-backend pipeline). The others match
#           what rubrc ships so the registry row covers the same
#           surface plus the i686 delta.
# Note on path: this branch reads `bootstrap.toml` as the primary,
# `config.toml` as a deprecated fallback. Writing the primary so
# nothing else can shadow our settings.
#
# `profile = "..."` deliberately omitted: the `compiler` profile
# carries `[llvm] download-ci-llvm = true` as its default, which
# is hostile for a --depth 1 shallow clone (the bootstrap then walks
# git history looking for the LLVM submodule's last upstream commit
# and dies with "could not find commit hash for downloading LLVM").
# Going profile-less keeps the merge clean.
cat > "$rust_src/bootstrap.toml" <<EOF
change-id = 0

[build]
build = "x86_64-unknown-linux-gnu"
host = ["wasm32-wasip1-threads"]
target = [
    "i686-unknown-linux-gnu",
    "x86_64-unknown-linux-gnu",
    "wasm32-wasip1",
]
extended = false
docs = false

[install]
prefix = "$install_dir"
sysconfdir = "etc"

[rust]
debug-logging = false
codegen-units = 1

# Local LLVM build. The CI download path is incompatible with the
# --depth 1 shallow clone (needs git history to find the matching
# upstream LLVM commit). Local build adds ~1-2 hours but is the
# deterministic option from a shallow tree.
[llvm]
download-ci-llvm = false
EOF
# Sweep any leftover config.toml from earlier runs so its (possibly
# stale) settings can't shadow bootstrap.toml via the deprecated
# fallback path.
rm -f "$rust_src/config.toml"

env \
    WASI_SDK_PATH="$wasi_sdk" \
    WASI_SYSROOT="$wasi_sdk/share/wasi-sysroot" \
    WASI_CLANG_WRAPPER_LINKER="$linker_wrapper" \
    bash -c "cd '$rust_src' && ./x.py install"

# ── 5. Stage per-target sysroots into the layout the driver expects ─
# `./x.py install` already drops them at $install_dir/lib/rustlib/...,
# but only for the host target. The wasm-targeted bootstrap should
# also have produced the wasm32-wasip1 and i686 sysroots — but we
# guard here and warn loudly if the i686 one is missing, since that's
# the load-bearing target for the mov pipeline.
i686_dir="$install_dir/lib/rustlib/i686-unknown-linux-gnu/lib"
if [ ! -d "$i686_dir" ]; then
    echo "==> WARNING: i686 sysroot not produced by ./x.py install."
    echo "    Bootstrap likely needs target= adjustments in config.toml."
    echo "    The 'self-bjorn3-wasm20' registry row will keep erroring"
    echo "    on i686 targets until this is fixed."
fi

# ── 6. Mark completion ──────────────────────────────────────────────
echo "==> done. Mark cache complete:"
touch "$cache/.complete-rustc"
for target in "${TARGETS[@]}"; do
    if [ -d "$install_dir/lib/rustlib/$target/lib" ]; then
        touch "$cache/.complete-sysroot-$target"
        echo "    ✓ sysroot-$target"
    fi
done

cat <<EOF

==> Self-hosted rustc.wasm artefact ready at:
    $install_dir/bin/rustc.wasm
==> Verify with:
    node --input-type=module -e "
        import { rsToIR } from '$root/llvm-mov.mjs';
        const ir = await rsToIR(
            'fn main(){}',
            { rustcVersion: 'self-bjorn3-wasm20',
              target: 'i686-unknown-linux-gnu',
              edition: '2024' },
        );
        console.log(ir.split('\\\\n').slice(0, 6).join('\\\\n'));
    "
EOF
