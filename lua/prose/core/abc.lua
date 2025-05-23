local ABC = {}

---@class obsidian.ABC
---@field init function an init function which essentially calls 'setmetatable({}, mt)'.
---@field as_tbl function get a raw table with only the instance's fields
---@field mt table the metatable

---Create a new class.
---
---This handles the boilerplate of setting up metatables correctly and consistently when defining new classes,
---and comes with some better default metamethods, like '.__eq' which will recursively compare all fields
---that don't start with a double underscore.
---
---When you use this you should call `.init()` within your constructors instead of `setmetatable()`.
---For example:
---
---```lua
---    local Foo = new_class()
---
---    Foo.new = function(x)
---      local self = Foo.init()
---      self.x = x
---      return self
---    end
---```
---
---The metatable for classes created this way is accessed with the field `.mt`. This way you can easily
---add/override metamethods to your classes. Continuing the example above:
---
---```lua
---    Foo.mt.__tostring = function(self)
---      return string.format("Foo(%d)", self.x)
---    end
---
---    local foo = Foo.new(1)
---    print(foo)
---```
---
---Alternatively you can pass metamethods directly to 'new_class()'. For example:
---
---```lua
---    local Foo = new_class {
---      __tostring = function(self)
---        return string.format("Foo(%d)", self.x)
---      end,
---    }
---```
---
---@param metamethods table|? {string, function} - Metamethods
---@param base_class table|? A base class to start from
---@return obsidian.ABC
ABC.new_class = function(metamethods, base_class)
  local class = base_class and base_class or {}

  -- Metatable for the class so that all instances have the same metatable.
  class.mt = vim.tbl_extend("force", {
    __index = class,
    __eq = function(a, b)
      -- In order to use 'vim.deep_equal' we need to pull out the raw fields first.
      -- If we passed 'a' and 'b' directly to 'vim.deep_equal' we'd get a stack overflow due
      -- to infinite recursion, since 'vim.deep_equal' calls the '.__eq' metamethod.
      local a_fields = a:as_tbl()
      local b_fields = b:as_tbl()
      return vim.deep_equal(a_fields, b_fields)
    end,
  }, metamethods and metamethods or {})

  class.init = function(t)
    local self = setmetatable(t and t or {}, class.mt)
    return self
  end

  class.as_tbl = function(self)
    local fields = {}
    for k, v in pairs(self) do
      if not vim.startswith(k, "__") then
        fields[k] = v
      end
    end
    return fields
  end

  return class
end

return ABC
