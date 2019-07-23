---
title: Nix
subtitle: Язык, пакетный менеджер и экосистема
author: Александр Бантьев @balsoft, typeable.io
description: |
  Вольный пересказ nix-pills на русском языке.
  https://nixos.org/nixos/nix-pills, автор Luca Bruno (aka Lethalman)
theme: Boadilla
colortheme: dolphin
mainfont: Roboto
monofont: Hack
aspectratio: 169
titlegraphic: images/nix.png
toc: true
header-includes:
  - \usepackage[utf8]{inputenc}
  - \usepackage[russian]{babel}
  - \uselanguage{Russian}
  - \languagepath{Russian}
  - \usepackage{tikz}
---

# Вступление

<!--
<meta charset="utf8" />
<title>Заметки выступающего</title>
-->

Основано на <https://nixos.org/nixos/nix-pills> . Огромная благодарность @Lethalman и @grahamc за написание и поддержку этого материала!

Я хотел бы, чтобы к концу презентации всем стало понятно

* Что такое Nix
* Как собрать пакеты из `contractor` с помощью nix
* Что находится в `contractor/nix/pkgs`
* Что находится в `contractor/nix/overlay.nix`
* Как писать несложные выражения на nix, не совершая неочевидных ошибок

Вы можете прекратить слушать после любой секции, и я надеюсь, что вы унесете какую-то полезную для себя информацию.


<!-- 
Как вы все скорее всего знаете, мы используем Nix для сборки и тестирования нашего кода. Я, Александр Бантьев (@balsoft) отвечаю за инфраструктуру сборки пакетов (Hydra, NixOps), а также за поддержание инструкций сборки в актуальном состоянии. Я бы хотел рассказать вам про nix с помощью вольного пересказа отличной серии статей ["Nix pills"](https://nixos.org/nixos/nix-pills)
-->

## Что такое nix?

<!-- 
Говоря "Nix", мы подразумеваем одну из двух его ипостасей -- Nix как язык или Nix как пакетный менеджер. Такая путаница возникла из-за того, что как DSL Nix имеет смысл только в связке со своим пакетным менеджером, а как пакетный менеджер он без своего языка слишком сложен в использовании, и Eelco Dolstra (создатель Nix) решил не разделять их.
-->

[Nix](https://nixos.org/nix) -- это

1. Язык
   + Декларативный
   + Функциональный
   + Чистый
   + Ленивый
   + Динамически типизированный
2. Пакетный менеджер
   + Атомарный
   + Повторяемый
   + Source/Binary


## Экосистема

<!-- 
Nix довольно быстро стал широко известен в узких кругах, и вокруг него возникла большая экосистема декларативных, атомарных инструментов, в том числе:

*  nixpkgs, репозиторий описаний пакетов на языке nix;
*  NixOS, дистрибутив GNU/Linux с интересным подходом к конфигурации системы;
*  NixOps, инструментарий для разворачивания виртуальных машин и приложений на них на базе NixOS;
*  Hydra, CI -- сервер;
*  Disnix, система для разворачивания распределенных систем.
-->

```{.graphviz layout=fdp}
digraph {
    graph [ dpi = 200; font = Hack; ];
    subgraph cluster_nix {
        "nix (пакетный менеджер)" -> "nix (язык)";
        "nix (язык)" -> "nix (пакетный менеджер)";
        color = blue;
    }
    cluster_nix -> Disnix;
    cluster_nix -> Hydra;
    cluster_nix -> nixpkgs -> NixOS -> NixOps;
}
```

    
# Nix как пакетный менеджер

> Nix is a powerful package manager for Linux and other Unix systems that makes package management reliable and reproducible. It provides atomic upgrades and rollbacks, side-by-side installation of multiple versions of a package, multi-user package management and easy setup of build environments.

*--- nixos.org/nix*

<!--
На https://nixos.org/nix заявлено, что nix -- это все-таки пакетный менеджер. С этого компонента мы и начнем.
-->

## Хранилище (nix store)

<!--
Центральным местом файловой системы для Nix является Хранилище (nix store). Именно здесь хранятся все файлы, с которыми оперирует наш пакетный менеджер: инструкции сборки и её результаты -- исполняемые файлы, документация, заголовочные файлы, etc.

Все элементы директории `/nix/store` имеют одинаковый формат имени -- `<hash>-<name>[-version][-output]`. Хэш вычисляется при добавлении в хранилище или при сборке на основе содержимого файла либо содержимого деривации (инструкции сборки), из которого этот путь был собран.
-->


> In the beginning was the Store, and the Store was with Nix, and the Store was Nix. 

*--- Nix manual, 1:1*


```bash 
$ ls /nix/store | wc -l
46251
$ nix add-to-store nix.conf
/nix/store/za34q8y0jcx3qsrnbrd005mh8zcnlrlr-nix.conf
```
### Формат имени
```
<hash>-<name>[-version][-output]
```
Например,
```
/nix/store/04mm93j20jlnwvhh21db674b3vy6fs54-pandoc-2.7.1-data
          |              hash              | name | ver | out |
```
    
## Принцип работы

<!-- 
В общих чертах, получение результата любого выражения (в терминологии ПМ -- пакета) на nix состоит из двух этапов -- вычисления (за это отвечает nix как язык), и сборки -- именно эта часть ложится на плечи nix как пакетного менеджера.
-->

```graphviz
digraph {
    graph [ dpi = 200; font = Hack; ]; 
    "myname.nix" -> "/nix/store/...-myname.drv" [ label = " Вычисление (nix как язык)" ];
    "/nix/store/...-myname.drv" -> "/nix/store/...-myname" [ label = " Сборка (nix как пакетный менеджер)" ];
}
```

## Деривации (derivations, `.drv` files)

<!--
Для сборки пакетов любому пакетному менеджеру нужны инструкции. Например, ABS (Arch build system) использует PKGBUILD, portage (Gentoo) использует EBUILD, brew использует recepies. Nix не является исключением, и для сборки он использует Деривации (.drv). Пример деривации (с добавленными мною переносами строки и пробелами для улучшения читаемости) -- на слайде.
-->


### `/nix/store/z3hhlxbckx4g3n9sw91nnvlkjvyw754p-myname.drv`
```
Derive
([("out"
  ,"/nix/store/40s0qmrfb45vlh6610rk29ym318dswdr-myname","","")]
,[]
,[]
,"mysystem"
,"mybuilder"
,[]
,[("builder","mybuilder")
 ,("name","myname")
 ,("out","/nix/store/40s0qmrfb45vlh6610rk29ym318dswdr-myname")
 ,("system","mysystem") ] )
```

## Краткая справка по инструментарию
### Собрать (build/realize) деривацию
```
$ nix-store -r /nix/store/z3hhlxbckx4g3n9sw91nnvlkjvyw754p-myname.drv
```
### Вычислить (evaluate) и затем собрать содержимое файла `default.nix`
```
$ nix build -f default.nix # или nix-build default.nix
```
### Вычислить, собрать и запустить интерактивное окружение
```
$ nix run -f default.nix # или nix-shell default.nix
```

# Nix как язык

<!--
В общих чертах разобравшись с пакетным менеджером, перейдем к языку. Большая часть синтаксиса, конструкций и идей будет знакома вам по другим языкам, поэтому мы быстро пробежимся по примерам, останавливаясь лишь на уникальных чертах и граблях, на которые легко наступить.
-->

Рассмотрим основы синтаксиса Nix.

Краткая инструкция для желающих повторить:
```bash
$ curl https://nixos.org/nix/install | sh
<...>
$ nix repl
```

## Числа, арифметика и комментарии
```
nix-repl> :t 4 # Показать тип выражения
an integer
nix-repl> 1 + 2 - 3 * 2
-3
nix-repl> 1 / 2
0
nix-repl> builtins.add 1 2
3
nix-repl> # Однострочный комментарий
nix-repl> /* Многострочный комментарий */
```
### Замечание
Арифметические операторы лучше обносить пробелами! У символов `/` и `-` есть особые значения в Nix
```
nix-repl> 6/2
/home/balsoft/6/2
```

## Булевы, булева арифметика и if
```
nix-repl> :t true
a boolean
nix-repl> true && false
false
nix-repl> true || false
true
nix-repl> if true || false then 3 else 4
3
nix-repl> if false then 5 else 6
6
```

## Строки (strings)
```
nix-repl> "foo"
"foo"
nix-repl> :t "foo"
a string
nix-repl> "Привет"
"Привет"
nix-repl> ''foo''
"foo"
nix-repl> ''
          foo
          bar
          ''
"foo\nbar\n"
```


## Переменные и стороковая интерполяция
```
nix-repl> foo = "hello"
nix-repl> "${foo}, world!"
"hello, world!"
```

### Замечание
Названия переменных могут содержать знак `-`
```
nix-repl> foo-bar = 10
nix-repl> foo-bar
10
```
Но не могут содержать не-ASCII!
```
nix-repl> привет
error: syntax error, unexpected $undefined, at (string):1:1
```

## Как избежать интерполяции?
Довольно часто встречаются ситуации, когда мы хотим вставить в строку последовательность `${...}` (например, в bash-код).

```
nix-repl> "\${foo}"
"${foo}"

nix-repl> ''test ''${foo} test''
"test ${foo} test"
```

## Пути (paths) и URL

```
nix-repl> /bin/sh
/bin/sh
nix-repl> :t /bin/sh
a path
nix-repl> ./hello # Относительно текущего .nix файла или PWD для repl
/home/balsoft/hello
nix-repl> https://typeable.io # Синтаксический сахар для строк
"https://typeable.io"
nix-repl> :t https://typeable.io
a string
```
### Замечание
Пути, как и названия переменных, не могут содержать не-ASCII. Я бы рассматривал это, как баг.
```
nix-repl> /home/balsoft/Документы
error: path '/home/balsoft/' has a trailing slash
```

## `NIX_PATH` и `<nixpkgs>`
<!--
`NIX_PATH` -- переменная, очень похожая на `PATH` по синтаксису значений (значения разделены двоеточием), в которой nix ищет пути запрошенные через синтаксис `<path>`.
-->
```
$ NIX_PATH=home=$HOME nix repl
nix-repl> <home>
/home/balsoft
^D
$ NIX_PATH=/home nix repl
nix-repl> <balsoft>
/home/balsoft
$ nix repl
nix-repl> <nixpkgs>
/nix/store/zzjhgd7p1y879z0y9pz70vjd45yfi9iz-nixpkgs
```
## Списки (lists)

Списки в Nix иммутабельны и могут содержать значения любых типов вперемешку.

```
nix-repl> [ 2 "foo" true (2+3) ]
[ 2 "foo" true 5 ]

```

### Замечание
Обратите внимание: элементы списка не разделены запятыми!
```
nix-repl> [ 1 + 2 ]
error: syntax error, unexpected '+', at (string):1:5
nix-repl> [ (1 + 2) ]
[ 3 ]
nix-repl> [ import ./hello.nix {} ]
[ «primop-app» /home/balsoft/hello.nix { ... } ]
```

## Множества аттрибутов (attribute sets, attrsets)
```
nix-repl> s = { foo = "bar"; a-b = "baz"; "123" = "num"; }
nix-repl> s
{ "123" = "num"; a-b = "baz"; foo = "bar"; }
nix-repl> s.a-b
"baz"
nix-repl> s."123"
"num"
nix-repl> s.${toString (122 + 1)}
"num"
nix-repl> s.abc or "not found" # Note that `or` is a keyword
"not found"
```
***
```
nix-repl> s ? "123"
true
nix-repl> s ? a-b
true
nix-repl> s ? sjdnfksjd
false
nix-repl> s // { a = 10; }
{ "123" = "num"; a = 10; a-b = "baz"; foo = "bar"; }
nix-repl> rec { a = 3; b = a + 4; } # Recursive attrset
{ a = 3; b = 7; }
```


## Let, with и inherit
```
nix-repl> let a = 3; b = 4; in a + b
7
nix-repl> let a = 4; b = a + 5; in b # Let definitions are recursive
9
nix-repl> let a = 3; a = 8; in a
error: attribute `a' at (string):1:12 already defined at (string):1:5
nix-repl> longName = { a = 3; b = 4; }
nix-repl> with longName; a + b
7
nix-repl> let a = 10; b = 20; in { inherit a; b = b + 1; }
{ a = 10; b = 21; }
nix-repl> { inherit (s) "123" foo; }
{ "123" = "num"; foo = "bar"; }
```

## Функции (functions)
``` 
nix-repl> x: x*2
«lambda»
nix-repl> double = x: x * 2
nix-repl> :t double
a function
nix-repl> double 3
6
nix-repl> greet = end: name: "Hello, ${name} ${end}"
nix-repl> greet "dredozubov" "!"
"Hello, dredozubov !"
nix-repl> greetExclamaition = greet "!"
nix-repl> greetExclamaition "s9gf4ult"
"Hello, s9gf4ult !"
```

## Паттерн-матчинг
```
nix-repl> greet = { name, end }: "Hello, ${name} ${end}"
nix-repl> greet { name = "ak3n"; exc = "!"; }
"Hello, ak3n !"
nix-repl> greet = { name, end ? "!" }: "Hello, ${name} ${end}"
nix-repl> greet { name = "ak3n"; }
"Hello, ak3n !"
nix-repl> greet { name = "ak3n"; end = "."; }
"Hello, ak3n ."
nix-repl> greet = { name, end ? "!", ... }: "Hello, ${name} ${end}"
nix-repl> greet { name = "ak3n"; end = "."; extra = "foo"; }
"Hello, ak3n ."
nix-repl> foo = {a, ...}@args: args // { a = a + 3; }
nix-repl> foo { a = 10; b = 11; }
{ a = 13; b = 11; }
```

## Подключения файлов (import)
### `number.nix`
```
3
```
### `function.nix`
```
a: a + 3
```
### Обратно в наш уютный repl
```
nix-repl> a = import ./number.nix
nix-repl> f = import ./function.nix
nix-repl> f a
6
```

## Деривации (derivation)
<!--
Вот мы и подошли к моменту, когда мы можем сделать свою собственную деривацию! Исследуем встроенную функцию `derivation`. Она возвращает attrset, но nix показывает его как `derivation`. Странные дела!
-->
```
nix-repl> d = derivation {
            name = "myname"; 
            builder = "mybuilder"; 
            system = "mysystem"; }
nix-repl> :t d
a set
nix-repl> d
«derivation /nix/store/z3hhlxbckx4g3n9sw91nnvlkjvyw754p-myname.drv»
```
## Деривации: сборка
<!--
Как вы помните, деривации -- это инструкции сборки для nix. Попробуем собрать нашу фейковую деривацию. nix подсказывает, что у нас система не `mysystem`, а `x86\_64-
linux`. Исправим это и попробуем ещё раз. Теперь проблема в том, что файла `mybuilder`, который должен собрать наш пакет, не существует. Fail. Остановимся и исследуем `derivation` поподробнее.
-->
```
nix-repl> :b d
[...]
error: a `mysystem' is required to build ..., but I am a `x86_64-linux'
nix-repl> d = derivation { 
            name = "myname"; 
            builder = "mybuilder"; 
            system = builtins.currentSystem; }
nix-repl> :b d
[...]
[...]: executing 'mybuilder': No such file or directory
```
## Деривации: что внутри?
<!--
Так как derivation -- это обычный attrset, мы можем исследовать его аттрибуты с помощью встроенного инструментария. Заметим, что `drvAttrs` содержит аргументы, переданные в функцию `derivation`, `out` совпадает с самой деривацией (т.к. на данный момент у нашей деривации только один результат), ну и восхитимся магией типизации на аттрибутах (так вот почему nix так странно себя ведет, показывая derivation вместо сета!). Также заметим, что `toString` превращает в строки только те сеты, которые содержат аттрибут `outPath`.
-->
```
nix-repl> builtins.attrNames d
[ "all" "builder" "drvAttrs" "drvPath" "name" 
 "out" "outPath" "outputName" "system" "type" ]
nix-repl> d.drvAttrs
{ builder = "mybuilder"; name = "myname"; system = "x86_64-linux"; }
nix-repl> (d == d.out)
true
nix-repl> { type = "derivation"; } # Типизация истинных джентельменов
«derivation ???»
nix-repl> toString d
"/nix/store/qaq9ir9w2a34dzkjmk3igfbibi5q59sd-myname"
nix-repl> toString { outPath = "blah"; }
"blah"
nix-repl> toString { a = 10; }
error: cannot coerce a set to a string, at (string):1:1
```
## Деривации: добавляем зависимости
```
nix-repl> :l <nixpkgs> # nixpkgs -- это огромная куча дериваций!
Added 10082 variables.
nix-repl> coreutils
«derivation /nix/store/...-coreutils-8.30.drv»
nix-repl> toString coreutils
"/nix/store/...-coreutils-8.30"
nix-repl> d = derivation { 
            name = "myname"; 
            builder = "${coreutils}/bin/true"; 
            system = builtins.currentSystem; }
nix-repl> :b d
builder for '...-myname.drv' failed to produce output path '...-myname'
```
## Деривации: смотрим на зависимости
<!--
`nix show-derivation` показывает содержимое деривации в виде pretty-printed JSON. Как мы видим, у нас в зависимостях появилась ссылка на coreutils.drv, и builder стал указывать на true.
-->
```
$ nix show-derivation /nix/store/...-myname.drv
{
  "/nix/store/apvmj79y84wivsnjc2vkv2q79a37nf7l-myname.drv": {
    [...]
    "inputDrvs": {
      "...-coreutils-8.30.drv": [
        "out"
      ]
    },
    "builder": "...-coreutils-8.30/bin/true",
    [...]
  }
}
```

## Деривации: рабочая деривация!
<!--
Исправим ошибку, которая не дает нам получить нашу первую собирающуюся деривацию! Создадим скрипт `builder.sh`, который создаст outPath. Обратите внимание: мы не будем указывать hashbang для нашего скрипта, потому что даже сам исполняемый файл bash лежит в `/nix/store`, и путь к нему мы можем определить только из nix. Из-за невозможности добавить hashbang, будем запускать наш сборщик как `bash builder.sh`:
-->
### `builder.sh`
```bash
declare -xp
echo foo > $out
```

### Уютный `nix repl`
```
nix-repl> :l <nixpkgs>
Added 10082 variables.
nix-repl> d = derivation { 
            name = "foo"; 
            builder = "${bash}/bin/bash"; 
            args = [ ./builder.sh ]; 
            system = builtins.currentSystem; } 
nix-repl> :b d
this derivation produced the following outputs:
  out -> /nix/store/82jrv90z3aj1lmzr437jpp7m9krnrrzf-foo
```
## Деривации: посмотрим на env
<!--
Посмотрим на то, что показал `declare -xp` (т.е. на переменные окружения, которые доступны внутри сборщика). `nix log` показывает вывод сборщика при сборке определенного пути.

* `$HOME` указывает в пустой `/homeless-shelter`
* `$PATH` тоже пуст
* `$PWD` указывает во временную директорию `/build` (на самом деле она находистся в `/tmp`)

Замечу, что все аргументы derivation окажутся в env сборщика.
-->
```
$ nix log /nix/store/...-foo
[...]
declare -x HOME="/homeless-shelter"
declare -x NIX_BUILD_CORES="0"
declare -x NIX_BUILD_TOP="/build"
declare -x NIX_LOG_FD="2"
declare -x NIX_STORE="/nix/store"
declare -x PATH="/path-not-set"
declare -x PWD="/build"
declare -x TEMP="/build"
declare -x builder="/nix/store/...-bash-4.4-p23/bin/bash"
declare -x name="foo"
declare -x out="/nix/store/82jrv90z3aj1lmzr437jpp7m9krnrrzf-foo"
declare -x system="x86_64-linux"
```


## Деривации: опакетим простую программу на C
<!--
Теперь, когда мы умеем создавать рабочие деривации, добавлять зависимости и передавать произвольные переменные в env их сборщика, попробуем опакетить простую программу на C.
На этот раз вылезем из привычного `nix repl` и напишем файл!

Для сборки программы нам нужны coreutils (для создания выходной директории) и gcc (для сборки). К счастью, эти (и десятки тысяч других) приложения уже опакечены в nixpkgs. Передадим их деривации как аргументы нашему `derivation`, и они окажутся в env сборщика.
-->
### `simple.c`
```C
void main() {
  puts("Simple!");
}
```

### `simple_builder.sh`
```bash
export PATH="$coreutils/bin:$gcc/bin" # Переменные из derivation
mkdir -p $out/bin # Создадим выходную директорию
gcc -o $out/bin/simple $src # Соберем нашу программу
```
***
### `simple.nix`
```
with (import <nixpkgs> {});
derivation {
  name = "simple";
  builder = "${bash}/bin/bash";
  args = [ ./simple_builder.sh ]; # Сборщик
  inherit gcc coreutils; # Зависимости
  src = ./simple.c;
  system = builtins.currentSystem;
}
```
### Поехали!
```
$ nix build -f simple.nix
[1 built, 0.0 MiB DL]
$ ./result/bin/simple
Simple!
```
<!--
Успех!
-->


***
### Посмотрим граф зависимостей (`nix-store -q result --graph`)
```graphviz
digraph G {
graph [ dpi=200; ]
"/nix/store/p6a11dai9b7xw3xgf44pgyr5kdlnr9rf-simple" [label = "simple", shape = box, style = filled];
"/nix/store/681354n3k44r8z90m35hm8945vsp95h1-glibc-2.27" -> "/nix/store/p6a11dai9b7xw3xgf44pgyr5kdlnr9rf-simple" [color = "black"];
"/nix/store/9sll05wmn9b05f0pm1pwfmmq92fg0syh-simple.c" -> "/nix/store/p6a11dai9b7xw3xgf44pgyr5kdlnr9rf-simple" [color = "red"];
"/nix/store/d4n93jn9fdq8fkmkm1q8f32lfagvibjk-gcc-7.4.0" -> "/nix/store/p6a11dai9b7xw3xgf44pgyr5kdlnr9rf-simple" [color = "green"];
"/nix/store/hlnxw4k6931bachvg5sv0cyaissimswb-gcc-7.4.0-lib" -> "/nix/store/p6a11dai9b7xw3xgf44pgyr5kdlnr9rf-simple" [color = "blue"];
"/nix/store/681354n3k44r8z90m35hm8945vsp95h1-glibc-2.27" [label = "glibc-2.27", shape = box, style = filled];
"/nix/store/9sll05wmn9b05f0pm1pwfmmq92fg0syh-simple.c" [label = "simple.c", shape = box, style = filled];
"/nix/store/d4n93jn9fdq8fkmkm1q8f32lfagvibjk-gcc-7.4.0" [label = "gcc-7.4.0", shape = box, style = filled];
"/nix/store/681354n3k44r8z90m35hm8945vsp95h1-glibc-2.27" -> "/nix/store/d4n93jn9fdq8fkmkm1q8f32lfagvibjk-gcc-7.4.0" [color = "magenta"];
"/nix/store/hlnxw4k6931bachvg5sv0cyaissimswb-gcc-7.4.0-lib" -> "/nix/store/d4n93jn9fdq8fkmkm1q8f32lfagvibjk-gcc-7.4.0" [color = "burlywood"];
"/nix/store/iiymx8j7nlar3gc23lfkcscvr61fng8s-zlib-1.2.11" -> "/nix/store/d4n93jn9fdq8fkmkm1q8f32lfagvibjk-gcc-7.4.0" [color = "black"];
"/nix/store/sr4253np2gz2bpha4gn8gqlmiw604155-glibc-2.27-dev" -> "/nix/store/d4n93jn9fdq8fkmkm1q8f32lfagvibjk-gcc-7.4.0" [color = "red"];
"/nix/store/hlnxw4k6931bachvg5sv0cyaissimswb-gcc-7.4.0-lib" [label = "gcc-7.4.0-lib", shape = box, style = filled];
"/nix/store/681354n3k44r8z90m35hm8945vsp95h1-glibc-2.27" -> "/nix/store/hlnxw4k6931bachvg5sv0cyaissimswb-gcc-7.4.0-lib" [color = "green"];
"/nix/store/iiymx8j7nlar3gc23lfkcscvr61fng8s-zlib-1.2.11" [label = "zlib-1.2.11", shape = box, style = filled];
"/nix/store/681354n3k44r8z90m35hm8945vsp95h1-glibc-2.27" -> "/nix/store/iiymx8j7nlar3gc23lfkcscvr61fng8s-zlib-1.2.11" [color = "blue"];
"/nix/store/sr4253np2gz2bpha4gn8gqlmiw604155-glibc-2.27-dev" [label = "glibc-2.27-dev", shape = box, style = filled];
"/nix/store/5lyvydxv0w4f2s1ba84pjlbpvqkgn1ni-linux-headers-4.19.16" -> "/nix/store/sr4253np2gz2bpha4gn8gqlmiw604155-glibc-2.27-dev" [color = "magenta"];
"/nix/store/681354n3k44r8z90m35hm8945vsp95h1-glibc-2.27" -> "/nix/store/sr4253np2gz2bpha4gn8gqlmiw604155-glibc-2.27-dev" [color = "burlywood"];
"/nix/store/f5wl80zkrd3fc1jxsljmnpn7y02lz6v1-glibc-2.27-bin" -> "/nix/store/sr4253np2gz2bpha4gn8gqlmiw604155-glibc-2.27-dev" [color = "black"];
"/nix/store/5lyvydxv0w4f2s1ba84pjlbpvqkgn1ni-linux-headers-4.19.16" [label = "linux-headers-4.19.16", shape = box, style = filled];
"/nix/store/f5wl80zkrd3fc1jxsljmnpn7y02lz6v1-glibc-2.27-bin" [label = "glibc-2.27-bin", shape = box, style = filled];
"/nix/store/681354n3k44r8z90m35hm8945vsp95h1-glibc-2.27" -> "/nix/store/f5wl80zkrd3fc1jxsljmnpn7y02lz6v1-glibc-2.27-bin" [color = "red"];
}
```

# Стандартные паттерны в Nix. nixpkgs.
## `mkDerivation`
<!--
Итак, у нас есть мощный и специализированный язык, а также пакетный менеджер, который предоставляет удобную, изолированную среду для сборки пакетов. Для того, чтобы опакечивать софт было проще, создадим функцию, которая будет обобщать `derivation` и уменьшать бойлерплейт. Назовем эту функцию...
-->

Неудобства `derivation`

- Очень большая часть написанного кода будет повторяться из пакета в пакет
  * Распаковка (чаще всего достаточно `tar -xf`)
  * Добавление зависимостей (`gcc`, `coreutils`, `bash`, `awk`, `make`, ...)
  * Сборка (очень часто можно обойтись `./configure && make`)
  * Установка (`make install`)
- Требует как минимум два файла -- builder и expression
- После вычисления уже нельзя поменять отдельные аргументы, а это может быть удобно

Создадим свой `derivation` ~~c блекджеком и шлюхами~~ без этих недостатков!

## `mkDerivation`: зависимости и стандартный сборщик
<!--
Для начала, напишем сборщик в файле `generic-builder.sh`. Сначала поставим свой `$PATH`, собрав его из содержимого `buildInputs`. Затем распакуем архив, переданный нам в `$src` и перейдем в свежесозданную директорию. Там сконфигурируем, соберем и установим наш autotools-проект.
-->
### `generic-builder.sh`
```
set -e
unset PATH
for p in $buildInputs $baseInputs; do
  export PATH=$p/bin${PATH:+:}$PATH
done
tar -xf $src
for d in *; do
  if [ -d "$d" ]; then
    cd "$d"
    break
  fi
done
./configure --prefix=$out
make
make install
```
***
<!--
В nix-части напишем функцию, которая создает деривацию с нашим сборщиком и некоторыми пакетами по-умолчанию, которые будут полезны при создании любого пакета.
-->
### `generic-builder.nix`
```
pkgs: attrs:
  with pkgs;
  let defaultAttrs = {
    builder = "${bash}/bin/bash";
    args = [ ./builder.sh ];
    baseInputs = [ gnutar gzip gnumake gcc binutils-unwrapped 
                   coreutils gawk gnused gnugrep findutils ];
    buildInputs = [];
    system = builtins.currentSystem;
  };
  in
derivation (defaultAttrs // attrs)
```
## `mkDerivation`: добавляем фазы
<!--
Создадим файл `setup.sh`, в котором определим стандартные "фазы" сборки, которые затем будем использовать в `builder.sh`.
-->
```
unset PATH
for p in $baseInputs $buildInputs; do
  export PATH=$p/bin${PATH:+:}$PATH
done

function unpackPhase() {
  tar -xzf $src

  for d in *; do
    if [ -d "$d" ]; then
      cd "$d"
      break
    fi
  done
}
```
***
```
function configurePhase() {
  ./configure --prefix=$out
}
function buildPhase() {
  make
}
function installPhase() {
  make install
}
function genericBuild() {
  unpackPhase
  configurePhase
  buildPhase
  installPhase
  fixupPhase
}
```

***

### `builder.sh`
```
set -e
source $setup
genericBuild
```

***

### `generic-builder.nix`
```
pkgs: attrs:
  with pkgs;
  let defaultAttrs = {
    builder = "${bash}/bin/bash";
    args = [ ./builder.sh ];
    setup = ./setup.sh;
    baseInputs = [ gnutar gzip gnumake gcc binutils-unwrapped 
                   coreutils gawk gnused gnugrep  findutils ];
    buildInputs = [];
    system = builtins.currentSystem;
  };
  in
derivation (defaultAttrs // attrs)
```
## `mkDerivation`: воспользуемся нашей функцией!
<!--
Отлично! Наша функция умеет собирать autotools-проекты, при этом `builder.sh` получился очень простым благодаря `setup.nix`. Теперь если мы хотим собрать проект не на основе autotools, мы можем это легко сделать, пропустив некоторые фазы в builder.
-->
### `default.nix`
```
let
  pkgs = import <nixpkgs> {};
  mkDerivation = import ./generic-builder.nix pkgs;
in
mkDerivation {
  name = "hello";
  src = ./hello-2.10.tar.gz;
};
```

## Пакеты как функции от зависимостей: паттерн inputs
<!--
Сделаем наш репозиторий ещё удобнее, вынеся определения пакетов в отдельные файлы. В каждом таком файле будет находиться функция, принимающая в качестве аргументов зависимости пакета и возвращающая деривацию (который мы будем создавать с помощью нашего `mkDerivation`)
-->
### `hello.nix`
```
{ mkDerivation }:
mkDerivation {
  name = "hello";
  src = ./hello-2.10.tar.gz;
}
```

### `default.nix`
```
let
  pkgs = import <nixpkgs> {};
  mkDerivation = import ./generic-builder.nix pkgs;
in
{
  hello = import ./hello.nix { inherit mkDerivation };
}
```

## Сборка с библиотеками: `NIX_CFLAGS_COMPILE`, `NIX_LDFLAGS`
<!--
Если мы хотим собирать пакеты, которые зависят от сторонних библиотек, нам понадобится ещё немного магии: нужно указать GCC и ld, где искать заголовочные и объектные файлы библиотек. Для этого существуют переменные `NIX_CFLAGS_COMPILE` и `NIX_LDFLAGS_`
-->
### `generic-builder.sh`
```
[...]
for p in $baseInputs $buildInputs; do
  if [ -d $p/bin ]; then
    export PATH="$p/bin${PATH:+:}$PATH"
  fi
  if [ -d $p/include ]; then
    export NIX_CFLAGS_COMPILE="-I $p/include${NIX_CFLAGS_COMPILE:+ }$NIX_CFLAGS_COMPILE"
  fi
  if [ -d $p/lib ]; then
    export NIX_LDFLAGS="-rpath $p/lib -L $p/lib${NIX_LDFLAGS:+ }$NIX_LDFLAGS"
  fi
done
[...]
```
***
### `graphviz.nix`
```
{ mkDerivation, gdSupport ? true, gd, fontconfig, libjpeg, bzip2 }:

mkDerivation {
  name = "graphviz";
  src = ./graphviz-2.38.0.tar.gz;
  buildInputs = if gdSupport then [ gd fontconfig libjpeg bzip2 ] else [];
}
```
***
### `default.nix`
```
let
  pkgs = import <nixpkgs> {};
  mkDerivation = import ./generic-builder.nix pkgs;
in
{
  hello = import ./hello.nix { inherit mkDerivation };
  graphviz = import ./graphviz.nix { inherit mkDerivation 
      gd fontconfig libjpeg bzip2; };
  graphvizCore = import ./graphviz.nix {
    inherit mkDerivation gd fontconfig libjpeg bzip2;
    gdSupport = false;
  };
}
```

## Паттерн `callPackage`
<!--
Здорово! Мы сделали свой небольшой репозиторий с красивой файловой структурой, научились собирать пакеты с помощью autotools с возможностью легко перейти на другие системы сборки и даже собирать пакеты с библиотеками. Теперь пора уменьшить бойлерплейт. Можно заметить, что в корневом файле репозитория мы повторяем названия аргументов функции при её вызове. Это будет происходить постоянно при структуре репозитория, похожего на наш. Для того, чтобы исправить эту проблему, мы создадим функцию `callPackage`, которая будет вызывать функцию из указанного файла, автоматически передавая ей аргументы из указанного attrset. Например:
-->
### `default.nix`
```
{
  hello = callPackage ./hello.nix { };
  graphviz = callPackage ./graphviz.nix { };
  graphvizCore = callPackage ./graphviz.nix
                 { gdSupport = false; };
}
```
***
<!--
Для начала разберемся с тем, как же нам найти названия аргументов функции. В nix для этого существует встроенная функция `builins.functionArgs`. Она возвращает attrset, в котором названию аргументов соответствует наличие у них значения по-умолчанию.
-->
```
nix-repl> add = { a ? 3, b }: a+b
nix-repl> builtins.functionArgs add
{ a = true; b = false; }
```
<!--
Также в nix существует удобный builtin для "пересечения" двух attrset-ов. Он возвращает attrset, в котором имена аттрибутов -- пересечение имен аттрибутов его аргументов, а их значения берутся из второго аргумента. Например:
-->
```
nix-repl> values = { a = 3; b = 5; c = 10; }
nix-repl> builtins.intersectAttrs values (builtins.functionArgs add)
{ a = true; b = false; }
nix-repl> builtins.intersectAttrs (builtins.functionArgs add) values
{ a = 3; b = 5; }
```
## Простой вариант `callPackage`
<!--
Обладая этими знаниями, напишем простую реализацию нашего callPackage.
-->
```
nix-repl> callPackage = set: f: 
          f (builtins.intersectAttrs 
            (builtins.functionArgs f) set)
nix-repl> callPackage values add
8
nix-repl> with values; add { inherit a b; }
8
```
## `callPackage`: добавляем оверрайды
<!--
Добавим возможность перегружать значения с помощью последнего аргумента...
-->
```
nix-repl> callPackage = set: f: overrides: 
            f ((builtins.intersectAttrs 
              (builtins.functionArgs f) set) // overrides)
nix-repl> callPackage values add { }
8
nix-repl> callPackage values add { b = 12; }
15
```
## `callPackage`: используем!
```
let
  nixpkgs = import <nixpkgs> {};
  allPkgs = nixpkgs // pkgs;
  callPackage = path: overrides:
    let f = import path;
    in f ((builtins.intersectAttrs (builtins.functionArgs f) allPkgs) // overrides);
  pkgs = with nixpkgs; {
    mkDerivation = import ./generic-builder.nix nixpkgs;
    hello = callPackage ./hello.nix { };
    graphviz = callPackage ./graphviz.nix { };
    graphvizCore = callPackage ./graphviz.nix { gdSupport = false; };
  };
in pkgs
```
## Паттерн `override`
<!--
Nix -- это функциональный язык. Одна из идей функциональной парадигмы состоит в композиции функций. Это может быть очень удобно при работе с деривациями. Например, если мы хотим получить `graphviz`, собранный с нашей собственной версией библиотеки gd, на данный момент нам придется заново делать `callPackage ./graphviz.nix { gd = customgd; }` Это неудобно и добавляет бойлерплейт. 
-->
```
mygraphviz = callPackage ./graphviz.nix { gd = customgd; }

VS.

mygraphviz = pkgs.graphviz.override { gd = customgd }
```
***
<!--
Для реализации нашей затеи напишем функцию `mkOverridable`, которая будет принимать функцию, возвращающую attrset, и attrset (который будет являться "дефолтными" аргументами для данной функции). Вернет `makeOverridable` тот же attrset, что вернула бы данная функция, с добавлением аттрибута `override`, который является функцией, позволяющей нам "перегружать" стандартные аргументы.
-->
### `lib.nix`
```
rec {
  makeOverridable = f: origArgs:
    let
      origRes = f origArgs;
    in
      origRes // { 
        override = newArgs: 
          makeOverridable f (origArgs // newArgs); 
      };
}
```
***
### Протестируем в `nix repl`
<!--
Работает! Теперь мы можем легко "перегружать" аргументы пакетов (которые, напомню, просто функции) в нашем репозитории. Нужно только не забыть вызывать все эти пакеты с makeOverridable.
-->
```
nix-repl> :l lib.nix
Added 1 variables.
nix-repl> f = { a, b }: { result = a+b; }
nix-repl> res = makeOverridable f { a = 3; b = 5; }
nix-repl> res2 = res.override { a = 10; }
nix-repl> res2
{ override = «lambda»; result = 15; }
nix-repl> res2.override { b = 20; }
{ override = «lambda»; result = 30; }
```
***
### `lib.nix`
```
rec {
  [...]
  callPackage = pkgs: path: overrides:
    let f = import path;
    in makeOverridable 
      f ((builtins.intersectAttrs 
        (builtins.functionArgs f) pkgs) // overrides);
}
```
***
### `default.nix`
```
let
  lib = import ./lib.nix;
  nixpkgs = import <nixpkgs> {};
  callPackage = lib.callPackage allPkgs;
  allPkgs = nixpkgs // pkgs;
  pkgs = with nixpkgs; rec {
    mkDerivation = import ./generic-builder.nix nixpkgs;
    hello = callPackage ./hello.nix { };
    graphviz = callPackage ./graphviz.nix { };
    graphvizCore = graphviz.override { gdSupport = false };
  };
in pkgs
```
## nixpkgs
<!--
Изначально я планировал вкратце рассказать про остальные паттерны nixpkgs, но в итоге получился просто объяснение, что же происходит в каждом файле, которое к тому же растянуло бы презентацию ещё на несколько десятков слайдов. На самом деле, на данный момент ваших знаний nix вполне достаточно для чтения исходников nixpkgs.
-->
> Изучение nixpkgs остается в качестве упражнения для слушателя. 

