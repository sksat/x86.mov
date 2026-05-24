# bench — llvm-mov vs movfuscator-wasm

**Planned.** Lands once the backend reaches stage 7 (real mov-only legalization)
— before that the comparison "mov-heavy LLVM output vs LCC mov-only output" is
apples-to-pears.

The premise: both back-ends consume **the same C source** and produce
**linked x86-32 ELF**. We measure three things side-by-side:

| metric                   | how                                                       |
|--------------------------|-----------------------------------------------------------|
| binary size              | `wc -c` on the linked ELF                                 |
| mov instruction count    | `objdump -d -Mintel | grep -c '^\s*[0-9a-f]\+:\s\+.*mov'` |
| runtime                  | `hyperfine` over the fixture's execution                  |
| total instruction count  | `objdump -d` line count, sanity check on "all mov?"       |

Fixtures come from the movfuscator-wasm test set —
[`../../movfuscator-wasm/tests/fixtures/`](../../movfuscator-wasm/tests/fixtures/)
— so both pipelines start from the same C and we don't have to re-author
benchmark programs. The interesting question is **"does LLVM's optimiser let
us emit a smaller mov-only binary than the LCC-era movfuscator?"** — LLVM
brings SROA, mem2reg, GVN, instcombine and a much stronger inliner to bear
before the mov-only legalization fires, so the hypothesis is yes, often
substantially.

Sketch of the runner (not implemented yet):

```
bench/
  run.sh          # discovers fixtures, runs both pipelines, writes results.md
  fixtures/       # symlink or copy of selected upstream-* fixtures
  results.md      # auto-generated table, committed for diffability across PRs
```

Stage-7 issue to watch when this lands: LCC's mov-only output relies on a
fairly specific allocator strategy (giant indirection tables, etc.).
A fair size comparison should look at `text + data + rodata` together,
not just `.text`.
