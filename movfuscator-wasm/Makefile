.PHONY: help setup build-native build-wasm build-wasm-rcc build-wasm-cpp goldens test clean distclean

help:
	@echo "Targets:"
	@echo "  setup            fetch upstream movfuscator + apply local patches"
	@echo "  build-native     build native rcc + cpp (needed for lburg + goldens)"
	@echo "  build-wasm       build both rcc.wasm and cpp.wasm via Emscripten"
	@echo "  build-wasm-rcc   only the rcc wasm artifact"
	@echo "  build-wasm-cpp   only the cpp wasm artifact"
	@echo "  goldens          regenerate tests/goldens/*.s with native rcc"
	@echo "  test             run wasm cpp+rcc against fixtures, compare to goldens"
	@echo "  clean            remove build artifacts (keep vendor checkout)"
	@echo "  distclean        remove build + vendor"

setup:
	./scripts/fetch.sh

build-native:
	./scripts/build-native.sh

build-wasm: build-wasm-rcc build-wasm-cpp

build-wasm-rcc:
	./scripts/build-wasm.sh

build-wasm-cpp:
	./scripts/build-wasm-cpp.sh

goldens:
	./scripts/regen-goldens.sh

test:
	./tests/run.sh

clean:
	rm -rf build

distclean: clean
	rm -rf vendor
