# Moduł `time` (wall / monotonic)

Model jak Go: **Instant** (wall UTC) + **MonoInstant** (pomiary) + **Duration**
(ns). Format tylko do **bufora użytkownika** — bez ukrytego `malloc`, bez
`${t:yyyy-MM-dd}` w interpolacji 016.

## Zegary (jawne)

| API | Źródło |
|---|---|
| `time.now()` | `CLOCK_REALTIME` → `Instant` |
| `time.mono()` | `CLOCK_MONOTONIC` → `MonoInstant` |
| RTC / cykle CPU | **osobne** API (HAL/board) — nie `now()` |

## Duration / span

- `between(a, b)` / `a.until(b)` — `b - a`
- `Duration.abs` / `mul`; składowe `as_ns` / `as_us` / `as_ms` / `as_s`
- `MonoInstant.add` / `sub` (`Duration`) jak u `Instant`

## Kalendarz (UTC, Go `AddDate`)

Nie mylić z `add(Duration)` (czyste ns). Operacje cywilne:

```klin
let t = time.unix(1704067200)   // 2024-01-01 UTC
let y = t.add_years(1) or { t } // 2025-01-01
let m = time.unix(1706659200).add_months(1) or { t }  // 2024-01-31 → 2024-03-02
let d = t.add_days(5) or { t }
```

`add_date(years, months, days)` — wspólna ścieżka; ujemne wartości cofają.
Zachowuje godzinę UTC i ułamek ns. Strefy IANA → [040](../issues/040-time-zones.md).

## Przykład

```klin
import time

fn main() {
    let t = time.unix(1704067200)
    let mut buf: [32]u8
    time.format(buf[:], "%Y-%m-%d", t)
    printf("%s\n", &buf[0])

    let later = t.add(time.seconds(5))
    printf("until_s=%lld\n", t.until(later).as_s())

    let t0 = time.mono()
    let dt = time.mono_since(t0)
    printf("elapsed_ns=%lld\n", dt.ns)
}
```

Dialekt formatu MVP: `strftime` (`%Y %m %d %H %M %S` …).  
Parse: `parse_iso` / `parse(fmt, s)` → `!Instant` (w `main` użyj `or { }`).

Szczegóły i poza zakresem: [issues/037-datetime-format.md](../issues/037-datetime-format.md),
[issues/038-time-api.md](../issues/038-time-api.md),
[issues/039-time-calendar.md](../issues/039-time-calendar.md).
Demo: [examples/time_demo.kl](../examples/time_demo.kl).
Golden calendar: `test/time_calendar.kl`.
