-- AI code completion (GitHub Copilot, shown as ghost text)
-- Same keys as the Codeium setup this replaced. <Tab> falls through to a real
-- tab when no suggestion is showing. Sign in once per machine with :Copilot auth.
return {
  "zbirenbaum/copilot.lua",
  cmd = "Copilot",
  event = "InsertEnter",
  opts = {
    panel = { enabled = false },
    suggestion = {
      enabled = true,
      auto_trigger = true,
      -- Keys are mapped below, because <Tab> needs the fall-through.
      keymap = { accept = false, next = "<M-]>", prev = "<M-[>", dismiss = "<C-]>" },
    },
    filetypes = {
      -- Everywhere, including markdown, yaml and commit messages, but never env files.
      ["*"] = true,
      dotenv = false,
      sh = function()
        return not vim.fn.expand("%:t"):match("^%.env")
      end,
    },
  },
  config = function(_, opts)
    require("copilot").setup(opts)
    vim.keymap.set("i", "<Tab>", function()
      local suggestion = require("copilot.suggestion")
      if suggestion.is_visible() then
        suggestion.accept()
      else
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Tab>", true, false, true), "n", false)
      end
    end, { silent = true, desc = "Accept Copilot suggestion, or a real tab" })
  end,
}
