# Build the bundled demo ELFs from their .s sources.
#
# The link base is set explicitly to 0x08048000 here — the i386 SysV
# convention for static executables and the same base turbo86's stub
# maps RWX guest memory at, so a movie86 Vm snapshot can be handed off
# via WebSocket and land in turbo86's writable region without
# rebasing. Don't change this without coordinating with `turbo86/stub/`
# and the deployed handover doctrine (see `CLAUDE.md`).
#
# Requirements: binutils with `as --32` and `ld -m elf_i386` — both
# stock on Debian (`binutils`) and Fedora (`binutils-i686-linux-gnu`).
#
# Usage:
#     make all       # build every example
#     make clean     # remove built artifacts (committed .elf stays)
#
# The .elf files are committed alongside their .s so the wasm smoke
# test, browser demo, and CI all consume them without a build step;
# regenerate via `make all` whenever a source changes.

ELFS    := return42.elf hello.elf call_greet.elf cycle.elf

# Toolchain selection:
#   - `--32` makes the i386 ELF the assembler emits.
#   - `-m elf_i386` constrains ld to the matching target.
#   - `-T link.ld` drives the layout: single PT_LOAD covering Ehdr +
#     Phdr + .text, vaddr 0x08048000, no spurious sections from the
#     `as`-emitted `.note.GNU-stack` etc. See link.ld for the why.
#   - `objcopy --strip-section-headers` drops the .symtab / .strtab /
#     .shstrtab + the section-header table itself. Linux's execve
#     doesn't need section headers (only program headers), and
#     committed fixtures shipping at ~100 B instead of ~4 KB makes
#     `git diff` and the wasm bundle stay tight.
ASFLAGS := --32
LDFLAGS := -m elf_i386 -T link.ld

.PHONY: all clean
all: $(ELFS)

%.o: %.s
	as $(ASFLAGS) -o $@ $<

%.elf: %.o link.ld
	ld $(LDFLAGS) -o $@.full $<
	objcopy --strip-section-headers $@.full $@
	rm -f $@.full

clean:
	rm -f *.o *.elf.full
