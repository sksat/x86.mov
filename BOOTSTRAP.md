# mov だけで自立する — Linux 移植とセルフホストの実現可能性

このリポジトリには「mov だけで動く世界」を目指す取り組みが 2 本ある。

- **Linux の移植** — [`linux-mov/`](linux-mov/)（設計は PR #86、tracking は issue #87）
- **movfuscator のセルフホスト** — [`movfuscator-selfhost/`](movfuscator-selfhost/)（PR #84）

本書は、両者を**同じ問いの 2 つの出口**として捉え直し、実測に基づいて
「今どこにいて、何を先に潰すべきか」を出す。結論を先に書く:

> **どちらも実現可能。しかも両者のクリティカルパスはほぼ同一で、
> その大半は llvm-mov の C カバレッジと、movie86 の mov-only ホスト呼び出し面に集約される。**
> ただし、両 PR のどちらも記録していない**マルチ TU のスケール問題**（バイトテーブルの
> オブジェクト単位複製とコンパイル時間）が、実カーネル・実コンパイラ規模では先に効く。

---

## 1. 現状（2026-08-18 時点）

| サブプロジェクト | 状態 |
|---|---|
| **llvm-mov** | stage 7h まで完了。整数・制御フロー・call/ret・f32/f64 ソフトフロートが全て mov 化済み。本環境で `make build` / `make test` (184) / `make test-mov-only` (58) すべて緑 |
| **movie86** | ELF32 i386 ランナー。mov-only ABI ページ（`ABI_BASE = 0x1FFE_0000`）に `SET_VIDEO_MODE` / `MMAP_REQUEST` / `WRITE` / `POLL_INPUT` / `EXIT` の 5 呼び出し |
| **turbo86** | ptrace で mov バイナリを実 x86 に native 実行 + trap。userspace 版 substrate の実在証拠 |
| **movfuscator-selfhost** (PR #84) | 36 TU 中 35 が mov-only 自己コンパイル成功。リンクも通る。実行は未達 |
| **linux-mov** (PR #86) | 設計 4 本。feasibility kill-test は **SURVIVES** |

未マージの関連 PR: **#73**（switch jump table）、**#84**、**#85**、**#86**。

---

## 2. 実測 — llvm-mov に実 C を食わせると何が起きるか

詳細な行列は [`llvm-mov/GAP-MATRIX.md`](llvm-mov/GAP-MATRIX.md)。要点だけ:

**すでに通るもの（設計文書が「要対応」と見積もっていたが、実は通った）**

- `volatile` load/store が正しく保存される（2 回の volatile load が 2 本の mov として残る）
- 空のコンパイラバリア `asm volatile("" ::: "memory")` — Linux の `barrier()` そのもの
- 構造体の値渡し/値返し、可変長 `memcpy`、i64 の加減乗、関数ポインタ経由の間接呼び出し

kill-test（[`linux-mov/L0.5-KILLTEST.md`](linux-mov/L0.5-KILLTEST.md)）が挙げた
「config で消せない llvm-mov 必須要件」5 項目のうち、**1・2 は既に満たされていた**。

**本ブランチで対応したもの**

- **varargs**（stage 6f）— kill-test の必須要件 3。i386 SysV の `va_list` は `char*` 1 本なので、
  実装は「名前付き引数の直後に fixed object を予約し、`va_start` でその番地を store する」だけ。
  呼び出し側は cdecl が全引数をスタックに置くので追加コードすら要らなかった。
- **`fastcc`** — clang は -O1 以上で internal 関数を `fastcc` に昇格させる。
  最適化ありの実 C は必ず踏むのに、`report_fatal_error` で弾いていた。

**まだ通らないもの**

| 項目 | 影響 |
|---|---|
| inline asm のオペランド制約（`"r"` 等） | Linux の `barrier_data()`（config で消せない）と任意 inline asm（L3b） |
| i64 の除算・可変長シフト | `__divdi3` 等の未注入 / `shl_parts` 未対応。どちらも i32 版と同型の作業 |
| **i64 の比較** | **120 秒でも終わらない**。機能の欠落ではなくコンパイル時の病理 |
| atomics | UP + 割り込みマスクで純 C 化できるので config 回避可（L4） |
| switch のジャンプテーブル | PR #73 で対応済み・未マージ |

---

## 3. 見落とされていた本命 — マルチ TU のスケール

両 PR とも単一 TU（あるいは単一 crate）での成否を測っている。実カーネルや実コンパイラは
数十〜数千の TU をリンクするので、そこで初めて出る問題がある。

### 3.1 バイトテーブルがオブジェクトごとに複製される

stage 7 のバイトテーブルは `MovAsmPrinter::emitEndOfAsmFile` が**オブジェクトごとに**吐き、
シンボルはファイルローカル、セクションは COMDAT ではない。**リンクしても重複排除されない。**

lcc の `list.c` を 1 TU コンパイルした実測:

```
.text                     7,955 B
オブジェクト合計        871,984 B      ← .text は全体の 0.9 %
```

2 オブジェクトを束ねると `.rodata.__mov_add8_tables` は 262 KiB → 524 KiB に倍増する
（実測確認済み）。rcc（39 TU）なら ~33 MiB、Linux カーネルでは成立しない。

**これはマルチ TU をやる前に必ず要る。** テーブルを COMDAT + weak にするか、
単一のランタイムオブジェクト（`libmovrt.a` 相当）へ切り出して外部参照にする。
後者のほうが `--gc-sections` と素直に噛み合い、副次的に全成果物が ~860 KiB 縮む。

### 3.2 コンパイル時間が構文次第で爆発する

`list.c`（IR 153 行）は 0 秒、`string.c`（IR 253 行）は **240 秒でも終わらない**。
行数ではなく特定の構文が効く。PR #73 も `base64` crate で
「単一の大きな関数の mov-only legalize が super-linear」を報告しており、同じ現象の別の顔。
マルチ TU のビルド時間を語る前に、ここのプロファイルが要る。

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

さらに、rcc が要求する IR 機能は驚くほど狭い:

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
movfuscator の SIGILL ディスパッチを使わない。**つまり native 実行に協調的 signal 処理が要らず、
blocker ③ も消える。**

### 4.3 ブートストラップ鎖

```
stage0  llvm-mov              （x86-64 native、既存）
stage1  rcc                   （clang → llvm-mov でコンパイルした mov-only rcc）
stage2  rcc'                  （stage1 が -target=x86/mov で自分のソースをコンパイル）
stage3  rcc''                 （stage2 が同じことをする）
   ⇒ stage2 と stage3 がバイト一致すれば、LCC 古典の `triple` テストと同じ意味での
     セルフホスト証明が成立する
```

stage1 の**実行**に要るものだけが残作業:

- **(a) 手っ取り早い版**: static glibc(i386) とリンクして native 実行。**今日できる（検証済み）**。
  `printf` / `sprintf` / `strlen` / `atoi` を呼ぶ C プログラムを
  `clang-22 -m32 → llvm-mov-llc → as --32 → ld -static`（`crt1.o` + `libc.a` + `libgcc`）に通したところ、
  ユーザコードの `.text` は **9,111 mov + 23 jmp のみ**（他のニーモニックはゼロ）で、
  正しい出力と終了コードを返した。varargs が実 glibc 相手に end-to-end で効くことの確認でもある。
  ただし成果物は「ユーザコード 100% mov / libc は native」という PR #84 と同じ正直さの水準。
- **(b) 100% mov 版**: movie86 上で走らせる。`rcc` は引数を省くと **stdin/stdout がデフォルト**
  （`freopen` はファイル指定時のみ）なので、ホスト呼び出し面は read / write / exit / メモリ確保に縮む。
  movie86 の mov-only ABI ページには `CALL_WRITE`（`int 0x80` の write と同じ ebx/ecx/edx 規約）と
  `CALL_MMAP_REQUEST` が**既にある**。足すのは `CALL_READ` 相当と brk/sbrk の筋だけ。
  その上に llvm-mov でコンパイルした最小 libc（stdio 3 fd / malloc / 文字列 / `strtod` / `strtol` / `qsort`）を載せる。

**(b) が本命**。同じ ABI ページ機構が linux-mov の PV-MMIO そのものなので、投資が二重に効く。

---

## 5. Linux 移植 — 設計は成立、L1 は近い、L7 は P0 待ち

[`linux-mov/DESIGN.md`](linux-mov/DESIGN.md) の設計（x86mov32 を独立 base ISA として定義し、
`arch/riscv`(rv32) を template に `arch/x86mov32` を新設、特権効果は PV-MMIO への mov に写像）は、
実測の裏付けを得て**より有利**になった。

- kill-test の必須要件 5 項目のうち、**1・2 は既に満たされ、3（varargs）は本ブランチで解消**。
  残るのは 4（i64 helper）と 5（C の irq-flag、これは movie86 側の PV 実装）。
- L1（自作極小カーネルが mov だけで `"Hello, x86mov32\n"`）は、要するに
  「PV-MMIO コンソールを叩くフリースタンディング C プログラム」であり、
  volatile・バリア・varargs が揃った今、**数日規模の作業**。ここが最初の旗になる。

一方で、**L7（実 Linux に `arch/x86mov32` を追加して boot）は §3 の解決が前提**。
数千 TU × 860 KiB のテーブル複製ではイメージが成立せず、
コンパイル時間の病理も残ったままではビルドが終わらない。
kill-test は「カーネル側に config BLOCKER は無い」を示したが、
**ツールチェイン側のスケールは kill-test の対象外だった**。そこが今回の追加知見。

---

## 6. 推奨する順序

### P0 — マルチ TU を可能にする（両ゴール共通、これ抜きでは何も進まない）

1. **バイトテーブルを共有ランタイムへ**（COMDAT + weak、または `libmovrt.a` 切り出し）
2. **コンパイル時間のプロファイル** — `string.c` と i64 比較の経路。まず再現最小化から

### P1 — 実 C を通す（両ゴール共通）

3. **PR #73 をマージ**（`br_jt`）— lcc の `decl.c` が踏む
4. varargs + fastcc — **本ブランチで完了**
5. i64: `__divdi3`/`__udivdi3`/`__moddi3`/`__umoddi3` の注入（i32 版と同型）＋
   `shl_parts`/`srl_parts`/`sra_parts` の Expand
6. inline asm の `"r"`/`"m"` 制約（`getRegForInlineAsmConstraint`）— `barrier_data()` に必要

### P2 — ゴール別

- **セルフホスト**: movie86 に `CALL_READ` + brk → 最小 libc を llvm-mov でビルド →
  §4.3 のブートストラップ鎖 → `triple` テスト
- **Linux**: linux-mov L0（movie86 に PV-MMIO 窓 + PV-CONSOLE）→ L1（極小カーネル）

P1 の 5・6 は P2 のどちらにも**必須ではない**（rcc は i64 も inline asm も使わない。
最小 Linux は inline asm オペランドだけ要る）ので、P0 → P2 を先に走らせて
最初の旗を早く立てるのが良い。

---

## 7. 明示的に非ゴールとしておくこと

**llvm-mov 自身のセルフホストは近い将来のゴールにしない。** `llvm-mov-llc` は C++ で
libLLVM に依存する。C++ 例外・RTTI・libstdc++・全面的な i64、そして §3.2 のコンパイル時間を
考えると、rcc とは桁が違う。「mov-only なコンパイラが自分を再生産する」という性質は
§4.3 の鎖で rcc により達成できるので、そちらで旗を立てるのが正しい。
