{
  description = "Docker development environment";

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
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            docker
            docker-compose
            docker-credential-helpers
            docker-client
            docker-buildx
          ];

          shellHook = ''
            echo "Docker development environment loaded!"
            echo "Docker version: $(docker --version)"
            echo "Docker Compose version: $(docker-compose --version)"

            if [ -z "$DOCKER_HOST" ]; then
              export DOCKER_HOST="unix:///var/run/docker.sock"
            fi
          '';
        };

        # You can also add packages if needed
        packages = {
          docker = pkgs.docker;
          docker-compose = pkgs.docker-compose;
        };

        # Default package
        defaultPackage = pkgs.docker;
      });
}
