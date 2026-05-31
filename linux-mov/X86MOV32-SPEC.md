# x86mov32 — canonical mov-only machine specification

> Version: **0.2-draft**
> 状態: base invariant（§3–§6, §9）は凍結対象。PV 拡張（§7）とプロファイル境界は version 付きで進化する。
>
> 本書が一次的・正典的な machine 定義である。`DESIGN.md`（Linux/x86mov32 移植ロードマップ）は本書に従属する。
>
> **名前**: `x86mov32` = x86(i386) サブセット encoding + mov 制約 + 32bit。
> **0.2 での方針転換**: x86mov32 を「x86 の一種」ではなく **独立した新アーキテクチャ** として扱う（§1）。これにより 0.1-draft にあった股裂き（segment mov・`int 0x80`・EFLAGS trap frame・「x86 が base に conform」）を解消した。

## 1. 立脚点：x86mov32 は base ISA、x86 はその拡張

x86mov32 を「ほぼ `mov` のみの **base ISA**」として定義し、**普通の x86 を「x86mov32 に大量の拡張を積んだもの」と位置づける**。RISC-V の `RV32I` + `M/A/F/D/C…` と同じモジュラ ISA 観である。Linux 移植も新アーキ `arch/x86mov32/` を起こす作法で進める（x86 の荷物を継承しない）。

> **参照アーキは RISC-V (rv32)**。x86mov32 は MMIO-only I/O（§1b）・device tree によるハードウェア記述・単一 trap ベクタ（§6.3）という点で構造的に RISC 的であり、Linux 側の移植も `arch/riscv` 32bit を主 template とする（`arch/x86` ではない）。trap モデルや CLINT/PLIC/SBI 相当の platform interface を既知の良設計として移植できる（§6.3, §7.4–§7.6 の注を参照）。

x86 と x86mov32 の関係は **2 つの軸**に分けると正確になる：

### (a) 計算拡張 — base に還元可能

x86 の算術 / `cmp`+`jcc` / FP / SIMD / 文字列命令などは、すべて base の `mov` 列に **一方向に還元できる**。これが「mov はチューリング完全」の正体であり、llvm-mov が実装している lowering そのもの。すなわち

```
x86 の計算 ISA = x86mov32-base + {計算拡張}      （計算拡張は base に還元可能）
```

- **この層では実 x86 は x86mov32-base の素直な実装**：`mov`/`jmp`/`call`/`ret` を同じ結果で実行する。x86 は計算コアに native に conform する。

### (b) システム面 — MMIO 機構は x86 と共有、特権命令だけが x86 専用

x86 のシステム面は **2 つの下位機構**に分かれる。両者を混同しないことが肝心：

- **MMIO（device address への `mov` でデバイスにアクセス）** — x86 が **native に持つ機構**。`mov` でそのまま表現でき、強い順序（UC メモリ型相当, §5）も含めて **x86mov32 と x86 で共有できる**。
- **特権命令**（`in`/`out` のポート I/O・`lgdt`/`lidt`・`mov CRn`・`cli`/`sti`・`iret`・`wrmsr`）— mov で表現できない専用オペコード。これが **x86 専用・base に還元できない拡張**。

x86mov32 は **MMIO 機構だけを採用し、ポート I/O と特権命令を捨てる**（RISC-V/ARM と同じ **MMIO-only I/O モデル**）。x86 のシステム効果（console・timer・CR3・IDT・割り込み）はすべて、共有 MMIO 機構の上のレジスタ（§7 PV-*）として **再表現**する。

- ゆえに PV-MMIO は「x86mov32 独自の並行システム」ではなく、**x86 と共有する MMIO 機構の上に必要なデバイス/制御レジスタを定義したもの**。エンコーディングも意味（mov + UC 順序）も x86 と一致する。
- 帰結: **x86-host 実行層の負担は小さい**。PV-CONSOLE/PV-TIMER は通常の MMIO デバイスを該当アドレスに map するだけ（shim ほぼゼロ）。shim が要るのは **MMIO レジスタが x86 の特権操作をラップする箇所だけ**（例: PV-CPU/PV-MMU の CR3・IDT 設定 → 実 x86 では `mov CRn`/`lidt` に翻訳）。

### (c) プラットフォーム契約

base の「マップ規約・fault 配送・boot」（§5/§6/§9）は x86 上で無料では成り立たない（ページング off の x86 は任意アドレスで fault しない）。x86-host 実行層がページング等でこれを敷く。

### まとめ

```
実 x86            = base + {計算拡張} + {MMIO(共有)} + {ポートI/O・特権命令 (x86専用)}
x86mov32          = base + {計算拡張は mov に lower} + {MMIO(共有) 上に PV-* デバイス/制御レジスタ}
```

- **計算コア**: 実 x86 が native に conform（§1a）。
- **MMIO 機構**: x86 と共有（§1b）。x86mov32 はこれを唯一の I/O 機構とする。
- **x86 専用拡張**（ポート I/O・特権命令）: x86mov32 は持たず、その効果を共有 MMIO 上の PV-* レジスタで再表現。x86-host 実行層はこのラップ箇所だけ shim する。
- **プラットフォーム契約**（マップ規約・fault・boot, §1c）: x86-host 実行層がページング等で敷く。

movie86 は base + MMIO + PV-* を直接実装するリファレンス実装。conformance は §8 のテストで定義され、movie86 と x86-host 実行層の双方がそれを通すことで担保する。

## 2. プロファイル（profile）

実装もゲストも「movie86」ではなく **named profile** を宣言する。

| profile | 含むもの | 用途 |
|---|---|---|
| **x86mov32-base** | §3 ISA + §4 レジスタ + §5 メモリ + §6 fault + §9 boot | 計算 + halt/exit。デバイス無し |
| **x86mov32-pv-min** | base + §7.3 PV-CONSOLE + §7.4 PV-TIMER（割り込み無しの read） | 極小カーネルが print / tick poll |
| **x86mov32-pv-kernel** | pv-min + §7.5 PV-CPU + §7.6 PV-IRQ + §7.7 PV-MMU + §6.3 trap 配送 | Linux/x86mov32 級（demand paging・割り込み・preemption）|

**規則**:
- 「X は x86mov32-pv-min を狙う」と profile 名で書く。movie86 は各 profile のリファレンス実装。
- **x86-host 実行層**は profile ではなく「実 x86/qemu 上で指定 profile を供給する層」。同名 profile の §8 テストを通すか、通らない差分を conformance gap として文書化した場合のみ「その profile を host できる」と言える。
- **design stance: movie86 の AS-IS 仕様の互換は非ゴール（best-effort ですらない）**。movie86 を x86mov32 のリファレンス機械へ再形成する際、現行の userspace-runner 挙動・movfuscator 実行・寛容な flat メモリ・`0x1FFE_0000` ABI を保存する義務は一切ない。旧 movfuscator 互換（`int 0x80`・SIGILL/SIGSEGV dispatch・segment-mov）は **x86mov32 の一部ではない**（§3.3）。既存資産（movfuscator-wasm / explorer 等）が壊れることは許容する。

## 3. ISA サブセット（base, 凍結）

### 3.1 「mov-only」の定義

**意味クラスではなくニーモニックで定義する。** base で許可されるのは以下のみ：

- `mov`（全幅・全アドレッシングモード。ただし control register / segment register への mov は base では**不許可** — 特権操作は §7 で PV-MMIO mov に写像）
- 制御転送の最小集合: `jmp rel32`(E9), `jmp r/m32`(FF /4), `call rel32`(E8), `ret`(C3), `push r32`(50–57), `pop r32`(58–5F)

> 注: 純粋主義の「100% mov（jmp すら無し）」は本 spec の非目標。本機械は **mov + 最小制御転送**（movie86/llvm-mov の既定 "mov+jmp" に一致）。

### 3.2 明示的に不許可（base）

`cmp`/`jcc`/算術命令/FP/SIMD/REX/`lock` prefix/`int`/segment-mov/control-reg-mov。条件分岐・算術・FP は llvm-mov が mov 列に lower 済み（README ステージ 7a–7h）。

### 3.3 x86mov32 に含まれないもの（旧 movfuscator 機構）

以下は **x86mov32 の一部ではない**（base / pv-* いずれにも現れず、互換も非ゴール §2）：

- `int 0x80` syscall（x86mov32 では PV-MMIO + §9 の exit/halt が syscall/終了の唯一の機構）
- SIGILL/SIGSEGV dispatch（`mov cs, r16` 経路を含む movfuscator trampoline）
- segment register への mov

### 3.4 EFLAGS

base / pv に **観測可能な EFLAGS は存在しない**。許可命令はフラグを意味的に読まない（条件分岐は branchless dispatch に lower 済み）。実 x86 host 上では物理 EFLAGS が副作用で変わるが、x86mov32 プログラムはそれを観測してはならない（移植性条件）。trap frame に EFLAGS は含めない（§6.3）。

## 4. レジスタ状態（base, 凍結）

- 8 本の 32bit GPR（EAX..EDI）、EIP、ESP。
- セグメントは概念として存在しない（flat。x86mov32 は segmentation を持たないアーキ）。x86 host 上では flat descriptor で実現するが、それは host 実装の都合。
- EFLAGS は §3.4 の通り非観測。

## 5. メモリモデル（base, 凍結）

- フラット 32bit バイトアドレス空間、リトルエンディアン。
- **マップ規約（Codex round-2 対応）**: x86mov32 は **明示的にマップされた領域のみ**有効。base/pv-min では「PT_LOAD + BSS（§9）+ boot stack（§9 で確保する実装定義領域）+ 宣言された PV-MMIO 領域（§7）」だけがマップされ、それ以外へのアクセスは fault（§6.1）。bare-metal 物理メモリモデルではない。
  - **実装モデル（L0）**: movie86 は現状の flat 配列を **interval map**（マップ済み区間の集合）に置き換え、区間外を fault とする。base/pv-min L0 では **presence（マップの有無）判定で十分**で、W^X / `p_flags` の権限強制は後段（保護を導入する pv-kernel）まで不要。
- **アラインメント**: 非整列アクセスは許可（`#AC` 相当は発生しない）。
- **自己書き換えコード**: base では **不許可**（W^X 前提）。Linux のテストパッチ機構（alternatives / static-keys / jump-label / ftrace / kprobes / paravirt-patch）は §7.8 PV-TEXTPATCH か「対象 config で全テキスト改変を無効化」のいずれかで扱う（§10 未確定、ただし mainline 移植の必須検討事項）。
- **MMIO は唯一の I/O 機構**（ポート I/O は持たない, §1b）。MMIO 領域（§7）アクセスは strong ordering（プログラム順, x86 の UC メモリ型相当 — この機構と順序は x86 と共有する）。UP・単一スレッド前提、投機・並べ替え無し。

## 6. fault / trap 意味論（base, 凍結）

「x86-like」とは **「許可された操作に対する同期 fault 境界が x86 と同じ」** の意であり、x86 protected-mode 挙動そのものではない（x86mov32 は独自アーキ）。

### 6.1 同期 fault（base/pv-min, 凍結）

| 条件 | x86mov32 base の挙動 |
|---|---|
| 未マップ領域（§5 のマップ外）への load/store | fault。ハンドラ未設定なら停止 |
| 未マップ領域からの命令フェッチ / decode 不能・非許可エンコード | fault（停止） |
| MMIO 不正オフセット / 不正方向（§7） | fault（停止）。silent success にしない（movie86 の trap-on-unknown を継承） |

base/pv-min では除算命令を持たない（llvm-mov が mov 列に lower）ため除算 fault は発生しない。

### 6.2 demand paging / page fault は pv-kernel の機能

「ページ不在」は base/pv-min には存在しない（マップは静的）。**demand paging・COW・vmalloc fault・`copy_*_user` の fixup** は x86mov32 が pv-kernel で定義する page fault 機構（§7.7 PV-MMU + §6.3 配送）に依存する。Linux/x86mov32 はこれを使う。

### 6.3 trap frame と配送（pv-kernel, **本 0.2 で形を確定** — Codex round-2 対応）

非同期/同期 trap をハンドラに配送するとき、機械が積む **x86mov32 trap frame** を以下に確定する（`IRET` ABI 破壊を将来回避するため今決める）：

```
offset  field
+0x00   saved EIP        (fault した命令、または次命令)
+0x04   saved ESP
+0x08   EAX .. +0x24 EDI (8 GPR)
+0x28   fault_addr       (#PF 相当の CR2 等価。該当しない trap では 0)
+0x2C   error_code       (trap 種別 + アクセス種別ビット)
+0x30   trap_kind        (PAGE/ILLEGAL/MMIO/IRQ ...)
```

- **EFLAGS は含めない**（§3.4 と整合）。x86mov32 は x86 の exception frame を模さず、自前の frame を定義する。Linux/x86mov32 の `pt_regs` 相当はこの frame に合わせて新規定義する（arch/x86mov32 側の責務）。
- `IRET`（§7.5）はこの frame から GPR/EIP/ESP を復帰する。割り込みは resume 点まで masked のまま（原子的再開）。
- **frame の置き場所と trap stack（round-4, 詳細は L2 で確定）**: 機械はゲストが事前に登録した **trap stack** に frame を積み、ハンドラ進入時に **ESP=その trap stack** とする。trap stack は PV-CPU `TRAP_STACK` レジスタ（§7.5）でゲストが設定する。これにより、割り込み元の ESP が不正/ユーザ空間でも既知良好スタックでハンドラが回り、ハンドラ本体は純 mov で書ける（ハンドラ prologue に非-mov なスタック確立は不要）。
  - **未確定（draft, L2 で決める, round-5）**: `TRAP_STACK` が top-of-stack か frame base か / 機械が frame サイズ分 decrement するか / **nested trap**（trap stack 上で再 fault した場合に frame を上書きするか別領域か）/ frame 構築の前後で async IRQ を mask するタイミング。pv-min（割り込み無し）では未使用なので L0 はブロックしない。
- **RISC-V との対応**: `saved EIP`↔`sepc`、`trap_kind`/`error_code`↔`scause`、`fault_addr`↔`stval`、`IRET`↔`sret`、`TRAP_STACK`↔`sscratch`（カーネルスタック退避）。frame レイアウトの確定はこの既知モデルを踏襲しており、arch/riscv の trap 処理が移植の参考になる。

## 7. PV-MMIO ABI

特権操作のうち base ISA で表現できないものを、予約アドレスへの `mov` に写像する。CPU は依然 `mov` のみ実行し、機械が反応する。

### 7.1 アドレスマップ

```
0x1FF0_0000 .. 0x1FF0_0FFF   PV-CPU        (pv-kernel)   IDT_BASE / INTR_MASK / IRET / TRAP_STACK
0x1FF0_1000 .. 0x1FF0_1FFF   PV-CONSOLE    (pv-min)      PUTC / STATUS
0x1FF0_2000 .. 0x1FF0_2FFF   PV-TIMER      (pv-min)      TICKS / ONESHOT
0x1FF0_3000 .. 0x1FF0_3FFF   PV-IRQ        (pv-kernel)   PENDING / EOI
0x1FF0_4000 .. 0x1FF0_4FFF   PV-MMU        (pv-kernel)   PGDIR / FLUSH / FAULT_ADDR
0x1FF0_5000 .. 0x1FF0_5FFF   PV-TEXTPATCH  (pv-kernel?)  予約（§7.8, §10 未確定）
0x1FF0_FF00 .. 0x1FF0_FFFF   PV-DISCOVERY  (all)         MAGIC / VERSION / FEATURE_BITS
```
（旧 movfuscator の `0x1FFE_0000` ABI は x86mov32 では予約しない。§7.1 の窓は自由に設計してよい。）
全レジスタ 4byte 幅・自然整列アクセスのみ有効。範囲外/不正方向は fault（§6.1）。

### 7.2 アクセス規約

read 専用レジスタへの write、write 専用への read、未定義オフセットアクセスはいずれも fault。

### 7.3 PV-CONSOLE（pv-min, 凍結候補）

| off | 名前 | RW | 意味 |
|---|---|---|---|
| +0x00 | `PUTC` | W | 下位 8bit を 1 文字出力 |
| +0x04 | `STATUS` | R | bit0=TX ready |

### 7.4 PV-TIMER（pv-min は read のみ / 割り込みは pv-kernel）

| off | 名前 | RW | 意味 |
|---|---|---|---|
| +0x00 | `TICKS` | R | 単調増加 tick（周波数は §7.9 VERSION 経由）|
| +0x04 | `ONESHOT` | W | 次回タイマ通知までの tick。配送は §7.6（pv-kernel）|

> RISC-V 対応: CLINT の `mtime`(=TICKS) / `mtimecmp`(=ONESHOT) とほぼ同型。実装・カーネル側ドライバとも CLINT を参考にできる。

### 7.5 PV-CPU（pv-kernel, draft — 意味は L0.5 後に確定）

`IDT_BASE`（trap ベクタ表 base）/ `INTR_MASK`（cli/sti 相当, 0=有効）/ `IRET`（§6.3 frame から復帰）/ `TRAP_STACK`（trap 進入時に機械が frame を積み ESP に据える既知良好スタック, §6.3）。

> RISC-V 対応: trap CSR（`stvec`=IDT_BASE, `sstatus.SIE`=INTR_MASK, `sret`=IRET, `sscratch`=TRAP_STACK）+ SBI（カーネルがプラットフォームに特権操作を依頼する役割）に相当。SBI の構造を PV-CPU の設計参考にする。

### 7.6 PV-IRQ（pv-kernel, draft）

`PENDING`(R, poll 型) / `EOI`(W)。配送: 初段 poll 型（純 mov）、preemption 要件が出たら強制ジャンプ型（trap frame §6.3 を積んで IDT 経由）を追加。

> RISC-V 対応: CLINT(software/timer IRQ) + PLIC(外部 IRQ) に相当。irqchip ドライバは PLIC を参考にできる。

### 7.7 PV-MMU（pv-kernel, draft）

`PGDIR`(W, ページディレクトリ物理 base = ページング有効化)/ `FLUSH`(W, TLB 相当 invalidate)/ `FAULT_ADDR`(R, 直近 page fault のアドレス)。ページテーブル形式は **x86mov32 独自に定義**（x86 PTE 形式の流用可否は L0.5 で判断）。

### 7.8 PV-TEXTPATCH（予約, §10 未確定）

自己書き換え/テキストパッチを安全に行う操作。Linux の alternatives/static-keys/ftrace 等を許す場合に必要。代替は「対象 config で全テキスト改変を無効化」。L0.5 のインベントリでどちらが現実的か判定。

### 7.9 PV-DISCOVERY（all, 凍結候補）

`MAGIC`(R, 固定値) / `VERSION`(R, spec version) / `FEATURE_BITS`(R, 実装 profile の bit 集合)。実装/ゲスト双方が実行時に profile を確認できる。

### 7.10 device tree によるハードウェア記述（pv-kernel）

ハードウェア構成（メモリマップ・PV-CONSOLE/TIMER/IRQ/MMU の MMIO アドレス・割り込み番号）は **device tree（DTB）で記述し、カーネルは起動時に DTB から discover する**（riscv/arm 流）。

- §7.1 のハードコード・アドレスマップは **デフォルト/リファレンス DT** という位置づけ。実アドレスは DTB が正。これにより §7.1 を凍結せずに済む（将来のアドレス変更が DT 差し替えで吸収できる）。
- DTB は起動時にカーネルへ渡す（§9 boot 契約）。movie86・x86-host 実行層の双方が DTB を供給する。
- PV-* デバイスには専用の DT compatible 文字列を割り当てる（例: `x86mov32,pv-console` / `x86mov32,pv-timer`）。ペリフェラルの *設計* は x86 の馴染んだデバイス（16550 UART 等）を参考にしてよいが、*記述・発見* は DT に統一する。

## 8. conformance（一級の成果物 — 0.2 で必須リスト確定）

各実装（movie86 / x86-host 実行層）は profile ごとに以下の **必須 fixture** を全て通すこと。通らない差分は conformance gap として明示文書化（沈黙の乖離を禁止）。

**base 必須**:
- decode whitelist（§3.1 許可命令が動く）/ blacklist（§3.2 非許可が fault）
- 非整列 load/store が成功する
- 未マップ data アクセスが fault する
- 未マップ命令フェッチが fault する
- 非許可エンコードが fault する
- boot stack 形状（§9）/ exit・halt

**pv-min 必須**: PUTC 出力 / STATUS / TICKS 単調増加 / MMIO 不正オフセット fault / DISCOVERY 各フィールド。

**L0 具体 fixture（実装の最初のテストセット）**: `putc_ok`（PUTC 出力が host に届く）/ `status_read_ok` / `putc_read_fault`（W 専用を read→fault）/ `status_write_fault`（R 専用を write→fault）/ `mmio_byte_fault`（PUTC へ byte store→fault, 4byte 自然整列のみ有効）/ `mmio_unaligned_fault` / `mmio_bad_offset_fault` / `unmapped_load_fault` / `unmapped_fetch_fault` / `exit_ok`。各 fixture は tiny ELF + 期待する stdout または fault record。

**pv-kernel 必須**（0.2 で枠、意味確定後に具体化）: trap frame レイアウト（§6.3）/ IRET 往復 / INTR_MASK 効果 / page fault → FAULT_ADDR / PGDIR による VA→PA。

## 9. boot / calling convention（base, 凍結）

- ELF32 LE i386, `ET_EXEC`, 静的リンク。`PT_INTERP`/`PT_DYNAMIC` 不可。
- 初期 EIP = `e_entry`。memory は PT_LOAD + BSS をゼロ初期化。これらと PV-MMIO 領域のみがマップされる（§5）。
- **2 種類の boot 契約**（凍結）:
  - **program boot**（base / pv-min）: 初期スタック = SysV ABI 最小像（argc=0, argv/envp/auxv=NULL）、ESP は argc を指す。極小プログラム・L1 極小カーネル用。**boot stack は実装定義の固定領域**（base/top と extent を実装が決め、§5 のマップ集合に含める）。L0 テストの決定性のため、この領域の base/サイズを実装で固定する。
  - **kernel boot**（pv-kernel）: エントリで **DTB 物理アドレスを `EBX` に**、boot magic を `EAX` に渡す（RISC-V の `a0=hartid, a1=dtb` に相当する規約を x86mov32 用に固定）。カーネルは DTB からハードウェアを discover する（§7.10）。今この規約を固定し、将来の破壊的変更を避ける。
- 終了 = halt（PV exit / halt 機構, §7）。

## 10. version 方針と未確定事項

- **凍結（0.x で変えない）**: §3 ISA、§4 レジスタ、§5 メモリ（マップ規約含む）、§6.1 同期 fault、§6.3 trap frame レイアウト、§9 boot。
- **version 付きで進化**: §7.5–§7.7 の詳細意味論、ページテーブル形式、割り込み配送モデル、§7.8 テキストパッチ方針。
- **0.3 への入力 = L0.5「Linux/x86mov32 feasibility kill-test」→ 完了**（[`L0.5-KILLTEST.md`](./L0.5-KILLTEST.md)、二者独立検証で **SURVIVES**）。結論: 最小 config（UP/nommu/no-SMC/no-jumplabel）にカーネル側 config BLOCKER は無く、難所は無効化 or 純 C 化できる。llvm-mov の irreducible 要件は **(1) volatile codegen 正しさ (2) 空+operand 付き memory バリア (3) i386 varargs (4) i64 helper lower（libgcc 除算は emit しない）(5) C/PV irq-flag**。任意制約 inline asm は first boot 不要。entry/特権パスは PV-MMIO mov 列として `arch/x86mov32` に手書き（link/boot 必須）。
