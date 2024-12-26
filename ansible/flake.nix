{
  description = "Development environment with Ansible";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
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
            ansible
            ansible-lint
            python3
            python3Packages.pip
            python3Packages.pywinrm  # For Windows remote management
            python3Packages.jmespath # For JSON query support
            sshpass  # For password-based SSH authentication
          ];

          shellHook = ''
            echo "Ansible development environment loaded"
            echo "Ansible version: $(ansible --version | head -n1)"
          '';
        };
      });
}
