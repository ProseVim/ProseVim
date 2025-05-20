local utils = require("prose.core.utils")
local M = {}

M.setup_autocmds = function()
  local augroup = vim.api.nvim_create_augroup("Prose", { clear = true })

  -- Automatically save markdown files as the text changes
  vim.api.nvim_create_autocmd({ "BufNewFile", "BufRead" }, {
    pattern = "*.md",
    group = augroup,
    callback = function(ev)
      local initial_word_count = utils.get_words()
      vim.notify("Initial Word Count: " .. initial_word_count)
      -- Create nested autocommand for the buffer
      vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
        buffer = ev.buf,
        group = augroup,
        callback = function()
          local running_word_count = utils.get_words()
          vim.notify("Running Word Count: "..running_word_count)
          vim.cmd("silent write")
        end,
      })
    end,
  })

  vim.api.nvim_create_autocmd("BufUnload", {
    pattern = "*.md",
    group = augroup,
    callback = function(ev)
      vim.notify("Close session for file")
      -- close session
    end,
  })

  -- vim.api.nvim_create_autocmd("BufReadPre", {
  --   pattern = "*.md",
  --   group = augroup,
  --   callback = function(ev)
  --     -- get yaml
  --     -- Save initial word state when buffer is opened
  --     local wc = tostring(vim.fn.wordcount().words)
  --     vim.notify("BufReadPre Words:" .. wc)
  --   end,
  -- })
end

M.setup_autocmds()

return M
