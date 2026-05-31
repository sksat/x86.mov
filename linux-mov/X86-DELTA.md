# x86mov32 と x86 の本質的差分 — 特権命令の要否分析

> 状態: 分析ドラフト。[`X86MOV32-SPEC.md`](./X86MOV32-SPEC.md) §1(b) を裏付ける。PV surface（どの特権操作を MMIO mov に写像すべきか）の必要十分性を、原理から詰める。

## 0. 問い

「特権命令を使わないと**本質的に** x86 で実現できないことは何か」。それが x86mov32 が機械側（PV）で供給すべき差分であり、x86-host 実行層が実特権命令で shim すべき範囲。

## 1. 原理：mov はチューリング完全 → 「計算」は差分ではない

mov はチューリング完全。**閉じた計算（入出力を伴わない任意の変換）は全て mov 列で書ける**。ゆえに差分は「計算能力」ではない。差分が生じうるのは次の3つの境界だけ：

1. **外界の観測**（デバイス状態・タイマ・入力を読む）
2. **外界への作用**（コンソール出力・デバイス制御）
3. **外界との非同期**（プログラムの都合と無関係な時刻に起きる事象）

(1)(2) のうち **デバイスの制御レジスタ I/O は MMIO への mov**で表現でき、x86 と機構を共有する（spec §1b）→ 特権命令は要らない。

ただし2つ留保がある（round-3 指摘）：

- **外部事象は「pollable な状態に latch されている」場合に限り poll で観測できる**。タイマ tick・IRQ edge・パケット到着などを mov で読めるのは、デバイス/割り込みコントローラがそれを MMIO 可視の状態に**ラッチする外部エージェントがいるから**。この latch 自体はプログラム外の機械機能であり、特権命令の差分ではないが**指定すべきプラットフォーム意味論**（§2 の A クラス）。
- **DMA / bus master は「I/O = MMIO mov」では覆えない**。DMA デバイスは命令列の外で非同期にメモリを読み書きする**非同期メモリエージェント**。pv-min/pv-kernel v0.2 は実 DMA デバイスを持たない（PV-CONSOLE/TIMER は DMA しない）ので回避できるが、将来のデバイスは「MMIO 制御プレーン + 非同期メモリエージェント + コヒーレンシ規約」が要る。

よって本質的差分の候補は (3)・「機械がプログラムに対して行う保護・変換」・「外部エージェントの latch/DMA」に絞られる。

## 2. 分類軸

各 x86 特権/システム機構を次で分類する：

- **E (eliminated)**: x86mov32 は概念ごと持たない。差分ですらない。
- **R-instr (reducible by instrumentation)**: mov 計装で原理的に実現可能だが高コスト or 非協調コードを扱えない。**数学的には特権不要**。実用上 PV で提供する設計選択。
- **R-mmio (reducible to shared MMIO + poll)**: 共有 MMIO mov + ポーリングで実現。x86 と機構共有、特権命令不要。
- **A (external-agent)**: 命令列の外で非同期に状態を latch/変更する外部エージェント（タイマ latch・IRQ pending latch・DMA writer・host wall clock）。特権命令ではなく、強制制御転送でもないが、**pollable MMIO 状態として露出されない限り閉じた mov 計算に還元できない**プラットフォーム機能（round-3 で追加）。
- **M (genuinely machine-driven)**: ポーリングや計装で代替**できない**。機械がプログラムに*強制的に*介入する必要がある。← **真の差分の核**。

## 3. 命令・機構ごとの分類

| x86 機構 | 分類 | 根拠 / x86mov32 での扱い |
|---|---|---|
| segmentation（`lgdt`,`mov sreg`, far jmp の seg 切替） | **E** | x86mov32 は flat のみ。概念を持たない。 |
| ポート I/O（`in`/`out`） | **E→R-mmio** | デバイスを MMIO に置く。共有 MMIO で代替。特権不要。 |
| 多くの MSR（`wrmsr` APIC base / syscall MSR 等）, `cpuid` | **E** | 設定対象の機能（APIC, `syscall`命令, セグメント）を使わないので不要。 |
| `rdtsc` / タイマ読み | **R-mmio** | PV-TIMER `TICKS` の MMIO read。x86 と共有可。 |
| `syscall`/`sysenter`/`int` による user→kernel 遷移 | **M（保護ありの場合）/ R（保護なしなら単なる call）** | 保護を敷くなら特権遷移が必要（§5 参照）。保護を敷かない初期段階では `call` で足りる。 |
| アドレス変換 / paging（`mov CR3`,`CR0.PG`,`invlpg`, TLB） | **R-instr（原理）/ M（実用）** | 全 load/store をソフトページウォーク（mov）に計装すれば**原理的には特権不要**。だが (a) 莫大なコスト、(b) Linux は HW paging 前提。よって設計選択として PV-MMU（機械側変換）にする。 |
| 保護 / 特権分離（ring, page U/S, SMEP/SMAP, limit 違反 #GP） | **R-instr（原理）/ M（実用）** | SFI 的に全アクセスを境界チェック計装すれば**原理的には可能**。だが非協調（未計装）コードを隔離できず、コストも高い。実用上は PV-MMU の保護ビット + fault（機械が**禁止**する）。 |
| `iret`（EIP/SP の原子的復帰 + 特権遷移） | **M（保護/割り込みありなら）** | trap frame からの復帰自体は mov で書けるが、特権遷移と「割り込み窓を閉じたままの原子的再開」は機械機能。PV `IRET`。 |
| 割り込み禁止/許可（`cli`/`sti`, IF） | **M（の補助）** | 後述 §4 の async 制御の窓制御。PV `INTR_MASK`。 |
| 外部事象の latch（タイマ tick・IRQ pending を MMIO 可視状態に記録） | **A** | poll で読めるのは外部エージェントが latch するから。プラットフォーム意味論として指定要（§2 A）。 |
| **強制的な非同期制御転送**（latch された事象で命令列を*強制的に*奪う = preemption） | **M** | ← §4。協調コードは safepoint で近似可、未計装/低遅延は irreducible。 |
| DMA / bus master | **A** | 命令列外の非同期メモリエージェント。「I/O=MMIO mov」では覆えない。pv v0.2 は実 DMA 無しで回避、将来はコヒーレンシ規約要。 |
| atomic RMW（`lock`,`cmpxchg`） | **R（UP）/ M（SMP）** | UP では「割り込みを閉じた非分割 mov 列」で原子性が出る（INTR_MASK 依存）。**特権不要**。SMP のバスロックは M だが SMP は非ゴール。 |
| 自己書き換え/テキストパッチ | **R-instr / M(小)** | x86 の icache は coherent なので「icache 同期」は本質でない。本質は**改変の原子性・quiescence**（部分パッチ実行を避ける、serialize / stop-machine）。PV-TEXTPATCH = host 承認のパッチプロトコル。 |
| `hlt`（割り込みまで idle） | **R-mmio（busy poll）/ M(任意)** | busy-loop で代替可。真の idle/省電力だけ機械機能。任意。 |
| cache 制御（`wbinvd`,MTRR,PAT,`clflush`） | **E/host** | リファレンス機械（movie86）はキャッシュ無しで no-op。x86-host が MMIO を UC 化する shim 内事項。 |
| メモリ順序/fence | **E(UP) / 後日** | UP/no-SMP では大半が消える。MMIO は UC・program order（spec §5）。DMA/SMP 導入時に本格的なメモリモデルが要る。 |
| TLB shootdown（クロス CPU） | **M(SMP)** | UP は local `FLUSH` で足りる（PV-MMU）。SMP の shootdown は非同期クロス CPU 機構（非ゴール）。 |

## 4. 蒸留：irreducible なのは「native/非協調/低遅延な実行への強制介入」

round-3 補正。「非同期制御転送が *唯一の数学的* M」は**言い過ぎ**だった。正しくは：

> **完全に計装された協調コード**なら、MMU・保護・preemption・イベント配送はすべて mov 計装 + MMIO ポーリングで*原理的に*モデル化できる（safepoint を全 back-edge/呼び出し境界に挿せば timer preemption を有界遅延で近似でき、basic block を細分すればさらに詰まる）。
> ゆえに真に irreducible な機械サービスは、**native ないし非協調なコードへの、計装密度に依存しない低遅延な強制介入**である：(i) preemption、(ii) *未計装*コードに対する保護強制、(iii) 精密な restartable trap。これに (iv) 外部エージェントの latch（§2 A クラス）が加わる。

- **協調コードに対する preemption は safepoint で近似可能**（有界遅延）。irreducible なのは「自分で yield を選べない/未計装のコードを止める」「計装密度と独立な低遅延・リアルタイム保証を出す」場合のみ。
- 付随して `INTR_MASK`（介入窓）と `IRET`（原子的再開）が要る。

MMU・保護は **原理的に reducible**（ソフトページング/SFI 計装）だが、(a) 莫大なコスト、(b) *未計装/非協調*コードを隔離できない、ため **設計選択**として機械機能（PV-MMU）にする — *必要*だからではなく*実用的かつ非協調コードを扱うため*、と正直に位置づける。

## 4.5 worked example：「特権パスが mov 列」とは

特権操作は RISC-V/x86 では**専用オペコード**（`csrw stvec`/`csrw satp`/`sret`、`lidt`/`mov CR3`/`iret`）で、C でも普通の load/store でも書けない。x86mov32 はこれを **MMIO レジスタへの store に定義し直す**（§1b）。entry/boot を並べると：

```
; RISC-V (専用命令, 手書き .S)        ; x86mov32 (全て mov)
csrw  stvec, trap_handler             mov [PV_CPU + IDT_BASE],  trap_handler
csrw  satp,  (MODE|pgdir>>12)         mov [PV_MMU + PGDIR],     pgdir_phys
csrsi sstatus, SIE                    mov [PV_CPU + INTR_MASK], 0
sret                                  mov [PV_CPU + IRET],      0
```

`csrw stvec, h`（専用命令）が `mov [magic], h`（ただのストア）になる。**機械**がそのアドレスへの mov を傍受して効果を実行する：

- movie86: magic-address 機構（既存 `0x1FFE_0000`→AbiHost）の拡張で内部状態を操作 → guest は文字通り 100% mov。
- 実 x86 host: PV ページを not-present にし、mov→#PF→substrate(非-mov ring0)が faulting mov をデコードして本物の `lidt`/`mov CR3` を実行。**特権命令は substrate に隔離、カーネルは純 mov**。

文脈切替のレジスタ退避/復帰は元から mov+push/pop（特権ですらない）；特権なのはアドレス空間切替=PV-MMU `PGDIR` への mov だけ。

**境界**: カーネルが能動的に*やる*ことは全て mov（特権効果の要求すら PV store）。mov でないのは命令ですらない2つの機械機能 — (1) trap の*配送*（§4 の M, 機械が命令列を奪い frame を積む）、(2) `IRET` の*原子的*復帰（カーネルは mov で要求、復元は機械）。**カーネルの命令ストリームは 100% mov、非-mov な部分は「機械そのもの」**。

## 5. PV surface への帰結（必要十分）

| 真の性質 | PV | 理由 |
|---|---|---|
| 強制的な非同期制御転送（M, 核） | PV-IRQ + 強制ジャンプ配送 + `INTR_MASK` + `IRET` | native/未計装/低遅延では poll 代替不能 |
| 外部事象の latch（A） | PV-TIMER/PV-IRQ の pending 状態 | poll の前提となる外部記録 |
| アドレス変換（実用的 M, 原理 R-instr） | PV-MMU `PGDIR`/`FLUSH`/`FAULT_ADDR` | HW paging 前提 + コスト |
| 保護/特権分離（実用的 M, 原理 R-instr） | PV-MMU 保護ビット + fault + `IDT_BASE` | 非協調コード隔離 + コスト |
| 外界 device I/O（R-mmio, **x86 と共有**） | PV-CONSOLE / PV-TIMER（+任意デバイス） | 特権不要、shim ほぼ無し。ただし DMA は別（A, v0.2 外） |
| テキストパッチの原子性/quiescence（小 M） | PV-TEXTPATCH or config-off | 部分パッチ実行回避 |

→ spec §7 の PV-* は過不足ない。**特に「外界 device I/O は特権差分ではなく共有」**である点が重要（x86-host shim が要るのは MMU/protection/preempt/textpatch の機械機能 + 外部 latch だけ）。DMA を持つ実デバイスは v0.2 のスコープ外（A クラスのメモリモデルが要る）。

**閉包（round-4 補正: 等号でなく包含）**: カーネルの PV M-set（`lgdt`/`lidt`/`mov CRn`/`sti`/`cli`/`iret`/`invlpg` 相当）は、x86-host substrate を mov 化したときに残る非-mov 核の **部分集合**。substrate の非-mov 集合は **真の上位集合**であり、host 固有の義務が加わる：

- **PV M-set**（カーネルが PV-MMIO で要求する特権効果を実命令で実装）
- **+ substrate-only**: real-mode→protected-mode boot（A20/`lgdt`/`mov CR0`/far jump）、#PF cause 読み（`mov from CR2` — カーネルは PV `FAULT_ADDR` を読むが substrate は CR2）、実 IRQ コントローラ操作（PIC=port I/O / APIC=MMIO+MSR）と EOI、whitelist/実行権限の強制フック。

つまり **カーネル PV M-set ⊂ substrate irreducible set**。movie86 ではこの全体を Rust で実装、実 x86 substrate では実特権命令の最小スタブ群として実装する。x86mov32 がカーネルから追い出した特権はここで最小化されて再出現する — ゼロにはできないが、周辺は全て mov 化できる。

## 6. L0.5 で実 Linux / arch/riscv と突き合わせる検証

本分析は原理側。実装側の致命要因は別途 kill-test で確認する：

- Linux UP で atomics を本当に「割り込みマスク + 非分割列」に落とせるか（`atomic_t`,`cmpxchg`, `local_irq_save` の使われ方）。
- preemption を safepoint 近似に落とせるか、それとも真の timer 割り込み（強制ジャンプ M）が必須か（`CONFIG_PREEMPT*`, cond_resched, スケジューラ）。
- demand paging / `copy_*_user` fixup が PV-MMU + fault 配送で閉じるか。
- テキストパッチ経路（alternatives/static-keys/ftrace/kprobes/paravirt）を対象 config で無効化できるか、PV-TEXTPATCH が要るか。
- arch/riscv が上記をどう解いているか（SBI/CLINT/PLIC/sfence）を直接の移植参照点にする。
