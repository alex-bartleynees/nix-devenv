{ pkgs, ... }: {
  # Used to find the project root
  projectRootFile = "flake.nix";

  # Enable nixfmt-classic for Nix files
  programs.nixfmt = {
    enable = true;
    package = pkgs.nixfmt-classic;
  };
}
