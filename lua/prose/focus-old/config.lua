local util = require("prose.focus.util")
local M = {}

local defaults = {
  border = "none",
  zindex = 40, -- zindex of the zen window. Should be less than 50, which is the float default
  window = {
    backdrop = 1, -- shade the backdrop of the zen window. Set to 1 to keep the same as Normal
    -- height and width can be:
    -- * an asbolute number of cells when > 1
    -- * a percentage of the width / height of the editor when <= 1
    width = 100, -- width of the zen window
    height = .8, -- height of the zen window
    -- by default, no options are changed in for the zen window
    -- uncomment any of the options below, or add other vim.wo options you want to apply
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
    -- disable some global vim options (vim.o...)
    -- comment the lines to not apply the options
    options = {
      enabled = true,
      ruler = false, -- disables the ruler text in the cmd line area
      showcmd = false, -- disables the command in the last line of the screen
    },
    twilight = { enabled = false }, -- enable to start Twilight when zen mode opens
    gitsigns = { enabled = false }, -- disables git signs
    tmux = { enabled = false }, -- disables the tmux statusline
    diagnostics = { enabled = false }, -- disables diagnostics
  },
  -- callback where you can add custom code when the zen window opens
  on_open = function(_win) end,
  -- callback where you can add custom code when the zen window closes
  on_close = function() end,
}

M.options = nil

function M.colors(options)
  options = options or M.options
  local normal = util.get_hl("Normal")
  if normal then
    if normal.background then
      local bg = util.darken(normal.background, options.window.backdrop)
      vim.cmd(("highlight default ZenBg guibg=%s guifg=%s"):format(bg, bg))
    else
      vim.cmd("highlight default link ZenBg Normal")
    end
  end
end

function M.setup(options)
  M.options = vim.tbl_deep_extend("force", {}, defaults, options or {})
  M.colors()
  vim.cmd([[autocmd ColorScheme * lua require("prose.focus.config").colors()]])
  for plugin, plugin_opts in pairs(M.options.plugins) do
    if type(plugin_opts) == "boolean" then
      M.options.plugins[plugin] = { enabled = plugin_opts }
    end
    if M.options.plugins[plugin].enabled == nil then
      M.options.plugins[plugin].enabled = true
    end
  end
end

return setmetatable(M, {
  __index = function(_, k)
    if k == "options" then
      M.setup()
    end
    return rawget(M, k)
  end,
})
