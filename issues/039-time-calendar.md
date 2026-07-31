# 039 — Operacje kalendarzowe na `Instant`

**Status:** 💭 do rozważenia
**Zależy od:** [037](037-datetime-format.md)

## Kontekst

MVP `time` dodaje / odejmuje tylko nanosekundy (`Duration`). Luxon / Go
`AddDate` operują na **kalendarzu** (dzień / miesiąc / rok wall-clock), co
nie sprowadza się 1:1 do stałej liczby ns (miesiące, DST przy lokalnym
czasie — strefy → [040](040-time-zones.md)).

## Propozycja

- `add_days` / `add_months` / `add_years` na wall `Instant` (UTC w MVP)
- opcjonalnie cienki `Interval` `{ start, end }` + metody długości w ns;
  MVP 037: dwa `Instant` + `between` wystarczy — nie wymuszać typu od razu

## Czego nie robić

- Ukrytej alokacji / magicznego locale.
- Mieszać ze strefami IANA (040) ani z cukrem `${t:…}` (nie planowane).
- Kalendarzowych miesięcy jako `Duration` w ns.
