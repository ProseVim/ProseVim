local utils = require("prose.core.utils")

local Line = {}

local modes = {
  ["n"] = "NORMAL",
  ["no"] = "NORMAL",
  ["v"] = "VISUAL",
  ["V"] = "VISUAL LINE",
  [""] = "VISUAL BLOCK",
  ["s"] = "SELECT",
  ["S"] = "SELECT LINE",
  [""] = "SELECT BLOCK",
  ["i"] = "INSERT",
  ["ic"] = "INSERT",
  ["R"] = "REPLACE",
  ["Rv"] = "VISUAL REPLACE",
  ["c"] = "COMMAND",
  ["cv"] = "VIM EX",
  ["ce"] = "EX",
  ["r"] = "PROMPT",
  ["rm"] = "MOAR",
  ["r?"] = "CONFIRM",
  ["!"] = "SHELL",
  ["t"] = "TERMINAL",
}

local function get_mode()
  local current_mode = vim.api.nvim_get_mode().mode
  return string.format(" %s ", modes[current_mode]):upper()
end

local stl_parts = {
  pad = " ",
  path = nil,
  sep = "%=",
  trunc = "%<",
  venv = nil,
}

local stl_order = {
  "pad",
  "mode",
  "sep",
  "sep",
  "fileinfo",
  "path",
  "pad",
}

local function ordered_tbl_concat(order_tbl, stl_part_tbl)
  local str_table = {}
  local part = nil

  for _, val in ipairs(order_tbl) do
    part = stl_part_tbl[val]
    if part then
      table.insert(str_table, part)
    end
  end

  return table.concat(str_table, " ")
end

Line.render = function()
  local fname = vim.api.nvim_buf_get_name(0)

  stl_parts["mode"] = get_mode()
  stl_parts["path"] = vim.fn.fnamemodify(fname, ":t")
  stl_parts["fileinfo"] = utils.get_words()

  return ordered_tbl_concat(stl_order, stl_parts)
end

vim.o.statusline = "%!v:lua.require('line.line').render()"

return Line
