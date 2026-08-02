# 073 — Wykrywanie potencjalnych wycieków pamięci

**Status:** 💭 do rozważenia
**Zależy od:** 055/057 (`Allocator`, [docs/14](../docs/14-allocator.md)), 008 (`defer`)

## Pytanie

Czy Klin powinien wykrywać potencjalne wycieki pamięci — i czy to w ogóle
możliwe bez łamania zasady nadrzędnej (brak ukrytego runtime / kosztu)?

## Odpowiedź krótko

Częściowo. Pełne, **pewne** wykrywanie jest w ogólności nierozstrzygalne i
wymagałoby systemu własności/borrow (à la Rust) — duży, sprzeczny z prostotą
Klina. Ale kilka tańszych mechanizmów jest realnych, a model Klina temu sprzyja:
jawny `Allocator` ([`stdlib/mem.kl`](../stdlib/mem.kl)), `defer` do sprzątania,
brak GC i ukrytej alokacji.

## Warianty (od najtańszego)

1. **Zewnętrzne narzędzia na emitowanym C** — Klin emituje czytelny `.c`/binarkę,
   więc Valgrind / ASan+LSan działają wprost na hostowych buildach. Zero kosztu
   językowego. Najsilniejsza pragmatyczna ścieżka; wystarczy udokumentować wzorzec
   (np. w CI / `docs/`).
2. **Debug-alokator (opcjonalny, host)** — wariant `mem`, który liczy
   `alloc`/`free`, taguje miejsce alokacji i na końcu raportuje niezwolnione
   bloki. Biblioteka / opt-in (jak `slice_alloc`); bare-metal bez heapu go nie
   ciąga. Zero „magii" w rdzeniu.
3. **Konserwatywny lint statyczny (frontend)** — wewnątrz funkcji: wynik
   `mem.alloc_*` / `alloc_bytes` przypisany do zmiennej powinien mieć pasujący
   `defer mem.free_*` / jawny `free` przed końcem zakresu; inaczej **ostrzeżenie**
   „alloc bez free". Tani, ale tylko heurystyka (patrz ograniczenia).

## Ograniczenia (uczciwie)

- Lint statyczny jest z natury niepełny: aliasy, przekazanie własności do innej
  funkcji, zwrot bufora z funkcji, warunkowe ścieżki → fałszywe alarmy albo
  przeoczenia.
- Sound-check wymagałby modelu własności/borrow — zmienia język; poza zakresem.
- Dlatego: lint jako **ostrzeżenie** (nie twardy błąd), a „twarde" wykrywanie
  oprzeć na Valgrind/ASan w CI.

## Propozycja zakresu (gdy wejdzie do prac)

- [ ] Nota/wzorzec: Valgrind + ASan/LSan na hostowym buildzie (CI) — najpierw to.
- [ ] Opcjonalny debug-alokator w `stdlib` (licznik + raport niezwolnionych).
- [ ] (Opcjonalnie) konserwatywny lint intra-proceduralny „alloc bez
  free/defer" jako ostrzeżenie, z jawnym wyłącznikiem dla przekazania własności.

## Non-goals

- GC / liczniki referencji w rdzeniu.
- Ownership / borrow-checker jako cecha języka.
- „Autofree" wyniku / ukryte `defer`.
- Pełna, sound analiza między-proceduralna wycieków.
