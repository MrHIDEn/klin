# 016 — Interpolowane napisy

**Status:** ✅ zrobione
**Zależy od:** 012 (`str` / `io`)

## Ustalenia

- Składnia Dart/V w zwykłym `"…"`: `$name`, `${expr}`, `${expr:format}`
- Format: **printf** (`%d`, `%.2f`) + cukier masek (`0.00` → `%.Nf`, `0.###` →
  trim helper), `sN` → `%.Ns`, `hex` / `sci`
- Emisja: `printf` (zero ukrytej alokacji); `0.###` → bufor na stosie +
  `klin_fmt_trim_frac`
- **Print-only MVP** — sinki: `puts` / `printf` / `io.print` / `io.println`
- Bez `n3` / kultury; daty → [037](037-datetime-format.md)

Runtime podmiana wąsów (wzorzec-jako-dane, `{0}` / `{klucz}`) → osobno
[077](077-string-template.md).

Szczegóły: [docs/07-interpolacja.md](../docs/07-interpolacja.md).
Golden: `test/interp.kl`. Demo: `examples/interp.kl`.
