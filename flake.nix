{
  description = "Nixvim Manager";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  };

  outputs = {
    nixpkgs,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {
          inherit system;
        };

        nixvim-manager = import ./nix/nixvim-manager.nix {inherit pkgs;};
      in {
        packages.default = nixvim-manager;
      }
    );
}
