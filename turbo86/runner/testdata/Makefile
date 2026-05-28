# Build a fully-linked movfuscator ELF for the optional E2E test
# (TURBO86_MOVFUSCATOR_FIXTURE).
#
# Requires the movfuscator runtime objects materialized via:
#   (cd ../../../movfuscator-wasm && make setup && make build-native)

VENDOR := ../../../movfuscator-wasm/vendor/movfuscator
RT_BUILD := $(VENDOR)/build
RT_LIB := $(VENDOR)/movfuscator/lib
GOLDENS := ../../../movfuscator-wasm/tests/goldens-o

CRT_OBJECTS := \
    $(RT_BUILD)/crt0_cf.o \
    $(RT_BUILD)/crtf_cf.o \
    $(RT_BUILD)/crtd_cf.o \
    $(RT_LIB)/softfloat32_cf.o

return42.elf: stubs.o $(GOLDENS)/return42.o $(CRT_OBJECTS)
	ld -m elf_i386 -static -o $@ \
	    $(GOLDENS)/return42.o \
	    $(CRT_OBJECTS) \
	    stubs.o

stubs.o: _stubs.s
	as --32 _stubs.s -o stubs.o

.PHONY: clean
clean:
	rm -f stubs.o return42.elf
