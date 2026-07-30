# 017 — Metody kolekcji w stylu JS (`map` / `filter` / …)

**Status:** 💭 do rozważenia
**Zależy od:** 007 (tablice/slice), ewentualnie D3 (makra) / domknięcia

## Kontekst

W JS: `arr.map(…)`, `filter`, `reduce`, `find`, `forEach`. Wygodne, ale w językach systemowych łatwo o ukrytą alokację i ukryty koszt (callback, heap).

## Propozycja (później)

API na slice/tablicach **jawne co do alokacji**, np.:

```
let out = xs.map(a, |x| x * 2)   // a = alokator — widać koszt
// albo tylko wersje in-place / z buforem wyjściowym:
xs.map_into(dst, |x| x * 2)
```

Alternatywa bliższa Klinie (D3): makra czasu kompilacji generujące pętle — zero runtime „funkcji wyższego rzędu”, jeśli nie ma tanich domknięć.

## Czego nie robić

- Nie kopiować JS 1:1 (`map` zawsze nowa tablica z GC).
- Nie dodawać przed slice’ami (007) i decyzją o domknięciach (`note/01-decyzje.md` D7).
- Każda taka metoda: test zasady nadrzędnej (`objdump` vs ręczna pętla w C).
