# 012 — Opcjonalny moduł I/O (`println` itd.)

**Status:** ✅ zrobione
**Zależy od:** 006 (moduły)

## Kontekst

W 001 hello world idzie przez C-owe `puts` — to świadomie cienkie FFI,
nie biblioteka standardowa Klina.

V ma builtin `print` / `println` / `eprint` / `eprintln`. Klin **nie**
powinien mieć dwóch równorzędnych API w rdzeniu (`puts` + `println`).

## Decyzja

Opcjonalny moduł `stdlib/io.kl`, importowany jawnie — nie w builtinach:

```
import io

fn main() {
    io.print("hello")
    io.println(" world")
}
```

- Nazwa: `io` (nie `vstd`).
- `println` → `@[cimport, codename("puts")]` (z newline, zero narzutu).
- `print` → cienki wrapper `printf("%s", …)` (bez newline).
- Typ `str` = `const char*` (parametry FFI / stdlib; literały napisów).
- Na bare-metalu po prostu nie importujesz.
- Szukanie: sibling → `$KLIN_STDLIB` → `<repo>/stdlib/`.

## Kryterium ukończenia

- [x] `import io` + `io.print` / `io.println` w teście złotym
- [x] `println` emituje `puts` (nie `io_println(`)
- [x] `puts` w rdzeniu nadal działa bez importu (cienkie FFI jak w 001)
