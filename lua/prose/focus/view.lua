local M = {}
local Popup = require("nui.popup")

M.state = {
  open = false,
}

local background = Popup({
  position = {
    row = 0,
    col = 0,
  },
  focusable = false,
  buf_options = {
    modifiable = false,
    readonly = true,
  },
  size = "100%",
  border = "none",
  win_options = {
    winhighlight = "Normal:Normal",
  },
  zindex = 50,
})

local height = 1 -- Number of lines tall
local footer = Popup({
  focusable = false,
  buf_options = {
    modifiable = false,
    readonly = true,
  },
  relative = "editor",
  position = {
    row = vim.o.lines - height,
    col = 0,
  },
  size = {
    width = "100%",
    height = height,
  },
  border = "none",
  zindex = 70,
})

vim.api.nvim_buf_set_lines(footer.bufnr, 0, 1, false, { "Hello World" })

-- Overlay popup
local content = Popup({
  position = {
    row = 1,
    col = "50%",
  },
  relative = "win",
  enter = true,
  size = {
    width = 80,
    height = vim.o.lines - height,
  },
  bufnr = vim.api.nvim_get_current_buf(),
  border = "none",
  win_options = {
    winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
  },
  zindex = 60,
})

M.open = function()
  background:mount()
  content:mount()
  footer:mount()
end

M.close = function()
  background:unmount()
  content:unmount()
  footer:unmount()
end

M.toggle = function()
  if M.state.open == true then
    M.state.open = false
    M.close()
  else
    M.state.open = true
    M.open()
  end
end

return M
