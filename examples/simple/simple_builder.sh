export PATH="$coreutils/bin:$gcc/bin" # Переменные из derivation
mkdir -p $out/bin # Создадим выходную директорию
gcc -o $out/bin/simple $src # Соберем нашу программу
