int main(void) {
    unsigned value = 3u;
    unsigned i;
    for (i = 0; i < 100000u; ++i)
        value = value * 1664525u + 1013904223u;
    return (int)value;
}
