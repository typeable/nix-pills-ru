with (import <nixpkgs> {});
derivation {
  name = "simple";
  builder = "${bash}/bin/bash";
  args = [ ./simple_builder.sh ]; # Сборщик
  inherit gcc coreutils; # Зависимости
  src = ./simple.c;
  system = builtins.currentSystem;
}
