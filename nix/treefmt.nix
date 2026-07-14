{ pkgs, ... }: {
  # Used to find the project root
  projectRootFile = "flake.nix";

  # Enable nixfmt for Nix files
  programs.nixfmt = {
    enable = true;
    package = pkgs.nixfmt;
  };
}
