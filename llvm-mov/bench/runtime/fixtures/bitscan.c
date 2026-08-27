static unsigned sink;

int main(void) {
    unsigned i;
    unsigned x;
    for (i = 0; i < 100000u; ++i) {
        x = i * 2654435761u + 1u;
        sink += __builtin_clz(x) + __builtin_ctz(x);
    }
    return sink;
}
