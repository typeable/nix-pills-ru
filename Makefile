loop: ; while inotifywait nix.md; do eval $$buildPhase; done

all: loop
