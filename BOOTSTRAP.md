# mov だけで自立する — Linux 移植とセルフホストの実現可能性

このリポジトリには「mov だけで動く世界」を目指す取り組みが 2 本ある。

- **Linux の移植** — [`linux-mov/`](linux-mov/)（設計は PR #86、tracking は issue #87）
- **movfuscator のセルフホスト** — [`movfuscator-selfhost/`](movfuscator-selfhost/)（PR #84）

本書は両者を**同じ問いの 2 つの出口**として捉え直し、実測に基づいて
「今どこにいて、何を先に潰すべきか」を出す。結論を先に書く。

> **どちらも実現可能。クリティカルパスはほぼ同一で、その大半は llvm-mov の
> C カバレッジと movie86 の mov-only ホスト呼び出し面に集約される。**
>
> そして、両 PR のどちらも把握していなかった事実が 2 つある。
> 1. **「コンパイルが遅い」と思われていたものは無限ループだった。** lcc の 32 翻訳単位のうち
>    16 本がこれで 5 分以内にコンパイルできていなかった。原因は `SELECT ↔ SELECT_CC` の
>    相互展開で、2 つの入口を塞いだ（本ブランチで修正済み）。
> 2. **その先に待っているのはメモリ**。無限ループを潰すと lcc の 32 翻訳単位のうち
>    21 本が mov-only にコンパイルできるようになり、残る 11 本は機能ではなく
>    **1 TU あたり ~27 GiB のピーク RSS** で落ちる。数千 TU の Linux を語る前にここが要る。

---

## 1. 現状（2026-08-18 時点）

| サブプロジェクト | 状態 |
|---|---|
| **llvm-mov** | stage 7h まで完了。整数・制御フロー・call/ret・f32/f64 ソフトフロートが全て mov 化済み。本環境で `make build` / `make test` (188) / `make test-mov-only` (58) すべて緑 |
| **movie86** | ELF32 i386 ランナー。mov-only ABI ページ（`ABI_BASE = 0x1FFE_0000`）に `SET_VIDEO_MODE` / `MMAP_REQUEST` / `WRITE` / `POLL_INPUT` / `EXIT` の 5 呼び出し |
| **turbo86** | ptrace で mov バイナリを実 x86 に native 実行 + trap。userspace 版 substrate の実在証拠 |
| **movfuscator-selfhost** (PR #84) | 36 TU 中 35 が mov-only 自己コンパイル成功。リンクも通る。実行は未達 |
| **linux-mov** (PR #86) | 設計 4 本。feasibility kill-test は **SURVIVES** |

未マージの関連 PR: **#73**（switch jump table）、**#84**、**#85**、**#86**。

---

## 2. 実測 — llvm-mov に実 C を食わせると何が起きるか

構文ごとの詳細は [`llvm-mov/GAP-MATRIX.md`](llvm-mov/GAP-MATRIX.md)。要点。

**すでに通っていたもの（設計文書が「要対応」と見積もっていた）**

kill-test（[`linux-mov/L0.5-KILLTEST.md`](linux-mov/L0.5-KILLTEST.md)）が挙げた
「config で消せない llvm-mov 必須要件」5 項目のうち、**1（volatile codegen）と
2（空のコンパイラバリア）は既に満たされていた**。2 回の volatile load が
2 本の `mov` として残ることを asm レベルで確認している。

**本ブランチで対応したもの**

| | |
|---|---|
| **varargs** | kill-test の必須要件 3。i386 SysV の `va_list` は `char*` 1 本なので、実装は「名前付き引数の直後に fixed object を予約し、`va_start` でその番地を store する」だけ。呼び出し側は cdecl が全引数をスタックに置くので追加コードすら要らなかった |
| **`fastcc`** | clang は -O1 以上で internal 関数を `fastcc` に昇格させる。最適化ありの実 C は必ず踏むのに `report_fatal_error` で弾いていた |
| **`SELECT` の無限ループ 2 件** | §3 |
| **i16 / i1 の ext-load** | i8 の Custom 経路を幅パラメータ化しただけ。実 C の `short` メンバと `_Bool` グローバルが踏む |
| **GAS 予約語と同名のシンボル** | `offset` という名前の C グローバルが Intel 構文で参照できず `as` が落ちていた。`.att_syntax` 窓で `.set` エイリアスを定義する形に |

**まだ通らないもの**

| 項目 | 影響 |
|---|---|
| inline asm のオペランド制約（`"r"` 等） | Linux の `barrier_data()`（config で消せない）と任意 inline asm（L3b） |
| i64 の除算・可変長シフト・比較 | i32 版と同型の作業（比較は別途コンパイル時間の問題） |
| atomics | UP + 割り込みマスクで純 C 化できるので config 回避可（L4） |
| switch のジャンプテーブル | PR #73 で対応済み・未マージ |

---

## 3. 「コンパイルが遅い」の正体は無限ループだった

当初これを「構文次第でコンパイル時間が super-linear」と記録していた
（PR #73 も `base64` crate で同様の観察をしている）。測ったら違った。

- RSS は **108 MB で 100 秒間 1 バイトも動かない**
- スタックは何度サンプルしても `SelectionDAG::Legalize()` の中

進んでいない。**回っている。** LegalizeDAG は `SELECT` を `SELECT_CC` へ、
`SELECT_CC` を `SETCC` + `SELECT` へ展開するので、両方 `Expand` だと互いを
生成し続けて不動点に到達しない。入口が 2 つあった。

1. **ポインタ型の `select`。** ドライバの IR 書き換えは i32（と helper 内の i64）
   だけを bit-blend に潰しており、コメントも「i1 / pointer / aggregate は default
   Expand を通す」と明記していた。Rust の `no_std` フィクスチャはポインタをほとんど
   select しないが、C は常時やる。
2. **レガライザ自身が合成する `SELECT`。** IR 書き換えでは原理的に届かない。
   最小再現は `select` を 1 つも含まない、ただの i32 カウントループで、
   上限がループ外の if-diamond の PHI から来るもの。

`ISD::SELECT` を Custom 化して同じ bit-blend を SDAG 側でも行うことで、
サイクルを自然な位置で断ち切った。回帰は `test/Execution/ptr_select.ll` と
`test/Execution/loop_diamond_bound.ll`。

---

## 4. movfuscator セルフホスト — 別ルートのほうが短い

### 4.1 PR #84 が突き当たっている壁

1. **壁 #3**: `movfuscator.c` が lburg のテーブルを `static short *_nts[];` と前方宣言する。
   lcc の C89 front-end はこの「static な不完全配列の tentative definition」を拒否する。
   解消には lcc front-end の緩和 + wasm rcc の再ビルドが要る。
2. **blocker ③**: リンクは通るが実行できない。movfuscator の crt0 は SIGILL/SIGSEGV
   ディスパッチ前提で、native 起動に協調的 signal 処理が要る。
   （PR #84 は二分探索で「犯人は mov コンパイルではなく runtime」と正しく特定している。）

### 4.2 llvm-mov を stage0 にすると両方消える

rcc を構成する翻訳単位 — lcc front-end 29 本 + lburg 生成の `mov.c` / `x86linux.c` /
`dagcheck.c` の計 32 本 — を `clang-22 -m32 -std=gnu89 -emit-llvm` に通したところ
**32/32 が成功**した。`movfuscator.c` を取り込む `mov.c` も含めてである。
lcc の C89 front-end を経由しないので、**壁 #3 はそもそも発生しない**。

さらに、rcc が要求する IR 機能は驚くほど狭い。

| 機能 | 出現 |
|---|---|
| inline asm | **0 箇所** |
| atomics | **0 箇所** |
| i64 の乗除算・可変長シフト | **0 箇所**（定数量 `ashr i64` が 1 箇所だけ。これは通る） |
| setjmp/longjmp | **0 箇所** |
| varargs | 5 TU ← 本ブランチで対応 |
| switch | 24 TU ← PR #73 で対応 |
| byval / sret | 14 TU ← stage 6b で対応済み |
| memcpy / memset | 11 TU ← 対応済み |

そして llvm-mov の出力は 7c ディスパッチャによる `jmp` ベースの制御フローで、
movfuscator の SIGILL ディスパッチを使わない。**native 実行に協調的 signal 処理が
要らないので、blocker ③ も消える。**

### 4.3 実測した到達度

`clang → llvm-mov-llc → as --32` を rcc の 32 TU に対して通した結果の推移
（PR #73 の `br_jt` と `-mlong-double-64` を併用）:

| 状態 | コンパイル完走 | 無限ループ | 失敗 |
|---|---|---|---|
| 本ブランチ以前 | 7 | 16 | 9 |
| + varargs / fastcc | 7 | 16 | 9 |
| + ポインタ `select` 修正 | 12 | 8 | 12 |
| + レガライザ合成 `SELECT` 修正 | 13 | 7 | 12 |
| + i16 / i1 ext-load | 20 | 1 | 11 |
| + GAS 予約語シンボル | **21** | **0** | 11 |

**無限ループは 0 になった。** 残る 11 本は機能の欠落ではない。
1 本ずつ逐次で走らせても全て同じ落ち方をする:

```
TU            wall(s)    peakRSS  verdict
dag                92   26.0 GiB  (OOM kill)
dagcheck          118   25.7 GiB  (OOM kill)
decl               98   26.0 GiB  (OOM kill)
gen               114   25.1 GiB  (OOM kill)
mov               200   26.0 GiB  (OOM kill)
prof              132   26.0 GiB  (OOM kill)
stab               63   26.0 GiB  (OOM kill)
symbolic          106   26.0 GiB  (OOM kill)
types             114   26.0 GiB  (OOM kill)
```

29 GiB のマシンの上限に張り付いている。実際 `dag.c` は machine が空いていた
一度だけ **104 秒 / 27.4 GiB で成功**した。つまり要求は 27 GiB 前後で、
このマシンでは「たまたま通る/通らない」の境界にある。

**機能上の壁はほぼ無くなり、残りは資源の問題に変わった。**

### 4.4 end-to-end の確認

`printf` / `sprintf` / `strlen` / `atoi` を呼ぶ C プログラムを
`clang-22 -m32 → llvm-mov-llc → as --32 → ld -static`（`crt1.o` + `libc.a` + `libgcc`）
に通したところ、ユーザコードの `.text` は **9,111 mov + 23 jmp のみ**（他のニーモニックはゼロ）で、
正しい出力と終了コードを返した。varargs が実 glibc 相手に end-to-end で効くことの確認でもある。

### 4.5 ブートストラップ鎖

```
stage0  llvm-mov              （x86-64 native、既存）
stage1  rcc                   （clang → llvm-mov でコンパイルした mov-only rcc）
stage2  rcc'                  （stage1 が -target=x86/mov で自分のソースをコンパイル）
stage3  rcc''                 （stage2 が同じことをする）
   ⇒ stage2 と stage3 がバイト一致すれば、LCC 古典の `triple` テストと同じ意味での
     セルフホスト証明が成立する
```

stage1 の実行に要るものだけが残作業。

- **(a) 手っ取り早い版**: static glibc(i386) とリンクして native 実行。§4.4 で実証済み。
  ただし成果物は「ユーザコード 100% mov / libc は native」という PR #84 と同じ正直さの水準。
- **(b) 100% mov 版**: movie86 上で走らせる。`rcc` は引数を省くと **stdin/stdout がデフォルト**
  （`freopen` はファイル指定時のみ）なので、ホスト呼び出し面は read / write / exit / メモリ確保に縮む。
  movie86 の mov-only ABI ページには `CALL_WRITE`（`int 0x80` の write と同じ ebx/ecx/edx 規約）と
  `CALL_MMAP_REQUEST` が**既にある**。足すのは `CALL_READ` 相当と brk/sbrk の筋だけ。
  その上に llvm-mov でコンパイルした最小 libc（stdio 3 fd / malloc / 文字列 / `strtod` / `strtol` / `qsort`）を載せる。

**(b) が本命**。同じ ABI ページ機構が linux-mov の PV-MMIO そのものなので、投資が二重に効く。

---

## 5. マルチ TU のスケール — ここから先が本命

### 5.1 バイトテーブルがオブジェクトごとに複製される

stage 7 のバイトテーブルは `MovAsmPrinter::emitEndOfAsmFile` が**オブジェクトごとに**吐き、
シンボルはファイルローカル、セクションは COMDAT でもない。**リンクしても重複排除されない。**
lcc の `list.c` 1 TU で `.text` 7,955 B に対しオブジェクト全体 871,984 B（`.text` は 0.9 %）。
2 オブジェクトを `ld -r` で束ねるとテーブルは倍増する（実測確認済み）。
rcc（39 TU）で ~33 MiB、Linux カーネルでは成立しない。

対処はテーブルの COMDAT + weak 化、または単一ランタイムオブジェクト
（`libmovrt.a` 相当）への切り出し。後者のほうが `--gc-sections` と素直に噛み合い、
副次的に全成果物が ~860 KiB 縮む。

### 5.2 ピークメモリ

無限ループを潰したあと、残る壁はメモリになった。`dag.c`（IR 4,459 行、
特別大きくもない C ファイル 1 本）で

```
Elapsed (wall clock) time:   1:44
Maximum resident set size:   27,435,892 kB   ← 27.4 GiB
```

lcc の 32 翻訳単位のうち 11 本がこの領域にいて、29 GiB のマシンでは
**逐次に走らせても OOM で落ちる**（§4.3 の表）。`make -j` は論外。
数千 TU の Linux カーネルを語る前にここが解けている必要がある。
（stage 7 の mov-only legalize が 1 命令を ~50 mov のバイトチェーンへ展開するため
MachineFunction が巨大化する、が素直な仮説。プロファイルは未取得。）

---

## 6. Linux 移植 — 設計は成立、L1 は近い、L7 は §5 待ち

[`linux-mov/DESIGN.md`](linux-mov/DESIGN.md) の設計（x86mov32 を独立 base ISA として定義し、
`arch/riscv`(rv32) を template に `arch/x86mov32` を新設、特権効果は PV-MMIO への mov に写像）は、
実測の裏付けを得て**より有利**になった。

- kill-test の必須要件 5 項目のうち、**1・2 は既に満たされ、3（varargs）は本ブランチで解消**。
  残るのは 4（i64 helper）と 5（C の irq-flag、これは movie86 側の PV 実装）。
- L1（自作極小カーネルが mov だけで `"Hello, x86mov32\n"`）は、要するに
  「PV-MMIO コンソールを叩くフリースタンディング C プログラム」であり、
  volatile・バリア・varargs が揃った今、**数日規模の作業**。ここが最初の旗になる。

一方で、**L7（実 Linux に `arch/x86mov32` を追加して boot）は §5 の解決が前提**。
数千 TU × 860 KiB のテーブル複製ではイメージが成立せず、
1 TU あたり 27 GiB のピークメモリではビルドが終わらない。
kill-test は「カーネル側に config BLOCKER は無い」を示したが、
**ツールチェイン側のスケールは kill-test の対象外だった**。そこが今回の追加知見。

---

## 7. 推奨する順序

### P0 — スケール（両ゴール共通、これ抜きでは実カーネル・実コンパイラに届かない）

1. **ピークメモリのプロファイルと削減** — `dag.c` の 27.4 GiB。まず何が保持されているかを測る
2. **バイトテーブルを共有ランタイムへ**（COMDAT + weak、または `libmovrt.a` 切り出し）

### P1 — 実 C を通す（両ゴール共通）

3. **PR #73 をマージ**（`br_jt`）
4. varargs / fastcc / `SELECT` 無限ループ / i16・i1 ext-load / GAS 予約語シンボル
   — **本ブランチで完了**
5. i64: `__divdi3`/`__udivdi3`/`__moddi3`/`__umoddi3` の注入（i32 版と同型）＋
   `shl_parts`/`srl_parts`/`sra_parts` の Expand
6. inline asm の `"r"`/`"m"` 制約（`getRegForInlineAsmConstraint`）— `barrier_data()` に必要

### P2 — ゴール別

- **セルフホスト**: movie86 に `CALL_READ` + brk → 最小 libc を llvm-mov でビルド →
  §4.5 のブートストラップ鎖 → `triple` テスト
- **Linux**: linux-mov L0（movie86 に PV-MMIO 窓 + PV-CONSOLE）→ L1（極小カーネル）

P1 の 5・6 は P2 のどちらにも必須ではない（rcc は i64 も inline asm も使わない。
最小 Linux は inline asm オペランドだけ要る）ので、**P0 → P2 を先に走らせて
最初の旗を早く立てる**のが良い。

---

## 8. 明示的に非ゴールとしておくこと

**llvm-mov 自身のセルフホストは近い将来のゴールにしない。** `llvm-mov-llc` は C++ で
libLLVM に依存する。C++ 例外・RTTI・libstdc++・全面的な i64、そして §5.2 のメモリを
考えると、rcc とは桁が違う。「mov-only なコンパイラが自分を再生産する」という性質は
§4.5 の鎖で rcc により達成できるので、そちらで旗を立てるのが正しい。
