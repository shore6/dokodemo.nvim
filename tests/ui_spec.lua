-- Run with: nvim --headless -u NONE -l tests/ui_spec.lua
vim.opt.rtp:prepend(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h"))
local dokodemo = require("dokodemo")
dokodemo.setup({})

local failed = 0
local function expect(name, got, want)
  local ok = vim.deep_equal(got, want)
  if not ok then
    failed = failed + 1
  end
  print(("%s %s: %s"):format(ok and "ok  " or "FAIL", name, vim.inspect(got)) .. (ok and "" or (" expected " .. vim.inspect(want))))
end

local buf = vim.api.nvim_create_buf(true, true)
vim.api.nvim_set_current_buf(buf)
vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
  "これはテストです。",
  "天ぷらを食べたい test",
  "東京タワー",
})

local function run(keys)
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  vim.api.nvim_feedkeys(keys, "t", false)
  dokodemo.jump()
  return vim.api.nvim_win_get_cursor(0)
end

-- "te" -> nearest match is テ on line 1; <CR> jumps there
expect("te<CR>", run("te\r"), { 1, #"これは" })
-- "ten" only matches 天
expect("ten<CR>", run("ten\r"), { 2, 0 })
-- "tab" -> 食べ, label "a" is free since "taba" doesn't match
expect("taba (label)", run("taba"), { 2, #"天ぷらを" })
-- "tou" -> 東
expect("touk<CR>", run("touk\r"), { 3, 0 })
-- Esc cancels
expect("<Esc>", run("te\27"), { 1, 0 })

-- operator-pending: d + jump deletes up to the target
vim.api.nvim_win_set_cursor(0, { 1, 0 })
vim.keymap.set("o", "s", dokodemo.jump)
vim.api.nvim_feedkeys("dste\r", "tx", false)
expect("dste<CR>", vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], "テストです。")

if failed > 0 then
  print(failed .. " test(s) failed")
  os.exit(1)
end
print("all tests passed")
