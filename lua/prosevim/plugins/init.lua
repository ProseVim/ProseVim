return {
  {
    "folke/twilight.nvim",
    config = true,
  },
  {
    "folke/zen-mode.nvim",
    config = function()
      require("zen-mode").setup {
        window = {
          backdrop = 1,
          width = 100,
          height = 1,
          options = {
            signcolumn = "no", -- disable signcolumn
            number = false, -- disable number column
            relativenumber = false, -- disable relative numbers
            cursorline = false, -- disable cursorline
            cursorcolumn = false, -- disable cursor column
            foldcolumn = "0", -- disable fold column
            list = false, -- disable whitespace characters
          },
        },
        plugins = {
          options = {
            enabled = true,
            ruler = false,
            showcmd = false,
          },
          twilight = { enabled = true },
          gitsigns = { enabled = false },
          tmux = { enabled = true },
        },
        -- callback where you can add custom code when the Zen window opens
        on_open = function()
          -- vim.cmd("LspStop")
          vim.wo.linebreak = true
        end,
        -- -- callback where you can add custom code when the Zen window closes
        on_close = function()
          -- vim.cmd("LspStart")
          vim.wo.linebreak = false
        end,
      }
      nmap("<leader>w", "<cmd>ZenMode<cr>")
    end,
  },
}
