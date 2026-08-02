# 078 — Operatory bitowe (`| & ^ ~ << >>`)

**Status:** ✅ zrobione (MVP)
**Zależy od:** [002](002-tablica-symboli-checker.md) (typy/checker), [019](019-default-int-types.md) (typy całkowite)

## Cel

Dodać do Klina operatory bitowe na typach całkowitych. Manipulacja bitami
występowała wcześniej wyłącznie w **generowanym C** dla rejestrów SVD
(`lib/svd/emit.dart`) — nie w kodzie źródłowym Klina.

## Zakres (MVP) — zrobione

| Klin | Znaczenie | C |
|---|---|---|
| `a & b` | AND bitowy | `a & b` |
| `a \| b` | OR bitowy | `a \| b` |
| `a ^ b` | XOR bitowy | `a ^ b` |
| `~a` | NOT bitowy (unarny) | `~a` |
| `a << b` | przesunięcie w lewo | `a << b` |
| `a >> b` | przesunięcie w prawo | `a >> b` |
| `a &= b` itd. | złożone przypisanie | `a &= b` … (`\|= ^= <<= >>=`) |

Zasady semantyczne:
- **Tylko typy całkowite** (`i8..u64`, `usize`/`isize`); błąd na `bool`/`float`/
  wskaźnikach (checker), tak jak dla `%`.
- `>>` na typach ze znakiem = przesunięcie arytmetyczne (jak w C dla
  implementacji dwójkowych); na bez znaku — logiczne.
- Operand przesunięcia (`b` w `a << b`) — całkowity; wynik ma typ lewego
  operandu. Ujemny/za duży count to UB w C — bez lintu w MVP.
- Emisja 1:1 do C (w tym promocje całkowite C w „gołych” wyrażeniach);
  przypisanie do węższego typu obcina jak w C.

## Precedencja (ustalone — jak Rust, nie C)

Decyzja projektowa: [note/01-decyzje.md](../note/01-decyzje.md) **D8**.

```
* / %  →  + -  →  << >>  →  &  →  ^  →  |  →  porównania  →  == !=
```

Dzięki temu `a & b == c` to `(a & b) == c`, a nie pułapka C
`a & (b == c)`. Binarny `&` vs unarny `&` (adres) — rozróżnienie po pozycji,
jak `*` (mnożenie vs dereferencja).

## Punkty implementacji

- `lib/token.dart` + `lib/lexer.dart`: `pipe |`, `caret ^`, `tilde ~`,
  `lessLess <<`, `greaterGreater >>`.
- `lib/parser.dart`: warstwy `_shift` / `_bitAnd` / `_bitXor` / `_bitOr` + `~`
  w `_unary`.
- `lib/checker.dart`: `_bitOps` / `_inferShift`; `~` w inferencji unarnej.
- Emisja: istniejący `BinaryExpr` / `UnaryExpr` (nawiasowanie `(a op b)`).
- `lib/fmt.dart`: `~` jak pozostałe unarne prefiksy.

## Relacja do innych issue

- Odblokowuje „bitflagi” dla enumów ([072](072-enums.md)) — `Flags.A | Flags.B`
  wymaga tych operatorów (oraz semantyki bitflagów na enumach — osobno).
- Przydatne dla HAL/rejestrów ([031](031-biblioteki-hal.md), [011](011-svd.md))
  po stronie kodu Klina.

## Poza zakresem

- Rotacje bitów, `popcount`/`clz` itp. (to funkcje/`@cimport`, nie operatory).
- Bitflagi jako cecha enuma — należą do [072](072-enums.md).
- Ostrzeżenia o UB przesunięć (ujemny/za duży count) — ewentualnie z lintem.

Arytmetyczne złożone (`+= -= *= /= %=`) używają tego samego `AssignStmt.compoundOp`
co bitowe — osobny follow-up PR, nie część semantyki bitowej.

## Kryteria

- [x] Tokeny + parser (precedencja Rust-like, `~` unarny, infiks `&`).
- [x] Checker: ograniczenie do typów całkowitych; błędy na `bool`/`float`.
- [x] Emisja przenośna (gcc/clang/tcc), `#line`; goldeny.
- [x] `fmt` drukuje operatory idempotentnie.
- [x] Złożone bitowe `&= |= ^= <<= >>=` (emisja 1:1 C `op=`).

Zob. [`examples/bitwise.kl`](../examples/bitwise.kl), `test/bitwise.kl`.
