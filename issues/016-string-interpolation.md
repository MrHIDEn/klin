# 016 — Interpolated strings

**Status:** ✅ done
**Depends on:** 012 (`str` / `io`)

## Decisions

- Dart/V syntax in plain `"…"`: `$name`, `${expr}`, `${expr:format}`
- Format: **printf** (`%d`, `%.2f`) + mask sugar (`0.00` → `%.Nf`, `0.###` →
  trim helper), `sN` → `%.Ns`, `hex` / `sci`
- Emission: `printf` (zero hidden allocation); `0.###` → stack buffer +
  `klin_fmt_trim_frac`
- **Print-only MVP** — sinks: `puts` / `printf` / `io.print` / `io.println`
- No `n3` / locale; dates → [037](037-datetime-format.md)

Runtime mustache substitution (pattern-as-data, `{0}` / `{key}`) → separately
[077](077-string-template.md).

Details: [docs/07-interpolacja.md](../docs/07-interpolacja.md).
Golden: `test/interp.kl`. Demo: `examples/interp.kl`.
