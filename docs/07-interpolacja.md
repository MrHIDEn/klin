# String interpolation

Syntax like Dart/V in plain `"…"` (no `$"` prefix).

## Slots

| Form | Meaning |
|---|---|
| `$name` | simple name |
| `${expr}` | expression; default format from type |
| `${expr:%d}` | native `printf` specifier |
| `${x:0.00}` | mask → `%.2f` |
| `${x:0.###}` | optional places → `klin_fmt_trim_frac` + `%s` |
| `${s:s8}` | truncate → `%.8s` |
| `${n:hex}` / `${f:sci}` | aliases for `%x` / `%e` |
| `\$` | literal `$` |

**MVP:** interpolation is **print-only** — sole argument to `puts` / `printf` /
`io.print` / `io.println`. Not: `let s = "a $b"`.

Alignment / padding: explicit printf (`%8s`, `%-8s`, `%08x`). Dates → [issue 037](../issues/037-datetime-format.md).

Example: [`examples/interp.kl`](../examples/interp.kl).
