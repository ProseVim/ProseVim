local config = require "prosevim.focus.config"
local view = require "prosevim.focus.view"

local M = {}

M.setup = config.setup
M.toggle = view.toggle
M.open = view.open
M.close = view.close

function M.reset()
  M.close()
  require("plenary.reload").reload_module "prosevim.focus"
  require("prosevim.focus").toggle()
end

vim.api.nvim_create_user_command("ProseFocus", function()
  require("prosevim.focus").toggle()
end, {})

return M
