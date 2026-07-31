# 056 — Dekonstrukcja (`{}` / `[]` / multi-assign)

**Status:** 💭 do rozważenia
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

| Faza | Co | Zależy |
|---|---|---|
| A | `let { a, b } = s` / `{ a, b } = s` | 005 |
| B | `a, b = b, a` (multi-assign, bez multi-return) | parser + checker tmp |
| C | `let [a, b] = xs` dla `[N]T`, `N` znane | 007 |
| D | rename `{ x: px }`, `_` w tablicach | po A/C |

## Kryterium „issue zamknięte jako decyzja”

Nie trzeba od razu kodować. Wystarczy:

- [ ] potwierdzenie: **bez tupli**
- [ ] wybór fazy A jako pierwszej (struct `{}`)
- [ ] decyzja: multi-assign B przed czy po tablicach C
- [ ] krótka notatka w `note/` po decyzji (albo aktualizacja D7)
