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

## Przykład

```klin
import time

fn main() {
    let t = time.unix(1704067200)
    let mut buf: [32]u8
    time.format(buf[:], "%Y-%m-%d", t)
    printf("%s\n", &buf[0])

    let t0 = time.mono()
    let dt = time.mono_since(t0)
    printf("elapsed_ns=%lld\n", dt.ns)
}
```

Dialekt formatu MVP: `strftime` (`%Y %m %d %H %M %S` …).  
Parse: `parse_iso` / `parse(fmt, s)` → `!Instant` (w `main` użyj `or { }`).

Szczegóły i poza zakresem: [issues/037-datetime-format.md](../issues/037-datetime-format.md).
Demo: [examples/time_demo.kl](../examples/time_demo.kl).
