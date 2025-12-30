-- AI code completion (Codeium/Windsurf)
return {
  "Exafunction/windsurf.vim",
  event = "BufEnter",
  config = function()
    local map = vim.keymap.set
    local opts = { expr = true, silent = true }

    map("i", "<Tab>", function() return vim.fn["codeium#Accept"]() end, opts)
    map("i", "<M-]>", function() return vim.fn["codeium#CycleCompletions"](1) end, opts)
    map("i", "<M-[>", function() return vim.fn["codeium#CycleCompletions"](-1) end, opts)
    map("i", "<C-]>", function() return vim.fn["codeium#Clear"]() end, opts)
  end,
}
