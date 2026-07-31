# 037 — Formatowanie daty/czasu (`stdlib/time`)

**Status:** ✅
**Zależy od:** 016 (print / `str`), 012

## Ustalenia (MVP)

- Moduł [`stdlib/time.kl`](../stdlib/time.kl): `Instant`, `MonoInstant`, `Duration`
- Jawne zegary: `now()` (wall), `mono()` (monotonic) — RTC / CPU **osobno**
- Format/parse do bufora użytkownika (`strftime` / ISO); **nie** `${t:…}` w 016
- Host helpers w emisji C: `klin_time_*` (`clock_gettime`, `gmtime_r`, `strftime`, `timegm`)
- Zero `malloc` na ścieżce bibliotecznej

Docs: [note/08-time.md](../note/08-time.md). Golden: `test/time_basic.kl`.
Demo: `examples/time_demo.kl`.

## Poza zakresem / później (Luxon-like)

```klin
// NIE w 037 MVP:
DateTime.setZone("Europe/Warsaw")
DateTime.fromFormat(…, { locale: "pl" })
interval.toDuration("months")
t.toRelative()
"${t:yyyy-MM-dd}"
time.now() ukrywający RTC / CYCCNT
```

Follow-upy (osobne issue):

- [ ] [039](039-time-calendar.md) — kalendarzowe `add_days` / `add_months` / `add_years`; ewentualnie `Interval`
- [ ] [040](040-time-zones.md) — IANA timezones + DST
- [ ] [041](041-time-locale-relative.md) — locale (nazwy dni/miesięcy) + relative strings
- [ ] [042](042-time-format-luxon.md) — tokeny Luxon (`yyyy-MM-dd`) tylko w `time.format` / `parse`
- [ ] [043](043-rtc.md) — `rtc.read() → Instant` (nie `time.now()`)
- [ ] [044](044-cpu-cycles.md) — cykle CPU / SysTick → `Duration` (osobny moduł, jawne `freq_hz`)

**Nie planowane** (bez osobnego issue): cukier interpolacji `${t:…}` / `${t:yyyy-MM-dd}` —
format tylko przez API `time` (016 zostaje printf/maski).

## Powiązanie z 016

Interpolacja = printf/maski. Daty = wyłącznie `time.format` / `parse`.
