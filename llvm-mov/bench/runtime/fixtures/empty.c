int main(void) {
    unsigned i;
    for (i = 0; i < 100000u; ++i) {
        /* Matched loop/control-flow cost for kernel-time subtraction. */
    }
    return (int)i;
}
