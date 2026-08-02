# 039 — Calendar operations on `Instant`

**Status:** ✅ done
**Depends on:** [037](037-datetime-format.md)

## Scope

Go-style UTC civil calendar add on wall `Instant`:

- `add_date(years, months, days): !Instant`
- `add_years` / `add_months` / `add_days` (negative `n` = go back)
- Host: `klin_time_add_date` (`gmtime_r` + `timegm`, preserved ns fraction)
- No `Interval` type (still two `Instant` + `between`)

Golden: `test/time_calendar.kl`. Docs: [docs/08-time.md](../docs/08-time.md).

## Out of scope

- IANA / DST → [040](040-time-zones.md)
- Locale / relative → [041](041-time-locale-relative.md)
- Interval struct, `${t:…}` sugar, calendar months as `Duration` in ns
