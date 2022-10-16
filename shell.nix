{ sources ? import ./nix/sources.nix, pkgs ? import sources.nixpkgs {
  overlays = [ ];
  config = { };
} }:

with pkgs;
let
  lib = import <nixpkgs/lib>;
  inherit (lib) optional optionals;

  packages = with pkgs;
    [
      (python310.withPackages (ps: with ps; [ pynvim pip virtualenv ipython ]))

      # Without this, we see a whole bunch of warnings about LANG, LC_ALL and locales in general.
      # The solution is from: https://github.com/NixOS/nix/issues/318#issuecomment-52986702
      glibcLocales
      coreutils
      git
    ] ++ lib.optional stdenv.isLinux inotify-tools
    ++ lib.optionals stdenv.isDarwin
    (with darwin.apple_sdk.frameworks; [ CoreFoundation CoreServices ]);

  env = buildEnv {
    name = "dev-environment";
    paths = packages;
  };

in stdenv.mkDerivation {
  name = "ecosystem-environment";

  buildInputs = [ env ];

  shellHook = ''
    if [[ ! -d venv ]]; then
      pip freeze | grep "virtualenv" &> /dev/null || pip install virtualenv
      python -m virtualenv venv --download
      source venv/bin/activate
    else
      source venv/bin/activate
    fi
    pip install -r ./requirements/dev-requirements.lock.txt -vv || exit 1
  '';
  enableParallelBuilding = true;

  LOCALE_ARCHIVE =
    if stdenv.isLinux then "${glibcLocales}/lib/locale/locale-archive" else "";

  nobuild = ''
    echo Do not run this derivation with nix-build, it can only be used with nix-shell
  '';
}
