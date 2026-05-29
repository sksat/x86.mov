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
        test test-e2e test-e2e-dist stage-deploy serve clean distclean

help:
	@echo "Targets:"
	@echo "  setup                       fetch upstream LLVM source at pinned tag"
	@echo "  build                       build everything needed for test"
	@echo "  build-wasm-llvm             emcmake LLVM + clang static libs (long; tag bump only)"
	@echo "  build-wasm-clang            link the standalone clang driver to clang.wasm"
	@echo "  build-wasm-llvm-mov-llc     emcmake the Mov backend + llvm-mov-llc.wasm"
	@echo "  build-native-llvm-mov-llc   ensure ../build/bin/llvm-mov-llc exists"
	@echo "  test                        parity test: wasm .s vs native .s (per fixture)"
	@echo "  test-e2e                    playwright: drive the demo page in a headless browser"
	@echo "                              and diff the rendered .s against native (needs npm + browsers)"
	@echo "  test-e2e-dist               same as test-e2e but against the staged ../../dist/ via a"
	@echo "                              _headers-respecting Node server — exercises the zstd path"
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

# Same shape as ../../movfuscator-wasm/scripts/stage-deploy.sh — copies
# the browser-loadable artifacts + the demo index.html into
# ../../dist/llvm-mov/ so Cloudflare Pages serves them at /llvm-mov/.
# (The URL subpath stays as `llvm-mov`, even though the source tree
# moved to llvm-mov/wasm/, because the deploy is the front door for the
# subproject.)
stage-deploy: build
	./scripts/stage-deploy.sh

PORT ?= 8087
serve: build
	@echo "open http://localhost:$(PORT)/"
	python3 -m http.server $(PORT)

clean:
	rm -rf $(BUILD_DIR)

distclean: clean
	rm -rf vendor
