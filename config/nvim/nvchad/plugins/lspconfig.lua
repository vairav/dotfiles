local on_attach = require("plugins.configs.lspconfig").on_attach
local capabilities = require("plugins.configs.lspconfig").capabilities

local lspconfig = require("lspconfig")

-- lsp servers with default config
local servers = {
  "rust_analyzer",
  "taplo",
  -- "gopls",
  -- "html",
  -- "cssls",
  -- "jsonls",
  -- "eslint",
  -- "tsserver",
  -- "vimls",
  -- "sumneko_lua",
}

for _, lsp in ipairs(servers) do
  lspconfig[lsp].setup({
    on_attach = on_attach,
    capabilities = capabilities,
    flags = {
      debounce_text_changes = 150,
    },
  })
end
