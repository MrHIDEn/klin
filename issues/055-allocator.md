# 055 — `Allocator` (jawny alokator)

**Status:** 💭 do rozważenia
**Zależy od:** [007](007-wskazniki-tablice-slice.md), [008](008-defer.md); D1 w [note/01-decyzje.md](../note/01-decyzje.md)

## Kontekst

Model pamięci (D1): ręczny + `defer` + **alokator jako jawny argument**
(Zig/Odin). Dziś w kodzie nie ma typu `Allocator` — tylko szkic w notatkach
i fazę 4 w [017](017-collection-methods.md) (`map_alloc` / `filter_alloc`).

Bez tego stdlib nie może oferować `*_alloc` bez ukrytego `malloc`.

## Propozycja (MVP)

```klin
// szkic — dokładne API do ustalenia przy implementacji
let buf = a.alloc(u8, n)!
defer a.free(buf)
```

- Typ / interfejs `Allocator` (lub cienki struct + metody) widoczny w sygnaturach
- Host MVP: libc `malloc` / `free` (opcjonalny moduł — nie na bare-metal bez libc)
- Później: arena (`deinit` jednym `defer`)
- Zero ukrytej alokacji w języku: alokacja tylko przez jawne `a.alloc` / `*_alloc`

Follow-up po MVP: [017](017-collection-methods.md) warstwa 2 — `slice.map_alloc_*`
/ `filter_alloc_*` z `*Allocator`.

## Czego nie robić

- GC, autofree, RAII / `using`
- Ukrytego `malloc` w emisji „dla wygody”
- Wymuszania alokatora na freestanding (import opcjonalny)
- Łączenia z pełnym 017 `*_alloc` w jednym PR, jeśli sam `Allocator` wystarczy jako osobny krok
