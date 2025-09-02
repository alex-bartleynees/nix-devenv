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
        buildDeps = with pkgs; [ gcc gnumake cmake pkg-config unzip curl gzip rustc cargo ];

        # Core dependencies with common LSP servers
        neovimDeps = with pkgs; [ 
          neovim 
          tree-sitter 
          nodejs_22 
          # Common LSP servers that work better as system packages
          lua-language-server
          nil # Nix LSP
          nodePackages.typescript-language-server
          nodePackages.vscode-langservers-extracted # html, css, json, eslint
          pyright
          # Add Python pip support
          python3Packages.pip
        ];

        libraries = with pkgs;
          [ stdenv.cc.cc ] ++ (if isLinux then [ glibc ] else [ ]);

        # Function to check if rebuild is needed
        checkRebuildNeeded = pkgs.writeScriptBin "nvim-check-rebuild-needed" ''
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

          # Count files newer than stamp file, limit search depth for performance
          LATEST_CHANGE=$(find "$DIR" -maxdepth 3 -type f -not -path '*/\.*' -newer "$STAMP_FILE" 2>/dev/null | wc -l || echo "0")

          if [ "$LATEST_CHANGE" -gt 0 ]; then
            echo "true"
          else
            echo "false"
          fi
        '';

        # Function to mark build as complete
        markBuildComplete = pkgs.writeScriptBin "nvim-mark-build-complete" ''
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
            # Improved PATH handling - add Mason after system tools to avoid conflicts
            # but allow Mason to override if explicitly needed
            export MASON_BIN="$HOME/.local/share/nvim/mason/bin"
            if [ -d "$MASON_BIN" ]; then
              # Remove Mason from PATH if already present
              export PATH=$(echo "$PATH" | sed "s|:*$MASON_BIN:*|:|g" | sed "s|^:||" | sed "s|:$||")
              # Add Mason at the end so system tools take precedence
              export PATH="$PATH:$MASON_BIN"
            fi
            export NVIM_CONFIG_DIR="$HOME/.config/nvim"

            # Set up Lua module path for tests
            export LUA_PATH="./?.lua;./?/init.lua;$HOME/.local/share/nvim/lazy/?/lua/?.lua;$HOME/.local/share/nvim/lazy/?/lua/?/init.lua;;"
            export LUA_CPATH="./?.so;$HOME/.local/share/nvim/lazy/?/lua/?.so;;"


            TELESCOPE_FZF_PATH="$HOME/.local/share/nvim/lazy/telescope-fzf-native.nvim"
            if [ -d "$TELESCOPE_FZF_PATH" ]; then
              if [ "$(nvim-check-rebuild-needed "$TELESCOPE_FZF_PATH")" = "true" ]; then
                echo "Building telescope-fzf-native..."
                cd "$TELESCOPE_FZF_PATH"
                make clean
                if make; then
                  nvim-mark-build-complete "$TELESCOPE_FZF_PATH"
                  echo "Successfully built telescope-fzf-native"
                else
                  echo "Failed to build telescope-fzf-native, skipping..."
                fi
                cd - > /dev/null
              fi
            fi

            # Build other C dependencies only if needed with improved error handling
            for plugin_dir in "$HOME/.local/share/nvim/lazy"/*; do
              if [ -f "$plugin_dir/Makefile" ] && [ "$plugin_dir" != "$TELESCOPE_FZF_PATH" ]; then
                if [ "$(nvim-check-rebuild-needed "$plugin_dir")" = "true" ]; then
                  echo "Building $(basename "$plugin_dir")..."
                  cd "$plugin_dir"
                  
                  # Clean previous build
                  if ! make clean 2>/dev/null; then
                    echo "Warning: Failed to clean $(basename "$plugin_dir"), continuing..."
                  fi
                  
                  # Try different build targets with error handling
                  build_success=false
                  if [ -f "Makefile" ] && grep -q "^binary:" "Makefile"; then
                    if make binary; then
                      build_success=true
                    fi
                  elif make SKIP_TESTS=1 2>/dev/null; then
                    build_success=true
                  elif make 2>/dev/null; then
                    build_success=true
                  fi
                  
                  if [ "$build_success" = "true" ]; then
                    nvim-mark-build-complete "$plugin_dir"
                    echo "Successfully built $(basename "$plugin_dir")"
                  else
                    echo "Failed to build $(basename "$plugin_dir"), skipping..."
                  fi
                  
                  cd - > /dev/null
                fi
              fi
            done

            echo "Neovim development environment loaded!"
            echo "System LSP servers available: lua-language-server, nil, typescript-language-server, pyright"
            echo "Mason tools available in: $MASON_BIN"
            echo "Note: If plugins still need building, run :Lazy sync in Neovim"
          '';
        };
      });
}
