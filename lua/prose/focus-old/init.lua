local config = require("prose.focus.config")
local view = require("prose.focus.view")

local M = {}

M.setup = config.setup
M.toggle = view.toggle
M.open = view.open
M.close = view.close

function M.reset()
  M.close()
  require("plenary.reload").reload_module("prose.focus")
  require("prose.focus").toggle()
end

vim.api.nvim_create_user_command("ProseFocus", function()
  M.toggle() 
end, {})

return M
