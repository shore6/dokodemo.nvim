# dokodemo.nvim

日本語に対応した [flash.nvim](https://github.com/folke/flash.nvim) / [hop.nvim](https://github.com/smoka7/hop.nvim) 風のジャンププラグインです。

ローマ字で入力すると、英字だけでなく **ひらがな・カタカナ・漢字（音読み・訓読み）** にもマッチします。

```
s → t       test / テスト / 天ぷら / 手紙 / 東京 ... にマッチ
s → te      test / テスト / 天ぷら / 手紙
s → tenp    天ぷ（ら）
s → tabe    食べ（る）
s → gakko   学校
s → nihongo 日本語
```

## 特徴

- ローマ字でかな・漢字にマッチ（IME の切り替え不要）
  - ヘボン式・訓令式どちらも可（`shi`/`si`, `chi`/`ti`, `tsu`/`tu`, `fu`/`hu`, `ja`/`zya` ...）
  - 拗音（`kya`, `cho`）、促音（`tto` → っと, `xtu`）、撥音（`n`/`nn`）、長音（`-` → ー）
  - 漢字は Unicode Unihan の読み（JIS 第1・第2水準 約6,300字）を使用
  - 送り仮名付きの訓読み（`tabe` → 食べ）、促音化（`gakko` → 学校）、連濁（`hitobito` → 人々）、踊り字 `々`
- 全角英数字（`ｔｅｓｔ`）は半角として扱う
- 英字は `ignorecase` / `smartcase`
- 続けて入力しうる文字はラベルに使わないので、パターン入力とラベル選択が衝突しない
- normal / visual / operator-pending モード対応（`d` + `s` + `te` + ラベル など）

## 必要環境

- Neovim 0.10 以上

## インストール

[lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "shore6/dokodemo.nvim",
  opts = {},
  keys = {
    { "s", mode = { "n", "x", "o" }, function() require("dokodemo").jump() end, desc = "Dokodemo jump" },
  },
}
```

その他のプラグインマネージャの場合:

```lua
require("dokodemo").setup()
vim.keymap.set({ "n", "x", "o" }, "s", function() require("dokodemo").jump() end)
```

## 使い方

1. `s` を押す (`gs` 等に設定すると flash.nvim と両立できます)
2. ローマ字（または英字）を入力する。入力するたびに候補が絞り込まれ、ラベルが表示される
3. ラベルの文字を押すとジャンプ

| キー | 動作 |
| --- | --- |
| ラベル文字 | そのマッチへジャンプ |
| `<CR>` | 最も近いマッチ（強調表示されているもの）へジャンプ |
| `<BS>` | 1文字削除 |
| `<Esc>` / `<C-c>` | キャンセル |

コマンド `:Dokodemo [pattern]` からも起動できます。

## 設定

デフォルト値:

```lua
require("dokodemo").setup({
  -- ラベルに使う文字（優先順）
  labels = "asdfghjklqwertyuiopzxcvbnm",
  -- 英字の大文字小文字の扱い（ローマ字→かな/漢字のマッチは常に大文字小文字を区別しない）
  ignorecase = true,
  smartcase = true,
  -- ジャンプ中に画面を暗くする
  backdrop = true,
  -- ラベルの位置: "after"（マッチの直後, flash.nvim と同じ）または "start"（マッチの先頭）
  label_position = "after",
  -- 候補が1つになったら自動でジャンプ
  autojump = false,
  -- 漢字の読みを追加する（"音読み|訓読み" をひらがなで）
  readings = {
    -- ["蕎"] = "|そ",
  },
})
```

### ハイライト

| グループ | デフォルトのリンク先 |
| --- | --- |
| `DokodemoBackdrop` | `Comment` |
| `DokodemoMatch` | `Search` |
| `DokodemoCurrent` | `IncSearch` |
| `DokodemoLabel` | `Substitute` |
| `DokodemoPrompt` | `Question` |

## 制限

- 漢字は1文字ずつの読みで判定するため、熟字訓（`今日` = きょう、`大人` = おとな など）にはマッチしません。
  必要なら `readings` で個別に読みを追加してください。
- 対象は現在のウィンドウの表示範囲のみです。

## 開発

```sh
make test           # nvim が PATH にある場合
make test NVIM=/path/to/nvim
```

漢字の読みデータ `lua/dokodemo/kanji.lua` は `scripts/gen_kanji.py` で生成しています。
元データは Unicode Unihan データベースの `kJapanese` プロパティ（[Unicode License v3](https://www.unicode.org/license.txt)）で、
SQLite 化されたもの（npm パッケージ [kanji-inspector](https://www.npmjs.com/package/kanji-inspector) の `dist/db/Readings.db`）から変換しています。

## ライセンス

[MIT](LICENSE)。ただし `lua/dokodemo/kanji.lua`（Unihan 由来の漢字読みデータ）は Unicode License v3 に従います（全文は [LICENSE](LICENSE) に記載）。
[flash.nvim](https://github.com/folke/flash.nvim) 等のソースは使用していません。
