# 026 — Preprocessor (`$…`, D3)

**Status:** 💭 do rozważenia
**Zależy od:** stabilny frontend (praktycznie po 010+); nie blokuje 011

## Cel

Implementacja decyzji D3 ([note/01-decyzje.md](../note/01-decyzje.md)): makra
czasu kompilacji z dostępem do AST (wzorzec Nelua), **nie** generyki w gramatyce.

## Zakres szkicu

- `$fn` / expand przed checker+emit
- komunikaty błędów z lokalizacją w makrze
- bez pełnego języka szablonów w pierwszym cięciu
- wynik preprocessingu możliwy do obejrzenia

Generator SVD z [011](011-svd.md) jest narzędziem zewnętrznym; nie jest
preprocesorem kompilatora. Ładne API SVD → [027](027-svd-ergonomic-api.md).

## Kryterium

Proste makro generuje wyspecjalizowany AST i przechodzi golden test.
