{
  lib,
  config,
  pkgs,
  inputs,
  ...
}: let
  inherit (pkgs.stdenv.hostPlatform) system;
  inherit (inputs) nixvim np yalms;
  pkgs-unstable = import inputs.nixpkgs-unstable {
    inherit (pkgs.stdenv) system;
  };
  nvim = import ./nix/nixvim.nix {inherit lib config system pkgs pkgs-unstable nixvim np yalms;};
  o = "${pkgs.vimPlugins.orgmode}/lua";
  pp = "${pkgs.vimPlugins.plenary-nvim}";
  c = "${pkgs.vimPlugins.catppuccin-nvim}/lua";
  p = "${pp}/lua";
  s = "${pkgs.vimPlugins.snacks-nvim}/lua";
  y = "${yalms.packages.${system}.default}/lua";
  test = pkgs.writeShellScriptBin "test" ''
    export HOME=$(mktemp -d)
    export XDG_CONFIG_HOME=$HOME/.config
    export XDG_DATA_HOME=$HOME/.local/share
    export XDG_STATE_HOME=$HOME/.local/state
    export XDG_CACHE_HOME=$HOME/.cache
    export LUA_PATH=";${o}/?.lua;${o}/?/init.lua;${c}/?.lua;${c}/?/init.lua;${p}/?.lua;${p}/?/init.lua;${s}/?.lua;${s}/?/init.lua;${y}/?.lua;${y}/?/init.lua;;"

    ${nvim}/bin/nvim --headless -u NONE -i NONE --noplugin \
      -c "set rtp+=." \
      -c "runtime plugin/plenary.vim" \
      -c "PlenaryBustedDirectory ./tests { timeout = 5 * 60 * 1000 }" \
      -c "qa!"
  '';
in {
  env = {
    GITHUB_TOKEN = null;
    NVIM_SNACKS_LUA_TYPES = "${pkgs.vimPlugins.snacks-nvim}/lua";
  };

  cachix.enable = false;
  packages = with pkgs; [luarocks stylua alejandra nvim test];

  git-hooks = {
    hooks = {
      alejandra.enable = true;
      stylua.enable = true;
    };
  };

  enterTest = ''
    ${test}/bin/test
  '';

  enterShell = ''
    export ORGMODE_LUA_TYPES=${o}/
    echo ${test}/bin/test
    echo " Nixvim manager development environment"
  '';
}
