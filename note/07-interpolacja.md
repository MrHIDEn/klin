# Interpolacja napisów

Składnia jak w Dart/V w zwykłym `"…"` (bez prefiksu `$"`).

## Sloty

| Forma | Sens |
|---|---|
| `$name` | prosta nazwa |
| `${expr}` | wyrażenie; format domyślny z typu |
| `${expr:%d}` | natywny specyfikator `printf` |
| `${x:0.00}` | maska → `%.2f` |
| `${x:0.###}` | opcjonalne miejsca → `klin_fmt_trim_frac` + `%s` |
| `${s:s8}` | truncate → `%.8s` |
| `${n:hex}` / `${f:sci}` | aliasy `%x` / `%e` |
| `\$` | dosłowny `$` |

**MVP:** interpolacja jest **print-only** — jedyny argument `puts` / `printf` /
`io.print` / `io.println`. Nie: `let s = "a $b"`.

Wyrównanie / padding: jawny printf (`%8s`, `%-8s`, `%08x`). Daty → [issue 037](../issues/037-datetime-format.md).

Przykład: [`examples/interp.kl`](../examples/interp.kl).
