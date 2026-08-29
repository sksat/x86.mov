# x86mov32 と x86 の本質的差分

> 特権命令を使わないと本当に実現できないことは何か。それが x86mov32 が機械側（PV-MMIO）で供給すべき差分であり、実 x86 substrate が実特権命令で埋める範囲。[`X86MOV32-SPEC.md`](./X86MOV32-SPEC.md) §1(b) の裏付け。

## 1. 原理：mov はチューリング完全 → 「計算」は差分ではない

mov はチューリング完全で、入出力を伴わない任意の変換は mov 列で書ける。差分が生じるのは3つの境界だけ：

1. **外界の観測**（デバイス状態・タイマ・入力）
2. **外界への作用**（コンソール・デバイス制御）
3. **外界との非同期**（プログラムと無関係な時刻に起きる事象）

(1)(2) のうちデバイスの制御レジスタ I/O は **MMIO への mov** で表現でき、x86 と機構を共有する → 特権命令は要らない。残る差分の候補は (3)、「機械がプログラムに対して行う保護・変換」、そして外部エージェントの latch / DMA に絞られる。

## 2. 分類

各 x86 機構を次で分類する：

- **E** — x86mov32 が概念ごと持たない（差分ですらない）
- **R-instr** — mov 計装で原理的に実現可能だが高コスト or 非協調コードを扱えない（数学的には特権不要）
- **R-mmio** — 共有 MMIO mov + ポーリングで実現（x86 と共有、特権不要）
- **A** — 命令列の外で非同期に状態を latch/変更する外部エージェント（タイマ latch・IRQ pending・DMA・host clock）。pollable MMIO として露出されない限り閉じた mov 計算に還元できない
- **M** — ポーリング/計装で代替できず、機械がプログラムに強制介入する必要がある（真の差分の核）

| x86 機構 | 分類 | 扱い |
|---|---|---|
| segmentation（`lgdt`/`mov sreg`/far jmp）| E | flat のみ。概念を持たない |
| ポート I/O（`in`/`out`）| E→R-mmio | デバイスを MMIO に。共有機構で代替 |
| 多くの MSR / `cpuid` | E | 設定対象の機能（APIC・syscall命令・seg）を使わない |
| `rdtsc` / タイマ読み | R-mmio | PV-TIMER `TICKS` の MMIO read |
| user→kernel 遷移（`syscall`/`int`）| M（保護あり）/ R（保護なしは call）| 保護を敷くなら特権遷移、初期段階は call |
| アドレス変換 / paging（`mov CR3`/`invlpg`/TLB）| R-instr / M(実用) | ソフトページウォークで原理可だが高コスト → PV-MMU に |
| 保護 / 特権分離（ring・page U/S・limit）| R-instr / M(実用) | SFI 計装で原理可だが非協調コードを隔離できない → PV-MMU 保護ビット + fault |
| `iret`（原子的復帰 + 特権遷移）| M | trap frame からの復帰自体は mov、原子性は機械機能 → PV `IRET` |
| 割り込み禁止/許可（`cli`/`sti`）| M(補助) | 介入窓制御 → PV `INTR_MASK` |
| **強制的な非同期制御転送**（latch 事象で命令列を奪う = preemption）| **M** | §3。協調コードは safepoint で近似可、未計装/低遅延は irreducible |
| 外部事象の latch（タイマ/IRQ pending を MMIO 可視に）| A | poll の前提となる外部記録 |
| DMA / bus master | A | 命令列外の非同期メモリエージェント。pv v0.2 は実 DMA 無しで回避 |
| atomic RMW（`lock`/`cmpxchg`）| R(UP) / M(SMP) | UP は「割り込みを閉じた非分割 mov 列」で原子性（特権不要）。SMP は非ゴール |
| 自己書き換え / テキストパッチ | R-instr / M(小) | x86 の icache は coherent。本質は改変の原子性/quiescence → PV-TEXTPATCH |
| `hlt`（idle）| R-mmio(busy poll) / M(任意) | busy-loop で代替可。真の idle だけ機械機能 |

## 3. 蒸留：irreducible なのは「native/非協調/低遅延な実行への強制介入」

完全に計装された協調コードなら、MMU・保護・preemption・イベント配送はすべて mov 計装 + MMIO ポーリングで原理的にモデル化できる（safepoint を全 back-edge に挿せば preemption を有界遅延で近似できる）。

ゆえに真に irreducible な機械サービスは、**native ないし非協調なコードへの、計装密度に依存しない低遅延な強制介入** — (i) preemption、(ii) 未計装コードへの保護強制、(iii) 精密な restartable trap、(iv) 外部エージェントの latch（A）。

MMU・保護は原理的に reducible（ソフトページング/SFI）だが、コストと非協調コード隔離のため設計選択として機械機能（PV-MMU）にする — *必要*だからではなく*実用的だから*、と正直に位置づける。

## 4. worked example：「特権パスが mov 列」とは

特権操作は RISC-V/x86 では専用オペコード（`csrw stvec` / `mov CR3` / `iret`）で、C でも普通の load/store でも書けない。x86mov32 はこれを MMIO レジスタへの store に定義し直す。

```
; RISC-V (専用命令, 手書き .S)     ; x86mov32 (全て mov)
csrw  stvec, trap_handler          mov [PV_CPU + IDT_BASE],  trap_handler
csrw  satp,  (MODE|pgdir>>12)      mov [PV_MMU + PGDIR],     pgdir_phys
csrsi sstatus, SIE                 mov [PV_CPU + INTR_MASK], 0
sret                               mov [PV_CPU + IRET],      0
```

`csrw stvec, h`（専用命令）が `mov [magic], h`（ただのストア）になり、機械がそれを傍受して効果を実行する。movie86 はマジックアドレス機構で内部状態を操作（guest は 100% mov）；実 x86 substrate は PV ページを not-present にして mov→#PF→本物の `lidt`/`mov CR3` を実行（特権命令は substrate に隔離）。文脈切替のレジスタ退避/復帰は元から mov+push/pop。

**境界**: カーネルが能動的に*やる*ことは全て mov（特権効果の要求すら PV store）。mov でないのは命令ですらない2つの機械機能 — trap の*配送*（M）と `IRET` の*原子的*復帰。**カーネルの命令ストリームは 100% mov、非-mov な部分は「機械そのもの」**。

## 5. PV surface への帰結

| 真の性質 | PV | 理由 |
|---|---|---|
| 強制的な非同期制御転送（M, 核）| PV-IRQ + 強制ジャンプ + `INTR_MASK` + `IRET` | native/未計装/低遅延では poll 代替不能 |
| 外部事象の latch（A）| PV-TIMER/PV-IRQ の pending | poll の前提 |
| アドレス変換（実用 M, 原理 R）| PV-MMU `PGDIR`/`FLUSH`/`FAULT_ADDR` | HW paging 前提 + コスト |
| 保護/特権分離（実用 M, 原理 R）| PV-MMU 保護ビット + fault + `IDT_BASE` | 非協調コード隔離 |
| 外界 device I/O（R-mmio, x86 と共有）| PV-CONSOLE / PV-TIMER | 特権不要。DMA は別（A, v0.2 外）|
| テキストパッチの原子性（小 M）| PV-TEXTPATCH or config-off | 部分パッチ実行回避 |

spec §7 の PV-* はこの差分を覆う（pv-min は確定、pv-kernel 面は draft）。**外界 device I/O は特権差分ではなく x86 と共有**である点が重要。

**閉包（substrate との関係）**: カーネルの PV M-set（`lidt`/`mov CRn`/`sti`/`iret`/`invlpg` 相当）は、substrate を mov 化したときの非-mov 核の**部分集合**。substrate の非-mov 集合はその**上位集合**で、host 固有義務（real-mode boot・`mov from CR2`・実 IRQ コントローラ+EOI・whitelist 強制）が加わる。movie86 はこの全体を Rust で、実 x86 substrate は実特権命令の最小スタブ群で実装する。x86mov32 がカーネルから追い出した特権は、ここで最小化されて再出現する — ゼロにはできないが、周辺は全て mov 化できる。
