// Multi-file fixture, "main" half.
// Pair with multi-add-helper.c — the helper defines add() and this file
// uses it. Linking the two .o files should produce an ELF that exits 42.

extern int add(int a, int b);

int main(void) {
    return add(20, 22);
}
