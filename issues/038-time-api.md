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

Luxon-like / hardware — osobne issue: [039](039-time-calendar.md)–[044](044-cpu-cycles.md)
(lista w [037](037-datetime-format.md)). Cukier `${t:…}` nie planowany.
