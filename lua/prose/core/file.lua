local Path = require("prose.core.path")
local AsyncFile = require("prose.core.async").File
local abc = require("prose.core.abc")
local with = require("plenary.context_manager").with
local open = require("plenary.context_manager").open
local yaml = require("prose.core.yaml")
local log = require("prose.core.log")
local util = require("prose.core.utils")
local iter = require("prose.core.itertools").iter
local enumerate = require("prose.core.itertools").enumerate
local compat = require("prose.core.compat")

local File = abc.new_class({
  __tostring = function(self)
    return string.format("File('%s')", self.id)
  end,
})

File.is_file_obj = function(file)
  if getmetatable(file) == File.mt then
    return true
  else
    return false
  end
end

File.new = function(tags, path)
  local self = File.init()
  self.tags = tags and tags or {}
  self.path = path and Path.new(path) or nil
  self.metadata = nil
  self.has_frontmatter = nil
  self.frontmatter_end_line = nil
  return self
end

--- Get markdown display info about the file.
---
---@return string
File.display_info = function(self, opts)
  opts = opts and opts or {}

  ---@type string[]
  local info = {}

  if opts.label ~= nil and string.len(opts.label) > 0 then
    info[#info + 1] = ("%s"):format(opts.label)
    info[#info + 1] = "--------"
  end

  if self.path ~= nil then
    info[#info + 1] = ("**path:** `%s`"):format(self.path)
  end

  info[#info + 1] = ("**id:** `%s`"):format(self.id)

  if #self.aliases > 0 then
    info[#info + 1] = ("**aliases:** '%s'"):format(table.concat(self.aliases, "', '"))
  end

  if #self.tags > 0 then
    info[#info + 1] = ("**tags:** `#%s`"):format(table.concat(self.tags, "`, `#"))
  end

  return table.concat(info, "\n")
end

--- Check if the file exists on the file system.
---
---@return boolean
File.exists = function(self)
  ---@diagnostic disable-next-line: return-type-mismatch
  return self.path ~= nil and self.path:is_file()
end

--- Get the filename associated with the file.
---
---@return string|?
File.fname = function(self)
  if self.path == nil then
    return nil
  else
    return vim.fs.basename(tostring(self.path))
  end
end

--- Check if a file has a given tag.
---
---@param tag string
---
---@return boolean
File.has_tag = function(self, tag)
  return util.tbl_contains(self.tags, tag)
end

--- Add a tag to the file.
---
---@param tag string
---
---@return boolean added True if the tag was added, false if it was already present.
File.add_tag = function(self, tag)
  if not self:has_tag(tag) then
    table.insert(self.tags, tag)
    return true
  else
    return false
  end
end

--- Add or update a field in the frontmatter.
---
---@param key string
---@param value any
File.add_field = function(self, key, value)
  if key == "id" or key == "aliases" or key == "tags" then
    error("Updating field '%s' this way is not allowed. Please update the corresponding attribute directly instead")
  end

  if not self.metadata then
    self.metadata = {}
  end

  self.metadata[key] = value
end

--- Get a field in the frontmatter.
---
---@param key string
---
---@return any result
File.get_field = function(self, key)
  if key == "id" or key == "aliases" or key == "tags" then
    error("Getting field '%s' this way is not allowed. Please use the corresponding attribute directly instead")
  end

  if not self.metadata then
    return nil
  end

  return self.metadata[key]
end

---@class obsidian.file.LoadOpts
---@field max_lines integer|?
---@field load_contents boolean|?

--- Initialize a file from a file.
---
---@param path string|obsidian.Path
---@param opts obsidian.file.LoadOpts|?
---
---@return obsidian.File
File.from_file = function(path, opts)
  if path == nil then
    error("file path cannot be nil")
  end
  local n
  with(open(tostring(Path.new(path):resolve({ strict = true }))), function(reader)
    n = File.from_lines(reader:lines(), path, opts)
  end)
  return n
end

--- An async version of `.from_file()`, i.e. it needs to be called in an async context.
---
---@param path string|obsidian.Path
---@param opts obsidian.file.LoadOpts|?
---
---@return obsidian.File
File.from_file_async = function(path, opts)
  local f = AsyncFile.open(Path.new(path):resolve({ strict = true }))
  local ok, res = pcall(File.from_lines, f:lines(false), path, opts)
  f:close()
  if ok then
    return res
  else
    error(res)
  end
end

--- Initialize a file from a buffer.
---
---@param bufnr integer|?
---@param opts obsidian.file.LoadOpts|?
---
---@return obsidian.File
File.from_buffer = function(bufnr, opts)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local path = vim.api.nvim_buf_get_name(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local file = File.from_lines(iter(lines), path, opts)
  file.bufnr = bufnr
  return file
end

--- Initialize a file from an iterator of lines.
---
---@param lines fun(): string|?
---@param path string|obsidian.Path
---@param opts obsidian.file.LoadOpts|?
---
---@return obsidian.File
File.from_lines = function(lines, path, opts)
  opts = opts or {}
  path = Path.new(path):resolve()

  local tags = {}

  -- Iterate over lines in the file, collecting frontmatter and parsing the title.
  local frontmatter_lines = {}
  local has_frontmatter, in_frontmatter, at_boundary = false, false, false -- luacheck: ignore (false positive)
  local frontmatter_end_line = nil
  for line_idx, line in enumerate(lines) do
    line = util.rstrip_whitespace(line)

    if line_idx == 1 and File._is_frontmatter_boundary(line) then
      has_frontmatter = true
      at_boundary = true
      in_frontmatter = true
    elseif in_frontmatter and File._is_frontmatter_boundary(line) then
      at_boundary = true
      in_frontmatter = false
      frontmatter_end_line = line_idx
    else
      at_boundary = false
    end

    if in_frontmatter and not at_boundary then
      table.insert(frontmatter_lines, line)
    end
  end

  -- Parse the frontmatter YAML.
  local metadata = nil
  if #frontmatter_lines > 0 then
    local frontmatter = table.concat(frontmatter_lines, "\n")
    local ok, data = pcall(yaml.loads, frontmatter)
    if type(data) ~= "table" then
      data = {}
    end
    if ok then
      ---@diagnostic disable-next-line: param-type-mismatch
      for k, v in pairs(data) do
        if k == "tags" then
          if type(v) == "table" then
            for tag in iter(v) do
              if type(tag) == "string" then
                table.insert(tags, tag)
              else
                log.warn(
                  "Invalid tag value found in frontmatter for "
                    .. tostring(path)
                    .. ". Expected string, found "
                    .. type(tag)
                    .. "."
                )
              end
            end
          elseif type(v) == "string" then
            tags = vim.split(v, " ")
          else
            log.warn("Invalid 'tags' in frontmatter for '%s'", path)
          end
        else
          if metadata == nil then
            metadata = {}
          end
          metadata[k] = v
        end
      end
    end
  end

  -- ID should default to the filename without the extension.
  if id == nil or id == path.name then
    id = path.stem
  end
  assert(id)

  local n = File.new(tags, path)
  n.metadata = metadata
  n.has_frontmatter = has_frontmatter
  n.frontmatter_end_line = frontmatter_end_line
  return n
end

--- Check if a line matches a frontmatter boundary.
---
---@param line string
---
---@return boolean
---
---@private
File._is_frontmatter_boundary = function(line)
  return line:match("^---+$") ~= nil
end

--- Get the frontmatter table to save.
---
---@return table
File.frontmatter = function(self)
  local out = { id = self.id, aliases = self.aliases, tags = self.tags }
  if self.metadata ~= nil and not vim.tbl_isempty(self.metadata) then
    for k, v in pairs(self.metadata) do
      out[k] = v
    end
  end
  return out
end

--- Get frontmatter lines that can be written to a buffer.
---
---@param eol boolean|?
---@param frontmatter table|?
---
---@return string[]
File.frontmatter_lines = function(self, eol, frontmatter)
  local new_lines = { "---" }

  local frontmatter_ = frontmatter and frontmatter or self:frontmatter()
  if vim.tbl_isempty(frontmatter_) then
    return {}
  end

  for line in
    iter(yaml.dumps_lines(frontmatter_, function(a, b)
      local a_idx = nil
      local b_idx = nil
      for i, k in ipairs({ "id", "aliases", "tags" }) do
        if a == k then
          a_idx = i
        end
        if b == k then
          b_idx = i
        end
      end
      if a_idx ~= nil and b_idx ~= nil then
        return a_idx < b_idx
      elseif a_idx ~= nil then
        return true
      elseif b_idx ~= nil then
        return false
      else
        return a < b
      end
    end))
  do
    table.insert(new_lines, line)
  end

  table.insert(new_lines, "---")
  if not self.has_frontmatter then
    -- Make sure there's an empty line between end of the frontmatter and the contents.
    table.insert(new_lines, "")
  end

  if eol then
    return vim.tbl_map(function(l)
      return l .. "\n"
    end, new_lines)
  else
    return new_lines
  end
end

--- Save the file to a file.
--- In general this only updates the frontmatter and header, leaving the rest of the contents unchanged
--- unless you use the `update_content()` callback.
---
---@param opts { path: string|obsidian.Path|?, insert_frontmatter: boolean|?, frontmatter: table|?, update_content: (fun(lines: string[]): string[])|? }|? Options.
---
--- Options:
---  - `path`: Specify a path to save to. Defaults to `self.path`.
---  - `insert_frontmatter`: Whether to insert/update frontmatter. Defaults to `true`.
---  - `frontmatter`: Override the frontmatter. Defaults to the result of `self:frontmatter()`.
---  - `update_content`: A function to update the contents of the file. This takes a list of lines
---    representing the text to be written excluding frontmatter, and returns the lines that will
---    actually be written (again excluding frontmatter).
File.save = function(self, opts)
  opts = opts or {}

  if self.path == nil and opts.path == nil then
    error("a path is required")
  end

  local save_path = Path.new(assert(opts.path or self.path)):resolve()
  assert(save_path:parent()):mkdir({ parents = true, exist_ok = true })

  -- Read contents from existing file or buffer, if there is one.
  -- TODO: check for open buffer?
  ---@type string[]
  local content = {}
  ---@type string[]
  local existing_frontmatter = {}
  if self.path ~= nil and self.path:is_file() then
    with(open(tostring(self.path)), function(reader)
      local in_frontmatter, at_boundary = false, false -- luacheck: ignore (false positive)
      for idx, line in enumerate(reader:lines()) do
        if idx == 1 and File._is_frontmatter_boundary(line) then
          at_boundary = true
          in_frontmatter = true
        elseif in_frontmatter and File._is_frontmatter_boundary(line) then
          at_boundary = true
          in_frontmatter = false
        else
          at_boundary = false
        end

        if not in_frontmatter and not at_boundary then
          table.insert(content, line)
        else
          table.insert(existing_frontmatter, line)
        end
      end
    end)
  elseif self.title ~= nil then
    -- Add a header.
    table.insert(content, "# " .. self.title)
  end

  -- Pass content through callback.
  if opts.update_content then
    content = opts.update_content(content)
  end

  ---@type string[]
  local new_lines
  if opts.insert_frontmatter ~= false then
    -- Replace frontmatter.
    new_lines = compat.flatten({ self:frontmatter_lines(false, opts.frontmatter), content })
  else
    -- Use existing frontmatter.
    new_lines = compat.flatten({ existing_frontmatter, content })
  end

  -- Write new lines.
  with(open(tostring(save_path), "w"), function(writer)
    for _, line in ipairs(new_lines) do
      writer:write(line .. "\n")
    end
  end)
end

--- Save frontmatter to the given buffer.
---
---@param opts { bufnr: integer|?, insert_frontmatter: boolean|?, frontmatter: table|? }|? Options.
---
---@return boolean updated True if the buffer lines were updated, false otherwise.
File.save_to_buffer = function(self, opts)
  opts = opts or {}

  local bufnr = opts.bufnr
  if not bufnr then
    bufnr = self.bufnr or 0
  end

  local cur_buf_file = File.from_buffer(bufnr)

  ---@type string[]
  local new_lines
  if opts.insert_frontmatter ~= false then
    new_lines = self:frontmatter_lines(nil, opts.frontmatter)
  else
    new_lines = {}
  end

  if util.buffer_is_empty(bufnr) and self.title ~= nil then
    table.insert(new_lines, "# " .. self.title)
  end

  ---@type string[]
  local cur_lines = {}
  if cur_buf_file.frontmatter_end_line ~= nil then
    cur_lines = vim.api.nvim_buf_get_lines(bufnr, 0, cur_buf_file.frontmatter_end_line, false)
  end

  if not vim.deep_equal(cur_lines, new_lines) then
    vim.api.nvim_buf_set_lines(
      bufnr,
      0,
      cur_buf_file.frontmatter_end_line and cur_buf_file.frontmatter_end_line or 0,
      false,
      new_lines
    )
    return true
  else
    return false
  end
end

return File
