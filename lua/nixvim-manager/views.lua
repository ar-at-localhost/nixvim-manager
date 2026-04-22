local M = {
  setup = function()
    local nixvim_picker = require("nixvim-manager.nixvim")
    Snacks.picker.sources["nixvim"] = nixvim_picker
  end,
}

return M
