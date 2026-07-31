# 038 — Ergonomia API `stdlib/time`

**Status:** ✅
**Zależy od:** 037

## Zakres

Dopisanie metod (zero FFI, zero alokacji):

- `Instant.until` / `MonoInstant.until` → `Duration`
- `MonoInstant.add` / `sub` (`Duration`)
- `Duration.abs` / `mul`
- Rename `as_sec` → `as_s`

Golden: `test/time_basic.kl`. Docs: [note/08-time.md](../note/08-time.md).

## Poza zakresem

Luxon-like z 037 (IANA, locale, kalendarzowe miesiące, `${t:…}`, RTC/CPU).
