# Moduły (issue 006)

`module` / `import` / `pub` — enkapsulacja zamiast płaskiego linkage C.
Ścieżki search (`lib/`, `-I`, katalog-pakiet): [11-biblioteki-klin.md](11-biblioteki-klin.md).

## Składnia

```klin
module geom

pub struct Vec2 {
    x: i32
    y: i32
}

pub fn (v: Vec2) len_sq(): i32 {
    return v.x * v.x + v.y * v.y
}
```

```klin
module app
import geom

fn main() {
    let p = geom.Vec2{ x: 3, y: 4 }
    printf("%d\n", p.len_sq())
}
```

- `module name` — deklaracja modułu pliku (albo wszystkich plików pakietu-katalogu)
- `import name` — qualifier w użyciu: `name.Symbol`
- bez `pub` = private w **module**; `pub` = widoczne po `import`

## Emisja C

- mangling: `modul_Typ_metoda` (np. `geom_Vec2_len_sq`) — [01-decyzje.md](01-decyzje.md)
- symbole prywatne → `static` w wygenerowanym `.c`
- cały program nadal **jeden** `.c`

## Plik vs katalog

| Forma | Sens |
|---|---|
| `name.kl` | jeden plik = jeden moduł |
| `name/*.kl` | **jeden** moduł (issue [047](../issues/047-directory-modules.md)); `*_test.kl` pomijane |

Entry (`klin run app.kl`) ładuje też siblings z tym samym `module`.
Szczegóły resolucji: [11-biblioteki-klin.md](11-biblioteki-klin.md).

## Przykłady

Wiele modułów (osobne pliki):

```sh
dart run bin/klin.dart run examples/modules/app.kl
```

Katalog = jeden pakiet:

```sh
dart run bin/klin.dart run examples/pkg_geom/app.kl
# → 25
```

## Poza zakresem

Aliasy / `import "…"`: [048](../issues/048-import-aliases.md).
Remote GitHub: [049](../issues/049-remote-imports.md).
CLI: [06-cli.md](06-cli.md).
