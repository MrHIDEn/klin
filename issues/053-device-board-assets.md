# 053 — `$device` + Go-like SVD fetch (IOC / board)

**Status:** ✅ MVP (SVD + `device` in `klin.mod`); board / `.ioc` → [074](074-board-ioc-klin-mod.md)  
**Depends on:** [027](027-svd-ergonomic-api.md); [049](049-remote-imports.md)

## Context

Today an app (e.g. blink) calls directly:

```klin
$peripherals_from_svd("../../../third_party/svd/stm32f411.svd", "RCC,GPIOA,STK")
```

That works and is zero-cost, but UX mixes a **local path to XML** with code
and requires manual SVD vendoring. We want a cleaner model: like Go —
**you provide an artifact id / path, Klin fetches and caches**.

`import` = Klin modules (symbols, `pub`, mangling) — [048](048-import-aliases.md) /
[049](049-remote-imports.md).  
`$device` / `$board` = **vendor artifacts** (SVD, optionally IOC) → codegen —
same string style as Go/`import "…"`, but **different command** so models
are not mixed.

## Goal A — Go-style SVD fetch (UX priority) — MVP ✅

User (or thin package) writes a path like a Go module; Klin resolves →
cache → codegen. No manual copying of `third_party/svd/`.

```klin
// top-level — not in main
$device("github/tinygo-org/stm32-svd/svd/stm32f411.svd", "RCC,GPIOA,STK")
// alias: $peripherals_from_svd(…)

fn main() {
  RCC.AHB1ENR.GPIOAEN.set(1)
}
```

**Resolution:**

1. local file / relative path (027)
2. cache `$KLIN_CACHE/asset/host/owner/repo/…` (after `klin get`)
3. network only via `klin get` / `klin update` — allowlist
   `github/tinygo-org/stm32-svd` (not raw ST; see [011](011-svd.md))
4. pin in `klin.mod` (`device path ref`) + `klin.lock` (commit + sha256 of file)

**Manifest — one `klin.mod`:**

```
klin 1
require github/klin-lang/osa v0.1.0
device github/tinygo-org/stm32-svd/svd/stm32f411.svd main
```

`klin get github/tinygo-org/stm32-svd/svd/stm32f411.svd@main` appends `device`.
Without args refreshes `require` **and** `device`. Compile / `run` without network;
missing cache → error with `klin get` hint.

## Goal B — package layer (optional, later)

```klin
import stm32_f411          // inside: $device("github/…/….svd", …)
import board_nucleo_f411re // pin constants; optionally $board("…")
```

## Built-in syntax

```klin
$device("…" /* local | github/…/….svd */, "RCC,GPIOA")
$board("…")   // later — narrow .ioc → constants; not full CubeMX
```

- top-level, `$` family (D3); `$device` = alias for `$peripherals_from_svd`
- **not** `import "foo.svd"` — remote string for SVD goes through `$device("…")`

## Evolution sketch

1. ~~Local `$peripherals_from_svd` ([027](027-svd-ergonomic-api.md)).~~
2. ~~`$device` + local resolution.~~
3. ~~Remote path + cache + allowlist + visible fetch + `device` in mod.~~
4. **Later:** `board` / narrow `.ioc` → [074](074-board-ioc-klin-mod.md); short chip IDs; board packages.
5. Remote Klin packages with `$device` inside (049).

## What not to do

- `import "x.svd"` as module syntax — mixes with [048](048-import-aliases.md);
  SVD fetch = `$device("…")` (Go-like string, not the `import` keyword)
- separate keyword `svd` / `ioc` / `device` outside the `$` family (`device` line in
  **mod** is OK — not a language keyword)
- full CubeMX `.ioc` → Klin — pinout / `$board` / `board` directive → [074](074-board-ioc-klin-mod.md)
- silent download on `run` / compile
- raw ST SVD by default (errors — [011](011-svd.md)); mirror with patches
- HAL through this mechanism — [031](031-hal-libraries.md)

## Criteria

- [x] `$device("github/…/….svd", …)` → `klin get` + cache + codegen
- [x] recompile offline from cache; missing file = error with `klin get`
- [x] allowlist (`github/tinygo-org/stm32-svd`); pin in mod + lock
- [x] local path still works (`$device` / `$peripherals_from_svd`)
- [x] zero-cost like 027 (same emitter)
- [x] documentation: `import` = Klin; `$device("github/…")` = artifact
- [x] example: [`examples/stm32/device_f411/`](../examples/stm32/device_f411/)
- [x] `device` directive in `klin.mod` (beside `require`; explicit + implicit like 049)
- [ ] (optional) packages `import stm32_…` / short chip ID — board → [074](074-board-ioc-klin-mod.md)

## Related

- [011](011-svd.md) / [027](027-svd-ergonomic-api.md) — generator and fluent API
- [023](023-examples.md) — `examples/stm32/`
- [054](054-embedded-project-layout.md) — directory layout / scaffold (separate from SVD)
- [031](031-hal-libraries.md) — HAL separately
- [048](048-import-aliases.md) / [049](049-remote-imports.md) — string/remote for
  **Klin modules**; this issue = same *fetch style* for **artifacts** `$device`
- [074](074-board-ioc-klin-mod.md) — `board` in `klin.mod` + narrow `.ioc` (after 053)
