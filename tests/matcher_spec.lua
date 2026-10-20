-- Run with: nvim --headless -u NONE -l tests/matcher_spec.lua
vim.opt.rtp:prepend(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h"))
local matcher = require("dokodemo.matcher")

local failed = 0
local function check(line, pattern, expected, opts)
  local got = {}
  for _, m in ipairs(matcher.find(line, pattern, opts)) do
    got[#got + 1] = line:sub(m.col + 1, m.end_col)
  end
  local ok = vim.deep_equal(got, expected)
  if not ok then
    failed = failed + 1
  end
  print(("%s %-14s %-24s -> %s"):format(ok and "ok  " or "FAIL", pattern, line, vim.inspect(got)))
  if not ok then
    print("     expected " .. vim.inspect(expected))
  end
end

check("test テスト 天ぷら", "t", { "t", "t", "テ", "ト", "天" })
check("test テスト 天ぷら", "te", { "te", "テ", "天" })
check("test テスト 天ぷら", "tenp", { "天ぷ" })
check("天ぷら", "tenpura", { "天ぷら" })
check("Test", "t", { "T", "t" })
check("Test テスト", "T", { "T", "テ", "ト" })
check("ちゃんと", "cha", { "ちゃ" })
check("ちゃんと", "tya", { "ちゃ" })
check("ちゃんと", "chant", { "ちゃんと" })
check("しんぶん", "si", { "し" })
check("しんぶん", "shinb", { "しんぶ" })
check("学校へ行く", "gakk", { "学校" })
check("学校へ行く", "gakko", { "学校" })
check("食べる", "tabe", { "食べ" })
check("日本語", "nihongo", { "日本語" })
check("人々", "hitobito", { "人々" })
check("ちょっと待って", "tto", { "っと" })
check("ちょっと待って", "chotto", { "ちょっと" })
check("ちょっと待って", "matte", { "待って" })
check("ｔｅｓｔ", "te", { "ｔｅ" })
check("コーヒー", "ko-h", { "コーヒ" })
check("漢字", "kanji", { "漢字" })
check("ファイル", "fai", { "ファイ" })
check("abc", "x", {})
check("蕎麦屋", "sobaya", {})
matcher.add_readings({ ["蕎"] = "|そ", ["麦"] = "|ば" })
check("蕎麦屋", "sobaya", { "蕎麦屋" })

-- collect mode must agree with brute force: a letter is collected iff
-- pattern..letter matches at one of the starts of pattern
local sample = matcher.chars("日本語の文章で天ぷらを食べたいと思っています。ちょっとTest 東京タワー学校人々")
for _, pattern in ipairs({ "t", "te", "ch", "cho", "ga", "n", "hi", "ta", "s" }) do
  local starts = {}
  for _, m in ipairs(matcher.find(sample, pattern)) do
    starts[#starts + 1] = m.idx
  end
  local set = {}
  matcher.find(sample, pattern, { starts = starts, collect = set })
  local missing, extra = {}, {}
  for l in ("abcdefghijklmnopqrstuvwxyz"):gmatch(".") do
    local brute = #matcher.find(sample, pattern .. l, { starts = starts }) > 0
    if brute and not set[l] then
      missing[#missing + 1] = l
    elseif set[l] and not brute then
      extra[#extra + 1] = l
    end
  end
  -- missing letters would be unusable labels (bug); extra ones only waste a label
  local ok = #missing == 0
  failed = failed + (ok and 0 or 1)
  print(("%s collect %-4s missing=%s extra=%s"):format(ok and "ok  " or "FAIL", pattern, table.concat(missing), table.concat(extra)))
end

if failed > 0 then
  print(failed .. " test(s) failed")
  os.exit(1)
end
print("all tests passed")
