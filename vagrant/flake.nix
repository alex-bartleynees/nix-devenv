{
  description = "Vagrant development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
          };
        };
      in
      {
        devShell = pkgs.mkShell {
          buildInputs = with pkgs; [
            vagrant
          ];

          shellHook = ''
            echo "Vagrant development environment activated!"
            echo "Vagrant version: $(vagrant --version)"
          '';
        };

        devShells.default = self.devShell.${system};
      });
}
