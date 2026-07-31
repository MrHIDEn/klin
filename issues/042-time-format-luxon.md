# 042 — Dialekt formatu Luxon/V (`yyyy-MM-dd`)

**Status:** 💭 do rozważenia
**Zależy od:** [037](037-datetime-format.md)

## Kontekst

MVP: dialekt `strftime` (`%Y-%m-%d`) w `time.format` / `parse`. Tokeny w
stylu Luxon / V (`yyyy-MM-dd`, `HH:mm`) bywają czytelniejsze — **wyłącznie**
jako drugi dialekt w API `time`, nigdy jako slot interpolacji globalnej.

## Propozycja

- `time.format(buf, "yyyy-MM-dd", t)` albo jawny tryb / osobna fn
- ten sam subset co dziś (data/czas UTC); bez locale-heavy tokenów (041)
- parse odwrotny dla tego dialektu

## Czego nie robić

- `${t:yyyy-MM-dd}` / `${t:%Y-…}` w 016 — **nie planowane** (zostaje w 037).
- Zastępowania `strftime` bez potrzeby — oba dialekty mogą współistnieć.
