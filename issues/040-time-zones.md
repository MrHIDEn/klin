# 040 — Strefy IANA + DST

**Status:** 💭 do rozważenia
**Zależy od:** [037](037-datetime-format.md)

## Kontekst

`Instant` w 037 to UTC / unix ns. Brak `setZone("Europe/Warsaw")`, offsetu
lokalnego i reguł DST. Baza stref to duży artefakt (rozmiar, aktualizacje)
— świadomie poza MVP.

## Propozycja

- jawne API strefy (np. `Instant` + `Zone` / offset), zero magii w `now()`
- źródło danych stref: do decyzji (host libc? osadzona baza? zewnętrzny plik)
- format lokalny nadal do **bufora użytkownika**

## Czego nie robić

- Ukrywania RTC / CPU jako `time.now()` ([043](043-rtc.md), [044](044-cpu-cycles.md)).
- Locale nazw dni ([041](041-time-locale-relative.md)) w tym samym kroku, jeśli
  da się rozdzielić.
- Cukru interpolacji `${t:…}`.
