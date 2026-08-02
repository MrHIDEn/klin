# 038 — `stdlib/time` API ergonomics

**Status:** ✅ done
**Depends on:** 037

## Scope

Added methods (zero FFI, zero allocation):

- `Instant.until` / `MonoInstant.until` → `Duration`
- `MonoInstant.add` / `sub` (`Duration`)
- `Duration.abs` / `mul`
- Rename `as_sec` → `as_s`

Golden: `test/time_basic.kl`. Docs: [docs/08-time.md](../docs/08-time.md).

## Out of scope

Luxon-like / hardware — separate issues: [039](039-time-calendar.md)–[044](044-cpu-cycles.md)
(list in [037](037-datetime-format.md)). `${t:…}` sugar not planned.
