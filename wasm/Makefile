.PHONY: help setup build-native build-wasm goldens test clean distclean

help:
	@echo "Targets:"
	@echo "  setup          fetch upstream movfuscator + apply local patches"
	@echo "  build-native   build native rcc (needed for lburg + goldens)"
	@echo "  build-wasm     build rcc.wasm via Emscripten"
	@echo "  goldens        regenerate tests/goldens/*.s with native rcc"
	@echo "  test           run wasm rcc against fixtures, compare to goldens"
	@echo "  clean          remove build artifacts (keep vendor checkout)"
	@echo "  distclean      remove build + vendor"

setup:
	./scripts/fetch.sh

build-native:
	./scripts/build-native.sh

build-wasm:
	./scripts/build-wasm.sh

goldens:
	./scripts/regen-goldens.sh

test:
	./tests/run.sh

clean:
	rm -rf build

distclean: clean
	rm -rf vendor
