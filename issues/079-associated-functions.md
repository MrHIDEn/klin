# 079 — Funkcje asocjowane (statyczne) na typach (`Type.func`)

**Status:** ✅ zrobione (enum + struct, bieżący moduł)
**Zależy od:** 005 (metody z receiverem), 072 (enumy)

## Cel

Funkcje „na typie" bez receivera-instancji — deklarowane z kwalifikacją typu,
wołane jako `Type.func(args)`. To konstruktory / parsery / fabryki:
odwrotność metody instancyjnej (`fn (c: Color) name(): str` ↔
`fn Color.from_name(s: str): !Color`). Znikają w emisji (zwykła funkcja C
`Type_func(...)`, bez ukrytego receivera) — zero ukrytego kosztu.

## Składnia

```klin
fn Color.from_name(s: str): !Color { … }   // deklaracja (lustro wywołania)
let c = Color.from_name("red") or { Color.Blue }

fn Point.new(x, y: i32): Point { return Point{ x: x, y: y } }
let p = Point.new(3, 4)
```

- Deklaracja: `fn Type.name(params): Ret { … }` — pierwszy identyfikator po `fn`
  z kropką to typ, pod którym funkcja jest w przestrzeni nazw. Brak receivera.
- Wywołanie: `Type.name(args)` — checker rozpoznaje, że `Type` to nazwa typu
  (nie zmienna), i kieruje do funkcji asocjowanej.
- Działa dla **enumów i struktur**. Jest osobną przestrzenią od metod
  instancyjnych i stałych enuma (`Color.Red` bez `()` to nadal stała).

## Jak robią to inni

- Rust: `impl T { fn from_str(…) -> T }` → `T::from_str(…)`.
- Zig: typ jako namespace — `T.fromName(…)` (najbliższe temu podejściu).
- Swift/Kotlin/Java/C#: `static` / `companion` / failable `init?`.
- Go/C: brak cechy — konwencja wolnej funkcji (`NewT` / `t_from_name`).

Klin: wariant Zig/Rust‑like z emisją do zwykłej funkcji C.

## Poza zakresem (świadomie)

- Auto‑generowane `values()` / `valueOf` / `to_string` (wymaga tablic napisów /
  refleksji → ukryty koszt). Piszesz jawnie (`from_name` + `strcmp`).
- `mod.Type.func` (cross-module) — na razie bieżący moduł.
- Asocjowane `@[cimport]`/`@[cexport]`, użycie `Type.func` jako wskaźnika funkcji.
- Przeciążanie nazw (Klin nie ma overloadingu).

## Zrobione

- Parser: `fn Type.name(...)` (`FuncDecl.associatedType`).
- Checker: rejestracja w `_assocFuncs` pod `Type.func`; rozpoznanie wywołania
  `Type.func(...)` (receiver = nazwa typu, nie zmienna); arność/typy; mangling.
- Emisja: nagłówek bez receivera, wywołanie bez argumentu‑receivera,
  mangling `Type_func` (spójny z metodami).
- Fmt: druk `fn Type.func(...)`.

Przykład: `examples/associated_fn.kl`. Golden: `test/assoc_fn.kl`.
