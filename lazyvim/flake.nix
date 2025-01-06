{
  description = "LazyVim development environment";
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
        
        # Build dependencies
        buildDeps = with pkgs; [
          gcc
          gnumake
          cmake
          pkg-config
          unzip
          curl
          gzip
        ];
        
        # Core dependencies
        neovimDeps = with pkgs; [
          neovim
          git
          ripgrep
          fd
          nodejs
          nodePackages.typescript
          nodePackages.typescript-language-server
          nodePackages.prettier
          python3
          python3Packages.python-lsp-server
          tree-sitter
          #fzf
        ];
        
        libraries = with pkgs; [
          stdenv.cc.cc
          glibc
        ];

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

        # LazyVim wrapper script
        lazyvim = pkgs.writeScriptBin "lazyvim" ''
          #!${pkgs.bash}/bin/bash
          export NVIM_APPNAME="lazyvim"
          exec nvim "$@"
        '';

      # Create a package that includes all dependencies
        lazyvimPackage = pkgs.symlinkJoin {
          name = "lazyvim-complete";
          paths = buildDeps ++ neovimDeps ++ libraries ++ [ 
            checkRebuildNeeded
            markBuildComplete
            lazyvim
          ];
        };
      in
      {
        packages.default = lazyvimPackage;
        devShell = pkgs.mkShell {
          NIX_BUILD_SHELL = "${pkgs.zsh}/bin/zsh";
          buildInputs = buildDeps ++ neovimDeps ++ libraries ++ [ 
            checkRebuildNeeded
            markBuildComplete
            lazyvim
          ];
          NIX_LD = "${pkgs.glibc}/lib/ld-linux-x86-64.so.2";
          
          shellHook = ''
            export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath libraries}:$LD_LIBRARY_PATH"
            export PATH="$HOME/.local/share/lazyvim/mason/bin:$PATH"
            
            # Set up Lua module path for tests
            export LUA_PATH="./?.lua;./?/init.lua;$HOME/.local/share/lazyvim/lazy/?/lua/?.lua;$HOME/.local/share/lazyvim/lazy/?/lua/?/init.lua;;"
            export LUA_CPATH="./?.so;$HOME/.local/share/lazyvim/lazy/?/lua/?.so;;"

        # Build other C dependencies only if needed
            for plugin_dir in "$HOME/.local/share/lazyvim/lazy"/*; do
              if [ -f "$plugin_dir/Makefile" ]; then
                if [ "$(check-rebuild-needed "$plugin_dir")" = "true" ]; then
                  echo "Building $plugin_dir..."
                  cd "$plugin_dir"
                  
                  # For neo-tree specifically bypass the test running completely
                  if [[ "$plugin_dir" == */neo-tree.nvim ]]; then
                    echo "Skipping build for neo-tree.nvim as it's not required"
                    cd - > /dev/null
                    continue
                  fi
                  
                  # For other plugins
                  if [ -f "Makefile" ]; then
                    make clean
                    # Try different make targets to skip tests
                    if grep -q "^binary:" "Makefile"; then
                      make binary
                    elif grep -q "^build:" "Makefile"; then
                      make build
                    else
                      SKIP_TESTS=1 NO_TESTS=1 make
                    fi
                  fi
                  mark-build-complete "$plugin_dir"
                  cd - > /dev/null
                fi
              fi
            done
            
            echo "LazyVim development environment loaded!"
            echo "Use 'lazyvim' command to start Neovim"
          '';
        };
      });
}
