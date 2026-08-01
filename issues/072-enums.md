# 072 — Enumy (styl C23, opcjonalny typ bazowy)

**Status:** 💭 do rozważenia
**Zależy od:** 002 (checker/typy), 005 (metody z receiverem), 014 (`match`)

## Cel

Dodać do Klina enumy w stylu **C23**: nazwany zbiór stałych, **opcjonalnie z
typem bazowym**. Enum ma znikać w emisji (zwykły `enum`/`int` w C) — zero
ukrytego kosztu (zasada nadrzędna). Dziś Klina nie ma enumów (`enum` nie jest
słowem kluczowym).

## Rdzeń (MVP)

```klin
enum Color { Red, Green, Blue }         // domyślny typ bazowy (int)
enum Status: u8 { Ok, Warn = 5, Err }   // opcjonalny typ bazowy + jawne wartości
```

- Wartości domyślnie 0,1,2… (jak C); jawne `= N` dozwolone.
- Typ bazowy opcjonalny: `enum E: u8 { … }` (C23 `enum E : uint8_t`).
- Enum to **osobny typ** w checkerze (nie alias `i32`); porównania `==`,
  użycie w `match` ([014](014-match.md)).
- Konwersja do/z liczby: jawna (np. `cast`/dedykowana funkcja) — bez ukrytej
  koercji.

### Emisja / przenośność (do decyzji przy realizacji)

C23 „fixed underlying type" (`enum E : uint8_t`) wspiera gcc 13+/clang 16+ z
`-std=c23`, ale **tcc nie**. Domyślny backend to gcc, lecz `--cc tcc` musi
działać. Opcje:
- typ bazowy podany → emitować przenośnie: `typedef uint8_t E;` + `#define`/`enum`
  stałych (albo `static const`), zamiast polegać na C23; albo
- emitować C23 `enum E : T` tylko gdy backend to wspiera (flaga), z fallbackiem.
Rozstrzygnąć tak, by `#line` i „gcc nigdy nie krzyczy" zostały spełnione.

## Metody rozszerzające na enumach — tak, warto

Klin ma już metody z receiverem na strukturach (`fn (v: Vec2) len_sq()`). Ten
sam mechanizm pasuje do enumów (emisja = zwykła funkcja C biorąca wartość enuma
— zero kosztu):

```klin
enum Color { Red, Green, Blue }

fn (c: Color) name(): str {
    match c {
        Color.Red { return "red" }
        Color.Green { return "green" }
        else { return "blue" }
    }
}
```

Rekomendacja: dopuścić receiver na typie enum (jak na strukturze). To najbliższe
modelowi **Go** (nazwany typ + metody) i zeru kosztu.

### Jak to robią inne języki (metody na enumach)

| Język | Metody na enumie |
|---|---|
| Go | enum = nazwany typ int (`iota`) + metody na tym typie — tak |
| Rust | `impl Enum { fn … }` — tak (enum algebraiczny) |
| Swift | metody / computed props / protokoły — tak |
| Kotlin | `enum class` z metodami (i abstrakcyjnymi per wariant) — tak |
| Java | enum = klasa z metodami — tak |
| C# | enum = int bez metod, ale **extension methods** przez `static` klasę — tak |
| Dart | **enhanced enums** (2.17+): pola/metody/konstruktory/interfejsy; dodatkowo `extension on Enum` — tak |
| TS | enum bez metod; obejścia przez namespace/obiekt |
| C / C23 | stałe całkowite, **bez** metod |

Wniosek: metody na enumach są normą (poza C/TS). Dla Klina najtańszy i spójny
model to „nazwany typ + receiver" (Go-like), bez wariantów-z-danymi (patrz niżej).

## Do rozważenia: enumy stringowe (styl TS)

TS: `enum E { A = "a", B = "b" }`. W języku kompilowanym do C „string enum" to
nie enum (brak dyskryminanty całkowitej), tylko **nazwany zbiór stałych
`str`** (`const char*`). Bywa wygodne (np. nazwy w logach/protokole), ale:
- to inna cecha niż enum całkowity — myląca pod jedną składnią;
- realizowalne jako zwykłe `pub` stałe / funkcja `name()` (wyżej), więc może
  nie ma sensu jako osobny „string enum".

Propozycja: **na razie pominąć**; jeśli potrzebne, dać `fn (c: E) label(): str`
zamiast enuma stringowego. Zapisane jako opcja, nie zobowiązanie.

## Do rozważenia: enum oparty o KV / uniwersalny „kvenum" / string-enum

Osobny, opcjonalny wariant enuma jako **mapa klucz→wartość** (nie tylko
całkowita dyskryminanta). Warianty do rozważenia:

- **kv-enum** — wariant `wariant = wartość` z jednym, wspólnym typem wartości,
  np. `str` (string-enum), `i64`, czy inny skalar: `enum Http: str { Ok = "ok",
  NotFound = "not_found" }`. Emisja: tablica stałych (`static const`) indeksowana
  dyskryminantą + akcesor `value()` — zero ukrytego kosztu.
- **uniwersalny kvenum** — każdy wariant niesie krotkę/rekord metadanych
  (np. `{ code: i32, label: str }`), coś jak „enhanced enum" z Darta, ale
  **bez** heap i refleksji: statyczna tablica rekordów + akcesory. To już bliskie
  wariantom-z-danymi, więc granica z „enum algebraiczny" (poza zakresem) musi być
  jasna: tu **stała** tablica per-wariant, nie payload runtime.
- **string-enum** (styl TS) — szczególny przypadek kv-enum z wartością `str`
  (patrz sekcja wyżej).

Relacja do [060](060-map-kv.md) (mapa KV): kvenum to **statyczny, domknięty**
zbiór (znany w compile-time), więc lepiej pasuje tablica stałych niż hash-mapa;
map-KV zostaje dla danych dynamicznych. Realizacja przez `$fn` (monomorfizacja)
jak reszta.

Status: **do rozważenia** — czy jako rozszerzenie składni `enum` (wartości per
wariant), czy jako osobny konstrukt; oraz czy w ogóle, skoro `fn (c: E)
value(): T` + `match` już to pokrywa bez nowej cechy.

## Poza zakresem (na start)

- Enumy algebraiczne z danymi (Rust/Swift `enum` z payloadem) — duży, osobny
  temat (wymaga tagged union w emisji); tu tylko enum „C-like".
- Automatyczne `to_string`/refleksja bez jawnej metody.
- Wymuszona wyczerpalność `match` po enumie — do rozważenia osobno (wartościowe,
  ale to rozszerzenie checkera/`match`).
- Bitflagi/`enum` jako flagi (`|`/`&`) — ewentualnie później; wymaga operatorów
  bitowych ([078](078-bitwise-ops.md)), których język dziś nie ma.

## Kryteria (gdy wchodzi do prac)

- [ ] `enum E { … }` i `enum E: T { … }` (jawne wartości) — parser + checker.
- [ ] Enum jako osobny typ; użycie w `match`; jawna konwersja do liczby.
- [ ] Metody z receiverem na enumie (jak na strukturze) + golden.
- [ ] Emisja przenośna (gcc/clang/tcc), `#line`, „gcc nie krzyczy".
- [ ] Decyzja: string-enum (TS) — pominąć czy dodać jako `str`-stałe.
