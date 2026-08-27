int main(void) {
    unsigned value = 305419896u;
    unsigned i;
    for (i = 0; i < 100000u; ++i)
        value = value << (i & 31u);
    return (int)value;
}
