{
  system,
  pkgs,
  nixvim,
  np,
  yalms,
  ...
}: (nixvim.legacyPackages.${system}.makeNixvimWithModule {
  inherit pkgs;

  module = {lib, ...}: let
    example = {
      bases = {
        web = ''
          { bases, np, ...}: bases.default.extend {
            imports = [np.nixvimModules.langs.web];
          }
        '';
      };

      nixvim = {
        spa = {
          dirs = ["/projects/a/app-stable/" "/projects/a/app/"];
          initial_content = ''
            { bases, np, ...}: bases.web.extend {
                plugins.lsp.servers.svelte.enable = true;
            }
          '';
        };
      };
    };

    example_settings = lib.nixvim.lua.toLuaObject example;
  in {
    imports = [
      np.nixvimModules.base
      np.nixvimModules.xtras.orgmode
    ];

    extraPlugins = [(import ./nixvim-manager.nix {inherit pkgs yalms system;}) yalms.packages.${system}.default];

    extraConfigLuaPost = ''
      require("nixvim-manager").setup(${example_settings})
    '';
  };

  extraSpecialArgs = {
    inherit (pkgs) stdenv;
    inherit np nixvim;
  };
})
