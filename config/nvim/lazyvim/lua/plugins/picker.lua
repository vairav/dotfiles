-- show hidden files (dotfiles) in fuzzy finder
return {
  "folke/snacks.nvim",
  opts = {
    picker = {
      sources = {
        files = {
          hidden = true,
        },
      },
    },
  },
}
