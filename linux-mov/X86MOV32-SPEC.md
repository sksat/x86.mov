# x86mov32 — 機械仕様

> version 0.2-draft ／ 本書が x86mov32 という機械の正典定義。`DESIGN.md` はこれを Linux に適用するロードマップで、本書に従属する。

x86mov32 は「ほぼ `mov` のみの命令列で計算・I/O・OS を実行する 32bit 機械」。エンコーディングは i386 のサブセットで、実 x86 はこの機械語をそのまま実行できる。

---

## 1. 立脚点：x86mov32 は base ISA、x86 はその拡張

x86mov32 を「ほぼ `mov` だけの **base ISA**」と定義し、普通の x86 を「x86mov32 に拡張を積んだもの」と見る（RISC-V の `RV32I` + `M/A/F/D` と同じモジュラ ISA 観）。x86 との関係は2軸に分かれる。

**(a) 計算 — 拡張は base に還元できる。** x86 の算術・`cmp`/`jcc`・FP・SIMD は、すべて base の `mov` 列に還元できる（「mov はチューリング完全」。llvm-mov が行う lowering）。この層で実 x86 は x86mov32-base を native に実行する。

**(b) システム — MMIO は x86 と共有、特権命令だけが x86 専用。** x86 のシステム面は2つに分かれる：
- **MMIO**（device アドレスへの `mov` でデバイスにアクセス）は x86 native の機構で、`mov` で表現でき UC 順序ごと x86 と共有できる。
- **特権命令**（ポート I/O・`lgdt`/`lidt`/`mov CRn`/`sti`/`iret`/`wrmsr`）は `mov` で表現できない x86 専用拡張。

x86mov32 は MMIO 機構だけを採用し（MMIO-only I/O）、特権命令を捨てる。x86 のシステム効果（console・timer・ページング・割り込み）はすべて MMIO レジスタ（§7 PV-*）として再表現する。

```
実 x86    = base + 計算拡張 + MMIO(共有) + ポートI/O・特権命令(x86専用)
x86mov32  = base + (計算拡張は mov に lower) + MMIO(共有) 上の PV-* レジスタ
```

**実装の役割分担。** **movie86** は base + PV を直接実装する**リファレンス実装**。**実 x86 host** は base の計算コアを native 実行し、PV システム拡張とプラットフォーム契約（マップ・fault・boot）を薄い **substrate**（実特権命令を使う ring0 層、`DESIGN.md` §3.5）が供給する。両実装は §8 の conformance テストで揃える。

> movie86 の現行仕様（userspace runner 挙動・movfuscator 実行・寛容メモリ・`0x1FFE_0000` ABI）の互換は **非ゴール**。movie86 を x86mov32 リファレンス機械へ自由に再形成してよい。

---

## 2. プロファイル

実装もゲストも profile 名で対象を宣言する。

| profile | 含むもの | 用途 |
|---|---|---|
| **x86mov32-base** | §3 ISA + §4 レジスタ + §5 メモリ + §6 fault + §9 boot | 計算 + halt/exit。デバイス無し |
| **x86mov32-pv-min** | base + §7 PV-CONSOLE + PV-TIMER（read のみ） | 極小カーネルが print / tick poll |
| **x86mov32-pv-kernel** | pv-min + PV-CPU + PV-IRQ + PV-MMU + trap 配送 | Linux 級（demand paging・割り込み・preemption）|

---

## 3. ISA サブセット（base, 凍結）

許可される命令はニーモニックで定義する：

- **`mov`**（全幅・全アドレッシングモード。control/segment レジスタへの mov は不可 — 特権効果は §7 の PV-MMIO mov で表す）
- **最小の制御転送**: `jmp rel32`(E9) / `jmp r/m32`(FF /4) / `call rel32`(E8) / `ret`(C3) / `push r32` / `pop r32`

不可: `cmp`/`jcc`/算術/FP/SIMD/`int`/`lock`/REX。条件分岐・算術・FP は llvm-mov が mov 列に lower する。

**観測可能な EFLAGS は無い。** 許可命令はフラグを意味的に読まない（条件分岐は branchless dispatch に lower 済み）。実 x86 上で物理 EFLAGS が変化しても、x86mov32 プログラムはそれを観測してはならない。

旧 movfuscator の機構（`int 0x80`・`mov cs` 経由の SIGILL/SIGSEGV dispatch・segment mov）は **x86mov32 の一部ではない**。

---

## 4. レジスタ（base, 凍結）

- 8 本の 32bit GPR（EAX..EDI）、EIP、ESP。
- セグメントは存在しない（flat）。x86 host 上は flat descriptor で実現するが host の都合。
- EFLAGS は非観測（§3）。

---

## 5. メモリ（base, 凍結）

- フラット 32bit バイトアドレス空間、リトルエンディアン。
- **マップされた領域だけが有効。** base/pv-min でマップされるのは「PT_LOAD + BSS + boot stack（§9）+ 宣言された PV-MMIO 領域（§7）」のみ。範囲外アクセスは fault（§6）。実装は区間集合（interval map）で表す。
- 非整列アクセスは許可（`#AC` 相当は起きない）。
- **自己書き換えコードは base で不可**（W^X 前提）。Linux のテストパッチ（alternatives/static-key/ftrace 等）は §7 PV-TEXTPATCH か、対象 config で無効化（§10）。
- **MMIO は唯一の I/O 機構**（ポート I/O は無い）。MMIO 領域は strong ordering（x86 UC 相当、x86 と共有）。UP・単一スレッド前提。

---

## 6. fault / trap（凍結）

「x86-like」とは「許可された操作に対する同期 fault 境界が x86 と同じ」の意で、x86 protected-mode そのものではない。

### 6.1 同期 fault（base/pv-min）

| 条件 | 挙動 |
|---|---|
| マップ外への load/store | fault。ハンドラ未設定なら停止 |
| マップ外フェッチ / 不正・非許可エンコード | fault（停止）|
| MMIO 不正オフセット/方向（§7） | fault（停止。silent success にしない）|

base/pv-min は除算命令を持たない（llvm-mov が lower）ため除算 fault は起きない。

### 6.2 page fault は pv-kernel の機能

「ページ不在」は base/pv-min には無い（マップは静的）。demand paging・COW・`copy_*_user` fixup は pv-kernel の PV-MMU + trap 配送（§7）に依存する。

### 6.3 trap frame（pv-kernel）

trap をハンドラへ配送するとき機械が積む frame：

```
+0x00  saved EIP        +0x28  fault_addr   (#PF の CR2 相当、無ければ 0)
+0x04  saved ESP        +0x2C  error_code   (trap 種別 + アクセス種別)
+0x08  EAX..EDI (8 GPR) +0x30  trap_kind    (PAGE/ILLEGAL/MMIO/IRQ ...)
```

- **EFLAGS は含めない**（§4 と整合）。Linux の `pt_regs` 相当はこの frame に合わせて新規定義する。
- `IRET`（§7）はこの frame から GPR/EIP/ESP を復帰し、resume 点まで割り込みを mask したまま原子的に再開する。
- 機械はゲストが `TRAP_STACK`（§7）に登録した既知良好スタックに frame を積み、ハンドラ進入時に ESP をそこへ据える。これでハンドラ本体は純 mov で書ける。
- RISC-V 対応: `saved EIP`=`sepc`、`trap_kind`/`error_code`=`scause`、`fault_addr`=`stval`、`IRET`=`sret`、`TRAP_STACK`=`sscratch`。
- **未確定（L2 で確定）**: `TRAP_STACK` が top か base か、機械が frame サイズ分 decrement するか、nested trap での frame 扱い、割り込み mask のタイミング。pv-min（割り込み無し）では未使用。

---

## 7. PV-MMIO

特権操作を、予約アドレスへの `mov` に写像する。CPU は `mov` のみ実行し、機械が反応する。

### アドレスマップ

```
0x1FF0_0000   PV-CPU       (pv-kernel)  IDT_BASE / INTR_MASK / IRET / TRAP_STACK
0x1FF0_1000   PV-CONSOLE   (pv-min)     PUTC / STATUS
0x1FF0_2000   PV-TIMER     (pv-min)     TICKS / ONESHOT
0x1FF0_3000   PV-IRQ       (pv-kernel)  PENDING / EOI
0x1FF0_4000   PV-MMU       (pv-kernel)  PGDIR / FLUSH / FAULT_ADDR
0x1FF0_5000   PV-TEXTPATCH (pv-kernel)  予約（§10）
0x1FF0_FF00   PV-DISCOVERY (all)        MAGIC / VERSION / FEATURE_BITS
```

全レジスタ 4byte・自然整列のみ有効。範囲外/不正方向、R 専用への write、W 専用への read は fault（§6.1）。実アドレスは device tree で記述し（下記）、上表は既定/参照値。

| 領域 | レジスタ | 内容 |
|---|---|---|
| **PV-CONSOLE** (pv-min) | `PUTC` (W) | 下位 8bit を 1 文字出力 |
| | `STATUS` (R) | bit0 = TX ready |
| **PV-TIMER** (pv-min) | `TICKS` (R) | 単調増加 tick（周波数は VERSION 経由）|
| | `ONESHOT` (W) | 次回タイマ通知までの tick（配送は pv-kernel）|
| **PV-CPU** (pv-kernel) | `IDT_BASE` / `INTR_MASK` / `IRET` / `TRAP_STACK` | trap ベクタ / cli・sti / 復帰 / trap スタック。RISC-V の trap CSR + SBI 相当 |
| **PV-IRQ** (pv-kernel) | `PENDING` (R) / `EOI` (W) | 初段 poll 型、後に強制ジャンプ型。CLINT/PLIC 相当 |
| **PV-MMU** (pv-kernel) | `PGDIR` / `FLUSH` / `FAULT_ADDR` | ページディレクトリ base / TLB invalidate / 直近 page fault アドレス。ページテーブル形式は独自定義 |
| **PV-TEXTPATCH** (予約) | — | テキストパッチ（alternatives/static-key 等）を許す場合の host 承認パッチ機構。代替は config 無効化（§10）|
| **PV-DISCOVERY** (all) | `MAGIC` / `VERSION` / `FEATURE_BITS` | 機械の識別 / spec version / 実装 profile。実行時に profile を確認できる |

**device tree。** ハードウェア構成（メモリマップ・PV-* の MMIO アドレス・割り込み番号）は DTB で記述し、カーネルは起動時に DTB から discover する（riscv/arm 流）。上のアドレスマップは参照 DT。compatible は `x86mov32,pv-console` など。

---

## 8. conformance

各実装（movie86 / x86-host substrate）は profile ごとに必須 fixture を全て通す。通らない差分は gap として明示文書化する（沈黙の乖離を禁止）。

- **base**: 許可命令が動く / 非許可が fault / 非整列 load・store 成功 / マップ外 load・fetch fault / 非許可エンコード fault / boot stack 形状 / exit・halt
- **pv-min**: PUTC 出力 / STATUS / TICKS 単調増加 / MMIO 不正オフセット fault / DISCOVERY 各フィールド
- **pv-kernel**（意味確定後）: trap frame レイアウト / IRET 往復 / INTR_MASK / page fault→FAULT_ADDR / PGDIR の VA→PA

**L0 の最初のテストセット**（具体 fixture）: `putc_ok` / `status_read_ok` / `putc_read_fault` / `status_write_fault` / `mmio_byte_fault` / `mmio_unaligned_fault` / `mmio_bad_offset_fault` / `unmapped_load_fault` / `unmapped_fetch_fault` / `exit_ok`。各 fixture = tiny ELF + 期待 stdout または fault record。

---

## 9. boot / calling convention（凍結）

- ELF32 LE i386, `ET_EXEC`, 静的リンク（`PT_INTERP`/`PT_DYNAMIC` 不可）。初期 EIP = `e_entry`。PT_LOAD + BSS をゼロ初期化。マップされるのはこれらと boot stack と PV-MMIO のみ（§5）。
- **program boot**（base/pv-min）: 初期スタック = SysV 最小像（argc=0, argv/envp/auxv=NULL）、ESP は argc を指す。boot stack は実装定義の固定領域（L0 テストの決定性のため base/サイズを固定）。
- **kernel boot**（pv-kernel）: エントリで DTB 物理アドレスを `EBX`、boot magic を `EAX` に渡す（RISC-V の `a1=dtb` 相当）。カーネルは DTB から discover する。
- 終了 = PV exit / halt。

---

## 10. version 方針

- **凍結（0.x で変えない）**: §3 ISA、§4 レジスタ、§5 メモリ、§6.1 同期 fault、§6.3 trap frame レイアウト、§9 boot。
- **進化（version 付き）**: PV-CPU/IRQ/MMU の詳細意味論、ページテーブル形式、割り込み配送、PV-TEXTPATCH 方針。
- **feasibility**: `L0.5-KILLTEST.md` 参照（判定 SURVIVES）。最小 config にカーネル側の阻害要因は無く、llvm-mov の必須要件は volatile codegen / 空+operand バリア / i386 varargs / i64 helper lower / C irq-flag。
