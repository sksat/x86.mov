# movfuscator-wasm benchmark

_2026-05-24T11:46:06Z · Linux 6.12.74+deb13+1-amd64 x86_64 · v24.15.0 · hyperfine 1.19.0_

Three implementations of the .c → mov asm pipeline are compared per fixture:

- **native**: `cpp` + `rcc` (host x86_64)
- **wasm-node**: `build/{cpp,rcc}.js` under Node (NODERAWFS)
- **wasm-browser**: `web/movfuscator.mjs` under Node ESM (MEMFS — same code as in-browser, minus network fetch)

| fixture | asm lines |
|---|---:|
| `return42` | 712 |
| `hello` | 979 |
| `upstream-prime` | 9994 |
| `upstream-hanoi` | 16766 |
| `upstream-mandelbrot` | 12179 |
| `upstream-mersenne` | 33841 |
| `upstream-ray3` | 69554 |

## return42

| Command | Mean [ms] | Min [ms] | Max [ms] | Relative |
|:---|---:|---:|---:|---:|
| `native` | 2.8 ± 0.3 | 2.4 | 3.1 | 1.00 |
| `wasm-node` | 99.0 ± 4.6 | 93.8 | 105.6 | 34.82 ± 3.54 |
| `wasm-browser` | 85.7 ± 2.5 | 83.2 | 88.9 | 30.15 ± 2.86 |

## hello

| Command | Mean [ms] | Min [ms] | Max [ms] | Relative |
|:---|---:|---:|---:|---:|
| `native` | 7.5 ± 1.0 | 6.7 | 9.1 | 1.00 |
| `wasm-node` | 114.4 ± 1.2 | 113.0 | 115.8 | 15.26 ± 1.95 |
| `wasm-browser` | 99.2 ± 1.2 | 97.7 | 100.4 | 13.23 ± 1.70 |

## upstream-prime

| Command | Mean [ms] | Min [ms] | Max [ms] | Relative |
|:---|---:|---:|---:|---:|
| `native` | 10.6 ± 0.8 | 9.4 | 11.4 | 1.00 |
| `wasm-node` | 141.6 ± 3.5 | 137.1 | 146.8 | 13.36 ± 1.12 |
| `wasm-browser` | 114.5 ± 6.8 | 106.6 | 124.6 | 10.80 ± 1.07 |

## upstream-hanoi

| Command | Mean [ms] | Min [ms] | Max [ms] | Relative |
|:---|---:|---:|---:|---:|
| `native` | 14.9 ± 1.4 | 13.7 | 17.0 | 1.00 |
| `wasm-node` | 182.0 ± 2.3 | 179.6 | 184.7 | 12.24 ± 1.16 |
| `wasm-browser` | 133.8 ± 3.9 | 129.1 | 139.7 | 9.00 ± 0.89 |

## upstream-mandelbrot

| Command | Mean [ms] | Min [ms] | Max [ms] | Relative |
|:---|---:|---:|---:|---:|
| `native` | 11.7 ± 1.7 | 9.5 | 13.3 | 1.00 |
| `wasm-node` | 154.7 ± 1.3 | 153.3 | 156.5 | 13.21 ± 1.94 |
| `wasm-browser` | 118.6 ± 2.8 | 114.7 | 122.5 | 10.13 ± 1.50 |

## upstream-mersenne

| Command | Mean [ms] | Min [ms] | Max [ms] | Relative |
|:---|---:|---:|---:|---:|
| `native` | 8.5 ± 0.8 | 7.4 | 9.4 | 1.00 |
| `wasm-node` | 189.7 ± 3.3 | 186.0 | 193.9 | 22.35 ± 2.13 |
| `wasm-browser` | 122.1 ± 2.7 | 117.3 | 123.8 | 14.38 ± 1.39 |

## upstream-ray3

| Command | Mean [ms] | Min [ms] | Max [ms] | Relative |
|:---|---:|---:|---:|---:|
| `native` | 24.9 ± 0.5 | 24.2 | 25.4 | 1.00 |
| `wasm-node` | 335.9 ± 5.4 | 331.6 | 344.7 | 13.48 ± 0.33 |
| `wasm-browser` | 181.6 ± 5.7 | 175.0 | 190.1 | 7.29 ± 0.27 |

