.PHONY: help build-wasm stage-deploy serve examples clean distclean

help:
	@echo "Targets:"
	@echo "  build-wasm        cargo build wasm32 + wasm-bindgen → build/browser/"
	@echo "  stage-deploy      assemble ../dist/movie86-wasm/ for Cloudflare Pages"
	@echo "  serve             python http.server on \$$PORT (default 8087)"
	@echo "  examples          rebuild bundled examples/*.elf from their .s sources"
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

# Rebuild bundled example ELFs from their .s sources. Linker base is
# pinned to 0x08048000 inside examples/Makefile + examples/link.ld so
# the resulting binaries match the i386 SysV convention turbo86's stub
# maps RWX at — no post-link rebasing needed. Run when you change a
# .s source or add a new example fixture.
examples:
	$(MAKE) -C examples all

clean:
	rm -rf build target

distclean: clean
	rm -f Cargo.lock
