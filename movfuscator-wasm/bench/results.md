# movfuscator-wasm benchmark

_2026-05-24T12:02:13Z · Linux 6.12.74+deb13+1-amd64 x86_64 · v24.15.0 · hyperfine 1.19.0_

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
| `upstream-md5` | 124521 |

## return42

| Command | Mean [ms] | Min [ms] | Max [ms] | Relative |
|:---|---:|---:|---:|---:|
| `native` | 3.5 ± 0.2 | 3.3 | 3.8 | 1.00 |
| `wasm-node` | 96.7 ± 3.1 | 93.9 | 101.6 | 27.51 ± 1.86 |
| `wasm-browser` | 89.2 ± 3.0 | 85.6 | 93.3 | 25.38 ± 1.75 |

| pipeline | peak RSS |
|---|---:|
| native | 3.3 MB |
| wasm-node | 56.5 MB |
| wasm-browser | 66.1 MB |

## hello

| Command | Mean [ms] | Min [ms] | Max [ms] | Relative |
|:---|---:|---:|---:|---:|
| `native` | 6.9 ± 1.3 | 5.7 | 8.9 | 1.00 |
| `wasm-node` | 113.6 ± 3.6 | 109.6 | 117.3 | 16.48 ± 3.15 |
| `wasm-browser` | 102.0 ± 1.6 | 100.4 | 104.5 | 14.80 ± 2.80 |

| pipeline | peak RSS |
|---|---:|
| native | 3.3 MB |
| wasm-node | 58.7 MB |
| wasm-browser | 69.7 MB |

## upstream-prime

| Command | Mean [ms] | Min [ms] | Max [ms] | Relative |
|:---|---:|---:|---:|---:|
| `native` | 9.4 ± 1.7 | 7.7 | 12.1 | 1.00 |
| `wasm-node` | 141.7 ± 2.4 | 138.5 | 145.2 | 15.12 ± 2.76 |
| `wasm-browser` | 112.8 ± 2.2 | 109.6 | 115.4 | 12.04 ± 2.20 |

| pipeline | peak RSS |
|---|---:|
| native | 3.3 MB |
| wasm-node | 61.8 MB |
| wasm-browser | 70.1 MB |

## upstream-hanoi

| Command | Mean [ms] | Min [ms] | Max [ms] | Relative |
|:---|---:|---:|---:|---:|
| `native` | 15.4 ± 1.1 | 13.9 | 16.9 | 1.00 |
| `wasm-node` | 179.7 ± 3.3 | 176.3 | 184.8 | 11.67 ± 0.88 |
| `wasm-browser` | 136.4 ± 2.4 | 134.5 | 140.6 | 8.86 ± 0.67 |

| pipeline | peak RSS |
|---|---:|
| native | 3.3 MB |
| wasm-node | 67.9 MB |
| wasm-browser | 75.9 MB |

## upstream-mandelbrot

| Command | Mean [ms] | Min [ms] | Max [ms] | Relative |
|:---|---:|---:|---:|---:|
| `native` | 10.6 ± 1.3 | 8.5 | 11.7 | 1.00 |
| `wasm-node` | 156.2 ± 2.3 | 153.6 | 158.8 | 14.76 ± 1.82 |
| `wasm-browser` | 120.7 ± 3.2 | 117.6 | 125.8 | 11.41 ± 1.43 |

| pipeline | peak RSS |
|---|---:|
| native | 3.3 MB |
| wasm-node | 61.7 MB |
| wasm-browser | 70.2 MB |

## upstream-mersenne

| Command | Mean [ms] | Min [ms] | Max [ms] | Relative |
|:---|---:|---:|---:|---:|
| `native` | 7.9 ± 0.3 | 7.6 | 8.2 | 1.00 |
| `wasm-node` | 187.9 ± 2.7 | 185.6 | 192.2 | 23.84 ± 0.90 |
| `wasm-browser` | 125.8 ± 8.8 | 118.2 | 140.9 | 15.96 ± 1.25 |

| pipeline | peak RSS |
|---|---:|
| native | 3.3 MB |
| wasm-node | 61.9 MB |
| wasm-browser | 69.9 MB |

## upstream-ray3

| Command | Mean [ms] | Min [ms] | Max [ms] | Relative |
|:---|---:|---:|---:|---:|
| `native` | 25.0 ± 0.5 | 24.1 | 25.5 | 1.00 |
| `wasm-node` | 334.9 ± 4.3 | 329.6 | 341.0 | 13.40 ± 0.34 |
| `wasm-browser` | 181.5 ± 4.5 | 177.2 | 186.5 | 7.26 ± 0.24 |

| pipeline | peak RSS |
|---|---:|
| native | 3.3 MB |
| wasm-node | 72.1 MB |
| wasm-browser | 87.2 MB |

## upstream-md5

| Command | Mean [ms] | Min [ms] | Max [ms] | Relative |
|:---|---:|---:|---:|---:|
| `native` | 72.1 ± 2.0 | 70.3 | 74.5 | 1.00 |
| `wasm-node` | 637.6 ± 11.4 | 622.4 | 653.7 | 8.84 ± 0.29 |
| `wasm-browser` | 264.6 ± 11.7 | 257.9 | 285.5 | 3.67 ± 0.19 |

| pipeline | peak RSS |
|---|---:|
| native | 3.2 MB |
| wasm-node | 73.5 MB |
| wasm-browser | 99.8 MB |

