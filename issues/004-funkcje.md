# 004 — Funkcje

**Status:** ⬜ do zrobienia
**Zależy od:** 003

## Zakres

- parametry z typami, wartość zwracana
- wiele funkcji w pliku
- rekurencja
- **sortowanie topologiczne deklaracji + forward declarations w emisji**

## Uwaga kluczowa

W Klinie kolejność funkcji w pliku nie ma znaczenia. W C ma.
Codegen musi sam posortować i wyemitować prototypy w sekcji deklaracji.

To pierwszy moment, gdy generowany C przestaje być odbiciem źródła.

## Kryterium ukończenia

- [ ] funkcja wywołana przed swoją definicją w pliku działa
- [ ] rekurencja (fibonacci)
- [ ] błąd przy złej liczbie/typie argumentów
