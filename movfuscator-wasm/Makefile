.PHONY: help setup build-native build-wasm build-wasm-rcc build-wasm-cpp \
        build-wasm-browser build-wasm-as build-wasm-as-browser \
        build-wasm-ld-browser stage-link-libs stage-deploy \
        goldens goldens-o test test-browser test-as test-ld bench serve \
        clean distclean

help:
	@echo "Targets:"
	@echo "  setup                fetch upstream movfuscator + apply local patches"
	@echo "  build-native         build native rcc + cpp (needed for lburg + goldens)"
	@echo "  build-wasm           build node-mode rcc.wasm + cpp.wasm (NODERAWFS)"
	@echo "  build-wasm-rcc       only the node rcc wasm artifact"
	@echo "  build-wasm-cpp       only the node cpp wasm artifact"
	@echo "  build-wasm-browser   build browser-mode rcc.wasm + cpp.wasm (MEMFS)"
	@echo "  build-wasm-as        build wasm as (GNU binutils 2.44 gas, Phase C)"
	@echo "  build-wasm-as-browser  re-link wasm-as for browser (MEMFS, ES module)"
	@echo "  build-wasm-ld-browser  re-link wasm-ld for browser (MEMFS, ES module)"
	@echo "  stage-link-libs        copy host crt + libc + libgcc into web/lib/ for demo"
	@echo "  stage-deploy           assemble ../dist/ for Cloudflare Pages upload"
	@echo "  goldens              regenerate tests/goldens/*.s with native rcc"
	@echo "  goldens-o            regenerate tests/goldens-o/*.o with native as"
	@echo "  test                 node pipeline test vs .s goldens"
	@echo "  test-browser         browser pipeline test (via wrapper) vs .s goldens"
	@echo "  test-as              wasm-as test vs .o goldens"
	@echo "  test-ld              wasm-ld test (links .o to ELF, compares with native ld)"
	@echo "  bench                hyperfine native vs wasm-node vs wasm-browser → bench/results.md"
	@echo "  serve                serve web/ + build/browser/ on \$$PORT (default 8086)"
	@echo "  clean                remove build artifacts (keep vendor checkout)"
	@echo "  distclean            remove build + vendor"

setup:
	./scripts/fetch.sh

build-native:
	./scripts/build-native.sh

build-wasm: build-wasm-rcc build-wasm-cpp

build-wasm-rcc:
	./scripts/build-wasm.sh

build-wasm-cpp:
	./scripts/build-wasm-cpp.sh

build-wasm-browser:
	./scripts/build-wasm-browser.sh

build-wasm-as:
	./scripts/build-wasm-as.sh

build-wasm-as-browser:
	./scripts/build-wasm-as-browser.sh

build-wasm-ld-browser:
	./scripts/build-wasm-ld-browser.sh

stage-link-libs:
	./scripts/stage-link-libs.sh

stage-deploy:
	./scripts/stage-deploy.sh

goldens:
	./scripts/regen-goldens.sh

goldens-o:
	./scripts/regen-goldens-o.sh

test:
	./tests/run.sh

test-browser:
	node tests/browser.mjs

test-as:
	./tests/run-as.sh

test-ld:
	./tests/run-ld.sh

bench:
	./scripts/bench.sh

PORT ?= 8086
serve:
	@echo "open http://localhost:$(PORT)/web/"
	python3 -m http.server $(PORT)

clean:
	rm -rf build

distclean: clean
	rm -rf vendor
