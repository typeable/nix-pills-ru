all: presentation.pdf presentation.html speaker-notes.html
.PHONY : all


.PHONY: autoreload
autoreload: ; while sleep 1; do make --no-print-directory -s; done


%.pdf: %.md; pandoc $< -t beamer --slide-level=2 --pdf-engine xelatex -F pandoc-filter-graphviz -o $@
%.html: %.md; pandoc $< -t slidy -F pandoc-filter-graphviz -o $@;


speaker-notes.md: presentation.md; sed -e "/<!--/,/-->/!d" nix.md | sed -e "s/<!--//" | sed -e "s/-->/\n\* \* \*/" > speaker-notes.md


