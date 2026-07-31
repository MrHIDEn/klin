# 006 — Moduły

**Status:** ✅ zrobione
**Zależy od:** 005

## Zakres

- wiele plików
- `module nazwa` / `import`
- `pub` — bez niego symbol jest prywatny (**w module**; pliki pakietu-katalogu
  z [047](047-directory-modules.md) dzielą tę przestrzeń)
- prefiks modułu w manglingu
- `static` w C dla symboli prywatnych

## Uzasadnienie

To odpowiedź na pierwotny problem: w C nazwy zewnętrzne mają domyślnie
external linkage i leżą w jednej płaskiej przestrzeni. Obejścia to
`static` i konwencja prefiksów (`gtk_widget_show`, `sqlite3_open`).
Klin ma to zrobić za programistę.

C23 nadal nie ma modułów; C++ dostał je dopiero w C++20.

## Decyzja

`pub` jawne, a nie eksport przez wielkość litery jak w Go — jawne bije
ukryte w konwencji nazewniczej.

## Nota

[`note/12-moduly.md`](../note/12-moduly.md). Przykłady: [`examples/modules/`](../examples/modules/),
katalog-pakiet: [`examples/pkg_geom/`](../examples/pkg_geom/).

## Kryterium ukończenia

- [x] projekt z 3 modułów kompiluje się do jednego `.c`
- [x] symbol bez `pub` niedostępny z innego modułu (błąd kompilacji)
- [x] symbole prywatne są `static` w wyjściu
