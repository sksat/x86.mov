# llvm-mov ギャップ行列 — 実 C を食わせたとき何が起きるか

`llvm-mov` が「Rust の `no_std` フィクスチャ」から「実在の C プログラム」へ広がるとき、
何が通って何が落ちるのかを**実測**した表。Linux 移植（[`../linux-mov/`](../linux-mov/)）と
movfuscator セルフホスト（[`../movfuscator-selfhost/`](../movfuscator-selfhost/)）は
どちらもここを共通のクリティカルパスに持つので、両者の設計文書からこの表を参照する。

計測環境: LLVM 22.1.8 / clang-22 / binutils 2.47 / x86-64 Linux。
プローブは `clang-22 -m32 -O1 -fno-stack-protector -S -emit-llvm` で IR 化し、
`llvm-mov-llc -mtriple=mov-unknown-linux-gnu` に通したもの。

## 表

| 構文 | 判定 | 詳細 |
|---|---|---|
| `volatile` load/store | ✅ 通る | `READ_ONCE`/`WRITE_ONCE` 相当。2 回の volatile load が 2 本の `mov` として残ることを asm で確認済み（マージされない） |
| 空のコンパイラバリア `asm volatile("":::"memory")` | ✅ 通る | Linux の `barrier()`。命令を出さず順序だけ縛る。ターゲット側の対応不要 |
| 関数ポインタテーブル経由の間接呼び出し | ✅ 通る | stage 6e |
| 構造体の値渡し / 値返し（byval / sret） | ✅ 通る | stage 6b |
| `memcpy` / `memset`（定数長・可変長とも） | ✅ 通る | 定数長は 64 ストアまでインライン展開、可変長は libcall |
| i64 の加減算・乗算 | ✅ 通る | 型レガライザが i32 ペアへ分解。`mul i64` も通る |
| `setjmp` の呼び出し側 | ✅ 通る | 単なる call。ただし `longjmp` の巻き戻し自体は未検証 |
| **varargs（定義側 `va_start` / 呼び出し側）** | ✅ **本 PR で対応** | stage 6f。i386 SysV の `va_list` は `char*` 1 本なので `va_start` は store 1 発。`test/Execution/vararg_sum.ll` |
| **`fastcc`** | ✅ **本 PR で対応** | clang は -O1 以上で internal 関数を `fastcc` に昇格させるので、最適化ありの実 C は必ず踏む。`test/Execution/fastcc_call.ll` |
| `switch` のジャンプテーブル（`br_jt`） | ⚠️ PR #73 で対応済み・未マージ | `LLVM ERROR: Cannot select: br_jt`。lcc の `decl.c` が踏む |
| inline asm のオペランド制約（`"r"` 等） | ❌ 未対応 | `error: couldn't allocate input reg for constraint 'r'`。`getRegForInlineAsmConstraint` 未実装。Linux の `barrier_data()` と任意 inline asm（linux-mov L3b）が該当 |
| atomics（`__atomic_fetch_add` 等） | ❌ 未対応 | `Cannot select: AtomicLoadAdd`。linux-mov L4。UP なら割り込みマスクで純 C 化できるので config で回避可 |
| i64 の可変長シフト | ❌ 未対応 | `Cannot select: shl_parts`。`__ashldi3`/`__lshrdi3`/`__ashrdi3` の注入 or `shl_parts` の Expand で解決 |
| i64 の除算・剰余 | ❌ 未対応 | `unsupported library call operation`。`__divdi3`/`__udivdi3` 等が未注入（i32 版 `__divsi3` は注入済みなので同型の作業） |
| **i64 の比較（`icmp` on i64）** | ❌ **コンパイル時病理** | 120 秒でも終わらない。`DESIGN.md` の 7h4 が「i64 SETCC で DAG-ISel が数分かかる」と記録している既知現象が、ごく小さな関数でも出る |

## 表に出てこない、しかしより重い問題: バイトテーブルの TU 複製

stage 7 のバイトテーブル（`__mov_add8_sum_table` ほか）は
`MovAsmPrinter::emitEndOfAsmFile` が**オブジェクトごとに**吐く。しかもシンボルは
`.globl` されないファイルローカル、セクションも COMDAT ではない。つまり
**リンクしても重複排除されない**。

実測（lcc の `list.c`、1 TU）:

```
.text                              7,955 B
.rodata.__mov_add8_tables        262,144 B
.rodata.__mov_and8_table          65,536 B   (or / xor も同じ)
…
オブジェクト合計                   871,984 B   ← .text は 0.9 %
```

2 つのオブジェクトを `ld -r` で束ねると `.rodata.__mov_add8_tables` は
262,144 → 524,288 B に**倍増**する（重複排除されないことを確認済み）。

単一 TU のフィクスチャしか通していない間は「固定 ~700 KiB の .rodata」で済んでいたが、
N 個の TU をリンクする瞬間から **N × ~860 KiB** になる。rcc（39 TU）で ~33 MiB、
Linux カーネル（数千 TU）では成立しない。

**対処**: テーブルを (a) COMDAT セクション + weak シンボルにする、または
(b) `llvm-mov-llc` とは独立した単一のランタイムオブジェクト（`libmovrt.a` 相当）に切り出し、
コード側は外部シンボル参照にする。(b) のほうが `--gc-sections` とも素直に噛み合う。
どちらも本 PR のスコープ外だが、**マルチ TU をやる前に必ず要る**。

## コンパイル時間

`list.c`（IR 153 行）は 0 秒。一方 `string.c`（IR 253 行）は **240 秒でも終わらない**。
行数ではなく特定の構文（i64 比較を含む式、巨大な単一関数の mov-only legalize）が効く。
PR #73 も `base64` crate で「単一の大きな関数の legalize が super-linear」を報告しており、
同じ現象の別の顔と見てよい。マルチ TU のビルド時間を語る前にここのプロファイルが要る。
