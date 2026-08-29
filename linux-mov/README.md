# linux-mov — Linux を x86mov32 へ移植する

Linux カーネルを、ほぼ全てが x86 `mov`(+最小制御転送) から成る ELF32 イメージとしてビルドし、**movie86**（エミュレータ＝リファレンス実装）と**実 x86/qemu** で起動させる取り組み。

中心アイデアは **x86mov32 を独立した base ISA として定義する**こと。普通の x86 は「x86mov32 + 拡張」とみなせる（RISC-V の `RV32I` + 拡張と同じモジュラ ISA 観）：
- x86 の**計算**拡張（算術・分岐・FP）は base の `mov` 列に還元できる（llvm-mov が行う）。
- **MMIO** は x86 と共有する機構。
- **特権命令**だけが x86 専用で、その効果は MMIO への `mov`（PV-MMIO）で再表現する。

これにより Linux 移植は arch/x86 の流用ではなく、`arch/riscv`(rv32) を手本にした **新アーキ `arch/x86mov32`** の追加になる。

## 状態

設計フェーズ（実装前）。feasibility kill-test は **SURVIVES**。tracking issue: #87。

## ドキュメント

| 文書 | 内容 |
|---|---|
| [`X86MOV32-SPEC.md`](./X86MOV32-SPEC.md) | **正典の機械仕様**。ISA・メモリ・fault・trap frame・PV-MMIO・プロファイル・boot |
| [`X86-DELTA.md`](./X86-DELTA.md) | x86 との本質的差分の分析。「mov で本当にできないこと」＝ PV が供給すべきもの |
| [`DESIGN.md`](./DESIGN.md) | Linux 移植ロードマップ（L0–L8）と、実 x86 起動のための substrate |
| [`L0.5-KILLTEST.md`](./L0.5-KILLTEST.md) | 実 Linux に対する実現可能性調査の結果（判定 SURVIVES）|

初めて読むなら SPEC → DELTA → DESIGN → KILLTEST の順。
