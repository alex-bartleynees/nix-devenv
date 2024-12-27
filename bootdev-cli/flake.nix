{
  description = "Development environment for bootdev CLI";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            go # Go compiler and tools
          ];

          shellHook = ''
            # Create GOPATH if it doesn't exist
            export GOPATH="$HOME/go"
            mkdir -p "$GOPATH"
            
            # Add GOPATH/bin to PATH
            export PATH="$GOPATH/bin:$PATH"
            
            # Install bootdev CLI
            echo "Installing bootdev CLI..."
            go install github.com/bootdotdev/bootdev@latest
            
            echo "bootdev CLI installation complete!"
          '';
        };
      }
    );
}
