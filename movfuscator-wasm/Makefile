.PHONY: help setup build-native build-wasm build-wasm-rcc build-wasm-cpp \
        build-wasm-browser goldens test test-browser serve clean distclean

help:
	@echo "Targets:"
	@echo "  setup                fetch upstream movfuscator + apply local patches"
	@echo "  build-native         build native rcc + cpp (needed for lburg + goldens)"
	@echo "  build-wasm           build node-mode rcc.wasm + cpp.wasm (NODERAWFS)"
	@echo "  build-wasm-rcc       only the node rcc wasm artifact"
	@echo "  build-wasm-cpp       only the node cpp wasm artifact"
	@echo "  build-wasm-browser   build browser-mode rcc.wasm + cpp.wasm (MEMFS)"
	@echo "  goldens              regenerate tests/goldens/*.s with native rcc"
	@echo "  test                 node pipeline test vs goldens"
	@echo "  test-browser         browser pipeline test (via wrapper) vs goldens"
	@echo "  serve                serve web/ + build/browser/ at http://localhost:8080"
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

goldens:
	./scripts/regen-goldens.sh

test:
	./tests/run.sh

test-browser:
	node tests/browser.mjs

serve:
	@echo "open http://localhost:8080/web/"
	python3 -m http.server 8080

clean:
	rm -rf build

distclean: clean
	rm -rf vendor
