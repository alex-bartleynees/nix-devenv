{
  description = "A Nix-flake-based C# development environment";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forEachSupportedSystem = f: nixpkgs.lib.genAttrs supportedSystems (system: f {
        pkgs = import nixpkgs { 
          inherit system;
          config = {
            allowUnfree = true;
          };
        };
      });
    in
    {
      devShells = forEachSupportedSystem ({ pkgs }: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            dotnet-sdk_9
            csharp-ls
          ];
          
          shellHook = ''
            export DOTNET_ROOT="${pkgs.dotnet-sdk_9}"
            export PATH=$PATH:$HOME/.dotnet/tools
            echo ".NET $(dotnet --version) development environment ready"
          '';
        };
      });
    };
}