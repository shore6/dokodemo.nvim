-- Romaji-aware matcher.
--
-- A pattern typed in romaji (e.g. "te") matches ASCII text literally and
-- Japanese text by reading: hiragana/katakana by their romaji spelling and
-- kanji by their on/kun readings ("te" matches "test", "テスト", "天ぷら"
-- and "手紙").
local kana = require("dokodemo.kana")

local M = {}

local units = kana.units
local kanji_table -- lazily loaded
local reading_cache = {}

-- Readings missing from Unihan that are common in everyday text.
-- Same format as dokodemo/kanji.lua: "on-readings|kun-readings".
local extra_readings = {
  ["日"] = { "に|" }, -- 日本
}

---Add readings for kanji (in addition to the built-in ones).
---@param tbl table<string, string> e.g. { ["蕎"] = "|そば" } ("on-readings|kun-readings", hiragana)
function M.add_readings(tbl)
  for ch, r in pairs(tbl) do
    extra_readings[ch] = extra_readings[ch] or {}
    table.insert(extra_readings[ch], r:find("|", 1, true) and r or ("|" .. r))
    reading_cache[ch] = nil
  end
end

local consonants = {}
for c in ("bcdfghjklmpqrstvwxyz"):gmatch(".") do
  consonants[c] = true
end

local function load_kanji()
  if not kanji_table then
    kanji_table = require("dokodemo.kanji")
  end
  return kanji_table
end

---@class dokodemo.Reading
---@field units string[] kana units
---@field partial boolean the reading may be cut after any unit (kun-readings carry okurigana)
---@field rendaku boolean voiced variant, only valid when not at the start of a match

---Readings of a kanji, expanded with sokuon/rendaku variants.
---@param ch string
---@return dokodemo.Reading[]?
local function readings(ch)
  local cached = reading_cache[ch]
  if cached ~= nil then
    return cached or nil
  end
  local entry = load_kanji()[ch]
  local extra = extra_readings[ch]
  if not entry and not extra then
    reading_cache[ch] = false
    return nil
  end
  local on, kun = (entry or "|"):match("^(.-)|(.*)$")
  if extra then
    for _, e in ipairs(extra) do
      local eo, ek = e:match("^(.-)|(.*)$")
      on, kun = on .. " " .. eo, kun .. " " .. ek
    end
  end
  local list = {}
  local function add(us, partial)
    list[#list + 1] = { units = us, partial = partial, rendaku = false }
    local voiced = kana.rendaku[us[1]]
    if voiced then
      for _, v in ipairs(voiced) do
        local copy = vim.list_slice(us)
        copy[1] = v
        list[#list + 1] = { units = copy, partial = partial, rendaku = true }
      end
    end
  end
  for r in on:gmatch("%S+") do
    local us = kana.split(r)
    add(us, false)
    if #us > 1 and kana.sokuon_able[us[#us]] then
      local copy = vim.list_slice(us)
      copy[#copy] = "っ"
      add(copy, false)
    end
  end
  for r in kun:gmatch("%S+") do
    add(kana.split(r), true)
  end
  reading_cache[ch] = list
  return list
end

---@class dokodemo.Char
---@field ch string original character
---@field norm string normalized character used for comparisons
---@field lower string lower-cased `norm`
---@field col integer 0-based byte column
---@field len integer byte length

---Split a line into characters with normalized forms.
---@param line string
---@return dokodemo.Char[]
function M.chars(line)
  local res = {}
  local col = 0
  for _, ch in ipairs(vim.fn.split(line, [[\zs]])) do
    local norm = ch
    local cp = vim.fn.char2nr(ch)
    if cp >= 0xFF01 and cp <= 0xFF5E then
      norm = vim.fn.nr2char(cp - 0xFEE0) -- full-width ASCII
    elseif cp == 0x3000 then
      norm = " "
    else
      norm = kana.to_hira(ch)
    end
    res[#res + 1] = { ch = ch, norm = norm, lower = norm:lower(), col = col, len = #ch }
    col = col + #ch
  end
  return res
end

---Split a pattern into characters.
---@param pattern string
---@return string[]
local split_cache, split_cache_size = {}, 0
function M.split_pattern(pattern)
  local res = split_cache[pattern]
  if not res then
    if split_cache_size > 64 then
      split_cache, split_cache_size = {}, 0
    end
    res = vim.fn.split(pattern, [[\zs]])
    split_cache[pattern] = res
    split_cache_size = split_cache_size + 1
  end
  return res
end

---Try to match `chars[i..]` against `pat[1..]`.
---@param chars dokodemo.Char[]
---@param i integer start index
---@param pat string[] pattern characters (as typed)
---@param lpat string[] lower-cased pattern characters (for romaji)
---@param literal_ci boolean compare literal characters case-insensitively
---@param collect? table<string, true> when given, explore every match and
---  collect the characters that could extend the pattern instead of
---  returning the first match
---@return integer? end index (inclusive) of the match
function M.match_at(chars, i, pat, lpat, literal_ci, collect)
  local n, np = #chars, #pat
  local start = i
  local dfs, collect_at

  -- Consume one kana unit. `here` is the buffer index where the match ends
  -- if the pattern runs out in the middle of this unit.
  local function eat_unit(unit, p, here, cont)
    if unit == "っ" then
      if collect and p > np then
        for k in pairs(consonants) do
          collect[k] = true
        end
      end
      local c = lpat[p]
      if consonants[c] then
        local nx = lpat[p + 1]
        if p == np then
          if not collect then
            return here
          end
          collect[c] = true
          if c == "t" then
            collect["c"] = true
          end
        end
        if nx == c or (c == "t" and nx == "c") then
          local r = cont(p + 1)
          if r then
            return r
          end
        end
      end
    end
    local spellings = units[unit]
    if not spellings then
      return nil
    end
    for _, s in ipairs(spellings) do
      local ok, j = true, 1
      while j <= #s do
        local pc = lpat[p + j - 1]
        if pc == nil then
          if not collect then
            return here -- pattern ends inside this spelling
          end
          collect[s:sub(j, j)] = true
          ok = false
          break
        end
        if pc ~= s:sub(j, j) then
          ok = false
          break
        end
        j = j + 1
      end
      if ok then
        local r = cont(p + #s)
        if r then
          return r
        end
      end
    end
  end

  local function eat_reading(rd, ui, p, idx)
    if ui > #rd.units then
      return dfs(idx + 1, p)
    end
    if rd.partial and ui > 1 then
      local r = dfs(idx + 1, p)
      if r then
        return r
      end
    end
    return eat_unit(rd.units[ui], p, idx, function(p2)
      return eat_reading(rd, ui + 1, p2, idx)
    end)
  end

  dfs = function(idx, p)
    if p > np then
      if collect then
        collect_at(idx)
        return nil
      end
      return idx - 1
    end
    if idx > n then
      return nil
    end
    local c = chars[idx]
    local r

    -- literal match (ASCII and anything typed through an IME)
    local pc = pat[p]
    if c.norm == pc or c.ch == pc or (literal_ci and c.lower == lpat[p]) then
      r = dfs(idx + 1, p + 1)
      if r then
        return r
      end
    end

    local h = c.norm
    -- kana digraph spanning two buffer characters
    local nxt = chars[idx + 1]
    if nxt and units[h .. nxt.norm] then
      r = eat_unit(h .. nxt.norm, p, idx + 1, function(p2)
        return dfs(idx + 2, p2)
      end)
      if r then
        return r
      end
    end
    if units[h] then
      return eat_unit(h, p, idx, function(p2)
        return dfs(idx + 1, p2)
      end)
    end

    -- kanji
    local kch = c.ch
    if kch == "々" and idx > 1 then
      kch = chars[idx - 1].ch
    end
    local rds = readings(kch)
    if rds then
      for _, rd in ipairs(rds) do
        if not (rd.rendaku and idx == start) then
          r = eat_reading(rd, 1, p, idx)
          if r then
            return r
          end
        end
      end
    end
    return nil
  end

  -- All characters that may start a match at `idx` (used in collect mode).
  collect_at = function(idx)
    local c = chars[idx]
    if not c then
      return
    end
    collect[c.lower] = true
    local function first_letters(unit)
      if unit == "っ" then
        for k in pairs(consonants) do
          collect[k] = true
        end
      end
      for _, s in ipairs(units[unit] or {}) do
        collect[s:sub(1, 1)] = true
      end
    end
    local nxt = chars[idx + 1]
    if nxt and units[c.norm .. nxt.norm] then
      first_letters(c.norm .. nxt.norm)
    end
    if units[c.norm] then
      first_letters(c.norm)
      return
    end
    local kch = c.ch
    if kch == "々" and idx > 1 then
      kch = chars[idx - 1].ch
    end
    for _, rd in ipairs(readings(kch) or {}) do
      first_letters(rd.units[1])
    end
  end

  return dfs(i, 1)
end

---@class dokodemo.LineMatch
---@field col integer 0-based byte column of the match start
---@field end_col integer 0-based exclusive byte column of the match end
---@field idx integer character index of the match start

---Find all matches of `pattern` in `line`.
---@param line string|dokodemo.Char[]
---@param pattern string
---@param opts? {ignorecase?: boolean, smartcase?: boolean, starts?: integer[], collect?: table<string, true>}
---@return dokodemo.LineMatch[] matches (empty when `collect` is given: the
---  characters that could extend the pattern are added to it instead)
function M.find(line, pattern, opts)
  opts = opts or {}
  local ignorecase = opts.ignorecase ~= false
  if ignorecase and opts.smartcase ~= false and pattern:find("%u") then
    ignorecase = false
  end
  local chars = type(line) == "string" and M.chars(line) or line
  local pat = M.split_pattern(pattern)
  local lpat = M.split_pattern(pattern:lower())
  if #pat == 0 then
    return {}
  end
  local res = {}
  local function try(i)
    if opts.collect then
      M.match_at(chars, i, pat, lpat, ignorecase, opts.collect)
      return
    end
    local e = M.match_at(chars, i, pat, lpat, ignorecase)
    if e then
      res[#res + 1] = { col = chars[i].col, end_col = chars[e].col + chars[e].len, idx = i }
    end
  end
  if opts.starts then
    for _, i in ipairs(opts.starts) do
      try(i)
    end
  else
    for i = 1, #chars do
      try(i)
    end
  end
  return res
end

return M
