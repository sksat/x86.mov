# Build the i386 child stub. Output `stub` is committed alongside the
# source so `//go:embed` always finds it; re-run `make` when stub.s changes.

stub: _stub.s
	as --32 _stub.s -o stub.o
	# Link well clear of 0x08048000 (the guest code region) and of
	# 0xBF000000+ (where the kernel places the stub's own initial stack).
	ld -m elf_i386 -static -Ttext-segment=0x40000000 -e _start stub.o -o stub
	strip stub
	rm stub.o

.PHONY: clean
clean:
	rm -f stub stub.o
