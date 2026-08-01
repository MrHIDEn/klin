# Makra czasu kompilacji (`$fn`, D3)

Decyzja: [01-decyzje.md](01-decyzje.md) § D3. Issue: [026](../issues/026-preprocessor.md).
Przykład: [`point.kl`](../examples/point.kl) (zwykły Klin) oraz
[`point_macro.kl`](../examples/point_macro.kl) (to samo przez `$fn`).

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
dart run bin/klin.dart --emit-pp examples/point_macro.kl
# → out/point_macro.pp.kl
```

## Parametry makra (MVP)

| Kind | Argument | Podstawienie |
|---|---|---|
| `type` | `i32`, `f64`, … | jak napisano |
| `name` / `str` | `Vec2i` albo `"Vec2i"` | identyfikator (cudzysłowy ze `str` odpadają) |

Definicja: `$fn nazwa(param: kind, …) { … }`.  
Wywołanie: `$nazwa(args…)`. Nieznane `$slot` w ciele po expand = błąd
(z wyjątkiem `$…` w stringach i `//` komentarzach).

## Built-in: `$device` / `$peripherals_from_svd` (027, 053)

```klin
// lokalnie (027) albo remote z cache (053):
$device("github/tinygo-org/stm32-svd/svd/stm32f411.svd", "RCC,GPIOA,STK")
// alias: $peripherals_from_svd("…", "…")

fn main() {
  RCC.AHB1ENR.GPIOAEN.set(1)
  GPIOA.MODER.MODER5.write(.Output)
  GPIOA.ODR.ODR5.toggle()
}
```

Expand → `@[cinclude("…_regs.h")]` + `RCC_AHB1ENR_GPIOAEN_set(1)` itd.
(reuse emittera z 011; zero-cost `static inline`). Przykład lokalny:
[`examples/stm32/blink_f411/blink.kl`](../examples/stm32/blink_f411/blink.kl).

Remote SVD (053): `klin get github/tinygo-org/stm32-svd/svd/stm32f411.svd@main`
→ cache `$KLIN_CACHE/asset/…`, linia `device …` w `klin.mod` + wpis w
`klin.lock`. Kompilacja / `run` bez sieci; brak cache → błąd z hintem
`klin get`. Allowlista MVP: `github/tinygo-org/stm32-svd`. Board / `.ioc`
osobno (później: `board` w `klin.mod` / wąski `.ioc`).

## Czego to nie jest

- Nie Nelua z pełnym AST-quote / metaprogramowaniem.
- Nie ukryty polimorfizm w C — w `.c` zostają zwykłe `Vec2i` / `int32_t`.
