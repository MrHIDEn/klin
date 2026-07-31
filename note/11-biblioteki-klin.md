# Biblioteki Klina (issues 020 / 047)

Wielokrotnego użytku `.kl` bez kopiowania źródeł — ścieżki search dla
`import name` (moduły z [006](../issues/006-moduly.md)). Bez menedżera pakietów.

## Resolucja `import name`

W każdym slocie search (pierwszy trafiony wygrywa; **plik i katalog naraz** =
błąd):

1. sibling: `name.kl` **lub** katalog `name/`
2. `lib/name.kl` **lub** `lib/name/`
3. `-I <dir>/…`
4. `$KLIN_PATH` (`:` / `;`)
5. `$KLIN_STDLIB` / repo `stdlib/`

### Plik vs katalog (047)

| | Sens |
|---|---|
| `name.kl` | jeden plik = jeden moduł (jak wcześniej) |
| `name/*.kl` | **jeden** moduł; wszystkie pliki z `module name`; `*_test.kl` pomijane |

W pakiecie-katalogu: bez `pub` = private w całym module (pliki widzą się
nawzajem); `pub` = eksport przy `import`. Entry (`klin run app.kl`) ładuje też
siblings z tym samym `module`.

`$KLIN_STDLIB` zostaje override’em stdlib; nie łączyć z `$KLIN_PATH`.

## Przykłady

Single-file w `lib/` ([020](../issues/020-biblioteki-klin.md)):

```sh
dart run bin/klin.dart run examples/klin_lib/app.kl
```

Katalog-pakiet ([047](../issues/047-directory-modules.md)):

```sh
dart run bin/klin.dart run examples/pkg_geom/app.kl
# → 25
```

```text
examples/pkg_geom/
  app.kl
  geom/
    vec.kl    # module geom — pub struct Vec2
    len.kl    # module geom — private sq + pub len_sq
```

Emisja nadal **jeden** `.c`.

## Poza zakresem

Manifest / wersje / rejestr, nested `import a/b`, osobne `.a` z lib Klin.
FFI C: [09-ffi-c.md](09-ffi-c.md). CLI: [06-cli.md](06-cli.md).
