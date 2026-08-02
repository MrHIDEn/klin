# 081 — Literały liczbowe i znakowe (binarne, wykładnik float, znakowe, ósemkowe?)

**Status:** 🔨 w toku — zrobione: `0b`, `0o`, wykładnik float; zostaje tylko Grupa 2 (znakowe `'A'`)
**Zależy od:** [002](002-tablica-symboli-checker.md) (lekser/typy); powiązane z [078](078-bitwise-ops.md) (maski)

## Zrobione (Grupa 1 + ósemkowe)

- Binarne `0b1010` / `0B…`, **ósemkowe `0o755` / `0O…`** (oba z `_`), oraz
  wykładnik float `1e9` / `1.5e-3` / `2.5E+2` (z kropką i bez). Lekser: walidacja
  cyfry po `0b`/`0o`; wykładnik konsumowany tylko gdy po `e`/`E` (opcjonalny znak)
  jest cyfra, więc `1end` = `1` + `end`.
- Emisja przenośna: `0b…`/`0o…` → `0x…` (ta sama wartość; brak `0b`/`0o` w
  wyjściu → gcc/clang/tcc OK); wykładniki wprost. Długość tablicy akceptuje
  `0b…`/`0o…`. **Nie** przejmujemy C‑owej ósemkowej z zerem wiodącym (`010` u nas
  to dziesiętne `10`).
- `fmt` zachowuje pisownię źródłową. Przykład: `examples/number_literals.kl`,
  golden: `test/number_literals.kl`.

## Stan obecny (lekser)

- Całkowite dziesiętne: `123`, separator `1_000`.
- Szesnastkowe: `0xFF` / `0X…`, z `_`.
- Zmiennoprzecinkowe: `1.5`, `1_000.5` — **tylko** forma z kropką.
- Napisy `"…"` (escapy `\n \t \\ \" \$`), `true`/`false`.

## Kandydaci

| Literał | Przykład | Wartość | Emisja do C | Koszt |
|---|---|---|---|---|
| binarne | `0b1010` | wysoka (maski/rejestry) | `0b` niepewne w C/tcc → zamiana na `0x…` | mały |
| wykładnik float | `1e9`, `1.5e-3` | wysoka (f64) | wprost (C rozumie) | mały |
| znakowe | `'A'` | średnia (bajty/ASCII) | wprost `'A'` (lub kod int); typ = untyped int | średni |
| ósemkowe | `0o755` | niska (host) | `0o` nielegalne w C → `0x…`/dec | mały |
| hex‑float | `0x1.8p3` | niska (nisza) | — | pomijamy |

## Decyzje projektowe

- **Przenośność:** literały nielegalne/niepewne w C (`0b`, `0o`) lekser przyjmuje,
  ale **emisja zamienia na `0x…`** (ten sam wzorzec bitów) — zasada „gcc/tcc nie
  krzyczą”. `fmt` zachowuje pisownię źródłową (`0b`/`0o`).
- **Ósemkowe tylko jawne** `0o755` — **nie** C‑owa forma z zerem wiodącym
  (`010` ≠ 10, klasyczny footgun).
- **Wykładnik float** emitowany wprost (C rozumie `1e9`); rozszerzenie ścieżki
  float w `_number` o `e`/`E` z opcjonalnym `+`/`-`.
- **Znakowe** `'A'`: nowa ścieżka leksera `'…'` z escapami; wartość jako
  untyped int (koercja do `u8`/`i32`); emisja `'A'` (przenośne).
- Separator `_` dozwolony we wszystkich formach liczbowych.

## Grupowanie

- **Grupa 1 — ✅ zrobiona:** binarne `0b` + wykładnik float `1e…`. Pokrywa realne
  potrzeby (bity + f64), emisja przenośna.
- **Ósemkowe `0o` — ✅ zrobione:** jawny prefiks `0o755`, emisja → `0x…`
  (bez C‑owej formy z zerem wiodącym).
- **Grupa 2 — 💭:** literały znakowe `'A'` (większa zmiana leksera) → osobno.

## Punkty implementacji

- `lib/lexer.dart` `_number`: gałęzie `0b`/`0o`, wykładnik we float; nowa ścieżka `'…'`.
- Emisja (`lib/emit/expr.dart` `IntLit`, `lib/emit_c.dart` wartości enuma):
  helper normalizujący `0b`/`0o` → `0x…`; `dec`/`0x`/`1e…`/`'A'` bez zmian.
- `lib/checker.dart`: parsowanie długości tablicy z `0b`/`0o` (radix 2/8).
- `lib/fmt.dart`: bez zmian (leksem zachowany); testy round-trip.
- Goldeny + testy błędów (np. `0b`/`0o` bez cyfry), sanity gcc/tcc; README (sekcja literałów).

## Poza zakresem

- Sufiksy typów literałów (`123u`, `1i64`) — Klin ma untyped int/float + koercję.
- hex‑float, literały napisów wieloliniowych/raw — osobno, jeśli w ogóle.
