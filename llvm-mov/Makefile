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

.PHONY: all build configure test test-exec test-codegen clean distclean help

all: build

help:
	@echo "Targets:"
	@echo "  build         — configure + build the backend and llvm-mov-llc"
	@echo "  test          — execution tests + codegen lit tests"
	@echo "  test-exec     — execution tests only  (test/Execution)"
	@echo "  test-codegen  — lit + FileCheck only  (test/CodeGen)"
	@echo "  clean         — remove build artefacts"
	@echo "  distclean     — also remove the build directory entirely"
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

test: test-exec test-codegen

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

clean:
	@[ -d $(BUILD_DIR) ] && ninja -C $(BUILD_DIR) clean || true

distclean:
	rm -rf $(BUILD_DIR)
