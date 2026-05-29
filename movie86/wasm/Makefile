.PHONY: help build-wasm stage-deploy serve rebase-examples clean distclean

help:
	@echo "Targets:"
	@echo "  build-wasm        cargo build wasm32 + wasm-bindgen → build/browser/"
	@echo "  stage-deploy      assemble ../dist/movie86-wasm/ for Cloudflare Pages"
	@echo "  serve             python http.server on \$$PORT (default 8087)"
	@echo "  rebase-examples   rerun examples/rebase.py on every examples/*.elf"
	@echo "  clean             remove build/ + target/"
	@echo "  distclean         remove build/ + target/ + Cargo.lock"

build-wasm:
	./scripts/build-wasm.sh

stage-deploy: build-wasm
	./scripts/stage-deploy.sh

PORT ?= 8087
serve: build-wasm
	@echo "open http://localhost:$(PORT)/"
	python3 -m http.server $(PORT)

# Rebase committed example ELFs to the 0x08048000 link base turbo86's
# stub maps RWX guest memory at. Idempotent — running it on already-
# rebased ELFs is a no-op (entries / vaddrs are already above OLD_BASE
# so the scan finds nothing to shift). Used when adding a new example
# fixture; the existing bundled .elf files were rebased once at
# commit time and are checked in at the new base.
rebase-examples:
	python3 examples/rebase.py

clean:
	rm -rf build target

distclean: clean
	rm -f Cargo.lock
