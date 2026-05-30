# 設計相談ブリーフ: SIMD86 デックの turbo86 ブースト(大デックのハンドオーバー)

## 背景(前提知識のない読者向け)

`x86.mov` は「x86 の `mov` 命令だけでチューリング完全」を遊ぶプロジェクト群。
関係するサブプロジェクト:

- **movie86** — ブラウザ(wasm)で動く mov-only ELF32 エミュレータ。`FlatMemory`
  に guest を載せてステップ実行する。遅い。
- **turbo86** — Linux 上で mov-only ELF を **ネイティブ実行**するランナー
  (ptrace + i386 スタブ)。速い。
- **SIMD86** — スライドシステム。スライド画像を生 RGBA で焼き込んだ mov-only
  ELF(`deck.elf`)を movie86 上で実行し、キー入力でフレームバッファに blit
  してページ送りする。「全ピクセルが mov で計算される」スライド。

### ブースト(アクセラレーションブースト)とは

movie86(wasm)はフルスクリーン blit が遅い(1280×720 で 1 ページ数百万 mov、
体感 数秒〜数十秒)。そこでブラウザのボタンで **movie86 → ローカル turbo86 に
ハンドオーバー**し、以降ネイティブ速度で動かす。movie86 デモで実装・実機検証
済みの仕組みを SIMD86 に流用している。

ハンドオーバーの実体:

1. ブラウザが movie86 Vm の **スナップショット**(`Context` = レジスタ +
   メモリ領域群 + reservation)を取る。
2. それを WebSocket で turbo86 に `LoadContext` として送る(JSON、メモリ領域は
   base64)。
3. turbo86 がレジスタとメモリを復元し、同じ EIP から **ネイティブ実行**を継続。
   以降は framebuffer 差分(`MemUpdate`)を逆向きに stream して canvas に反映、
   キー入力は `KeyInput` で前方に送る。

この方式は「**guest のメモリ状態を丸ごと送って同じ続きを別エンジンで走らせる**」
= エンジン間マイグレーション。movie86 デモ(数百 KB〜数 MiB の小さい canvas
デモ)では問題なく動く。

## 問題

SIMD86 の実デック(45 ページ × 1280×720 × 4byte RGBA)は、スライド画像を
`deck.elf` の `.rodata`(`slides_data[]`)に**生 RGBA で焼き込む**ため、

- `deck.elf` は約 **167 MB**(zstd 圧縮で配信は 3.4 MB、ブラウザ側で展開)。
- movie86 の guest メモリ上で `.rodata` が **約 160 MiB** を占める。
- ブースト時のスナップショットは guest メモリをほぼ丸ごと拾うので、
  `LoadContext` の region 合計が **160 MiB**、base64 JSON で **約 213 MiB**。

これが3段の上限に当たる(下2つは解決済み、最後が未解決):

1. ✅ **ブラウザの base64 化**: 一括 `btoa` が ~213 MiB 文字列でオーバーフロー。
   → 3 バイト境界チャンクで `btoa` する修正済み + 回帰テスト。
2. ✅ **turbo86 の WS 受信上限**: 旧 16 MiB(`SetReadLimit`)を超える。
   → 512 MiB に引き上げ済み + TDD。
3. ❌ **turbo86 スタブの静的アドレス空間**(本相談の主題)。
   turbo86 のスタブは guest コード/データ用に **0x08048000 から 16 MiB だけ**を
   RWX で mmap している(`turbo86/stub/_stub.s`、`runner.guestRegions =
   {0x08048000, 0x01000000}`)。デックの `.rodata` 160 MiB はこの 16 MiB に
   収まらず、0x09048000 を越える。snapshot のその領域を書き戻す段で破綻する。
   - 補足: turbo86 はスタブ静的領域の **外** にある領域は mov-only ABI の
     `mmap_request` 経由で動的 mmap する仕組みがある(フレームバッファ用)。
     ただし `.rodata` はコード/データ領域の延長(連続した PT_LOAD)なので、
     現状その動的 mmap 経路には乗っていない。runner には
     `mmapMaxRegions = 32` の上限もある。

## 制約・前提

- turbo86 は **ローカル開発ツール**。ユーザが自分のマシンで起動し、自分の
  ブラウザ(`x86.mov` / PR プレビュー / localhost)からつなぐ。WS は Origin
  ロック。外部公開サービスではない(= 大きなメモリ確保のリスクは自分の RAM に
  閉じる)。
- スタブは i386 アセンブリ(`stub/_stub.s`)を `as --32`/`ld -m elf_i386` で
  ビルドし、`//go:embed` でバイナリを Go に埋め込む。スタブ変更は再ビルド +
  コミットが要る。
- デックの `.rodata` は **読み取り専用で不変**(スライド画像。実行中に書き換え
  ない)。可変なのは framebuffer 領域とレジスタ/スタックのみ。
- `deck.elf`(の zstd, 3.4 MB)はブラウザがすでに持っている(movie86 に渡す
  ために fetch 済み)。turbo86 にも渡せる。
- TDD 必須(リポジトリ規約)。turbo86 は `runner/*_test.go`(ptrace 実行)+
  `server/*_test.go`(WS E2E)でテストする文化。
- 目的は「発表で 1280×720 デックをブースト実演」。ただしユーザは「まず組んで
  みてダメなら解像度を落とす」とも言っている(= 必ずしも 1280×720 死守では
  ない)。

## 選択肢

### A. スタブの静的領域を拡張(対症療法・最短)

`stub/_stub.s` の RWX コード/データ領域を 16 MiB → 256 MiB 程度に拡張し、
`runner.guestRegions` も合わせる。snapshot の 160 MiB `.rodata` がそのまま
収まる。`mmapMaxRegions` も要調整。

- 長所: 変更が局所的。ハンドオーバーの設計は不変。実装が読みやすい。
- 短所: 「160 MiB を毎回ワイヤで運ぶ」根本は残る(213 MiB JSON の送受信・
  base64・パースのコスト)。スタブが常に大領域を予約する(全 guest に対して)。
  解像度を上げるとまた壁が動く。

### B. turbo86 が deck.elf を直接ロードする(構造的・大)

ハンドオーバーで「160 MiB の生メモリ」を送る代わりに、**deck.elf(zstd 3.4 MB)
そのものを turbo86 に渡し、turbo86 が ELF をロードして entry から実行**する。
スナップショットはレジスタ + 可変領域(現在のスライド index 等のわずかな状態)
だけになる。

- 長所: ワイヤ転送が 213 MiB → 数 MB。`.rodata` を二重に運ばない。turbo86 が
  ELF ローダを持てば汎用的に「重い mov-only ELF をネイティブ実行」できる。
- 短所: turbo86 に ELF ローダ新設(PT_LOAD マッピング、エントリ設定)。
  ハンドオーバーのプロトコル変更(`LoadElf` 的な Inbound 追加)。movie86 で
  途中まで進めた状態の継続(EIP/スタック)をどう持ち込むか設計が要る
  (デックは「起動直後にスライド0表示で入力待ち」なので、実は最初から
  turbo86 で起動しても体感は同じかもしれない=継続状態がほぼ不要)。

### C. 解像度を下げて 16 MiB 内に収める(回避)

`deck.toml`/`pdf_to_deck.py` の解像度を落とし(例 全 320×200、45枚で
`.rodata` ≈ 11.5 MiB)、現状のスタブに収める。turbo86 無改修。

- 長所: ゼロ改修でブースト成立。movie86 プレビューは object-fit で拡大表示
  されるので「見た目」は維持。
- 短所: ネイティブで動かす意味(高解像度)が薄れる。ブースト後も低解像度。

### D. 不変な read-only 領域を snapshot から除外(B の軽量版)

snapshot 時に `.rodata`(読み取り専用 PT_LOAD)を「ELF 由来で復元可能」と
マークして送らず、turbo86 側が deck.elf からその領域を埋める。可変領域だけ
ワイヤに乗る。

- 長所: B のワイヤ削減効果を、ELF ローダ新設より小さい改修で得られる可能性。
- 短所: 「どの領域が ELF 由来で不変か」をブラウザ/turbo86 で一致させる必要。
  結局 turbo86 が deck.elf を読む必要があり、B と大差ない複雑さに寄る恐れ。

## 相談したいこと

1. **A（箱を大きく)で当面進めるべきか、B（deck.elf 直ロード）に倒すべきか。**
   発表が近い(短期)前提と、turbo86 を汎用に保ちたい(長期)前提のバランス。
2. B/D を採る場合、「movie86 で途中まで進めた状態の継続」は本当に必要か?
   デックは起動直後 = スライド0 + 入力待ちなので、turbo86 で最初から起動して
   も等価では?(= 継続状態の移送を諦めれば B が一気に簡単になる)
3. A を採る場合の妥当な領域サイズと、`mmapMaxRegions` 等の他の上限の洗い出し。
4. そもそも「全ピクセルを mov で blit」を維持したまま 1280×720 を実用にする、
   別のアイデア(例: スライドデータを圧縮して guest 内で展開、FB ソース切替
   ABI で blit 自体を無くす、等)。

## 参考: 関連ファイル

- `turbo86/stub/_stub.s`(16 MiB 領域の mmap)
- `turbo86/runner/runner.go`(`guestRegions`, `mmapRegionForLoadContext`,
  `mmapMaxRegions`)
- `turbo86/server/server.go`(`MaxReadBytes = 512<<20`, `readInbound`)
- `turbo86/proto/proto.go`(`LoadContext` / `Context` / `Reservation`)
- `simd/deck.c`(`slides_data[]` を FB に blit)
- `simd/gen_deck.py`(画像 → 生 RGBA メモリイメージ)
- `movie86/wasm/movie86.mjs`(`snapshotContext` / `makeLoadContextMessage`)
- `simd/simd.mjs`(`boost()` = ハンドオーバー)
