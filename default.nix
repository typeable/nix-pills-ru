with import <nixpkgs> { };
let
  pandoc-filter-graphviz = stdenv.mkDerivation rec {
    name = "pandoc-filter-graphviz";
    src = ./pandoc-filter-graphviz;
    buildInputs = [ (ghc.withPackages (ps: with ps; [ pandoc ])) ];
    propogatedBuildInputs = [ graphviz dot2tex ];
    buildPhase = "ghc --make Main.hs -o ${name}";
    installPhase = "mkdir -p $out/bin; cp ${name} $out/bin";
  };
in stdenv.mkDerivation rec {
  name = "presentation";
  buildInputs = [
    pandoc
    texlive.combined.scheme-full
    pandoc-filter-graphviz
    fontconfig
    roboto
    hack-font
    graphviz
    dot2tex
  ];
  
  src = ./.;
  
  phases = [ "buildPhase" ];
  
  preferLocalBuild = true;
}
