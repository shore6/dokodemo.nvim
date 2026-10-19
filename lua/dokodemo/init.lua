local matcher = require("dokodemo.matcher")

local M = {}

---@class dokodemo.Config
local defaults = {
  -- Characters used as jump labels, in order of preference.
  labels = "asdfghjklqwertyuiopzxcvbnm",
  -- Case handling for ASCII text (romaji matching is always case-insensitive).
  ignorecase = true,
  smartcase = true,
  -- Dim the window while jumping.
  backdrop = true,
  -- Where to show labels: "after" the match (like flash.nvim) or at its "start".
  label_position = "after",
  -- Jump immediately when only one match is left.
  autojump = false,
  -- Extra kanji readings, e.g. { ["蕎"] = "|そ" } ("on-readings|kun-readings" in hiragana).
  readings = {},
}

---@type dokodemo.Config
M.config = vim.deepcopy(defaults)

local ns = vim.api.nvim_create_namespace("dokodemo")

local function set_hl()
  local links = {
    DokodemoBackdrop = "Comment",
    DokodemoMatch = "Search",
    DokodemoCurrent = "IncSearch",
    DokodemoLabel = "Substitute",
    DokodemoPrompt = "Question",
  }
  for name, link in pairs(links) do
    vim.api.nvim_set_hl(0, name, { link = link, default = true })
  end
end

---@param opts? dokodemo.Config
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
  matcher.add_readings(M.config.readings)
  set_hl()
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("dokodemo", { clear = true }),
    callback = set_hl,
  })
end

---@class dokodemo.Match
---@field lnum integer 1-based line
---@field col integer 0-based byte column
---@field end_col integer 0-based exclusive byte column
---@field idx integer character index in the line
---@field label? string

---Collect the visible lines of the current window.
---@return {lnum: integer, chars: dokodemo.Char[]}[]
local function visible_lines(win)
  local res = {}
  local buf = vim.api.nvim_win_get_buf(win)
  vim.api.nvim_win_call(win, function()
    local top, bot = vim.fn.line("w0"), vim.fn.line("w$")
    local lines = vim.api.nvim_buf_get_lines(buf, top - 1, bot, false)
    local l = top
    while l <= bot do
      local fold_end = vim.fn.foldclosedend(l)
      if fold_end ~= -1 then
        l = fold_end + 1
      else
        res[#res + 1] = { lnum = l, chars = matcher.chars(lines[l - top + 1]) }
        l = l + 1
      end
    end
  end)
  return res
end

---Whether a match is horizontally visible (for 'nowrap').
local function in_view(win, m)
  if vim.wo[win].wrap then
    return true
  end
  local view = vim.api.nvim_win_call(win, vim.fn.winsaveview)
  local info = vim.fn.getwininfo(win)[1]
  local width = info.width - info.textoff
  local vcol = vim.fn.virtcol({ m.lnum, m.col + 1 }, false, win)
  return vcol > view.leftcol and vcol <= view.leftcol + width
end

---@param lines {lnum: integer, chars: dokodemo.Char[]}[]
---@param pattern string
---@param prev? table<integer, integer[]> previous match starts per line (to narrow the search)
---@return dokodemo.Match[], table<integer, integer[]>
local function search(win, lines, pattern, prev)
  local cfg = M.config
  local matches, starts = {}, {}
  for _, line in ipairs(lines) do
    local opts = { ignorecase = cfg.ignorecase, smartcase = cfg.smartcase }
    if prev then
      opts.starts = prev[line.lnum]
    end
    if not prev or opts.starts then
      for _, lm in ipairs(matcher.find(line.chars, pattern, opts)) do
        local m = { lnum = line.lnum, col = lm.col, end_col = lm.end_col, idx = lm.idx }
        if in_view(win, m) then
          matches[#matches + 1] = m
          starts[line.lnum] = starts[line.lnum] or {}
          table.insert(starts[line.lnum], lm.idx)
        end
      end
    end
  end
  return matches, starts
end

---Sort matches by distance from the cursor and assign labels that do not
---collide with characters that would continue the pattern.
local function assign_labels(win, lines, matches, pattern, starts)
  local cursor = vim.api.nvim_win_get_cursor(win)
  table.sort(matches, function(a, b)
    local da = math.abs(a.lnum - cursor[1])
    local db = math.abs(b.lnum - cursor[1])
    if da ~= db then
      return da < db
    end
    return math.abs(a.col - cursor[2]) < math.abs(b.col - cursor[2])
  end)
  -- characters that would extend the pattern can't be used as labels
  local skip = {}
  for _, line in ipairs(lines) do
    if starts[line.lnum] then
      matcher.find(line.chars, pattern, {
        ignorecase = M.config.ignorecase,
        smartcase = M.config.smartcase,
        starts = starts[line.lnum],
        collect = skip,
      })
    end
  end
  local labels = {}
  for _, l in ipairs(vim.fn.split(M.config.labels, [[\zs]])) do
    if not skip[l] then
      labels[#labels + 1] = l
    end
  end
  for i, m in ipairs(matches) do
    m.label = labels[i]
  end
  return matches
end

local function render(win, lines, matches, pattern)
  local buf = vim.api.nvim_win_get_buf(win)
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  if M.config.backdrop then
    for _, line in ipairs(lines) do
      vim.api.nvim_buf_set_extmark(buf, ns, line.lnum - 1, 0, {
        end_row = line.lnum,
        end_col = 0,
        hl_group = "DokodemoBackdrop",
        hl_eol = false,
        priority = 9000,
        strict = false,
      })
    end
  end
  local by_line = {}
  for _, line in ipairs(lines) do
    by_line[line.lnum] = line.chars
  end
  for i, m in ipairs(matches) do
    vim.api.nvim_buf_set_extmark(buf, ns, m.lnum - 1, m.col, {
      end_col = m.end_col,
      hl_group = i == 1 and "DokodemoCurrent" or "DokodemoMatch",
      priority = 9001,
    })
    if m.label then
      local chars = by_line[m.lnum]
      local col, ch
      if M.config.label_position == "start" then
        col, ch = m.col, chars[m.idx]
      else
        col = m.end_col
        for j = m.idx, #chars do
          if chars[j].col == m.end_col then
            ch = chars[j]
            break
          end
        end
      end
      local text = m.label
      if ch and vim.fn.strdisplaywidth(ch.ch) == 2 then
        text = text .. " " -- cover the whole wide character
      end
      vim.api.nvim_buf_set_extmark(buf, ns, m.lnum - 1, col, {
        virt_text = { { text, "DokodemoLabel" } },
        virt_text_pos = ch and "overlay" or "eol",
        priority = 9002,
      })
    end
  end
  vim.api.nvim_echo({ { "dokodemo: ", "DokodemoPrompt" }, { pattern } }, false, {})
  vim.cmd.redraw()
end

local function clear(win)
  if vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_buf_clear_namespace(vim.api.nvim_win_get_buf(win), ns, 0, -1)
  end
  vim.api.nvim_echo({ { "" } }, false, {})
  vim.cmd.redraw()
end

local function do_jump(win, m)
  local mode = vim.api.nvim_get_mode().mode
  if mode == "n" then
    vim.cmd("normal! m'")
  end
  vim.api.nvim_win_set_cursor(win, { m.lnum, m.col })
end

---Read a character, returning nil on <Esc>/<C-c>.
local function getchar()
  local ok, ch = pcall(vim.fn.getcharstr)
  if not ok or ch == "\27" or ch == "\3" then
    return nil
  end
  return ch
end

---Start a jump. Type romaji (or any text) to narrow down the matches, then a
---label to jump. <CR> jumps to the nearest match, <BS> deletes a character
---and <Esc> cancels.
---@param opts? {pattern?: string}
function M.jump(opts)
  opts = opts or {}
  if not M._did_setup then
    M._did_setup = true
    set_hl()
  end
  local win = vim.api.nvim_get_current_win()
  local lines = visible_lines(win)
  local pattern = opts.pattern or ""
  local matches = {}

  local ok, err = pcall(function()
    while true do
      if pattern ~= "" then
        local starts
        matches, starts = search(win, lines, pattern)
        assign_labels(win, lines, matches, pattern, starts)
        if M.config.autojump and #matches == 1 then
          do_jump(win, matches[1])
          return
        end
      else
        matches = {}
      end
      render(win, lines, matches, pattern)

      local ch = getchar()
      if not ch then
        return
      end
      if ch == "\r" then
        if matches[1] then
          do_jump(win, matches[1])
        end
        return
      elseif ch == "\8" or ch == vim.keycode("<BS>") then
        if pattern == "" then
          return
        end
        pattern = vim.fn.strcharpart(pattern, 0, vim.fn.strchars(pattern) - 1)
      else
        local target
        for _, m in ipairs(matches) do
          if m.label == ch then
            target = m
            break
          end
        end
        if target then
          do_jump(win, target)
          return
        end
        local new_pattern = pattern .. ch
        if #search(win, lines, new_pattern) == 0 then
          -- neither a label nor a continuation: stop, like flash.nvim
          return
        end
        pattern = new_pattern
      end
    end
  end)
  clear(win)
  if not ok then
    error(err)
  end
end

return M
