-- Kana <-> romaji tables.
--
-- Every kana "unit" (a single kana, or a kana followed by a small kana such
-- as きゃ) maps to the list of romaji spellings that may be typed for it.
-- Katakana is folded to hiragana before lookup.
local M = {}

-- stylua: ignore
local single = {
  ["あ"] = { "a" }, ["い"] = { "i", "yi" }, ["う"] = { "u", "wu", "whu" }, ["え"] = { "e" }, ["お"] = { "o" },
  ["か"] = { "ka", "ca" }, ["き"] = { "ki" }, ["く"] = { "ku", "cu", "qu" }, ["け"] = { "ke" }, ["こ"] = { "ko", "co" },
  ["が"] = { "ga" }, ["ぎ"] = { "gi" }, ["ぐ"] = { "gu" }, ["げ"] = { "ge" }, ["ご"] = { "go" },
  ["さ"] = { "sa" }, ["し"] = { "shi", "si", "ci" }, ["す"] = { "su" }, ["せ"] = { "se", "ce" }, ["そ"] = { "so" },
  ["ざ"] = { "za" }, ["じ"] = { "ji", "zi" }, ["ず"] = { "zu" }, ["ぜ"] = { "ze" }, ["ぞ"] = { "zo" },
  ["た"] = { "ta" }, ["ち"] = { "chi", "ti" }, ["つ"] = { "tsu", "tu" }, ["て"] = { "te" }, ["と"] = { "to" },
  ["だ"] = { "da" }, ["ぢ"] = { "di", "ji" }, ["づ"] = { "du", "zu" }, ["で"] = { "de" }, ["ど"] = { "do" },
  ["な"] = { "na" }, ["に"] = { "ni" }, ["ぬ"] = { "nu" }, ["ね"] = { "ne" }, ["の"] = { "no" },
  ["は"] = { "ha", "wa" }, ["ひ"] = { "hi" }, ["ふ"] = { "fu", "hu" }, ["へ"] = { "he", "e" }, ["ほ"] = { "ho" },
  ["ば"] = { "ba" }, ["び"] = { "bi" }, ["ぶ"] = { "bu" }, ["べ"] = { "be" }, ["ぼ"] = { "bo" },
  ["ぱ"] = { "pa" }, ["ぴ"] = { "pi" }, ["ぷ"] = { "pu" }, ["ぺ"] = { "pe" }, ["ぽ"] = { "po" },
  ["ま"] = { "ma" }, ["み"] = { "mi" }, ["む"] = { "mu" }, ["め"] = { "me" }, ["も"] = { "mo" },
  ["や"] = { "ya" }, ["ゆ"] = { "yu" }, ["よ"] = { "yo" },
  ["ら"] = { "ra", "la" }, ["り"] = { "ri", "li" }, ["る"] = { "ru", "lu" }, ["れ"] = { "re", "le" }, ["ろ"] = { "ro", "lo" },
  ["わ"] = { "wa" }, ["ゐ"] = { "wi" }, ["ゑ"] = { "we" }, ["を"] = { "wo", "o" },
  ["ん"] = { "nn", "n", "xn", "n'" },
  ["ゔ"] = { "vu" },
  ["ぁ"] = { "xa", "la" }, ["ぃ"] = { "xi", "li" }, ["ぅ"] = { "xu", "lu" }, ["ぇ"] = { "xe", "le" }, ["ぉ"] = { "xo", "lo" },
  ["ゃ"] = { "xya", "lya" }, ["ゅ"] = { "xyu", "lyu" }, ["ょ"] = { "xyo", "lyo" }, ["ゎ"] = { "xwa", "lwa" },
  ["ゕ"] = { "xka", "lka" }, ["ゖ"] = { "xke", "lke" },
  ["っ"] = { "xtu", "ltu", "xtsu", "ltsu" },
  ["ー"] = { "-" }, ["〜"] = { "~" }, ["～"] = { "~" },
  ["、"] = { "," }, ["。"] = { "." }, ["・"] = { "/" }, ["「"] = { "[" }, ["」"] = { "]" },
}

-- Consonant prefixes for the y-row digraphs (きゃ/きゅ/きょ, ...).
-- stylua: ignore
local yoon = {
  ["き"] = { "ky" }, ["ぎ"] = { "gy" }, ["に"] = { "ny" }, ["ひ"] = { "hy" }, ["び"] = { "by" },
  ["ぴ"] = { "py" }, ["み"] = { "my" }, ["り"] = { "ry", "ly" },
  ["し"] = { "sh", "sy" }, ["じ"] = { "j", "zy", "jy" }, ["ち"] = { "ch", "ty", "cy" },
  ["ぢ"] = { "dy" },
}

-- Other digraphs that are commonly found in loanwords.
-- stylua: ignore
local extra = {
  ["しぇ"] = { "she", "sye" }, ["じぇ"] = { "je", "zye", "jye" }, ["ちぇ"] = { "che", "tye", "cye" },
  ["てぃ"] = { "thi" }, ["でぃ"] = { "dhi" }, ["てゅ"] = { "thu" }, ["でゅ"] = { "dhu" },
  ["とぅ"] = { "twu" }, ["どぅ"] = { "dwu" },
  ["つぁ"] = { "tsa" }, ["つぃ"] = { "tsi" }, ["つぇ"] = { "tse" }, ["つぉ"] = { "tso" },
  ["ふぁ"] = { "fa" }, ["ふぃ"] = { "fi" }, ["ふぇ"] = { "fe" }, ["ふぉ"] = { "fo" }, ["ふゅ"] = { "fyu" },
  ["うぃ"] = { "wi" }, ["うぇ"] = { "we" }, ["うぉ"] = { "who" },
  ["ゔぁ"] = { "va" }, ["ゔぃ"] = { "vi" }, ["ゔぇ"] = { "ve" }, ["ゔぉ"] = { "vo" },
  ["くぁ"] = { "kwa", "qa" }, ["ぐぁ"] = { "gwa" },
  ["いぇ"] = { "ye" },
}

local units = vim.deepcopy(single)
for base, prefixes in pairs(yoon) do
  for small, vowel in pairs({ ["ゃ"] = "a", ["ゅ"] = "u", ["ょ"] = "o" }) do
    local list = {}
    for _, p in ipairs(prefixes) do
      list[#list + 1] = p .. vowel
    end
    units[base .. small] = list
  end
end
for k, v in pairs(extra) do
  units[k] = v
end

-- Voiced / semi-voiced variants used for rendaku (e.g. 人々 = ひとびと).
-- stylua: ignore
M.rendaku = {
  ["か"] = { "が" }, ["き"] = { "ぎ" }, ["く"] = { "ぐ" }, ["け"] = { "げ" }, ["こ"] = { "ご" },
  ["さ"] = { "ざ" }, ["し"] = { "じ" }, ["す"] = { "ず" }, ["せ"] = { "ぜ" }, ["そ"] = { "ぞ" },
  ["た"] = { "だ" }, ["ち"] = { "ぢ" }, ["つ"] = { "づ" }, ["て"] = { "で" }, ["と"] = { "ど" },
  ["は"] = { "ば", "ぱ" }, ["ひ"] = { "び", "ぴ" }, ["ふ"] = { "ぶ", "ぷ" }, ["へ"] = { "べ", "ぺ" }, ["ほ"] = { "ぼ", "ぽ" },
}

-- Kana that may turn into っ at the end of an on-reading (学校 = がっこう).
M.sokuon_able = { ["く"] = true, ["き"] = true, ["つ"] = true, ["ち"] = true }

M.units = units

---Fold a katakana character to hiragana. Other characters are returned as is.
---@param ch string
---@return string
function M.to_hira(ch)
  local cp = vim.fn.char2nr(ch)
  if cp >= 0x30A1 and cp <= 0x30F6 then
    return vim.fn.nr2char(cp - 0x60)
  end
  return ch
end

---Split a hiragana string into kana units, preferring digraphs.
---@param s string
---@return string[]
function M.split(s)
  local chars = vim.fn.split(s, [[\zs]])
  local res = {}
  local i = 1
  while i <= #chars do
    local two = chars[i + 1] and (chars[i] .. chars[i + 1])
    if two and units[two] then
      res[#res + 1] = two
      i = i + 2
    else
      res[#res + 1] = chars[i]
      i = i + 1
    end
  end
  return res
end

return M
