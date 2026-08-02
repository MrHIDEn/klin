# 034 — Typy generyczne w języku

**Status:** 💭 nie teraz (zostajemy przy D3)
**Zależy od:** doświadczenia z D3 / [026](026-preprocessor.md); nie blokuje kolejki głównej

## Werdykt (po 017 / 057)

**Nie wdrażamy generyków w gramatyce.** Zostajemy przy **D3**
([docs/01-decyzje.md](../docs/01-decyzje.md)): monomorfizacja przez `$fn`
przed parse.

Pełny system typów z `T` w tablicy symboli (wariant 3) to duży koszt frontendu
przy **tym samym** emitcie C — zysk to głównie ergonomia nazw, nie model
wykonania. Zasada nadrzędna i tak wymaga monomorfizacji.

Po [017](017-collection-methods.md) / [057](057-allocator.md) `$fn` w stdlib
wystarcza: `slice` / `slice_alloc` (`_i32` / `_u8`), `mem.alloc_i32` /
`alloc_u8`. Ból jest nazewniczy (`map_into_i32` vs `map_into[T]`), nie
semantyczny. **`a.alloc(T, n)` nadal nie obiecywać**
([docs/14-allocator.md](../docs/14-allocator.md)).

## Kontekst

D3: generyki **nie** w gramatyce — makra czasu kompilacji. MVP działa
(`point_macro`, SVD fluent, slice helpers — [docs/16-slice.md](../docs/16-slice.md)).

## Warianty (gdy wrócimy)

1. **Tylko D3** — wzmocnić makra (lepsze diagnostyki, dedent/`fmt`, cytowanie AST).
2. **Cienka warstwa generyków** — cukier (`fn id[T](x: T): T`) rozwijany do
   tego samego co `$fn` (checker widzi `T`, emit jak monomorfy). **Preferowany**
   cel przy otwarciu tematu.
3. **Pełniejsze generyki** — parametry typów w tablicy symboli, constraints;
   większy koszt — nie planować domyślnie.

Bez vtable / boxowania domyślnie; frontend łapie błędy zanim gcc zobaczy `.c`.

## Kryterium ponownego otwarcia

Dopiero gdy zbierzesz **2–3 twarde miejsca**, gdzie `$fn` jest wyraźnie gorsze
— nie „ładniej by było”:

1. kontener z metodami (`Vec[T]` / `HashMap[K,V]`) trudny jako sam makro-expand
2. parametryzowane `Option`/`Result` w wielu API (dziś `!T` wystarcza)
3. diagnostyki z rozwiniętego `$fn` realnie blokują użytkowników

Wtedy planować **wariant 2**, nie wariant 3.

## Checklist decyzji

- [x] Werdykt: zostajemy przy D3; otwarcie tematu = wariant 2 po kryteriach powyżej
- [x] Krótki dopisek w D3 ([docs/01-decyzje.md](../docs/01-decyzje.md))
- [ ] Zebrać 2–3 twarde miejsca bólu `$fn` (warunek startu implementacji — nie teraz)
