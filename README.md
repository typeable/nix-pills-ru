# Nix pills in russian

This repo contains a presentation about nix based on the wonderful [nix-pills](https://nixos.org/nixos/nix-pills).

Markdown document is located [here](./presentation.md).

PDF is located in the ["releases" tab in github repo](https://github.com/typeable/nix-pills-ru/releases).

To enter an environment with all the needed packages, run `nix-shell`.

To build PDF of the presentation and speaker's notes, run `make` (either after installing `pandoc`, `pandoc-filter-graphviz` and `graphviz` or from within the `nix-shell`).

To start automatic regeneration of aforementioned files, run `make autoreload`.
