# llvm-mov ギャップ行列 — 実 C を食わせたとき何が起きるか

`llvm-mov` が「Rust の `no_std` フィクスチャ」から「実在の C プログラム」へ広がるとき、
何が通って何が落ちるのかを**実測**した表。Linux 移植（[`../linux-mov/`](../linux-mov/)）と
movfuscator セルフホスト（[`../movfuscator-selfhost/`](../movfuscator-selfhost/)）は
どちらもここを共通のクリティカルパスに持つので、両者の設計文書からこの表を参照する。

計測環境: LLVM 22.1.8 / clang-22 / binutils 2.47 / x86-64 Linux（29 GiB RAM）。
プローブは `clang-22 -m32 -O1 -fno-stack-protector -S -emit-llvm` で IR 化し、
`llvm-mov-llc -mtriple=mov-unknown-linux-gnu` に通したもの。

コーパスは **lcc + M/o/Vfuscator backend（= `rcc`）の 32 翻訳単位**。
「実在の C」の代表として、書かれた年代・スタイルとも llvm-mov の Rust
フィクスチャから最も遠い。

## 1. 構文ごとの判定

| 構文 | 判定 | 詳細 |
|---|---|---|
| `volatile` load/store | ✅ | `READ_ONCE`/`WRITE_ONCE` 相当。2 回の volatile load が 2 本の `mov` として残ることを asm で確認（マージされない） |
| 空のコンパイラバリア `asm volatile("":::"memory")` | ✅ | Linux の `barrier()` そのもの。ターゲット側の対応不要 |
| 関数ポインタテーブル経由の間接呼び出し | ✅ | stage 6e |
| 構造体の値渡し / 値返し（byval / sret） | ✅ | stage 6b |
| `memcpy` / `memset`（定数長・可変長とも） | ✅ | 定数長は 64 ストアまでインライン展開、可変長は libcall |
| i64 の加減算・乗算 | ✅ | 型レガライザが i32 ペアへ分解 |
| `setjmp` の呼び出し側 | ✅ | 単なる call。`longjmp` の巻き戻し自体は未検証 |
| varargs（`va_start` / vararg 呼び出し） | ✅ stage 6f | i386 SysV の `va_list` は `char*` 1 本 |
| `fastcc` | ✅ stage 6f | clang は -O1 以上で internal 関数を昇格させる |
| ポインタ型の `select` | ✅ stage 6f | ← **無限ループだった**（§2） |
| レガライザが自分で作る `SELECT` | ✅ stage 6f | ← **無限ループだった**（§2） |
| i16 / i1 の ext-load | ✅ stage 6f | ← 半分は `Cannot select`、半分は無限ループだった。2 アラインでない i16 は依然として非対応（意図的） |
| `switch` のジャンプテーブル（`br_jt`） | ⚠️ PR #73（未マージ） | `Cannot select: br_jt` |
| `long double`（`x86_fp80`） | ⚠️ ビルドフラグで回避 | x87 80 ビットのソフトフロートは無い。`clang -mlong-double-64` で `double` になり既存の f64 経路に乗る |
| inline asm のオペランド制約（`"r"` 等） | ❌ | `couldn't allocate input reg for constraint 'r'`。`getRegForInlineAsmConstraint` 未実装。Linux の `barrier_data()`（config で消せない）と任意 inline asm（linux-mov L3b） |
| atomics | ❌ | `Cannot select: AtomicLoadAdd`。UP + 割り込みマスクで純 C 化できるので config 回避可（L4） |
| i64 の可変長シフト | ❌ | `Cannot select: shl_parts` |
| i64 の除算・剰余 | ❌ | `unsupported library call operation`。`__divdi3` 等が未注入（i32 版は注入済みなので同型の作業） |
| i64 の比較 | ❌ | 数分オーダー。`DESIGN.md` 7h4 が記録している既知現象 |
| GAS Intel 構文の予約語と同名のシンボル | ✅ stage 6f | `offset` という名前の C グローバル（lcc の `bytecode.c` にある）を Intel 構文では参照できず `as` が落ちていた。衝突するのは `offset mod short flat st and or not xor shl shr` の 11 語。回避形も総当たりし、`.att_syntax` 窓で `.set` エイリアスを定義するのが唯一一様に効く形だった |

## 1.5 別コーパスでの裏取り — movfuscator-wasm のテストフィクスチャ

rcc は「実在の C」の代表として選んだが、1 つのコーパスに寄りかかった結論に
ならないよう、隣の [`../movfuscator-wasm/tests/fixtures/`](../movfuscator-wasm/tests/fixtures/)
でも同じことを測った。こちらは movfuscator 自身の回帰テスト用に選ばれた
小さな C プログラム群で、素性がまるで違う。

`origin/mov` の `llvm-mov-llc` と本ブランチのものを**同一マシン**で
全フィクスチャにかけた結果:

| フィクスチャ | origin/mov | 本ブランチ |
|---|---|---|
| `bitops` `eq42` `fib10` `fib_rec` `lt_unsigned` `multi_call` `shift_reg` `shifts` `branch` `multi-add` `multi-add-helper` `return0` `return42` `sum10` | OK | **OK（`.s` がバイト一致）** |
| `hello` `upstream-hanoi` `upstream-hello` `upstream-knight` `upstream-mandelbrot` `upstream-prime` | `vararg calls not yet supported` | **OK** |
| `upstream-nqueens` `upstream-ray3` | 同上 / `unable to lower stackguard` | `unable to lower stackguard` |

2 つ読み取れる。

- **既に通っていたものは 1 バイトも変わっていない。** stage 6f の変更はどれも
  「これまで落ちていた形を通す」ものであって、通っていた経路の codegen には
  触れていない（`bench/results.md` を再生成していないのはこれが理由）。
- **`printf` を呼ぶだけの `hello` すら通っていなかった。** varargs が無いと
  「C の最初の一本」が書けない、という話でもある。

残る `unable to lower stackguard` は clang の stack protector で、
`-fno-stack-protector` で消える。`long double` と同じくビルドフラグの問題で、
バックエンドの穴ではない。

## 2. 「コンパイルが遅い」は遅さではなく無限ループだった

当初これを「構文次第でコンパイル時間が super-linear」と記録していた。測ったら違った。

- RSS は **108 MB で 100 秒間 1 バイトも動かない**
- スタックは何度サンプルしても `SelectionDAG::Legalize()` の中

進んでいない。**回っている。**

原因は 1 つのサイクルで、入口が 2 つあった。LegalizeDAG は `SELECT` を
`SELECT_CC` へ、`SELECT_CC` を `SETCC` + `SELECT` へ展開する。
両方 `Expand` だと互いを生成し続けて不動点に到達しない。

- **入口 1: ポインタ型の `select`。** ドライバの IR 書き換えは i32（と helper 内の i64）
  だけを bit-blend に潰しており、コメントも「i1 / pointer / aggregate は default Expand を
  通す」と明記していた。その default Expand がこのサイクルだった。
- **入口 2: レガライザ自身が合成する `SELECT`。** IR 書き換えでは原理的に届かない。
  最小再現は `select` を 1 つも含まない、ただの i32 カウントループで、
  上限がループ外の if-diamond の PHI から来るもの。

入口 2 が入口 1 の陰に隠れていたため、長く「特定の関数だけ謎に遅い」に見えていた。
どちらも stage 6f で解消（`ISD::SELECT` を Custom 化）。
回帰は `test/Execution/ptr_select.ll` と `test/Execution/loop_diamond_bound.ll`。

同じ「即失敗と無限ループの二つの顔」が i16 ext-load にもあった
（`sext i16 to i32` に食わせる i16 SEXTLOAD には終端する書き換えが無い）。

## 3. マルチ TU のスケール — ここから先が本命

単一 TU（あるいは単一 crate）での成否だけを見ていると出てこない問題が 2 つある。

### 3.1 バイトテーブルがオブジェクトごとに複製される

stage 7 のバイトテーブル（`__mov_add8_sum_table` ほか）は
`MovAsmPrinter::emitEndOfAsmFile` が**オブジェクトごとに**吐き、
シンボルはファイルローカル、セクションは COMDAT でもない。**リンクしても重複排除されない。**

lcc の `list.c` を 1 TU コンパイルした実測:

```
.text                     7,955 B
オブジェクト合計        871,984 B      ← .text は全体の 0.9 %
```

2 オブジェクトを `ld -r` で束ねると `.rodata.__mov_add8_tables` は
262 KiB → 524 KiB に**倍増**する（実測確認済み）。rcc（39 TU）なら ~33 MiB、
Linux カーネルでは成立しない。

**対処**: テーブルを COMDAT + weak にするか、単一のランタイムオブジェクト
（`libmovrt.a` 相当）へ切り出して外部参照にする。後者のほうが `--gc-sections` と
素直に噛み合い、副次的に全成果物が ~860 KiB 縮む。

### 3.2 ピークメモリ

無限ループを潰したあと、残る壁はメモリになった。`dag.c`（IR 4,459 行、
特別大きくもない C ファイル 1 本）のコンパイルで

```
Elapsed (wall clock) time:   1:44
Maximum resident set size:   27,435,892 kB   ← 27.4 GiB
```

lcc の 32 翻訳単位のうち 11 本がこの領域にいて、29 GiB のマシンでは
**逐次に走らせても OOM で落ちる**。`make -j` は論外。
数千 TU の Linux カーネルを語る前に、ここが解けている必要がある。
（stage 7 の mov-only legalize が 1 命令を ~50 mov のバイトチェーンへ展開するため
MachineFunction が巨大化することが素直な仮説だが、プロファイルは未取得。）

これは C の大きな翻訳単位に限った話ではない。**2,983 行の Rust の IR 1 本**でも起きる:
`base64` crate (v0.22.1) を rustc 1.97.1 が吐いた IR は、1 回の `llvm-mov-llc` 呼び出しで
**27.1 GiB / 90 秒**を要求する。29 GiB のマシンには「かろうじて入る」ので長く気付かれず、
16 GiB の GitHub runner で初めて牙を剥いた — `test-rust-example` が出力ゼロのまま
`exit 143` で死に、CI が壊れていた (原因はカーネルの OOM killer が runner agent を
選ぶこと)。rustc 1.96 が吐く IR ではこの経路に入らないので、runner イメージが
更新された時点で顕在化している。

対処として [`examples/rust/cargo-link.sh`](examples/rust/cargo-link.sh) は dep の
lowering に `ulimit -v` の上限 (既定 8 GiB、`LLVM_MOV_LLC_DEP_MAXMEM_KB`) を掛け、
超えたら既存の native fallback に落とすようにした。**時間制限では救えない**点が重要で、
27 GiB には 1 分足らずで到達するため、タイムアウトが発火する前にマシンが死ぬ。
これは症状を封じ込めるだけで、原因である「1 命令 = ~50 mov のバイトチェーン展開が
MachineFunction を膨らませる」ことには手を付けていない。
