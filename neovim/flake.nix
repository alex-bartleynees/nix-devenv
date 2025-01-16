{
  description = "Neovim development environment";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

        isLinux = system == "x86_64-linux" || system == "aarch64-linux";
        isDarwin = system == "x86_64-darwin" || system == "aarch64-darwin";

        # Build dependencies
        buildDeps = with pkgs; [ gcc gnumake cmake pkg-config unzip curl gzip ];

        # Core dependencies
        neovimDeps = with pkgs; [ neovim tree-sitter ];

        libraries = with pkgs;
          [ stdenv.cc.cc ] ++ (if isLinux then [ glibc ] else [ ]);

        # Function to check if rebuild is needed
        checkRebuildNeeded = pkgs.writeScriptBin "check-rebuild-needed" ''
          #!${pkgs.bash}/bin/bash
          DIR="$1"
          STAMP_FILE="$DIR/.build_stamp"

          # Create directory for stamp file if it doesn't exist
          mkdir -p "$(dirname "$STAMP_FILE")"

          # First build case
          if [ ! -f "$STAMP_FILE" ]; then
            echo "true"
            exit 0
          fi

          # Safe reading of last build time
          LAST_BUILD=$(cat "$STAMP_FILE" 2>/dev/null || echo "0")

          # Count files newer than stamp file, suppress errors
          LATEST_CHANGE=$(find "$DIR" -type f -not -path '*/\.*' -newer "$STAMP_FILE" 2>/dev/null | wc -l || echo "0")

          if [ "$LATEST_CHANGE" -gt 0 ]; then
            echo "true"
          else
            echo "false"
          fi
        '';

        # Function to mark build as complete
        markBuildComplete = pkgs.writeScriptBin "mark-build-complete" ''
          #!${pkgs.bash}/bin/bash
          DIR="$1"
          date +%s > "$DIR/.build_stamp"
        '';

        # Create a package that includes all dependencies
        neovimPackage = pkgs.symlinkJoin {
          name = "neovim-complete";
          paths = buildDeps ++ neovimDeps ++ libraries
            ++ [ checkRebuildNeeded markBuildComplete ];
        };
      in {
        packages.default = neovimPackage;
        devShell = pkgs.mkShell {
          NIX_BUILD_SHELL = "${pkgs.zsh}/bin/zsh";
          buildInputs = buildDeps ++ neovimDeps ++ libraries
            ++ [ checkRebuildNeeded markBuildComplete ];

          shellHook = ''
            ${if isLinux then
              ''export NIX_LD="${pkgs.glibc}/lib/ld-linux-x86-64.so.2"''
            else
              ""}
            ${if isLinux then
              ''
                export LD_LIBRARY_PATH="${
                  pkgs.lib.makeLibraryPath libraries
                }:$LD_LIBRARY_PATH"''
            else
              ""}
            export PATH="$HOME/.local/share/nvim/mason/bin:$PATH"
            export NVIM_CONFIG_DIR="$HOME/.config/nvim"

            # Set up Lua module path for tests
            export LUA_PATH="./?.lua;./?/init.lua;$HOME/.local/share/nvim/lazy/?/lua/?.lua;$HOME/.local/share/nvim/lazy/?/lua/?/init.lua;;"
            export LUA_CPATH="./?.so;$HOME/.local/share/nvim/lazy/?/lua/?.so;;"


            TELESCOPE_FZF_PATH="$HOME/.local/share/nvim/lazy/telescope-fzf-native.nvim"
            if [ -d "$TELESCOPE_FZF_PATH" ]; then
              if [ "$(check-rebuild-needed "$TELESCOPE_FZF_PATH")" = "true" ]; then
                echo "Building telescope-fzf-native..."
                cd "$TELESCOPE_FZF_PATH"
                make clean
                make
                mark-build-complete "$TELESCOPE_FZF_PATH"
                cd - > /dev/null
              fi
            fi

            # Build other C dependencies only if needed
            for plugin_dir in "$HOME/.local/share/nvim/lazy"/*; do
              if [ -f "$plugin_dir/Makefile" ] && [ "$plugin_dir" != "$TELESCOPE_FZF_PATH" ]; then
                if [ "$(check-rebuild-needed "$plugin_dir")" = "true" ]; then
                  echo "Building $plugin_dir..."
                  cd "$plugin_dir"
                  make clean
                  # Skip tests by explicitly calling make binary
                  if [ -f "Makefile" ] && grep -q "^binary:" "Makefile"; then
                    make binary
                  else
                    make SKIP_TESTS=1
                  fi
                  mark-build-complete "$plugin_dir"
                  cd - > /dev/null
                fi
              fi
            done

            echo "Neovim development environment loaded!"
            echo "Note: If plugins still need building, run :Lazy sync in Neovim"
          '';
        };
      });
}
