# Biblioteki Klina (issues 020 / 047)

Wielokrotnego użytku `.kl` bez kopiowania źródeł — ścieżki search dla
`import name`. Semantyka `module` / `pub`: [12-moduly.md](12-moduly.md)
([006](../issues/006-moduly.md)). Bez menedżera pakietów.

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

## Aliasy i import ścieżkowy (048)

```klin
import geom                      // qualifier = geom
import geom oso                  // lokalny alias: qualifier = oso (geom niedostępne)
import "sub/osa"                 // string; qualifier = ostatni segment (osa)
import "sub/osa" aa              // string + alias: qualifier = aa
```

- Alias/qualifier to pojęcie **frontendu** — mangling C używa realnej nazwy
  `module` (np. `oso.f()` → `geom_f`).
- Alias zastępuje domyślny qualifier (po `import geom oso` nie ma już `geom.…`).
- String to **ścieżka względna** (może zawierać `/`), resolwowana jak wyżej
  (`lib/`, `-I`, `$KLIN_PATH`, plik lub katalog). Domyślny qualifier = ostatni
  segment bez `.kl`. Katalog-pakiet: pliki muszą deklarować `module <segment>`.
- Ten sam qualifier związany z dwoma różnymi specyfikatorami = błąd. Słowo
  kluczowe C jako alias = błąd.

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
    vec.kl        # module geom — pub struct Vec2
    len.kl        # module geom — private sq + pub len_sq
    len_test.kl   # pomijany przy run
```

Emisja nadal **jeden** `.c`. Moduły: [12-moduly.md](12-moduly.md).

## Remote (`github` / `gitlab`) — issue 049

```klin
import "github/mrhiden/osa"
```

- Pierwszy segment `github` lub `gitlab` → pakiet z cache (`$KLIN_CACHE` / `~/.klin/pkg/…`).
- Brak w cache → błąd; najpierw `klin get github/mrhiden/osa@v0.1.0`
  (zapisze `klin.mod` + `klin.lock`).
- `klin run` bez sieci. Manifest: `klin.mod` (`require path ref`).
- Lock: `klin.lock` — commit SHA + `sha256` źródeł ([065](../issues/065-project-lockfile.md) ✅).
- Fixture: https://github.com/MrHIDEn/osa ([063](../issues/063-remote-fixture-osa.md)).

`upgrade` → [066](../issues/066-klin-upgrade-outdated.md).

## Poza zakresem

Osobne `.a` z lib Klin. Aliasy / import ścieżkowy: [048](../issues/048-import-aliases.md) ✅.
FFI C: [09-ffi-c.md](09-ffi-c.md). CLI: [06-cli.md](06-cli.md).
