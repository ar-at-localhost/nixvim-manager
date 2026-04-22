{
  pkgs,
  yalms,
  system,
  ...
}: let
  src = pkgs.lib.cleanSourceWith {
    src = ../.;
    filter = path: _: let
      rel = pkgs.lib.removePrefix (toString ../.) (toString path);
    in
      pkgs.lib.hasPrefix "/lua" rel
      || pkgs.lib.hasPrefix "/plugin" rel;
  };
in
  pkgs.vimUtils.buildVimPlugin {
    pname = "nixvim-manager";
    version = "unstable";
    inherit src;
    dependencies = [pkgs.vimPlugins.snacks-nvim yalms.packages.${system}.default];
  }
