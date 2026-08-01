# 056 — Dekonstrukcja (`{}` / `[]` / multi-assign)

**Status:** 🔨 w toku — faza A ✅ (struktury) + faza C ✅ (tablice `[N]T`)
**Zależy od:** [005](005-struktury-metody.md) (struct lit/pola ✅); mile [007](007-wskazniki-tablice-slice.md) (tablice stałej długości)

> **Nie mylić z destruktorami RAII.** D6 ([note/01-decyzje.md](../note/01-decyzje.md)):
> brak konstruktorów/destruktorów. Tu chodzi o **destructuring** —
> rozpakowanie wartości do wielu nazw w jednym zdaniu.

## Motywacja

Wzorce w stylu:

```
[a, b] = [b, a]     // swap / rozpakowanie tablicy
[x] = tab           // pierwszy element?
{ x, y } = p        // pola struktury
a, b = b, a         // multi-assign jak Go/V (bez nawiasów)
```

Dziś Klin ma literały `[…]` / `Typ{ … }` i pojedyncze `target = expr`.
Brak rozpakowania i brak jednoczesnego przypisania wielu LHS.

## Go / V — czy mają tuple?

| Język | Tuple jako typ pierwszej klasy? | Co zamiast |
|---|---|---|
| **Go** | **Nie.** Świadoma decyzja. | Wieloargumentowy `return`; multi-assign `a, b = b, a`; „krotka” = struct albo osobne wartości. |
| **V** | **Nie** (brak typu `tuple` w docs). | Multi-assign / swap `a, b = b, a`; multi-return; dane złożone = **struct**. Dekonstrukcja tablic/`{}` — propozycje społeczności, nie rdzeń. |

**Wniosek dla Klina:** nie dodawać tupli. Mamy struktury, `!T`, tablice
stałej długości — to wystarczy. Tuple to drugi sposób na to samo co
anonimowy struct, z gorszymi komunikatami i kolizją z literałami.

## Kierunek (preferowany)

### 1. Struct `{}` — naturalny MVP

Skoro są struktury i literały nazwane/pozycyjne, dekonstrukcja po
**nazwach pól** jest prosta i znika w emisji (zwykłe `.field`):

```
let p = Vec2{ x: 3, y: 4 }
let { x, y } = p          // ≡ let x = p.x; let y = p.y
let mut { x, y } = p      // mutowalne lokalne
{ x, y } = p              // przypisanie do istniejących (wymaga mut)
```

- kolejność w `{}` nieistotna (jak w literale nazwanym)
- podzbiór pól OK; brakujące pola = nie wprowadzane
- rename później: `{ x: px, y: py }` (opcjonalnie, nie w fazie 1)
- `_` do pominięcia? raczej niepotrzebne przy podzbiorze

Zasada nadrzędna: emisja = sekwencja odczytów pól / zapisów lokalnych.
Zero alokacji, zero ukrytego kopiowania poza tym, co i tak robi `let`
struktury (kopia wartości jak dziś).

### 2. Multi-assign (Go/V) — swap bez tablicy

```
a, b = b, a
x, y = foo()          // dopiero gdy/jeśli multi-return
```

- RHS ewaluowane „równolegle” (tmp jak w Go) — widać w emitowanym C
- nie wymaga nowego typu
- pokrywa swap bez `[a,b]=[b,a]`

### 3. Tablice `[…]` — tylko stała długość

```
let xs: [2]i32 = [10, 20]
let [a, b] = xs           // ≡ let a = xs[0]; let b = xs[1]
[a, b] = [b, a]           // swap przez literał / wzorzec
```

- **tylko** `[N]T` o znanym `N` w czasie kompilacji
- **nie** slice `[]T` (długość runtime → wyjątek / panika — łamie
  „błędy łapie frontend” albo wymaga ukrytego checka)
- liczba wzorców == `N` (albo `N` z `_` — decyzja później)

`[x] = tab` przy `tab: [3]i32` jest **niejednoznaczne** (pierwszy?
całość?). Propozycja: albo zabronić (wymagaj pełnego pokrycia), albo
jawny indeks / slice — nie cukier `[x]=`.

## Poza zakresem (na start)

- typ `tuple` / `(T, U)` w gramatyce
- dekonstrukcja slice / dynamicznych kolekcji
- pattern matching w `if` / `match` (osobny temat, jeśli kiedyś)
- destruktory / RAII (D6 zostaje)
- multi-return funkcji (może później; dziś `!T` + struct wystarcza)

## Fazy (gdy otworzyć implementację)

| Faza | Co | Zależy | Status |
|---|---|---|---|
| A | `let { a, b } = s` (deklaracja) | 005 | ✅ |
| A′ | bare `{ a, b } = s` (reassign; wymaga lookaheadu) | 005 | ⏳ |
| B | `a, b = b, a` (multi-assign, bez multi-return) | parser + checker tmp | ⏳ |
| C | `let [a, b] = xs` dla `[N]T`, `N` znane | 007 | ✅ |
| D | rename `{ x: px }`, `_` w tablicach (skip) | po A/C | ⏳ |

**Faza A (zrobione):** `let { … } = expr` i `let mut { … } = expr` dla struktur —
podzbiór pól, kolejność nieistotna, źródło liczone raz (kopia do tymczasowej gdy
nie jest nazwą), lowerowanie do `.field`. Przykład
[`examples/destructure.kl`](../examples/destructure.kl), testy w
[`test/destruct_struct.kl`](../test/destruct_struct.kl) +
`test/pipeline_test.dart`.

**Faza C (zrobione):** `let [a, b] = xs` i `let mut [a, b] = xs` dla tablic
stałej długości `[N]T`, gdzie `N` == liczba wzorców (pełne pokrycie, brak
niejednoznaczności `[x] = tab`). Nazwana tablica indeksowana w miejscu
(`xs[i]`), literał tablicowy wiązany element po elemencie. Odrzucane przez
frontend: slice `[]T` (długość runtime), niezgodna długość, źródło inne niż
zmienna/literał tablicy, zagnieżdżony element tablicowy. Skip `_` należy do
fazy D. Przykład [`examples/destructure.kl`](../examples/destructure.kl), testy
w [`test/destruct_array.kl`](../test/destruct_array.kl) +
`test/pipeline_test.dart`.

## Kryterium „issue zamknięte jako decyzja”

- [x] potwierdzenie: **bez tupli**
- [x] wybór fazy A jako pierwszej (struct `{}`)
- [x] decyzja: multi-assign B **po** tablicach jest OK; kolejność B/C otwarta,
  ale faza A (struct) idzie pierwsza i jest już zaimplementowana
- [x] dla tablic (faza C): jawne `_`, **nie** dziury w stylu JS `[,,a,b]`
  (spójność z Go/V, czytelność; zero-cost identyczny, więc decyduje ergonomia)
