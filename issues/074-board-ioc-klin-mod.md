# 074 — `board` in `klin.mod` + narrow CubeMX `.ioc` (pinout)

**Status:** 💭 under consideration (after MVP [053](053-device-board-assets.md))
**Depends on:** [053](053-device-board-assets.md) (`$device` + `device` in mod + `asset/` cache); optionally [054](054-embedded-project-layout.md); **not** [031](031-hal-libraries.md)

## Context

[053](053-device-board-assets.md) = chip / SVD (`device` + `$device`).  
This issue = **board / pinout**, including future CubeMX **`.ioc`** reading.

For now **no IOC implementation**. Here we record the model so decisions are not lost:

- single **`klin.mod`** file (not separate `klin.hw` / `klin.dev`)
- **`board`** directive (not `hardware`, not `device`)
- IOC scope = **pin map only**, not full Cube
- ld / startup **not** from IOC — from board pack / `klin init` (layers A+B in
  [075 §1b](075-board-pack-init-host.md); this issue = layer C)

## Example `klin.mod`

```text
klin 1
require  github/mrhiden/osa v0.1.0
device   github/tinygo-org/stm32-svd/stm32f411.svd v0.1.0
board    github/mrhiden/boards/nucleo_f411re.ioc v0.1.0
```

| Directive | Artifact | Code |
|---|---|---|
| `require` | Klin package (`.kl`) | `import` |
| `device` | chip SVD (`.svd`) — [053](053-device-board-assets.md) | `$device("…")` |
| `board` | board / pinout (`.ioc` or later other pack) | `$board("…")` |

Explicit (line in mod) and implicit (`klin get …@ref` appends `board`) — like `require` / `device`.

## Source syntax (later)

```klin
$device("github/tinygo-org/stm32-svd/stm32f411.svd", use: "RCC,GPIOA,STK")
$board("github/mrhiden/boards/nucleo_f411re.ioc")

fn main() {
  // constants generated from IOC — pins only, e.g. LED → PA5
  GPIOA.MODER.MODER5.write(.Output)
}
```

- `$` family (D3); **not** `import "*.ioc"`
- same `klin get` / `asset/` cache / `klin.lock` as SVD; **different** parser after fetch

## Local `.ioc` in project (verdict)

After editing in Cube / manually **`.ioc` belongs to the project** — goes in git.
Remote/`klin.mod` **must not** overwrite it on ordinary `get` / `update`.

| Source | Role |
|---|---|
| Cache after `klin get …ioc@ref` | upstream / seed |
| File in project (`board/*.ioc`) | **editable source of truth**; committed |

Flow:

1. **Local only** — `$board("board/nucleo.ioc")`; no `board github/…` line
   (or line only as documentation “where it came from").
2. **Remote as seed** — `klin get` → cache; `klin init` / first setup
   **copies** to `board/*.ioc`. From then on resolution = local path.
3. **`klin update` does not overwrite** local `.ioc`. Refresh from upstream =
   separate, explicit command (e.g. “reset from remote”), not default behavior.

Resolution like SVD ([053](053-device-board-assets.md)): **local-first** —
existing file next to sources wins over `asset/` cache.

Line `board github/…` in mod = pin **upstream** (seed version), not
“always fetch from network instead of local”.

## When to start implementation

1. MVP 053 works (`device` + `$device` + offline).
2. Manual pinouts in `board_…` / [054](054-embedded-project-layout.md) directory hurt.
3. Scope still: **pinout only**.

## Scope (when it lands)

- [ ] `board` directive in `klin.mod` parser + lock
- [ ] `$board("…")` locally, then remote path (local-first)
- [ ] local `.ioc` in project not overwritten by `get`/`update`
- [ ] **subset** `.ioc` parser → pin constants (name → port/pin)
- [ ] zero HAL / clock tree / generated `main` from Cube
- [ ] e2e: one Nucleo `.ioc` → several constants; blink without manual pinout
- [ ] docs: “does not replace Cube”; local truth vs upstream

## Do not

- full CubeMX → Klin project
- confuse with `device` (SVD) or `require` (`.kl` lib)
- silent download on `run`
- **`klin get`/`update` overwriting** local, edited `.ioc` in project
- HAL via IOC — [031](031-hal-libraries.md)

## Related

- [053](053-device-board-assets.md) — `$device` / `device` (chip); IOC deliberately here, not in 053
- [049](049-remote-imports.md) / [065](065-project-lockfile.md) — get / lock
- [054](054-embedded-project-layout.md) — `board/` layout (startup/ld) separate from mod
- [075](075-board-pack-init-host.md) — board pack / `klin init` (ld+startup); host without this magic
- [031](031-hal-libraries.md) — HAL separately
