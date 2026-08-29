int main(void) {
    unsigned value = 305419896u;
    unsigned i;
    for (i = 0; i < 100000u; ++i)
        value = ((value ^ i) & 16711935u) | 4278255360u;
    return (int)value;
}
