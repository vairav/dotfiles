-- seamless navigation between tmux panes and vim splits
return {
  "christoomey/vim-tmux-navigator",
  cmd = {
    "TmuxNavigateLeft",
    "TmuxNavigateDown",
    "TmuxNavigateUp",
    "TmuxNavigateRight",
    "TmuxNavigatePrevious",
  },
  keys = {
    { "<C-h>", "<cmd>TmuxNavigateLeft<cr>", desc = "Left" },
    { "<C-j>", "<cmd>TmuxNavigateDown<cr>", desc = "Down" },
    { "<C-k>", "<cmd>TmuxNavigateUp<cr>", desc = "Up" },
    { "<C-l>", "<cmd>TmuxNavigateRight<cr>", desc = "Right" },
  },
}
