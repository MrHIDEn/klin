# 045 — Eksport Klin → C (`@[cexport]`)

**Status:** ✅ zrobione
**Zależy od:** [021](021-biblioteki-c.md)

## Kontekst

021 = C → Klin (`@[cimport]` / `@[link]`).
Odwrotność: kod Klin wołany z C / ASM.

Częściowo działało już `@[codename("…")]` + ciało (ISR, np. `SysTick_Handler`).
Issue 045 dodaje jawny marker `@[cexport]`.

## API

```klin
@[cexport, codename("klin_add")]
fn add(a: i32, b: i32): i32 {
    return a + b
}
```

- `@[cexport]` — fn z ciałem; symbol globalny w emisji C
- `@[codename("…")]` — **wymagane** z `cexport` (stabilna nazwa dla C)
- `@[codename]` bez `cexport` — nadal OK (ISR / legacy)
- Nie łączyć z `@[cimport]`

Przykład: [`examples/cexport_add/`](../examples/cexport_add/).
Nota: [`note/09-ffi-c.md`](../note/09-ffi-c.md) (import **i** export).

## Poza zakresem

- [ ] `--emit-h` (nagłówek C z prototypami)
- [ ] automatyczne `.a` / `.so`
- [ ] `cexport` na metodach / typach
- [ ] rpath / `LD_LIBRARY_PATH`
