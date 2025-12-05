{
  description = "A Nix-flake-based Nix development environment";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.treefmt-nix.url = "github:numtide/treefmt-nix";

  outputs = { self, nixpkgs, treefmt-nix }:
    let
      supportedSystems =
        [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forEachSupportedSystem = f:
        nixpkgs.lib.genAttrs supportedSystems
        (system: f { pkgs = import nixpkgs { inherit system; }; });

      # Eval the treefmt modules from ./treefmt.nix
      treefmtEval = nixpkgs.lib.genAttrs supportedSystems (system:
        treefmt-nix.lib.evalModule (import nixpkgs { inherit system; })
        ./treefmt.nix);
    in {
      # for `nix fmt`
      formatter = nixpkgs.lib.genAttrs supportedSystems
        (system: treefmtEval.${system}.config.build.wrapper);

      # for `nix flake check`
      checks = nixpkgs.lib.genAttrs supportedSystems (system: {
        formatting = treefmtEval.${system}.config.build.check self;
      });

      devShells = forEachSupportedSystem ({ pkgs }: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            nixfmt-classic # Classic nixfmt formatter
            nil # Nix LSP
          ];
        };
      });
    };
}
