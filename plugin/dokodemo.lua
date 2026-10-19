if vim.g.loaded_dokodemo then
  return
end
vim.g.loaded_dokodemo = true

vim.api.nvim_create_user_command("Dokodemo", function(args)
  require("dokodemo").jump({ pattern = args.args ~= "" and args.args or nil })
end, { nargs = "?", desc = "Jump to a match (romaji matches kana and kanji)" })
