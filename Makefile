build: ; eval $$buildPhase

autoreload: ; while inotifywait -qq nix.md; do eval $$buildPhase; done

all: build
