# 000 — Trzy decyzje fundamentalne

**Status:** ✅ rozstrzygnięte (patrz `docs/01-decyzje.md`)
**Blokuje:** wszystko

## Opis

Przed pierwszą linią parsera podjąć trzy decyzje, które przenikają
tablicę symboli, checker i codegen. Zmiana później = przepisywanie.

1. **Model pamięci** → ręczny + `defer` + alokator jako jawny argument
2. **Model błędów** → `!T` + operator propagacji + `or { }`
3. **Generyki** → preprocesor, nie gramatyka

## Kryterium ukończenia

Zapisane w `docs/01-decyzje.md` z uzasadnieniem każdego odrzucenia.
