-- Completion (blink.cmp) - overrides two LazyVim defaults.
--
-- 1. Keys are vim-native: <C-y> accepts, <C-n>/<C-p> move, <C-e> cancels.
--    LazyVim's default is preset "enter", which binds <CR> to accept. Since
--    blink preselects the first item as soon as the menu opens, that makes
--    Enter swap the word under the cursor for a suggestion you never asked
--    for. Here <CR> is not a completion key at all, so Enter is always a
--    newline no matter what the menu is showing.
--
-- 2. The "buffer" source is dropped in prose. It scrapes every word out of
--    every open buffer, which is what makes English words show up with the
--    Text (abc) icon inside comments, strings and markdown. It stays enabled
--    in actual code, where it usefully surfaces identifiers the LSP has not
--    indexed yet.
--
-- Note: <Tab> belongs to Codeium (see codeium.lua, which maps it directly in
-- insert mode), so it is deliberately not used for completion here.

-- Filetypes that are prose end to end - no code to complete, so buffer words
-- would be the only thing on offer.
local prose_filetypes = {
  ["markdown"] = true,
  ["text"] = true,
  ["gitcommit"] = true,
  ["gitrebase"] = true,
  ["mail"] = true,
  ["help"] = true,
  ["asciidoc"] = true,
  ["rst"] = true,
  ["org"] = true,
  ["norg"] = true,
}

-- True when the cursor sits in prose rather than code: a prose filetype, or a
-- comment / string node in any language. Every call is pcall'd - buffers with
-- no treesitter parser are the normal case, not an error.
local function in_prose()
  if prose_filetypes[vim.bo.filetype] then
    return true
  end

  local ok, parser = pcall(vim.treesitter.get_parser, 0)
  if not ok or not parser then
    return false
  end

  -- get_node() only reads a tree that already exists; it never parses one. An
  -- unparsed or stale tree makes it return nil, which would read as "not a
  -- comment" and quietly let buffer words back in - so parse the cursor line
  -- first. Incremental, and usually already done by the highlighter.
  local row = vim.api.nvim_win_get_cursor(0)[1] - 1
  pcall(parser.parse, parser, { row, row + 1 })

  local node_ok, node = pcall(vim.treesitter.get_node)
  if not node_ok or not node then
    return false
  end

  local node_type = node:type()
  return node_type:find("comment") ~= nil or node_type:find("string") ~= nil
end

return {
  "saghen/blink.cmp",
  -- A function, not a table: LazyVim declares sources.default in opts_extend,
  -- so a table here would be appended to its list rather than replacing it.
  opts = function(_, opts)
    opts.keymap = vim.tbl_deep_extend("force", opts.keymap or {}, {
      preset = "default",
      ["<CR>"] = false,
    })

    opts.sources = opts.sources or {}
    opts.sources.default = function()
      if in_prose() then
        return { "lsp", "path", "snippets" }
      end
      return { "lsp", "path", "snippets", "buffer" }
    end

    return opts
  end,
}
