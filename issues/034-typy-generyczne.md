# 034 — Typy generyczne w języku (do rozważenia)

**Status:** 💭 do rozważenia
**Zależy od:** doświadczenia z D3 / [026](026-preprocessor.md); nie blokuje kolejki głównej

## Kontekst

Decyzja **D3** ([note/01-decyzje.md](../note/01-decyzje.md)): generyki **nie**
w gramatyce — zamiast tego makra czasu kompilacji (`$fn`, monomorfizacja
przed parse). MVP jest i działa (`macro_point`, SVD fluent przez expand).

To nie zamyka tematu na zawsze. Warto wrócić, gdy będzie widać, gdzie makra
bolą: komunikaty błędów, czytelność bibliotek, powtarzalne wzorce
(`Option`/`Result` parametryzowane, kontenery, [017](017-collection-methods.md)).

## Pytanie

Czy Klinowi **przydałyby się** typy generyczne w rdzeniu (np. `struct Vec[T]`,
`fn id[T](x: T): T`), przy zachowaniu zasady nadrzędnej:

- monomorfizacja do C (jak dziś makra) — **bez** vtable / boxowania domyślnie,
- zero ukrytego kosztu w emitowanym kodzie,
- frontend łapie błędy zanim gcc zobaczy `.c`.

## Warianty (później)

1. **Zostawić tylko D3** — wzmocnić makra (lepsze diagnostyki, dedent/`fmt`,
   cytowanie AST).
2. **Cienka warstwa generyków** — cukier składniowy rozwijany do tego samego
   co `$fn` (checker widzi `T`, emit jak monomorfy).
3. **Pełniejsze generyki** — parametry typów w tablicy symboli, constraints
   później; większy koszt implementacji.

## Kryterium otwarcia tematu

Nie „zaimplementować generyki”, tylko decyzja / notatka: **zostajemy przy D3**
albo **planujemy wariant 2/3** z przykładem (np. `Vec[T]` vs `$fn vec`).

- [ ] zebrać 2–3 miejsca w stdlib/przykładach, gdzie `$fn` jest wyraźnie gorsze
- [ ] krótka aktualizacja D3 albo osobna decyzja w `note/`
