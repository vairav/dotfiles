local M = {}

M.ui = {
  theme = "gruvchad",
}

M.options = {
  tabstop = 2,
}

local user_plugins = require "custom.plugins"

M.plugins = {
  user = require "custom.plugins",
}

return M
