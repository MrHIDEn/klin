# Formatowanie źródła (`klin fmt`)

Issue: [033](../issues/033-gofmt-style.md).

## Zasada

Jak `gofmt`: **jeden styl, zero flag**. Dyskusja o wcięciach kończy się na
`klin fmt -w`.

## Reguły (MVP)

- wcięcie: **4 spacje**
- klamry K&R / Go: `fn main() {` w tej samej linii; `} else {` w jednej linii
- spacje wokół operatorów binarnych i po przecinkach
- pusta linia między deklaracjami top-level (`struct` / `fn`)
- `module` / `import` na górze, potem pusta linia, potem deklaracje

## Użycie

```sh
dart run bin/klin.dart fmt examples/hello.kl          # stdout
dart run bin/klin.dart fmt -w path/a.kl path/b.kl     # zapis na miejscu
```

Wejście: lex → parse (`ModuleUnit`) → pretty-print. Bez preprocess / check / emit.

## Ograniczenia MVP

- **Komentarze giną** (lexer je pomija) — zachowanie komentarzy później.
- Pliki z makrami `$fn` / `$peripherals_from_svd` nie są poprawnym Klinem
  przed expandem — formatuj wynik `--emit-pp` albo plik bez `$`.
