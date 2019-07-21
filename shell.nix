with import <nixpkgs> { };
let
  diagrams-pandoc = (haskell.lib.doJailbreak
  (haskellPackages.diagrams-pandoc.overrideAttrs
  (_: { meta.isBroken = false; })));
  ghcDiagrams = ghc.withPackages (ps: with ps; [ diagrams-lib diagrams-builder diagrams-core SVGFonts ]);
in stdenv.mkDerivation rec {
  name = "presentation";
  buildInputs = [
    pandoc
    texlive.combined.scheme-full
    diagrams-pandoc
    fontconfig
    roboto
    hack-font
    
    inotify-tools
  ];
  
  NIX_GHC = "${ghcDiagrams}/bin/ghc";
  NIX_GHC_LIBDIR = "${ghcDiagrams}/lib/ghc-${ghcDiagrams.version}";
  
  FONTCONFIG_PATH = "${/etc/fonts}";
  
  src = ./.;
  
  phases = [ "buildPhase" ];
  
  preferLocalBuild = true;
  
  buildPhase = ''
    pandoc nix.md -t beamer --pdf-engine xelatex --filter diagrams-pandoc -o nix.pdf
  '';
}
