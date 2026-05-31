# Linux を x86mov32 へ移植する — 設計

> 設計フェーズ（実装前）。機械の定義は [`X86MOV32-SPEC.md`](./X86MOV32-SPEC.md) を正とし、本書はそれを Linux に適用するロードマップ。

## ゴール

Linux を **新アーキ `arch/x86mov32`** として移植し、ほぼ全てが `mov`(+最小制御転送) から成る ELF32 イメージとしてビルドして、movie86（リファレンス実装）と実 x86/qemu（substrate 上）で起動する。当面は UP・no-device・boot-to-shell に絞る（SMP・実ドライバ・性能は非ゴール）。

## なぜ新アーキ（arch/x86, mov backend ではなく）

x86mov32 を独立 base ISA と定義した以上（spec §1）、Linux 側も **`arch/riscv`(rv32) を主 template に `arch/x86mov32` を新設**する。x86mov32 は MMIO-only I/O・device tree・単一 trap ベクタという点で構造的に RISC 的で、arch/x86 の最難関（segmentation・protected-mode entry・alternatives/paravirt・ポート I/O・ACPI）— まさに mov 化が難しく、x86mov32 が継承しないと決めた領域 — を最初から持たずに済む。

既知の良設計をほぼ移植できる：trap 処理↔riscv trap（sepc/scause/stval/sret）、PV-CPU↔trap CSR + SBI、PV-TIMER↔CLINT、PV-IRQ↔CLINT/PLIC、ハードウェア記述↔device tree。ペリフェラルは設計を x86 の馴染んだもの（16550 UART 等）から借りてよいが、記述・発見は DT に統一する。

## 既存資産

- **movie86**: ELF32 i386 ランナー。`mov` を特定アドレスへ送ると host へ routing するマジックアドレス機構を持つ（PV-MMIO の母体）。`Memory` は trait。特権状態・割り込み・MMU・デバイスは未実装（= 実装対象）。
- **llvm-mov**: 整数・制御フロー（全 Jcc を mov 化）・call/ret・f32/f64 soft-float を mov 化済み。Rust/C→ELF。inline asm / atomics / varargs / native i64 は未対応。spec §1(a) の「計算拡張→base 還元」を担う。

## ロードマップ

各ステージは TDD（失敗するテスト→実装→緑）。各ステージは spec の profile を宣言する。

| Stage | profile | 内容 | 緑の判定 |
|---|---|---|---|
| **L0** | pv-min | movie86 に PV-MMIO 窓 + PV-CONSOLE。x86-like fault（interval map）| L0 fixture（spec §8）|
| **L0.5** ✅ | — | feasibility kill-test（[`L0.5-KILLTEST.md`](./L0.5-KILLTEST.md)、判定 SURVIVES）| 完了 |
| **L1** | pv-min | 自作極小カーネル（inline asm 不使用）が mov だけで `"Hello, x86mov32\n"` | E2E 出力 + `.text` が mov(+jmp) のみ |
| **L2** | pv-kernel | PV-CPU（IDT_BASE/INTR_MASK/IRET/TRAP_STACK）+ trap frame + poll 型 PV-IRQ | trap frame 往復 / マスク / tick |
| **L3a** | — | llvm-mov: volatile codegen・空+operand バリア・i386 varargs・i64 helper lower・memcpy/memset | 各 fixture が mov-only で通る |
| **L3b** | — | llvm-mov: 任意制約 inline asm（広い config / driver 用）| inline-asm fixture |
| **L4** | — | atomics（UP, 割り込みマスク）| atomic fixture |
| **L5** | pv-kernel | PV-MMU + demand paging / page fault 配送 | page fault→FAULT_ADDR / PGDIR で VA→PA |
| **L6** | pv-kernel | 強制ジャンプ型割り込み（preemption）| タイマで別タスクへ切替 |
| **L7** | pv-kernel | `arch/x86mov32` を実 Linux に追加し boot→`start_kernel`→early console | early console が PV-CONSOLE に出る |
| **L8** | pv-kernel | substrate（qemu machine type）で実 x86 起動を実証 | 同じイメージが movie86 と qemu 両方で起動 |

最初の旗 = L0–L1（mov だけで 1 文字）。生死を分けたのが L0.5。mainline への分水嶺が L3a。x86 起動の実証が L8。

**PV の実装段階。** spec は profile 定義（pv-kernel は PV-CPU/IRQ/MMU を含む）、本書は実装順。先に実装するのは pv-min（console+timer）まで（L0–L1）。pv-kernel は spec で予約済み、L2/L5/L6 で順次実装する。

## x86 で起動できるか — substrate

**起動できる**（設計上）。素の x86 ではなく、薄い x86-host **substrate**（実 x86 ring0、非-mov）の上で、計算は native・PV 境界だけ仲介して動く。実証は L8、下記 gate が条件。

substrate は RISC-V の **OpenSBI（M-mode ランタイム）に相当する薄い特権ファームウェア**。カーネルが PV-MMIO へ `mov` したのを substrate が処理する。movie86 はこの役割を Rust で兼ねる（だから別 substrate 不要）。movie86 が命令を解釈するのに対し、substrate は CPU に mov を native 実行させ、稀な PV 境界だけ仲介する。

| カーネル | substrate（実 x86） |
|---|---|
| (boot 前) | real→protected mode・初期ページング・DTB を渡して jump |
| PV-MMU `PGDIR` mov | 実 CR3/PT 設定 → 以後 HW MMU が native に保護・変換（全速）|
| PV-CONSOLE/TIMER mov | UART/timer デバイス応答 |
| 実行中 | 実 IRQ を実 IDT で受け、trap frame（spec §6.3）合成 → PV ハンドラへ jump |

**substrate 自体も mov 化できる。** 仕事の大半は純計算（faulting mov のデコード・trap frame 構築・whitelist 検証・EIP 前進）で llvm-mov でコンパイルできる。irreducible に非-mov なのは X86-DELTA の M セット（`lidt`/`mov CRn`/`sti`/`iret` 等）＋ substrate 固有の host 義務（real-mode boot・`mov from CR2`・実 IRQ コントローラ+EOI・whitelist 強制）。つまり substrate = mov-heavy + 最小の非-mov 特権スタブ群（[`X86-DELTA.md`](./X86-DELTA.md) §5）。

**形態。** (1) **qemu machine type `x86mov32`**（推奨）: qemu が PV-MMIO デバイスと割り込み注入を提供。movie86 と qemu が spec の2実装になる。(2) **bare-metal monitor**: 実機 ring0 最小 firmware。

**near-native の範囲。** 通常の計算と直接マップした MMIO は native 速度。not-present #PF で捕える PV 制御レジスタは意図的に高コストな exit で、hot path に置かない（高頻度 I/O は実 MMIO ページ直マップ）。

**substrate の conformance gate**（L8 の条件）:
1. **命令 whitelist の強制** — x86 に mov-only モードは無い。boot 前静的検証 or 検証済ページのみ実行可。
2. 正確な i386 `mov` デコーダ（PV を #PF+デコードで捕える場合）。
3. EIP 前進 vs 再実行の規則（MMIO emulation は前進、page fault は据え置き）。
4. host 例外を x86mov32 trap frame に翻訳（`popf`/`pushf`/`cmovcc` 等は whitelist で排除済み前提）。
5. **分離** — guest と substrate が同 ring だと崩壊。実質 micro-hypervisor（qemu/KVM がクリーン）。

**既存資産。** turbo86（ptrace で mov バイナリを実 x86 に native 実行+trap）は userspace 版 substrate の実在証拠。base/pv-min プログラムは turbo86 系で実 x86 に流せる。

## リスク

- **R1（最大）**: コンパイラ/カーネル意味論互換性。inline asm は氷山の一角。→ L0.5 で計測済み、最小 config では限定的（後述）。
- **R2**: llvm-mov の inline asm 実装コスト。→ L3a（first-boot 必須の最小形）と L3b（任意制約）に分割。
- **R3（host 間乖離）**: PV を movie86 だけが持つと実 x86 で落ちる。→ fault を x86-like に固定（spec §6.1）、PV を profile で明示、conformance を両 host で通す CI（spec §8）。
- **R5（テキストパッチ）**: alternatives/static-key/ftrace は自己書き換え。→ PV-TEXTPATCH か config 無効化。

## 決定事項

- ターゲット名 `x86mov32`、新アーキ `arch/x86mov32`（arch/x86 流用せず）、主 template は arch/riscv(rv32)。
- ハードウェア記述は device tree、kernel boot で DTB を渡す。
- PV-MMIO console は `0x1FF0_1000`。**movfuscator/AS-IS 互換は非ゴール**で PV 窓は自由設計、既存物の破壊を許容（spec §1 末尾）。
- L1 のカーネルは inline asm 非依存の自作。実装は pv-min 先行。

## 未決（実装で詰める）

- TRAP_STACK の nested trap / mask 順（L2）
- PV-* の device tree binding（compatible / reg / interrupts）
- arch/x86mov32 の defconfig 起点（SMP=n / PREEMPT_NONE / nommu uaccess / JUMP_LABEL=n / no ALTERNATIVE・FTRACE・KPROBES / GENERIC_ATOMIC64 / GENERIC_LIB_* / 無印 BUG）
- substrate の非-mov スタブ命令集合
