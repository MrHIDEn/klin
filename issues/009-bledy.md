# 009 — Błędy jako wartości

**Status:** ⬜ do zrobienia
**Zależy od:** 008

## Zakres

```
pub fn load(path: string): !Config {
    let f = os.open(path)!
    defer f.close()
    return parse(f)!
}

let cfg = load("app.toml") or {
    log.warn("brak configu")
    Config.defaults()
}
```

- `!T` jako typ sumaryczny → struct z tagiem w C
- operator propagacji → `if (r.is_err) return r;`
- blok `or { }` z dostępem do `err`
- brak `null`: `?T` jako opcja

## Kryterium ukończenia

- [ ] propagacja przez 3 poziomy wywołań
- [ ] `or` z wartością domyślną
- [ ] błąd kompilacji przy zignorowaniu `!T`
- [ ] objdump: narzut = sprawdzenie flagi, nic więcej
