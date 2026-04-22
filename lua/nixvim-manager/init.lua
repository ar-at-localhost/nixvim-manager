---@class Global
---@field __nixvim_manager_nvim NixvimManager
G = G or {}
local M = {}

---@param opts? NixvimManagerOpts
function M.setup(opts)
  require("nixvim-manager.views").setup()
  local NixvimManager = require("nixvim-manager.manager")

  G.__nixvim_manager_nvim = NixvimManager:new(opts)
  return G.__nixvim_manager_nvim
end

function M.get()
  return G.__nixvim_manager_nvim
end

return M
