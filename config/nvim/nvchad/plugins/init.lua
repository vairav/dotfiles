return {
  ["goolord/alpha-nvim"] = {
    disable = false,
  },
  ["neovim/nvim-lspconfig"] = {
    config = function()
      require "plugins.configs.lspconfig"
      require "custom.plugins.lspconfig"
    end,
  },
  ["simrat39/rust-tools.nvim"] = {
    tools = {
      autoSetHints = true,
      runnables = {
        use_telescope = true,
      },
      debuggables = {
        use_telescope = true,
      },
      inlay_hints = {
        auto = true,
        only_current_line = false,
        show_parameter_hints = true,
        parameter_hints_prefix = "<- ",
        other_hints_prefix = "=> ",
        highlight = "InlayHints",
      },
      hover_actions = {
        auto_focus = true,
      },
      -- execute_command = rust_execute_command,
    },
    server = {
      -- on_attach = on_attach,
      -- capabilities = capabilities,
      flags = {
        debounce_text_changes = 200,
      },
      settings = {
        ["rust-analyzer"] = {
          checkOnSave = {
            command = "clippy",
          },
          completion = {
            autoimport = {
              enable = true,
            },
          },
        },
      },
    },
  },
}
