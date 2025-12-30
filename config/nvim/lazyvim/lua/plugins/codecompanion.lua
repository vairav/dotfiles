-- AI assistant using Z.ai GLM models
return {
  "olimorris/codecompanion.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-treesitter/nvim-treesitter",
  },
  keys = {
    { "<leader>ai", "<cmd>CodeCompanion<cr>", mode = { "n", "v" }, desc = "Inline" },
    { "<leader>ac", "<cmd>CodeCompanionChat Toggle<cr>", mode = { "n", "v" }, desc = "Chat" },
    { "<leader>aa", "<cmd>CodeCompanionActions<cr>", mode = { "n", "v" }, desc = "Actions" },
  },
  opts = {
    adapters = {
      zai = function()
        return require("codecompanion.adapters").extend("openai", {
          formatted_name = "Z.ai GLM",
          url = "https://api.z.ai/api/coding/paas/v4/chat/completions",
          env = { api_key = "ZAI_API_KEY" },
          schema = {
            model = {
              default = "glm-4.7",
              choices = { "glm-4.7", "glm-4.6v", "glm-4.6v-flash" },
            },
          },
        })
      end,
    },
    strategies = {
      chat = { adapter = "zai" },
      inline = { adapter = "zai" },
    },
  },
}
