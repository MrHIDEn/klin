# 069 — Observer / EventEmitter / Signals (biblioteka)

**Status:** 💭 do rozważenia
**Zależy od:** fn-ptr ([note/13](../note/13-fn-ptr.md)), `Allocator` ([057](057-allocator.md) / [note/14](../note/14-allocator.md)), wzorce z [017](017-collection-methods.md); miejsce jak [024](024-rtos.md)/[029](029-async-event-loop.md)

## Pytanie

Czy da się w Klinie dorobić komunikację w stylu obserwatora — `EventEmitter`,
a nawet „signal" (w tym reaktywne signale z propozycji JS/TC39) — **bez** ukrytej
alokacji / ukrytego runtime (zasada nadrzędna).

## A. Ograniczenia z rdzenia (kształtują całe API)

- **Brak capture** (D7, [note/13](../note/13-fn-ptr.md)): callback to `fn(...)`
  top-level, nie domyka stanu. Kontekst przenosimy **jawnym wskaźnikiem**:
  listener = para `{ cb: fn(*mut u8, Ev): void, ctx: *mut u8 }`.
- **Brak ukrytej alokacji/kontroli/kosztu**: `emit`/`notify` to jawna pętla po
  slotach; żadnego auto-schedulera.
- **Pamięć jawnie**: zero-alloc (tablica slotów o stałej pojemności, `on()` →
  `!i32` przy przepełnieniu) **lub** dynamicznie przez `Allocator` (warstwa 2,
  jak `slice_alloc`; `defer` u callera).
- **Brak generyków w gramatyce**: monomorfizacja `$fn` per typ zdarzenia
  (`Emitter_i32`, `State_f64`, …).
- **Miejsce**: biblioteka (opcjonalny moduł stdlib lub zewnętrzna przez
  [049](049-remote-imports.md)), nie rdzeń — jak ustalono dla RTOS/loop
  ([024](024-rtos.md), [029](029-async-event-loop.md)).

## B. Observer / EventEmitter — tak, biblioteka

`EventEmitter` to po prostu wzorzec obserwatora (subject + wielu listenerów) —
wykonalny wprost:

```
struct Listener_i32 {
    cb: fn(*mut u8, i32): void
    ctx: *mut u8
}

$fn emitter(T) {
  pub struct Emitter_$T { /* sloty: [N]Listener_$T + n: i32 */ }
  pub fn (mut e: Emitter_$T) on(cb: fn(*mut u8, $T): void, ctx: *mut u8): !i32 { /* dodaj slot */ }
  pub fn (e: Emitter_$T) emit(ev: $T) { /* for i: sloty[i].cb(sloty[i].ctx, ev) */ }
}
```

Zero ukrytego kosztu; `off`/`once` opcjonalnie (jawne).

## C. Warianty „signal"

1. **Explicit signal / Qt-like** (wartość + jawne `subscribe`/`notify`): to ten
   sam obserwator (wartość + lista slotów; `set(x)` woła sloty). Tak, biblioteka.
2. **Reaktywny signal (propozycja JS/TC39: `State`/`Computed`/`Watcher`)**: 1:1
   się NIE przenosi — sedno propozycji to **automatyczne śledzenie zależności**
   (sam `get()` w `Computed` rejestruje zależność), leniwa memoizacja i
   glitch-free propagacja. To ukryta kontrola + koszt na każdym odczycie +
   dynamiczny graf (heap). Da się tylko jako **wariant jawny** (niżej).
3. **Signal systemowy** (POSIX / RTOS event flags): to FFI do C — inny temat
   ([024](024-rtos.md)/[031](031-biblioteki-hal.md)).

## D. „JS Signals" po klinowemu — explicit signals (propozycja)

Zostawiamy ergonomię (State/Computed/Effect, leniwość, memoizację), ale
**zależności wiążemy jawnie** (bez auto-trackingu):

| JS Signals (TC39) | Klin (jawnie) |
|---|---|
| `Signal.State(v)` | `State_$T { value, subs }` + `get`/`set`; `set` → `notify` |
| `Signal.Computed(fn)` | `Computed_$T { value, dirty, compute: fn(*mut u8): $T, ctx }`; deps wpisane ręcznie (subskrypcja na wejściach → `dirty = true`); `get` przelicza gdy `dirty` (memoizacja) |
| auto-tracking | brak — jawne `depend_on(input)` przy budowie |
| `Watcher` / effect | `fn(*mut u8): void` (+ ctx) zasubskrybowany do sygnału |
| propagacja | pull-based: `set` oznacza `dirty`, przelicza się na `get` |
| graf na stercie | jawny `Allocator` (warstwa 2) albo sloty o stałej pojemności |

Szkic:

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

## E. Wniosek

- Observer / EventEmitter oraz explicit signal (Qt-like) → tak, biblioteka
  (fn-ptr + jawny `ctx`; zero-alloc lub `Allocator`; `$fn` per typ).
- Reaktywny signal (JS/TC39) → tylko jako wariant **jawny** (bez auto-trackingu);
  reszta ergonomii zostaje.
- Wszystko poza rdzeniem: opcjonalny moduł / biblioteka zewnętrzna (049).

## Non-goals

- Auto-tracking zależności / globalny „current computation" (ukryty koszt na
  każdym `get()`).
- Promise-GC, ukryty scheduler, „reactive magic" bez jawnych zależności.
- Domknięcia w callbackach (D7) — zawsze `ctx`.
- Signale systemowe/RTOS jako składnia — to FFI ([024](024-rtos.md)).
