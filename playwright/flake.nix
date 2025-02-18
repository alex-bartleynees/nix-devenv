{
  description = "Angular development environment with Playwright based on FHS";

  inputs = { nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable"; };

  outputs = { nixpkgs, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      devShells.${system}.default = (pkgs.buildFHSEnv
        (pkgs.appimageTools.defaultFhsEnvArgs // {
          name = "Angular development environment";
          targetPkgs = pkgs:
            with pkgs; [
              nodejs_22
              nodePackages.npm
              chromium
              nodePackages."@angular/cli"
              git
              jq
              httpie
              zsh

              # Playwright system dependencies
              chromium
              firefox
              xvfb-run
              gtk3
              alsa-lib
              nss
              nspr
              atk
              cups
              dbus
              expat
              libdrm
              libxkbcommon
              mesa
              wayland
              xorg.libX11
              xorg.libXcomposite
              xorg.libXdamage
              xorg.libXext
              xorg.libXfixes
              xorg.libXrandr
              glib
              gobject-introspection
              pango
              cairo
              xorg.libxcb
              udev
              xorg.libXcursor
              xorg.libXi
              gdk-pixbuf
              xorg.libXrender
              freetype
              fontconfig

              harfbuzz
              icu
              libxml2
              sqlite
              libxslt
              lcms2
              woff2
              libevent
              libgcrypt
              libgpg-error
              libwebp
              libepoxy
              libjpeg
              libpng
              zlib
              enchant
              libsecret
              libtasn1
              hyphen
              pcre2
              libpsl
              nghttp2
              libevdev
              json-glib
              gnutls
              x264
              libffi

              # Service Worker dependencies
              systemd
              glibc
              glibc.dev
              openssl
              util-linux

              at-spi2-core
              at-spi2-atk
              libnotify
            ];

          profile = ''
            export PATH="$PWD/node_modules/.bin:$PATH"
            export npm_config_cache="$PWD/.npm"
            export NODE_OPTIONS="--enable-source-maps"
            export NG_CLI_ANALYTICS=false
            export PATH="$PWD/node_modules/.bin:$PATH"
            export PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=0
            export PLAYWRIGHT_BROWSERS_PATH="$PWD/playwright-browsers"
            export ANGULAR_DEV_ENVIRONMENT_LOADED=1
          '';
          runScript = "zsh";
        })).env;
    };
}
