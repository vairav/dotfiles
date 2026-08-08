-- formatting via conform.nvim
-- LazyVim ships conform.nvim; this configures formatters per filetype.
-- Formatters: prettier (web/md), rustfmt (rust), zigfmt (zig)
return {
  "stevearc/conform.nvim",
  opts = {
    formatters_by_ft = {
      markdown = { "prettier" },
      typescript = { "prettier" },
      typescriptreact = { "prettier" },
      javascript = { "prettier" },
      javascriptreact = { "prettier" },
      json = { "prettier" },
      yaml = { "prettier" },
      html = { "prettier" },
      css = { "prettier" },
      rust = { "rustfmt" },
      zig = { "zigfmt" },
    },
  },
}
