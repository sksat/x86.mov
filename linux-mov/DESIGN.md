# linux-mov — Linux を x86mov32 へ移植する

> 状態: **設計フェーズ（実装前）**。本書は合意形成のためのたたき台であり、コードは未着手。
>
> **本書は [`X86MOV32-SPEC.md`](./X86MOV32-SPEC.md)（正典の機械定義 v0.2-draft）に従属する**。機械の ISA/メモリ/fault/PV-MMIO/profile 定義は spec を正とする。本書はそれを Linux に適用するロードマップ。

## 0. ゴールと非ゴール

- **ゴール**: Linux を **新アーキテクチャ `arch/x86mov32/`** として移植し、ほぼ全てが `mov`(+最小制御転送) から成る ELF32 イメージとしてビルドして、movie86（x86mov32 のリファレンス実装）および x86-host 実行層（実 x86/qemu）上で起動する。
- **非ゴール（当面）**: SMP、実デバイスドライバ群、性能。まず UP・no-device・boot-to-shell の一点突破。

## 1. これは「arch/x86 + mov backend」ではなく「新アーキ移植」である

x86mov32 を独立 base ISA と定義した（spec §1）以上、Linux 側も **arch/x86 の流用ではなく `arch/x86mov32/` の新規追加**として進める。

**主 template は `arch/riscv`（32bit）**。x86mov32 は MMIO-only I/O・device tree・単一 trap ベクタという点で構造的に RISC 的（spec §1）なので、参照すべきは arch/x86 ではなく arch/riscv。具体的対応：trap 処理 ↔ riscv trap（sepc/scause/stval/sret, spec §6.3）、PV-CPU ↔ trap CSR + SBI、PV-TIMER ↔ CLINT、PV-IRQ ↔ CLINT/PLIC、ハードウェア記述 ↔ **device tree**（spec §7.10）。既知の良設計をほぼ移植できる。

**なぜ arch/x86 を流用しないか**: arch/x86 の最難関（segmentation・protected-mode entry・alternatives/static-keys パッチ・paravirt-ops・GDT/IDT 直叩き・ポート I/O・ACPI 列挙）は、まさに mov 化が難しい部分であり、spec §1(b) で「x86 専用拡張」として x86mov32 が継承しないと決めた領域そのもの。新アーキなら **それらを最初から持たず**、自分が制御できる最小面（ABI・ページテーブル形式・trap frame・entry/exit・atomics・barrier）だけを、x86 と共有する MMIO 機構（spec §1b）の上に定義できる。

**ペリフェラル**: デバイス *設計* は x86 の馴染んだもの（16550 UART 等）を参考にしてよいが、*記述・発見* は device tree に統一（spec §7.10）。movie86 / x86-host 層が起動時に DTB を渡し（spec §9 kernel boot）、カーネルは DT から discover する。

**エンコーディングは維持**: arch は新規だが機械語は i386 サブセット（spec §1）。ゆえに movie86 と実 x86 の両 host で走る性質は byte レベルで保たれる。

### 旧 (A)/(B) 二系統の整理

0.1-draft の「(A) arch/x86+shim / (B) para-virt movie86」という対立は解消した。新しい整理は **「単一の新アーキ x86mov32 を、複数の host で走らせる」**：

| host | 位置づけ |
|---|---|
| **movie86** | x86mov32（base + PV）のリファレンス実装。主開発ターゲット |
| **x86-host 実行層**（実 x86/qemu） | base 計算コアは native 実行、PV システム拡張とプラットフォーム契約を薄い非-mov 層で供給（spec §1(b)(c)） |

## 2. 既存資産（実地確認済み）

- **movie86**: ELF32 i386 静的リンク実行、flat メモリ、`0x1FFE_0000` ページへの mov を AbiHost に routing するマジックアドレス機構（= PV-MMIO の母体）。`Memory` は trait。特権状態・割り込み・MMU・デバイスは未実装（= 実装対象）。
- **llvm-mov**: 整数・制御フロー（全 Jcc を mov 化）・call/ret・f32/f64 soft-float を mov-only 化済み。Rust/C→ELF パイプライン。**inline asm / atomics / varargs / native i64 が無い**。実証規模 ~200 LoC。spec §1(a) の「計算拡張→base 還元」を担うのがこれ。

## 3. ロードマップ（ステージ制 — TDD、各ステージは spec の profile を宣言）

> **順序原則（smart-friend レビュー反映）**: 最大リスクは PV-MMIO ではなく **コンパイラ/カーネルの意味論互換性**。よって割り込み機構（L2）に労力を注ぐ前に **L0.5 = feasibility kill-test** を割り込ませ、その結果で PV-CPU/MMU/IRQ の意味論（spec §7.5–§7.7）と llvm-mov の作業順序を決める。

| Stage | profile | 内容 | 緑の判定 |
|---|---|---|---|
| **L0** | pv-min | movie86 に PV-MMIO ウィンドウ + PV-CONSOLE(`PUTC`)。spec §6.1 の x86-like 同期 fault（未マップ=fault）も実装 | 別 PV ページへの mov が console handler に届く単体 + base/pv-min conformance fixture（spec §8） |
| **L0.5** | — | **Linux/x86mov32 feasibility kill-test**（コード変更なし）。実 Linux ソースに対し inline asm 形態・**`asm goto`・`"memory"` clobber・exception-table/fault fixup**・atomics・builtins・special sections・linker script・varargs/i64 を棚卸し。**kill 条件**: llvm-mov がコンパイラバリア + faultable asm/制御フロー fixup をモデル化できないと判明したら、ロードマップを再設計（atomics より先に詰む論点） | blocking list が spec 0.3 入力として確定 |
| **L1** | pv-min | 自作極小カーネル（数百行 C, **inline asm 不使用**）を llvm-mov でビルドし `PUTC` に mov して `"Hello, x86mov32\n"` を出して停止 | E2E: ELF を movie86 で実行→期待出力。objdump で `.text` が mov(+jmp) のみ |
| **L2** | pv-kernel | PV-CPU(`INTR_MASK`/`IDT_BASE`/`IRET`) + spec §6.3 trap frame + poll 型 PV-IRQ。協調スケジューラの土台 | trap frame 往復 / マスク制御 / tick 単体 + E2E + pv-kernel conformance（一部） |
| **L3** | — | llvm-mov に **inline asm → mov**（mainline への分水嶺）。L0.5 の blocking list 順で、まず単純制約→`"memory"`/volatile→`asm goto` | 新規 inline-asm fixture が mov-only で通る |
| **L4** | — | atomics（UP 前提で `lock` 省略 + cmpxchg を mov 列に） | atomic fixture |
| **L5** | pv-kernel | PV-MMU(`PGDIR`/`FLUSH`/`FAULT_ADDR`) + `PagedMemory`。demand paging / page fault 配送（spec §6.2/§7.7） | page fault → FAULT_ADDR / PGDIR で VA→PA |
| **L6** | pv-kernel | 強制ジャンプ型割り込み（preemption） | タイマで別タスクへ切替 |
| **L7+** | pv-kernel | `arch/x86mov32/` を実 Linux に追加し、最小 config で boot→`start_kernel`→early console へ。テキストパッチ方針（spec §7.8）を確定 | early console が PV-CONSOLE に出る |
| **L8** | pv-kernel | x86-host substrate（qemu machine type `x86mov32`）で実 x86 経路を実証（§3.5）。同じイメージが movie86 と qemu の両方で起動 | conformance fixture（spec §8）が両 host で緑 |

> L0–L1 が「mov だけで動く極小カーネルが 1 文字出す」= 最初の旗。L0.5 が生死を分け、L3 が mainline への分水嶺。L8 が「x86 でも起動」の実証。

## 3.5 x86-host 実行層と「x86 で起動できるか」

**結論（設計上）: 起動可能。素の x86 ではなく、x86-host substrate（実 x86 ring0、非-mov）の上で、計算は near-native・PV 境界のみ仲介して動く。** ただし未検証の設計主張であり、L8 の実証は下記 conformance gate を満たすことが条件（round-3 反映）。詳細根拠は [`X86-DELTA.md`](./X86-DELTA.md)。

- カーネルの計算コード（mov バイト列）は実 x86 CPU が native 実行（i386 サブセット, spec §1a）。エミュレーションではなく全速。
- 足りないのは X86-DELTA §5 の差分（boot・PV-MMU・保護・割り込み配送・textpatch）だけ。これを substrate が供給する。**新アーキ化で「x86 で走る」性質は失っていない**（encoding を x86 サブセットに保った見返り）。

substrate の責務（= 差分そのもの、過不足なし）:

| カーネル | substrate（実 x86） |
|---|---|
| (boot 前) | real→protected mode・初期ページング・DTB を渡して jump |
| PV-MMU `PGDIR` mov | 実 CR3/PT 設定 → 以後 HW MMU が保護・変換を native 強制（全速） |
| PV-CONSOLE/TIMER mov | UART/timer デバイス応答（普通の MMIO emulation） |
| 実行中 | 実 timer/IRQ を実 IDT で受け、x86mov32 trap frame（spec §6.3）合成 → PV ハンドラへ jump |
| PV `IRET` mov | trap frame から復帰 |

PV 境界は稀なので計算は全速・仲介は薄い。

**substrate の形態**:
1. **qemu machine type `x86mov32`**（推奨）: guest=mov カーネル、qemu が PV-MMIO デバイス + 割り込み注入を提供。movie86 と qemu がこの spec の2実装になり conformance（spec §8）に乗る。
2. **bare-metal monitor**: 実機 ring0 最小 firmware。純度最高だが手間。

**既存資産**: turbo86（ptrace で mov バイナリを実 x86 に native 実行 + trap）は **userspace 版 x86-host 実行層**が既にある証拠。base/pv-min プログラム（L1 等）は turbo86 系で実 x86 に流せる。pv-kernel Linux はその system 版（qemu machine / KVM）が要る。

### substrate の必須要件（conformance gate, round-3）

「薄い」は計算が native という意味で、substrate 自体には正確さが要る：

1. **命令 whitelist の強制**（最重要）: x86 に "mov-only モード" は無い。guest が ring0 native 実行する以上、紛れ込んだ非-mov 命令は実 x86 意味論で動いてしまう。→ **boot 前の静的検証**（イメージ全体が許可命令のみか）か **検証済みページにのみ実行権限**を与える方式が必要。コンパイラを信頼するだけでは機械 conformance にならない。
2. **正確な i386 `mov` デコーダ**: PV-MMIO を not-present #PF + 命令デコードで捕える方式は、ModRM/SIB/disp/幅/方向/実効アドレスを正しく解く mov デコーダを要する（full x86 decode は不要だが正確さ必須）。
3. **EIP 前進 vs 再実行の規則**: MMIO エミュレーションは faulting 命令を再実行せず、結果を合成して **EIP を mov の次へ前進**。真の page fault は **EIP を faulting 命令に残す**。この区別を substrate spec に明記。
4. **host 例外の完全隠蔽**: EFLAGS 無し trap frame（spec §6.3）が成立するのは、許可 guest 命令が flags を観測しないから。host の timer IRQ・#PF・#UD は x86mov32 trap frame に翻訳するか substrate バグ扱い。`popf`/`pushf`/`lahf`/`cmovcc`/string ops 等は **whitelist で排除されている**ことが前提。
5. **PV アクセスは高コスト exit**: #PF+decode は稀な制御（MMU 設定・console char・timer・`PGDIR`・`IRET`）には十分だが **高頻度 I/O には不可**。高頻度経路は実 MMIO ページを直接マップする等の最適化が要る。near-native なのは計算であって PV 境界ではない。
6. **分離**: bare-metal monitor 形態は、guest と substrate が同 ring だと guest が substrate のページテーブル/IDT/GDT/実行マップを壊せて崩壊する。実質 **micro-hypervisor**（qemu/KVM 境界の方がクリーン）。
7. **SMC**: native 実行が妥当なのは W^X + テキストパッチ無効化の config か、PV-TEXTPATCH の host 承認プロトコル経由のときだけ（spec §5/§7.8）。

> L0/L1 を movie86 で固めた後、上記 gate を満たす qemu machine type で L8 として実機経路を実証する。

## 4. PV scope（spec §2 との整合 — 0.1 の矛盾を解消）

spec は profile 定義（pv-kernel は PV-CPU/IRQ/MMU を *含む*）、本書はその **実装の段階**を定める。両者は別物：

- **実装が先行するのは pv-min（console+timer）まで**（L0–L1）。
- **pv-kernel（PV-CPU/IRQ/MMU・trap 配送）は spec で named + reserved 済み、実装は L2/L5/L6 で順次**。
- 「console+timer のみ」は *いま実装する PV* の話であって、profile 定義の縮小ではない（0.1-draft の文言ミスを訂正）。

## 5. リスクと未決事項

- **R1（最大）**: コンパイラ/カーネル意味論互換性。inline asm は氷山の一角（compiler barrier・`asm goto`・exception-table fixup・object layout…）。→ L0.5 kill-test で早期に殺す。
- **R2**: llvm-mov の inline asm 実装コスト不明。L3 を L0.5 の優先順で段階導入。
- **R3（host 間乖離）**: PV を movie86 だけが持つと「movie86 で動くが x86-host で落ちる」。→ (a) fault を x86-like に固定（spec §6.1）、(b) PV/プラットフォームを named profile + x86-host 実行層として明示（spec §2）、(c) conformance fixture を両 host で通す CI ゲート（spec §8）。
- **R4**: movie86 の機械化で userspace ランナーの単純さを失う。`Memory`/実行モデルの trait を壊さず、PV は opt-in feature・profile で段階導入。
- **R5（テキストパッチ）**: Linux の alternatives/static-keys/ftrace/kprobes/paravirt-patch は自己書き換え（spec §5 で base 不許可）。→ PV-TEXTPATCH（spec §7.8）か「対象 config で全テキスト改変無効化」のいずれか。L0.5 で現実性を判定。

## 6. 即時の design TODO

- [ ] TODO-1: PV-MMIO アドレスマップを movie86 既存マップ（`0x1FFE_0000`）と突き合わせ確定（spec §7.1）
- [ ] TODO-2: 割り込み配送モデル（poll 型 → 強制ジャンプ型）の境界確定（spec §7.6）
- [ ] TODO-3: ページテーブル形式（x86 PTE 流用可否）を L0.5 結果で判断（spec §7.7）
- [x] TODO-4: **決定 — 自作の極小カーネル**（L1, inline asm 非依存）
- [x] TODO-5: **決定 — 実装は最小 PV(console+timer)先行**、pv-kernel は spec 予約・段階実装（§4）
- [x] TODO-6: **決定 — 新アーキ `arch/x86mov32/` として移植**（arch/x86 流用せず, §1）
- [x] TODO-7: **決定 — ターゲット名 `x86mov32`**
- [x] TODO-8: **決定 — 主 template は arch/riscv(rv32)**。trap/CLINT/PLIC/SBI/DT を移植参考に（§1, spec §6.3/§7.4–§7.6/§7.10）
- [x] TODO-9: **決定 — ハードウェア記述は device tree**。boot で DTB を渡す（spec §7.10/§9）
- [ ] TODO-10: L0.5 kill-test の具体的チェックリストと判定基準を起こす（arch/riscv の inline asm/atomics/fixup の使い方も比較参照点に）（spec §10 → 0.3）
- [ ] TODO-11: PV-* の DT binding（compatible 文字列・reg・interrupts）を起こす（spec §7.10）
