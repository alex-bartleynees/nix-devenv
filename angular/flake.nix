{
  description = "Angular development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            nodejs_20  # Latest LTS version
            nodePackages.npm
            nodePackages."@angular/cli"  # Quoted to handle special characters
            chromium  # For testing
            git
          ];

          shellHook = ''
            export CHROME_BIN=${pkgs.chromium}/bin/chromium
            export PATH="$PWD/node_modules/.bin:$PATH"
            
            # Create a new Angular project if one doesn't exist
            if [ ! -f "package.json" ]; then
              echo "No Angular project found. Use 'ng new project-name' to create one."
            fi
          '';
        };
      }
    );
}
