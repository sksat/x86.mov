# Single entry point for the llvm-mov backend.
# Mirrors the make-driven convention used by sibling subproject movfuscator-wasm.

LLVM_VERSION ?= 22
LLVM_CONFIG  ?= llvm-config-$(LLVM_VERSION)
BUILD_DIR    ?= build
BUILD_TYPE   ?= Release

# Resolve the LLVM cmake module dir up-front so a missing llvm-config-22 fails
# loudly with the install hint, rather than CMake silently trying a different
# LLVM and printing a less useful error 200 lines down.
LLVM_CMAKE_DIR := $(shell $(LLVM_CONFIG) --cmakedir 2>/dev/null)

.PHONY: all build configure test test-exec test-codegen test-mov-only \
        test-rust-example test-cargo-build test-deps-mov \
        bench bench-check clean distclean help

all: build

help:
	@echo "Targets:"
	@echo "  build              — configure + build the backend and llvm-mov-llc"
	@echo "  test               — execution tests + codegen lit tests"
	@echo "  test-exec          — execution tests only  (test/Execution)"
	@echo "  test-codegen       — lit + FileCheck only  (test/CodeGen)"
	@echo "  test-mov-only      — objdump gate: every fixture under test/MovOnly/"
	@echo "                       must disassemble to mov-only opcodes (stage 7+)"
	@echo "  test-rust-example  — plain 'cargo build' per examples/rust/<crate>"
	@echo "                       (alias: test-cargo-build); stage 6.5; needs"
	@echo "                       'rustup target add i686-unknown-linux-gnu'"
	@echo "  test-deps-mov      — issue #11 gate: a Rust dep crate's .o must"
	@echo "                       also disassemble mov-only (cargo-link.sh"
	@echo "                       routes each rlib's IR through llvm-mov-llc)"
	@echo "  bench              — side-by-side ELF comparison vs movfuscator on the"
	@echo "                       shared .c fixtures; writes bench/results.md"
	@echo "                       (needs 'make -C ../movfuscator-wasm setup build-native')"
	@echo "  bench-check        — regression test: re-run bench, diff against the"
	@echo "                       committed bench/results.md (runtime excluded);"
	@echo "                       fails on any deterministic-number drift"
	@echo "  clean              — remove build artefacts"
	@echo "  distclean          — also remove the build directory entirely"
	@echo ""
	@echo "Variables:"
	@echo "  LLVM_VERSION  (default $(LLVM_VERSION))"
	@echo "  BUILD_DIR     (default $(BUILD_DIR))"
	@echo "  BUILD_TYPE    (default $(BUILD_TYPE))"

# Surface the missing-llvm-config diagnostic before invoking cmake at all.
configure:
	@if [ -z "$(LLVM_CMAKE_DIR)" ]; then \
		echo "error: $(LLVM_CONFIG) not found. Install LLVM $(LLVM_VERSION) from apt.llvm.org:" 1>&2; \
		echo "  wget -qO- https://apt.llvm.org/llvm.sh | sudo bash -s -- $(LLVM_VERSION)" 1>&2; \
		echo "  sudo apt-get install -y llvm-$(LLVM_VERSION)-dev clang-$(LLVM_VERSION) lld-$(LLVM_VERSION) ninja-build" 1>&2; \
		exit 1; \
	fi
	cmake -S . -B $(BUILD_DIR) -G Ninja \
		-DCMAKE_BUILD_TYPE=$(BUILD_TYPE) \
		-DLLVM_DIR=$(LLVM_CMAKE_DIR)

build: configure
	ninja -C $(BUILD_DIR)

test: test-exec test-codegen test-mov-only

test-exec: build
	@./test/Execution/run.sh $(BUILD_DIR)

# test-codegen runs lit only if it's available — wired up once the lit suite
# actually has a fixture under test/CodeGen.
test-codegen: build
	@if command -v lit >/dev/null 2>&1 && [ -f test/lit.cfg.py ]; then \
		lit -sv $(BUILD_DIR)/test; \
	else \
		echo "test-codegen: lit not installed or no CodeGen suite yet — skipping"; \
	fi

# Stage-6.5 / 7d3 demo: plain `cd examples/rust/<crate> && cargo
# build --release` produces a runnable mov-only ELF for every Cargo-
# backed example. The custom linker driver wired in
# examples/rust/.cargo/config.toml does the llvm-mov-llc + as + ld
# pipeline; cargo itself sees the build as a normal `bin` crate
# compile.
#
# Opt-in — not in the default `test` target because it pulls in a
# Rust toolchain dependency. The harness surfaces a clear message
# if the i686 rust-std rlibs aren't installed.
test-rust-example test-cargo-build: build
	@./test/CargoBuild/run.sh $(BUILD_DIR)

# Issue #11 / Option C gate. `test/DepsMov/run.sh` cargo-builds
# the examples/rust/dep_mov_add fixture (a tiny bin crate with a
# path-local lib dep) and asserts the linked ELF's .text is mov-
# only end to end — i.e. the dep crate's code also went through
# llvm-mov-llc, not just the user's. Opt-in; passes only after the
# cargo-link.sh deps-mov path lands.
test-deps-mov: build
	@./test/DepsMov/run.sh $(BUILD_DIR)

# Stage-7+ gate. `test/MovOnly/run.sh` builds every fixture under
# test/MovOnly/ and asserts the disassembly contains only mov-family
# mnemonics. At stage 7a0 there are no fixtures yet, so this is a clean
# exit; each subsequent 7-stage (7a1 ADD, 7b AND/OR/XOR, 7c CMP/Jcc/JMP,
# 7d CALL/RET) lights up the next group.
test-mov-only: build
	@./test/MovOnly/run.sh $(BUILD_DIR)

# Side-by-side ELF comparison against movfuscator on the shared C
# fixtures. Regenerates bench/results.md; commit the result so PRs
# show the size/mov-ratio diff.
bench: build
	BUILD_DIR=$(BUILD_DIR) ./bench/run.sh

# CI-grade regression check: re-runs the bench into a temp file and
# diffs against the committed bench/results.md. The intentionally-
# volatile rows (generation timestamp + wall-clock runtime) are
# stripped before comparing; every other row must match exactly.
# When this fails, either the change is a regression to investigate,
# or it's intentional and the dev should `make bench` + commit the
# updated results.md alongside.
bench-check: build
	BUILD_DIR=$(BUILD_DIR) ./bench/check.sh

clean:
	@[ -d $(BUILD_DIR) ] && ninja -C $(BUILD_DIR) clean || true

distclean:
	rm -rf $(BUILD_DIR)
