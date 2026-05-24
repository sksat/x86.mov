# movfuscator-wasm benchmark

_2026-05-24T18:08:51Z · Linux 6.12.74+deb13+1-amd64 x86_64 · v24.15.0 · hyperfine 1.19.0_

Three back-ends running the full `.c → ELF` pipeline (cpp + rcc + as + ld) are compared per fixture:

- **native**: host `cpp`, `rcc`, `/usr/bin/as`, `/usr/bin/ld` (host x86_64)
- **wasm-node**: `build/{cpp,rcc,as,ld}.js` under Node (NODERAWFS), one subprocess per stage
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
| `native` | 140.4 ± 0.9 | 139.4 | 141.9 | 1.00 |
| `wasm-node` | 555.6 ± 7.7 | 550.1 | 568.9 | 3.96 ± 0.06 |
| `wasm-browser` | 509.8 ± 3.4 | 507.2 | 514.6 | 3.63 ± 0.03 |

| pipeline | peak RSS |
|---|---:|
| native | 66.2 MB |
| wasm-node | 107.5 MB |
| wasm-browser | 185.8 MB |

## hello

| Command | Mean [ms] | Min [ms] | Max [ms] | Relative |
|:---|---:|---:|---:|---:|
| `native` | 148.3 ± 2.4 | 145.8 | 152.1 | 1.00 |
| `wasm-node` | 605.9 ± 11.3 | 591.5 | 618.4 | 4.08 ± 0.10 |
| `wasm-browser` | 551.6 ± 7.1 | 545.3 | 562.5 | 3.72 ± 0.08 |

| pipeline | peak RSS |
|---|---:|
| native | 66.3 MB |
| wasm-node | 107.9 MB |
| wasm-browser | 196.6 MB |

## upstream-prime

| Command | Mean [ms] | Min [ms] | Max [ms] | Relative |
|:---|---:|---:|---:|---:|
| `native` | 159.5 ± 2.0 | 157.5 | 161.9 | 1.00 |
| `wasm-node` | 662.2 ± 6.8 | 656.6 | 673.3 | 4.15 ± 0.07 |
| `wasm-browser` | 597.4 ± 12.1 | 586.7 | 615.7 | 3.75 ± 0.09 |

| pipeline | peak RSS |
|---|---:|
| native | 66.2 MB |
| wasm-node | 108.4 MB |
| wasm-browser | 198.8 MB |

## upstream-hanoi

| Command | Mean [ms] | Min [ms] | Max [ms] | Relative |
|:---|---:|---:|---:|---:|
| `native` | 170.0 ± 3.5 | 165.8 | 174.6 | 1.00 |
| `wasm-node` | 701.5 ± 4.4 | 697.0 | 707.3 | 4.13 ± 0.09 |
| `wasm-browser` | 638.0 ± 19.2 | 619.6 | 669.9 | 3.75 ± 0.14 |

| pipeline | peak RSS |
|---|---:|
| native | 66.1 MB |
| wasm-node | 108.3 MB |
| wasm-browser | 201.9 MB |

## upstream-mandelbrot

| Command | Mean [ms] | Min [ms] | Max [ms] | Relative |
|:---|---:|---:|---:|---:|
| `native` | 165.5 ± 1.1 | 164.6 | 166.9 | 1.00 |
| `wasm-node` | 683.9 ± 8.2 | 674.7 | 696.9 | 4.13 ± 0.06 |
| `wasm-browser` | 597.4 ± 13.3 | 585.0 | 613.9 | 3.61 ± 0.08 |

| pipeline | peak RSS |
|---|---:|
| native | 66.1 MB |
| wasm-node | 109.3 MB |
| wasm-browser | 187.1 MB |

## upstream-mersenne

| Command | Mean [ms] | Min [ms] | Max [ms] | Relative |
|:---|---:|---:|---:|---:|
| `native` | 174.2 ± 2.5 | 171.8 | 178.1 | 1.00 |
| `wasm-node` | 711.8 ± 8.2 | 701.7 | 722.9 | 4.09 ± 0.08 |
| `wasm-browser` | 624.7 ± 6.3 | 615.3 | 631.9 | 3.59 ± 0.06 |

| pipeline | peak RSS |
|---|---:|
| native | 66.2 MB |
| wasm-node | 108.2 MB |
| wasm-browser | 195.2 MB |

## upstream-ray3

| Command | Mean [ms] | Min [ms] | Max [ms] | Relative |
|:---|---:|---:|---:|---:|
| `native` | 206.5 ± 0.6 | 205.7 | 207.2 | 1.00 |
| `wasm-node` | 890.3 ± 6.7 | 880.5 | 897.4 | 4.31 ± 0.03 |
| `wasm-browser` | 730.5 ± 6.9 | 721.5 | 735.9 | 3.54 ± 0.04 |

| pipeline | peak RSS |
|---|---:|
| native | 66.2 MB |
| wasm-node | 110.3 MB |
| wasm-browser | 201.1 MB |

## upstream-md5

| Command | Mean [ms] | Min [ms] | Max [ms] | Relative |
|:---|---:|---:|---:|---:|
| `native` | 284.7 ± 4.0 | 280.5 | 291.3 | 1.00 |
| `wasm-node` | 1237.1 ± 13.0 | 1222.0 | 1257.5 | 4.35 ± 0.08 |
| `wasm-browser` | 896.0 ± 12.6 | 879.3 | 910.0 | 3.15 ± 0.06 |

| pipeline | peak RSS |
|---|---:|
| native | 66.2 MB |
| wasm-node | 110.0 MB |
| wasm-browser | 241.5 MB |

