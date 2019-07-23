nix.pdf: nix.md; pandoc nix.md -t beamer --slide-level=2 --pdf-engine xelatex -F pandoc-filter-graphviz -o nix.pdf
nix.html: nix.md; pandoc nix.md -t slidy -F pandoc-filter-graphviz -o nix.html;
speaker-notes.md: nix.md; sed -e "/<!--/,/-->/!d" nix.md | sed -e "s/<!--//" | sed -e "s/-->/\n\* \* \*/" > speaker-notes.md
speaker-notes.html: speaker-notes.md; pandoc speaker-notes.md -o speaker-notes.html

build: nix.pdf nix.html speaker-notes.html

autoreload: ; while sleep 1; do make --no-print-directory -s; done

all: build
