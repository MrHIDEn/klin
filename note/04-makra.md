# Makra czasu kompilacji (`$fn`, D3)

Decyzja: [01-decyzje.md](01-decyzje.md) § D3. Issue: [026](../issues/026-preprocessor.md).
Przykład uruchamialny: [`examples/macro_point.kl`](../examples/macro_point.kl).

## Po co

Generyki **nie** są w gramatyce języka. Zamiast tego preprocesor przed
parse/check/emit podstawia sloty (`$name`, `$T`, …) i generuje zwykły
kod Klina — monomorfizacja widoczna w `--emit-pp`, zero narzutu w runtime.

## Przed (piszesz szablon)

```klin
$fn point(name: name, T: type) {
struct $name {
  x: $T
  y: $T
}
fn (p: $name) len_sq(): $T {
  return p.x * p.x + p.y * p.y
}
}

$point(Vec2i, i32)

fn main() {
  let v = Vec2i{ 3, 4 }
  printf("%d\n", v.len_sq())
}
```

Drugie wywołanie `$point(Vec2f, f64)` dałoby osobną kopię z `f64`.

## Po expand (to widzi checker / emit)

```klin
struct Vec2i {
  x: i32
  y: i32
}
fn (p: Vec2i) len_sq(): i32 {
  return p.x * p.x + p.y * p.y
}

fn main() {
  let v = Vec2i{ 3, 4 }
  printf("%d\n", v.len_sq())
}
```

Podgląd:

```sh
dart run bin/klin.dart --emit-pp examples/macro_point.kl
# → out/macro_point.pp.kl
```

## Parametry makra (MVP)

| Kind | Argument | Podstawienie |
|---|---|---|
| `type` | `i32`, `f64`, … | jak napisano |
| `name` / `str` | `Vec2i` albo `"Vec2i"` | identyfikator (cudzysłowy ze `str` odpadają) |

Definicja: `$fn nazwa(param: kind, …) { … }`.  
Wywołanie: `$nazwa(args…)`. Nieznane `$slot` w ciele po expand = błąd
(z wyjątkiem `$…` w stringach i `//` komentarzach).

## Czego to nie jest

- Nie Nelua z pełnym AST-quote / metaprogramowaniem.
- Nie `$peripherals_from_svd` — to [027](../issues/027-svd-ergonomic-api.md).
- Nie ukryty polimorfizm w C — w `.c` zostają zwykłe `Vec2i` / `int32_t`.
