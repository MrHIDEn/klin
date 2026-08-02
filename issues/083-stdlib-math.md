# 083 — `stdlib/math` — thin libm helpers

**Status:** ✅ done
**Depends on:** [012](012-stdlib-io.md) (stdlib module pattern), [021](021-c-libraries.md) (FFI / `@[link]`)

## Goal

Optional host module for common floating-point math — Klin style like
`io` / `str`, **not** a global JS `Math` object:

```klin
import math
let y = math.sin(x)
let a = math.abs(-2.5)
```

Thin `@[cimport]` over `<math.h>` + `@[link("-lm")]`. Cost is a call (libm).

## MVP API (`f64` only)

| Klin | C |
|---|---|
| `sin` / `cos` / `tan` | `sin` / `cos` / `tan` |
| `sqrt` | `sqrt` |
| `abs` | `fabs` |
| `floor` / `ceil` | `floor` / `ceil` |
| `pow` | `pow` |
| `log` / `log10` / `log2` | `log` (ln) / `log10` / `log2` |
| `min` / `max` | `fmin` / `fmax` |
| `pi()` / `di()` / `e()` | Klin literals (`di` = 2π; no module-level `const`) |

## Delivered

- [`stdlib/math.kl`](../stdlib/math.kl)
- Golden [`test/math_basic.kl`](../test/math_basic.kl)
- Example [`examples/math_basic.kl`](../examples/math_basic.kl)

## Out of scope

- Integer `abs` / `i32` overloads
- `random`, full `<math.h>`, complex numbers
- Bare-metal without libm (simply do not `import math`)
