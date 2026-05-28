.PHONY: help build-wasm stage-deploy serve clean distclean

help:
	@echo "Targets:"
	@echo "  build-wasm      cargo build wasm32 + wasm-bindgen → build/browser/"
	@echo "  stage-deploy    assemble ../dist/movie86-wasm/ for Cloudflare Pages"
	@echo "  serve           python http.server on \$$PORT (default 8087)"
	@echo "  clean           remove build/ + target/"
	@echo "  distclean       remove build/ + target/ + Cargo.lock"

build-wasm:
	./scripts/build-wasm.sh

stage-deploy: build-wasm
	./scripts/stage-deploy.sh

PORT ?= 8087
serve: build-wasm
	@echo "open http://localhost:$(PORT)/"
	python3 -m http.server $(PORT)

clean:
	rm -rf build target

distclean: clean
	rm -f Cargo.lock
