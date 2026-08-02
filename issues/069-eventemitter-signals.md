# 069 — Observer / EventEmitter / Signals (library)

**Status:** 💭 under consideration
**Depends on:** fn-ptr ([docs/13](../docs/13-fn-ptr.md)), `Allocator` ([057](057-allocator.md) / [docs/14](../docs/14-allocator.md)), patterns from [017](017-collection-methods.md); placement like [024](024-rtos.md)/[029](029-async-event-loop.md)

## Question

Can Klin get observer-style communication — `EventEmitter`,
even “signals” (including reactive signals from the JS/TC39 proposal) — **without**
hidden allocation / hidden runtime (overarching principle).

## A. Core constraints (shape the whole API)

- **No capture** (D7, [docs/13](../docs/13-fn-ptr.md)): callback is a top-level `fn(...)`
  , not closing over state. Context is passed via an **explicit pointer**:
  listener = pair `{ cb: fn(*mut u8, Ev): void, ctx: *mut u8 }`.
- **No hidden allocation/control/cost**: `emit`/`notify` is an explicit loop over
  slots; no auto-scheduler.
- **Memory explicit**: zero-alloc (fixed-capacity slot array, `on()` →
  `!i32` on overflow) **or** dynamically via `Allocator` (layer 2,
  like `slice_alloc`; `defer` at caller).
- **No generics in grammar**: monomorphization `$fn` per event type
  (`Emitter_i32`, `State_f64`, …).
- **Placement**: library (optional stdlib module or external via
  [049](049-remote-imports.md)), not core — as agreed for RTOS/loop
  ([024](024-rtos.md), [029](029-async-event-loop.md)).

### Status: checker blocker removed

Previously `on()` could not be written because the checker rejected writes to
nested places through a `mut` receiver (`self.slots[i] = …`). Assignment-target
mutability analysis (`_requireMutable*Place` in `lib/checker.dart`)
only accepted a bare variable as the base. Fixed: checking is now
recursive (like `_isMutablePlace` for `&`) — nested fields allowed,
array elements through `mut` receiver/variable, and writes through `*mut`. Emitter unchanged.
Unblocks emitter implementation.

## B. Observer / EventEmitter — yes, library

`EventEmitter` is simply the observer pattern (subject + many listeners) —
straightforward:

```
struct Listener_i32 {
    cb: fn(*mut u8, i32): void
    ctx: *mut u8
}

$fn emitter(T) {
  pub struct Emitter_$T { /* slots: [N]Listener_$T + n: i32 */ }
  pub fn (mut e: Emitter_$T) on(cb: fn(*mut u8, $T): void, ctx: *mut u8): !i32 { /* add slot */ }
  pub fn (e: Emitter_$T) emit(ev: $T) { /* for i: slots[i].cb(slots[i].ctx, ev) */ }
}
```

Zero hidden cost; `off`/`once` optional (explicit).

## C. “Signal” variants

1. **Explicit signal / Qt-like** (value + explicit `subscribe`/`notify`): same
   observer (value + slot list; `set(x)` calls slots). Yes, library.
2. **Reactive signal (JS/TC39 proposal: `State`/`Computed`/`Watcher`)**: does **not**
   port 1:1 — the essence of the proposal is **automatic dependency tracking**
   (`get()` in `Computed` registers a dependency), lazy memoization, and
   glitch-free propagation. That is hidden control + cost on every read +
   dynamic graph (heap). Only feasible as an **explicit variant** (below).
3. **System signal** (POSIX / RTOS event flags): FFI to C — different topic
   ([024](024-rtos.md)/[031](031-biblioteki-hal.md)).

## D. “JS Signals” the Klin way — explicit signals (proposal)

Keep ergonomics (State/Computed/Effect, laziness, memoization), but
**bind dependencies explicitly** (no auto-tracking):

| JS Signals (TC39) | Klin (explicit) |
|---|---|
| `Signal.State(v)` | `State_$T { value, subs }` + `get`/`set`; `set` → `notify` |
| `Signal.Computed(fn)` | `Computed_$T { value, dirty, compute: fn(*mut u8): $T, ctx }`; deps recorded manually (subscribe to inputs → `dirty = true`); `get` recomputes when `dirty` (memoization) |
| auto-tracking | none — explicit `depend_on(input)` at build time |
| `Watcher` / effect | `fn(*mut u8): void` (+ ctx) subscribed to signal |
| propagation | pull-based: `set` marks `dirty`, recompute on `get` |
| heap graph | explicit `Allocator` (layer 2) or fixed-capacity slots |

Sketch:

```
$fn signals(T) {
  pub struct State_$T { value: $T /*, subs, n */ }
  pub fn (s: State_$T) get(): $T { return s.value }
  pub fn (mut s: State_$T) set(v: $T) { s.value = v /* notify: dirty/effect */ }

  pub struct Computed_$T {
      value: $T
      dirty: bool
      compute: fn(*mut u8): $T
      ctx: *mut u8
  }
  pub fn (mut c: Computed_$T) get(): $T {
      if c.dirty {
          c.value = c.compute(c.ctx)
          c.dirty = false
      }
      return c.value
  }
}
```

## E. Conclusion

- Observer / EventEmitter and explicit signal (Qt-like) → yes, library
  (fn-ptr + explicit `ctx`; zero-alloc or `Allocator`; `$fn` per type).
- Reactive signal (JS/TC39) → only as an **explicit** variant (no auto-tracking);
  rest of ergonomics remains.
- Everything outside core: optional module / external library (049).

## Non-goals

- Auto-tracking dependencies / global “current computation” (hidden cost on
  every `get()`).
- Promise-GC, hidden scheduler, “reactive magic” without explicit dependencies.
- Closures in callbacks (D7) — always `ctx`.
- System/RTOS signals as syntax — that is FFI ([024](024-rtos.md)).
