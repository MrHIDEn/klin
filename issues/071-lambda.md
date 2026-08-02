# 071 — Lambdy / cukier `fn (…) => expr`

**Status:** 💭 do rozważenia (niski priorytet — **nie teraz**)
**Zależy od:** fn-pointer ✅ ([docs/13-fn-ptr.md](../docs/13-fn-ptr.md));
  prawdziwe domknięcia → [D7](../docs/01-decyzje.md); mile [055](055-short-decl.md) (`:=`)

## Podsumowanie

Propozycja składni (inspiracja JS/C# + typ jak w Klinie):

```klin
add := fn(a: i32, b: i32): i32 => a + b
let n = add(1, 2)
```

Dziś Klin ma tylko **nazwane** `fn` top-level + decay do `fn(...): T`
(wskaźnik C, **bez capture**). Go: `func(...) { }`, bez `=>`.
V: `fn (...) { }` oraz krótkie `|x| expr` przy callbackach — też bez `=>`.

Technicznie cukier `fn (…) => expr` da się zmapować na anonimową funkcję
bez capture (emisja ≈ zagnieżdżona / syntetyczna `static` fn w C + wskaźnik).
To **nie** jest jeszcze domknięcie: `fn(y) => x + y` z zewnętrznym `x`
wymaga D7 (environment / fat pointer / heap — ryzyko zasady nadrzędnej).

## Werdykt

**Nie dodawać na razie.** Mały zysk przy obecnym modelu (wystarczy nazwana
`fn` + przekazanie wskaźnika do `slice.map_into` itd.); duży koszt stylu
(Go-like Klin vs strzałki) i ryzyko dwóch sposobów na to samo.

Kolejność sensowna:

1. Zostawić fn-pointer bez capture (status quo).
2. Ewentualnie później **D7** (czy domknięcia w ogóle; jak bez ukrytej alokacji).
3. Dopiero potem osobna decyzja składni: `fn (…) { }` vs `|x|` (V) vs `=>`.

Opcjonalny cukier `=>` **bez** capture nie jest wart osobnego PR przed D7.
„Ostatnie wyrażenie = return” (Rust) — osobny temat; też raczej nie
(świadomie jak Go: zawsze `return`).

## Poza zakresem

- GC / autofree jako substytut capture
- `klingc` / `klin --gc`
- pełne HOF jak JS `arr.map(x => …)` z ukrytą alokacją ([017](017-collection-methods.md))

## Kryteria (gdy kiedyś wrócić)

- [ ] Decyzja D7 spisana (tak/nie + model pamięci capture)
- [ ] Jedna wybrana składnia (nie trzy naraz)
- [ ] Golden: anonimowa fn bez capture; negatyw: capture odrzucony albo jawny
- [ ] Emisja = zwykły wskaźnik C gdy brak capture (objdump vs ręczna fn)
