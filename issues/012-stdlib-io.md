# 012 — Opcjonalny moduł I/O (`println` itd.)

**Status:** 💭 do rozważenia
**Zależy od:** 006 (moduły), ewentualnie wygodniejsze stringi

## Kontekst

W 001 hello world idzie przez C-owe `puts` — to świadomie cienkie FFI,
nie biblioteka standardowa Klina.

V ma builtin `print` / `println` / `eprint` / `eprintln`. Klin **nie**
powinien mieć dwóch równorzędnych API w rdzeniu (`puts` + `println`).

## Propozycja (później)

Opcjonalny moduł stdlib, importowany jawnie — nie w builtinach:

```
import io

fn main() {
    io.println("hello")
}
```

Emisja: cienkie wywołanie C (`puts` / `fwrite` / podobne). Zero magii,
zgodne z zasadą nadrzędną. Na bare-metalu po prostu nie importujesz.

## Nazwa — do decyzji

| Kandydat | Uwaga |
|---|---|
| `io` / `std.io` / `klin.io` | Neutralne — preferowane |
| `vstd` / `vlike` | Sugeruje kompatybilność z V, której nie utrzymamy — unikać |

## Czego NIE robić teraz

- Nie dodawać `println` do rdzenia obok `puts`
- Nie zaczynać stdlib przed działającymi modułami (006)
