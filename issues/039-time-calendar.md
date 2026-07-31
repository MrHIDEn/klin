# 039 — Operacje kalendarzowe na `Instant`

**Status:** ✅
**Zależy od:** [037](037-datetime-format.md)

## Zakres

Go-style UTC civil calendar add na wall `Instant`:

- `add_date(years, months, days): !Instant`
- `add_years` / `add_months` / `add_days` (ujemne `n` = cofanie)
- Host: `klin_time_add_date` (`gmtime_r` + `timegm`, zachowany ułamek ns)
- Bez typu `Interval` (nadal dwa `Instant` + `between`)

Golden: `test/time_calendar.kl`. Docs: [note/08-time.md](../note/08-time.md).

## Poza zakresem

- IANA / DST → [040](040-time-zones.md)
- Locale / relative → [041](041-time-locale-relative.md)
- Interval struct, cukier `${t:…}`, kalendarzowe miesiące jako `Duration` w ns
