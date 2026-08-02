# 040 — IANA timezones + DST

**Status:** 💭 to consider
**Depends on:** [037](037-datetime-format.md)

## Context

`Instant` in 037 is UTC / unix ns. No `setZone("Europe/Warsaw")`, local
offset, or DST rules. Timezone database is a large artifact (size, updates)
— deliberately outside MVP.

## Proposal

- explicit zone API (e.g. `Instant` + `Zone` / offset), no magic in `now()`
- zone data source: to decide (host libc? embedded database? external file)
- local format still to **user buffer**

## What not to do

- Hide RTC / CPU as `time.now()` ([043](043-rtc.md), [044](044-cpu-cycles.md)).
- Locale day names ([041](041-time-locale-relative.md)) in same step if
  separable.
- Interpolation sugar `${t:…}`.
