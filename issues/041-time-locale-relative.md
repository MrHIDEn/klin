# 041 — Locale dat + relative strings

**Status:** 💭 do rozważenia
**Zależy od:** [037](037-datetime-format.md)

## Kontekst

MVP formatu = `strftime` bez nazw zależnych od języka (`%A` itd.) i bez
relative („2 days ago” / Luxon `toRelative`).

## Propozycja

- nazwy dni/miesięcy dla wybranego locale (jawny argument / stała — nie
  globalny ukryty stan, jeśli da się uniknąć)
- `to_relative` → zapis do bufora użytkownika (jak `format`), nie `str` z
  heapu
- bez `n3`-style number formats w datach (osobna decyzja vs 016)

## Czego nie robić

- Ukrytej alokacji przy formatowaniu.
- Wciągania IANA (040) „przy okazji”, jeśli nie jest konieczne.
- Cukru `${t:…}` w interpolacji 016.
