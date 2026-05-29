# Single entry point for the llvm-mov wasm port.
# Lives at llvm-mov/wasm/ — the parent llvm-mov/ subproject owns the
# backend sources we link against, and the deploy artefact lands under
# the same `/llvm-mov/` URL subpath as the demo. Same Makefile-driven
# convention as ../../movfuscator-wasm/.

LLVM_VERSION  ?= 22
LLVM_TAG      ?= llvmorg-22.1.6
BUILD_DIR     ?= build

.PHONY: help setup build build-wasm-llvm build-wasm-clang \
        build-wasm-llvm-mov-llc build-native-llvm-mov-llc \
        build-wasm-rustc \
        test test-rust test-e2e test-e2e-dist test-e2e-dist-fzstd \
        stage-deploy serve clean distclean

help:
	@echo "Targets:"
	@echo "  setup                       fetch upstream LLVM source at pinned tag"
	@echo "  build                       build everything needed for test"
	@echo "  build-wasm-llvm             emcmake LLVM + clang static libs (long; tag bump only)"
	@echo "  build-wasm-clang            link the standalone clang driver to clang.wasm"
	@echo "  build-wasm-llvm-mov-llc     emcmake the Mov backend + llvm-mov-llc.wasm"
	@echo "  build-native-llvm-mov-llc   ensure ../build/bin/llvm-mov-llc exists"
	@echo "  build-wasm-rustc            self-host rustc.wasm from bjorn3/rust wasm20 (multi-hour;"
	@echo "                              populates 'self-bjorn3-wasm20' row in RUSTC_VERSIONS)"
	@echo "  test                        parity test: wasm .s vs native .s (per fixture)"
	@echo "  test-e2e                    playwright: drive the demo page in a headless browser"
	@echo "                              and diff the rendered .s against native (needs npm + browsers)"
	@echo "  test-e2e-dist               same as test-e2e but against the staged ../../dist/ via a"
	@echo "                              _headers-respecting Node server — exercises the zstd path"
	@echo "  test-e2e-dist-fzstd         same as test-e2e-dist but the server drops Content-Encoding"
	@echo "                              so the wrapper falls back to fzstd — covers non-zstd browsers"
	@echo "  stage-deploy                stage ../../dist/llvm-mov/ for Cloudflare Pages"
	@echo "  serve                       static-serve the demo on \$$PORT (default 8087)"
	@echo "  clean                       remove $(BUILD_DIR)"
	@echo "  distclean                   also remove vendor/"
	@echo ""
	@echo "Variables:"
	@echo "  LLVM_VERSION  (default $(LLVM_VERSION))"
	@echo "  LLVM_TAG      (default $(LLVM_TAG))"
	@echo "  BUILD_DIR     (default $(BUILD_DIR))"

setup:
	./scripts/fetch.sh

# build-wasm-{clang,llvm-mov-llc} both consume static libs produced by
# build-wasm-llvm. We orchestrate the order here via sub-make invocations
# rather than ordinary prereqs so that a standalone `make build-wasm-clang`
# (the CI fine-grained step shape, where caching sits between layers)
# does NOT re-walk the LLVM tree. Phony-target prereqs would always
# re-run, which is correct but wastes ~30 s on every cached CI step.
build: build-native-llvm-mov-llc
	$(MAKE) build-wasm-llvm
	$(MAKE) build-wasm-clang
	$(MAKE) build-wasm-llvm-mov-llc

build-wasm-llvm:
	./scripts/build-wasm-llvm.sh

# Standalone clang driver — needs build-wasm-llvm's static libs +
# cmake config at build/llvm-wasm/lib/cmake/. If invoked on a fresh
# tree, the underlying script fails with a clear "wasm LLVM not built"
# message; run `make build` for an end-to-end build.
build-wasm-clang:
	./scripts/build-wasm-clang.sh

build-wasm-llvm-mov-llc:
	./scripts/build-wasm-llvm-mov-llc.sh

# Native llvm-mov-llc is the reference for parity tests. Defer to the
# parent subproject's Makefile so a single source of truth governs how
# it's built (we live at llvm-mov/wasm/, parent is ../).
build-native-llvm-mov-llc:
	$(MAKE) -C .. build

test: build
	./tests/run.sh

# Rust-frontend smoke test. Drives a wasm-hosted rustc (rubrc v0.2.0
# artefact, Rust 1.83-dev) through `rsToIR()`. Needs `wasmtime` on
# $PATH or at ~/.local/wasmtime/wasmtime — the driver prints an
# install hint if neither is present. Kept off the default `test`
# target because the artefact + sysroot fetch (~40 MB compressed,
# one-time per version) shouldn't gate a clean `make test`.
# See ../CLAUDE.md "Rust frontend (in progress)" §.
test-rust:
	./tests/run-rust.sh

# Self-host rustc.wasm from bjorn3/rust:compile_rustc_for_wasm20.
# Multi-hour build. See scripts/build-wasm-rustc.sh header for
# resource cost / quirks; see ../CLAUDE.md "Self-hosted artefact" §
# for why this row matters (i686 + edition 2024).
build-wasm-rustc:
	./scripts/build-wasm-rustc.sh

# Playwright drives the demo at index.html in a real (headless) Chromium,
# clicks Compile on every built-in example, and asserts the rendered .s
# matches the native llvm-mov-llc output for the same IR. The harness
# itself starts the static server (see playwright.config.js).
#
# The `npx playwright install` step lazy-fetches Chromium on the first
# run; once cached under ~/.cache/ms-playwright/ it's a no-op. We don't
# pin it as a Make prerequisite because the install step needs network
# and we'd rather fail loudly on the actual test if browsers are missing
# than silently re-run install on every invocation.
test-e2e: build
	@if [ ! -d node_modules/@playwright ]; then npm install; fi
	@npx playwright install chromium >/dev/null 2>&1 || true
	npx playwright test

# Same as test-e2e but the webServer reads from `../../dist/` and
# applies the `_headers` rules. The wrapper sees `CLANG_WASM_VERSION`
# set in the staged wasm-config.js and fetches `clang.wasm-{hash}.zst`
# with `Content-Encoding: zstd`, which exercises the production-shape
# loader path. The same demo.spec.js runs against this baseURL.
test-e2e-dist: stage-deploy
	@if [ ! -d node_modules/@playwright ]; then npm install; fi
	@npx playwright install chromium >/dev/null 2>&1 || true
	E2E_SERVE_DIST=1 npx playwright test

# Same as test-e2e-dist but the dist server drops `Content-Encoding:
# zstd`, so the wrapper sees the raw zstd bytes and has to fall
# through to its in-browser fzstd decoder. Without this target the
# default Chromium that ships with Playwright handles zstd natively
# at the network layer and the fzstd fallback path is never
# exercised on CI — a regression in fzstd integration would only
# surface for Safari users in production. The spec asserts a
# `decompress clang` label appears in the timing breakdown when
# `E2E_FZSTD_EXPECTED` is set, so a future change that breaks the
# magic-byte router and accidentally takes the native path again is
# caught here.
test-e2e-dist-fzstd: stage-deploy
	@if [ ! -d node_modules/@playwright ]; then npm install; fi
	@npx playwright install chromium >/dev/null 2>&1 || true
	E2E_SERVE_DIST=1 SERVE_DIST_STRIP_ENCODING=1 E2E_FZSTD_EXPECTED=1 \
	    npx playwright test

# Same shape as ../../movfuscator-wasm/scripts/stage-deploy.sh — copies
# the browser-loadable artifacts + the demo index.html into
# ../../dist/llvm-mov/ so Cloudflare Pages serves them at /llvm-mov/.
# (The URL subpath stays as `llvm-mov`, even though the source tree
# moved to llvm-mov/wasm/, because the deploy is the front door for the
# subproject.)
#
# fzstd (the in-browser zstd fallback) lives in node_modules/, so
# install if missing — keeps both local `make stage-deploy` and the
# CI deploy job self-sufficient without a separate `npm ci` step.
stage-deploy: build
	@if [ ! -d node_modules/fzstd ]; then npm install; fi
	./scripts/stage-deploy.sh

PORT ?= 8087
serve: build
	@echo "open http://localhost:$(PORT)/"
	python3 -m http.server $(PORT)

clean:
	rm -rf $(BUILD_DIR)

distclean: clean
	rm -rf vendor
