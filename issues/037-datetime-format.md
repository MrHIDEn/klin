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

- [ ] IANA timezones + DST
- [ ] Locale (nazwy dni/miesięcy)
- [ ] Relative strings (`toRelative` / „2 days ago”)
- [ ] Kalendarzowe `add_days` / `add_months` / `add_years`
- [ ] Typ `Interval` a la Luxon (MVP: dwa `Instant` + `between`)
- [ ] Cukier interpolacji `${t:…}` — format tylko przez API `time`
- [ ] RTC MCU / chip jako `time.now()` (zamiast: `rtc.read() → Instant`)
- [ ] Cykle CPU w module `time` (zamiast: osobne + jawne `freq_hz`)
- [ ] Tokeny Luxon (`yyyy-MM-dd`) jako dialekt w `time.format` (nie w slotach 016)

## Powiązanie z 016

Interpolacja = printf/maski. Daty = wyłącznie `time.format` / `parse`.
