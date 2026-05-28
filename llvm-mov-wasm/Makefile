# Single entry point for the llvm-mov wasm port.
# Mirrors the make-driven convention used by sibling subproject
# movfuscator-wasm.

LLVM_VERSION  ?= 22
LLVM_TAG      ?= llvmorg-22.1.6
BUILD_DIR     ?= build

.PHONY: help setup build build-wasm-llvm build-wasm-llvm-mov-llc \
        build-native-llvm-mov-llc test test-e2e stage-deploy serve \
        clean distclean

help:
	@echo "Targets:"
	@echo "  setup                       fetch upstream LLVM source at pinned tag"
	@echo "  build                       build everything needed for test"
	@echo "  build-wasm-llvm             emcmake LLVM static libs (long; tag bump only)"
	@echo "  build-wasm-llvm-mov-llc     emcmake the Mov backend + llvm-mov-llc.wasm"
	@echo "  build-native-llvm-mov-llc   ensure ../llvm-mov/build/bin/llvm-mov-llc exists"
	@echo "  test                        parity test: wasm .s vs native .s (per fixture)"
	@echo "  test-e2e                    playwright: drive the demo page in a headless browser"
	@echo "                              and diff the rendered .s against native (needs npm + browsers)"
	@echo "  stage-deploy                stage ../dist/llvm-mov-wasm/ for Cloudflare Pages"
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

build: build-native-llvm-mov-llc build-wasm-llvm-mov-llc

build-wasm-llvm:
	./scripts/build-wasm-llvm.sh

# The wasm backend build links against the wasm LLVM static libs, so it
# implicitly depends on build-wasm-llvm. We don't list it as a Make
# prerequisite because the LLVM build is idempotent — re-running it on
# a warm tree is fast but still does a full Ninja dep walk, and the
# script's "already built" check is faster. Run `make build-wasm-llvm`
# explicitly the first time.
build-wasm-llvm-mov-llc:
	./scripts/build-wasm-llvm-mov-llc.sh

# Native llvm-mov-llc is the reference for parity tests. Defer to the
# sibling subproject's Makefile so a single source of truth governs how
# it's built.
build-native-llvm-mov-llc:
	$(MAKE) -C ../llvm-mov build

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

# Same shape as movfuscator-wasm/scripts/stage-deploy.sh — copies the
# browser-loadable artifacts + the demo index.html into ../dist/llvm-mov-wasm/
# so Cloudflare Pages picks them up at the same URL subpath as the source
# tree.
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
