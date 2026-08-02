# `time` module (wall / monotonic)

Model like Go: **Instant** (wall UTC) + **MonoInstant** (measurements) + **Duration**
(ns). Format only into **user buffer** — no hidden `malloc`, no
`${t:yyyy-MM-dd}` in interpolation 016.

## Clocks (explicit)

| API | Source |
|---|---|
| `time.now()` | `CLOCK_REALTIME` → `Instant` |
| `time.mono()` | `CLOCK_MONOTONIC` → `MonoInstant` |
| RTC / CPU cycles | **separate** API (HAL/board) — not `now()` |

## Duration / span

- `between(a, b)` / `a.until(b)` — `b - a`
- `Duration.abs` / `mul`; components `as_ns` / `as_us` / `as_ms` / `as_s`
- `MonoInstant.add` / `sub` (`Duration`) like `Instant`

## Calendar (UTC, Go `AddDate`)

Do not confuse with `add(Duration)` (pure ns). Civil operations:

```klin
let t = time.unix(1704067200)   // 2024-01-01 UTC
let y = t.add_years(1) or { t } // 2025-01-01
let m = time.unix(1706659200).add_months(1) or { t }  // 2024-01-31 → 2024-03-02
let d = t.add_days(5) or { t }
```

`add_date(years, months, days)` — shared path; negative values go backward.
Preserves UTC time and ns fraction. IANA zones → [040](../issues/040-time-zones.md).

## Example

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

MVP format dialect: `strftime` (`%Y %m %d %H %M %S` …).  
Parse: `parse_iso` / `parse(fmt, s)` → `!Instant` (in `main` use `or { }`).

Details and out of scope: [issues/037-datetime-format.md](../issues/037-datetime-format.md),
[issues/038-time-api.md](../issues/038-time-api.md),
[issues/039-time-calendar.md](../issues/039-time-calendar.md).
Demo: [examples/time_demo.kl](../examples/time_demo.kl).
Golden calendar: `test/time_calendar.kl`.
