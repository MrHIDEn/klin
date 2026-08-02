# 080 — `stdlib/str` — comparisons and string helpers

**Status:** ✅ done
**Depends on:** [012](012-stdlib-io.md) (stdlib module pattern), [021](021-c-libraries.md) (FFI/libc); related to [016](016-string-interpolation.md), [077](077-string-template.md)

## Problem

`str` in Klin is `const char*`. `==` on `str` **does not work** (would compare addresses,
not content — silent trap), so content comparison used to be raw:

```klin
@[cimport, codename("strcmp")]
fn strcmp(a: str, b: str): i32

if strcmp(s, "red") == 0 { … }
```

Downsides: repeated `@cimport` boilerplate, easy to mix up direction / forget
`== 0`. We want something more mature, but **without** breaking the overarching principle.

## Design decision (why not an operator)

- **Do not** overload `==` for `str` to mean “content comparison". `==` on `int` disappears
  in emission (1 instruction); `strcmp` is an O(n) loop that **does not disappear** — hidden
  cost behind an operator breaks the principle (“if a feature does not disappear in C emission, it breaks
  the rule"). Cost must be visible → function, not operator.
- Similarly **do not** add “string‑match" (`match s { "red" {…} }`) — that is also a
  `strcmp` chain. `match` stays int/enum‑only.

## Delivered: thin library module

[`stdlib/str.kl`](../stdlib/str.kl) — libc wrapper, cost visible (call):

```klin
import str
if str.eq(s, "red") { … }
let n = str.len(s)
```

Golden: [`test/str_eq.kl`](../test/str_eq.kl). Example: [`examples/str_eq.kl`](../examples/str_eq.kl).

Model like Go (`strings`) / Zig — library functions, not operator magic.

## MVP

- [x] `stdlib/str` with `eq` (and `len`), via `@cimport` on `strcmp`/`strlen`.
- [x] Golden + example; hook into stdlib import mechanism (like `io`/`mem`).
- [x] Docs (README, stdlib README).

## Out of scope

- Overloading `==` / “string‑match" (deliberately, see above).
- Owning / mutable strings / allocation (that is `Allocator` + [077](077-string-template.md)).
- Unicode/locale (libc `strcmp` is byte-wise) — possibly later.
- `starts_with` / `ends_with` / `contains` (future).
