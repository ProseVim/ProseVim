local M = {}

require("prose.stats")
require("prose.line")

local utils = require("prose.core.utils")

M.setup = function(opts)
  print(utils.dump(opts))
end

-- Check for .prose dir
-- If in prose project then load else skip

return M
