# 012 — Opcjonalny moduł I/O (`println` itd.)

**Status:** ✅ ukończone
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
    io.println("hello")
}
```

- Nazwa: `io` (nie `vstd`).
- Emisja: `@[cimport, codename("puts")]` — zero narzutu względem `puts`.
- Typ `str` = `const char*` (parametry FFI / stdlib; literały napisów).
- Na bare-metalu po prostu nie importujesz.
- Szukanie: sibling → `$KLIN_STDLIB` → `<repo>/stdlib/`.

## Kryterium ukończenia

- [x] `import io` + `io.println(...)` działa w teście złotym
- [x] emisja woła `puts` (nie osobną funkcję-wrapper z `bl`)
- [x] `puts` w rdzeniu nadal działa bez importu (cienkie FFI jak w 001)
