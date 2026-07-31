# 007 — Wskaźniki, tablice, slice'y

**Status:** ✅ zrobione
**Zależy od:** 006

## Zakres

- `&` referencja, dereferencja
- `*T` typ wskaźnikowy
- tablice o stałym rozmiarze
- slice: `struct { T* ptr; size_t len; }`
- `cast(*volatile u32, 0x4000_1000)` — potrzebne pod bare metal

## Uwagi

- Slice wymusza generyki → zależność od D3 (preprocesor).
- Arytmetyka wskaźników: Nelua jej zabrania i wymaga jawnego rzutowania
  na liczbę. Rozważyć to samo — czy zbyt restrykcyjne pod MCU?
- Rozważyć sprawdzanie zakresu w slice (wyłączalne w release).

## Kryterium ukończenia

- [x] slice przekazany do funkcji bez kopii
- [x] zapis do rejestru przez rzutowany wskaźnik volatile
