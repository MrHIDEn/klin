# 078 — Operatory bitowe (`| & ^ ~ << >>`)

**Status:** 💭 do rozważenia
**Zależy od:** [002](002-tablica-symboli-checker.md) (typy/checker), [019](019-default-int-types.md) (typy całkowite)

## Cel

Dodać do Klina operatory bitowe na typach całkowitych. Dziś ich **nie ma**:
lekser nie tokenizuje `| ^ ~ << >>`, a binarny `&` nie istnieje (`&` jest tylko
unarne — branie adresu). Dostępne operatory to arytmetyka `+ - * / %`,
porównania `== != < <= > >=` oraz unarne `- ! * &`.

Manipulacja bitami występuje obecnie wyłącznie w **generowanym C** dla rejestrów
SVD (`lib/svd/emit.dart` wypluwa `<< & ~ | ^`) — nie w kodzie źródłowym Klina.

## Zakres (MVP)

Operatory (mapują się 1:1 na C, zero ukrytego kosztu — zasada nadrzędna):

| Klin | Znaczenie | C |
|---|---|---|
| `a & b` | AND bitowy | `a & b` |
| `a \| b` | OR bitowy | `a \| b` |
| `a ^ b` | XOR bitowy | `a ^ b` |
| `~a` | NOT bitowy (unarny) | `~a` |
| `a << b` | przesunięcie w lewo | `a << b` |
| `a >> b` | przesunięcie w prawo | `a >> b` |

Zasady semantyczne:
- **Tylko typy całkowite** (`i8..u64`, `usize`/`isize`); błąd na `bool`/`float`/
  wskaźnikach (checker), tak jak dla `%`.
- `>>` na typach ze znakiem = przesunięcie arytmetyczne (jak w C dla
  implementacji dwójkowych); na bez znaku — logiczne. Zapisać jako założenie.
- Operand przesunięcia (`b` w `a << b`) — całkowity; ujemny/za duży count to UB
  w C — do rozważenia ostrzeżenie/lint, ale nie w MVP.

## Precedencja (do ustalenia przy realizacji)

C ma niesławnie „dziwną” precedencję bitowych (poniżej porównań). Klin ma dziś:
`==`/`!=` → `< <= > >=` → `+ -` → `* / %` → unarne (`lib/parser.dart`). Do
decyzji, gdzie wstawić nowe warstwy. Bezpieczna, czytelna opcja (nie kopiować
pułapek C):
- `<<` / `>>` obok/tuż nad `* / %` (przesunięcie ~ mnożenie/dzielenie przez 2^n),
- `&`, potem `^`, potem `|` — każdy jako osobna warstwa **poniżej** porównań,
  lub **powyżej** — do rozstrzygnięcia; w razie wątpliwości wymagać nawiasów.

Uwaga: binarny `&` koliduje wizualnie z unarnym `&` (adres). Parser rozróżnia
je po pozycji (prefiks vs infiks), jak `*` (mnożenie vs dereferencja) —
`_termMul` już to robi dla `*`.

## Punkty implementacji

- `lib/token.dart` + `lib/lexer.dart`: nowe tokeny `pipe |`, `caret ^`,
  `tilde ~`, `shl <<`, `shr >>` (uwaga: `<<`/`>>` vs `<`/`>` — dłuższy pierwszy).
- `lib/parser.dart`: nowe warstwy precedencji (binarny `&`/`^`/`|`, `<<`/`>>`) +
  `~` w `_unary`.
- `lib/checker.dart`: rozszerzyć `_arithOps`/logikę o bitowe z ograniczeniem do
  typów całkowitych (osobny zbiór, np. `_bitOps`); `~` w inferencji unarnej.
- `lib/emit/*`: emisja wprost (nawiasowanie jak istniejące `BinaryExpr`
  `(a op b)`), `~` jak `UnaryExpr`.
- `lib/fmt.dart`: druk nowych operatorów.

## Relacja do innych issue

- Odblokowuje „bitflagi” dla enumów ([072](072-enums.md)) — `Flags.A | Flags.B`
  wymaga tych operatorów; obecnie „poza zakresem” tam.
- Przydatne dla HAL/rejestrów ([031](031-biblioteki-hal.md), [011](011-svd.md))
  po stronie kodu Klina, nie tylko generowanego C.

## Poza zakresem

- Operatory przypisania złożonego (`|=`, `&=`, `<<=`, …) — osobno/później.
- Rotacje bitów, `popcount`/`clz` itp. (to funkcje/`@cimport`, nie operatory).
- Bitflagi jako cecha enuma — należą do [072](072-enums.md).
- Ostrzeżenia o UB przesunięć (ujemny/za duży count) — ewentualnie z lintem.

## Kryteria (gdy wchodzi do prac)

- [ ] Tokeny + parser (precedencja, `~` unarny, infiks `&`).
- [ ] Checker: ograniczenie do typów całkowitych; błędy na `bool`/`float`/ptr.
- [ ] Emisja przenośna (gcc/clang/tcc), `#line`; goldeny (wartości + `objdump`
      vs ręczny C wg zasady 5).
- [ ] `fmt` drukuje operatory idempotentnie.
