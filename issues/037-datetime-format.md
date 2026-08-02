# 037 — Date/time formatting (`stdlib/time`)

**Status:** ✅ done
**Depends on:** 016 (print / `str`), 012

## Decisions (MVP)

- Module [`stdlib/time.kl`](../stdlib/time.kl): `Instant`, `MonoInstant`, `Duration`
- Explicit clocks: `now()` (wall), `mono()` (monotonic) — RTC / CPU **separately**
- Format/parse to user buffer (`strftime` / ISO); **not** `${t:…}` in 016
- Host helpers in C emission: `klin_time_*` (`clock_gettime`, `gmtime_r`, `strftime`, `timegm`)
- Zero `malloc` on library path

Docs: [docs/08-time.md](../docs/08-time.md). Golden: `test/time_basic.kl`.
Demo: `examples/time_demo.kl`.

## Out of scope / later (Luxon-like)

```klin
// NOT in 037 MVP:
DateTime.setZone("Europe/Warsaw")
DateTime.fromFormat(…, { locale: "pl" })
interval.toDuration("months")
t.toRelative()
"${t:yyyy-MM-dd}"
time.now() hiding RTC / CYCCNT
```

Follow-ups (separate issues):

- [039](039-time-calendar.md) ✅ — calendar `add_days` / `add_months` / `add_years`
- [040](040-time-zones.md) — IANA timezones + DST
- [041](041-time-locale-relative.md) — locale + relative strings
- [042](042-time-format-luxon.md) — Luxon tokens in `time.format` / `parse`
- [043](043-rtc.md) — `rtc.read() → Instant`
- [044](044-cpu-cycles.md) — CPU cycles / SysTick → `Duration`

**Not planned** (no separate issue): interpolation sugar `${t:…}` / `${t:yyyy-MM-dd}` —
format only via `time` API (016 stays printf/masks).

## Relation to 016

Interpolation = printf/masks. Dates = exclusively `time.format` / `parse`.
