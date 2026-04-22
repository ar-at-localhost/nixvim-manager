rockspec_format = "3.0"
package = "nixvim-manager"
version = "0.0.1-1"

source = {
  url = "https://github.com/ar-at-localhost/nixvim-manager.git",
  tag = "v0.0.1",
}

description = {
  summary = "Nixvim Manager Neovim Plugin",
  detailed = "A plugin to manage your Nixvim builds right in Neovim.",
  homepage = "https://github.com/ar-at-localhost/nixvim-manager",
  license = "GPL-3.0",
}

dependencies = {
  "lua >= 5.1",
}

build = {
  type = "builtin",
  modules = {
    ["nixvim-manager"] = "lua/nixvim-manager/init.lua",
  },
}
