local M = {}

M.treesitter = {
  ensure_installed = {
    'vim',
    'lua',
    'bash',
    'html',
    'css',
    'javascript',
    'json',
    'yaml',
    'toml',
    'markdown',
    'rust',
    'go'
  }
}

M.nvimtree = {
  lazy_load = true,
  git = {
    enable = true,
    ignore = true,
  }
}

return M
