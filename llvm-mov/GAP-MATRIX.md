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
| `volatile` な i32 の load/store | ✅ | `READ_ONCE`/`WRITE_ONCE` 相当。2 回の volatile load が 2 本の `mov` として残ることを asm で確認（マージされない） |
| `volatile` な i8 / i16 / i1 の load | ❌ stage 6f で**拒否するようにした** | narrow load の lowering は「囲む 4 バイトワードを読んでシフトで取り出す」形で、通常メモリなら余分なバイトは同じオブジェクトなので観測できないが、volatile では 1/2 バイト読みの要求に 4 バイト読みを出すことになる。MMIO なら隣のレジスタを読む副作用が出る（linux-mov の PV 面は丸ごと memory-mapped register）。正しい lowering が無いので `Cannot select` で落とす。**stage 6f 以前は volatile i8 が黙って 4 バイト読みになっていた**ので、これは機能の削除ではなく誤りの顕在化 |
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
  触れていない。`bench/results.md` の再生成でも llvm-mov 列は動いていない
  — 唯一の例外は `base64_decode` で、これは dep が native fallback するため
  rustc のバージョンが `.text` に混ざる分（`rust-toolchain.toml` で固定した）。
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

### 3.2 ピークメモリ ― と、それが幻だったこと

一時期ここには「1 TU あたり ~27 GiB のピーク RSS が壁である」と書いていた。
**その読みは誤りだった。** ピークではなく、停止しない無限ループだった。

見分け方は簡単で、上限を変えて測ると分かる。

```
cap  1 GiB -> OOM, peak  0.79 GiB,  3.9 s
cap  2 GiB -> OOM, peak  1.74 GiB,  8.7 s
cap  8 GiB -> OOM, peak  7.45 GiB, 34.6 s
cap 20 GiB -> OOM, peak 18.8  GiB, 88   s
```

ピークは常に上限に張り付き、時間は上限に比例する。有限のピークならこうはならない。
「29 GiB のマシンではかろうじて通る」と書いていたのも誤りで、
`/usr/bin/time -v` が SIGKILL されたプロセスにも `Exit status: 0` と
印字するのを読み違えていた。**メモリを積んでも直らない類のものだった。**

原因は 1 行、`setTruncStoreAction(MVT::i32, MVT::i16, Expand)`。
i16 はこのバックエンドで不正な型なので、LegalizeDAG の「in-memory type が
legal でない」腕が同じ i16 メモリ VT でトラックストアを作り直し、CSE が
legalize 中のノードを返して `ReplaceNode(N, N)` になり、ワークリストが回り続ける。
再現は 4 行 (`store i24 %v, ptr %p`) で足りる。

**このバックエンドで同型の罠は 3 度目**である —
i16 SEXTLOAD、`SELECT` / `SELECT_CC`、そしてこれ。
3 つから出る規則: **レジスタクラスを持たない型に、自分の入力を作り直しうる
`Expand` を設定しない。**

i16 を `Custom` にした結果、**無限ループは消えた**。

その先で「では narrow store をどう下げるか」が問題になり、答えは
**本物のバイトストア**だった（§3.2b）。

```
lcc 32 翻訳単位:  7/32 (無限ループ 16) → 22/32 (無限ループ 10) → 32/32
全体の所要時間:                                                  4 秒
```

### 3.2b ワード RMW をやめて本物のバイトストアにした

narrow store をワードの read-modify-write に下げるのは**健全でない**。
IR は `store i24` を「バイト範囲の重ならない独立したストア」に割るので
チェーンを張らないが、各々をワード全体の RMW に広げると事後的に重なる。
順序が無いので、片方が相手の書き込み前のワードを読んで上書きする。

差分オラクル（`llvm-reduce` + ネイティブ i386 ビルドとの比較）で捕まえた。
MIR に交錯がそのまま出る。

```
%29 = MOV32rm %28, 0     ; RMW #3 がワードを読む
MOV32mr %17, 0, %22      ; RMW #2 が書く
MOV32mr %28, 0, %33      ; RMW #3 が古いコピーを書き戻す
```

lowering フックからは直せない — 一度に 1 つのストアしか見えず、見えていない
兄弟にチェーンを張れない。空の `MachinePointerInfo` も MMO の `MOVolatile` も
効かない（並列性はフックが呼ばれる前のチェーン構造で決まっている）。

**バイトストアには読む対象が無いので、この危険自体が存在しない。**
`truncstorei8` を `STORE8` 疑似命令で選択し、MovOnlyLegalize が post-RA で
`mov byte ptr [mem], <low byte>` 1 命令に展開する。ソースは `GPR32_ABCD`
（低位バイトを持つ EAX/ECX/EDX/EBX のみ）に制約してあるので、レジスタ割り当てが
バイト名の付くレジスタを保証し、展開に spill も借用レジスタも要らない。
i16 はバイトストア 2 本に割る（アライン不足でワードをまたいでも自然に正しい）。

副産物としてコードがかなり縮んだ。ワード RMW 1 本が ~1,781 mov だったのに対し
バイトストアは 1 命令である。

```
rust_base64_decode  .text 35,151 → 22,879 B   mov 8,340 → 5,006
rust_qoi_decode     .text 132,917 → 115,052 B  mov 23,365 → 19,129
```

### 3.3 残る本物のスケール問題

無限ループが消えて、初めて実際の数字が見えるようになった。
32 翻訳単位を全部コンパイルすると:

```
オブジェクト合計   55 MB
.text 合計       17.5 MiB
```

差の約 27 MB が §3.1 のテーブル複製である（32 本 × ~860 KiB）。
リンク入力の 4 割がコピーというのは、まだ直す価値がある。

`MovOnlyLegalize` が展開後 MachineInstr を保持するコスト（命令あたり約 6.3 KiB、
上限なし）も残っているが、こちらは入力に線形で、現状の実測では
最大の翻訳単位 (`x86linux.c`、IR 18,826 行) でも 4 秒で終わる。
本当に効いてくるのはカーネル規模の関数を相手にするときである。

#### 経緯 (現状の説明ではない)

一時期ここには「`base64` crate の IR は 1 回の呼び出しで 27.1 GiB / 90 秒を要求し、
29 GiB のマシンにはかろうじて入るが 16 GiB の GitHub runner では OOM killer が
runner agent を巻き添えにする」と書いていた。**その診断は誤り**で、正しくは
§3.2 の無限ループである。要求量ではなく機械の残量を測っていた。

[`examples/rust/cargo-link.sh`](examples/rust/cargo-link.sh) が dep の lowering に
掛けている `ulimit -v` (既定 8 GiB、`LLVM_MOV_LLC_DEP_MAXMEM_KB`) はその頃の
対処で、無限ループが直った今は**保険として残してある**だけである
(将来また暴走する経路が出ても CI を殺さない)。当時「時間制限では救えない」と
書いたのは正しかった — 停止しないものにタイムアウトを掛けても、発火より先に
マシンが死ぬからである。
