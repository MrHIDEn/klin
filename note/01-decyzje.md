# Decyzje projektowe

Trzy pierwsze podjąć **przed pierwszą linią parsera** — przenikają
tablicę symboli, checker i codegen. Zmiana później to przepisywanie.

---

## D1. Model czasu życia pamięci — ROZSTRZYGNIĘTE

**Wybór: ręczny + `defer` + alokator jako jawny argument (model Zig/Odin).**

Odrzucone:
- **GC** — wyklucza bare-metal, łamie zasadę nadrzędną.
- **Borrow checker** — problem badawczy. Zespół Rusta poświęcił lata
  (NLL, Polonius) i nadal dokłada. Solo = projekt, który nie osiągnie 1.0.
- **Autofree** — patrz `00-idea.md`.

```
pub fn parse(a: *Allocator, src: []u8): !Doc {
    let buf = a.alloc(u8, src.len)   // szkic — MVP: alloc_bytes / alloc_i32
    defer a.free(buf)
    ...
}
```

MVP host: [`stdlib/mem`](../stdlib/mem.kl) (`heap`, `alloc_bytes`, `alloc_i32`) —
[note/14-allocator.md](14-allocator.md), issue [057](../issues/057-allocator.md).

**Nie obiecywać** `a.alloc(u8, n)` dopóki nie ma argumentu typu w wywołaniu
(generyki [034](../issues/034-typy-generyczne.md) / cukier D3). Dziś: `alloc_bytes`
+ jawne `alloc_i32` / `alloc_u8`. `slice_alloc.map_alloc_*` —
[017](../issues/017-collection-methods.md) / [note/16-slice.md](16-slice.md).
Arena, vtable — później (patrz note/14 § „Nie obiecywać / później”).

Tryby do rozważenia później (wzorzec z V, ale bez autofree):
ręczny (domyślny) / arena / opcjonalnie oznaczanie pojedynczych funkcji.

---

## D2. Model błędów — ROZSTRZYGNIĘTE

**Wybór: typ sumaryczny `!T` + operator propagacji + blok `or { }`.**

```
let f = os.open(path)!          // propaguj wyżej
let cfg = load(path) or {       // obsłuż lokalnie
    log.warn("brak: ${err}")
    Config.defaults()
}
```

Odrzucone:
- **Wyjątki** — ukryty przepływ sterowania, łamie zasadę nadrzędną.
- **Para `(T, error)` jak w Go** — zaśmieca kod przez `if err != nil`.

Uzasadnienie: Zig i Rust zbiegły się na tym niezależnie.

W emisji: `!T` to struct z tagiem. Operator propagacji to `if (r.is_err)
return r;`. Zero narzutu poza sprawdzeniem flagi.

---

## D3. Generyki — ROZSTRZYGNIĘTE

**Wybór: preprocesor/makra czasu kompilacji, NIE w gramatyce języka.**

Model Nelui: potężny preprocesor mający dostęp do AST generuje
wyspecjalizowany kod. Klasy, generyki i polimorfizm implementowane
ad hoc, bez wpisywania ich do rdzenia.

```
$fn point(name: str, T: type) {
    pub struct $name { x: $T, y: $T }
    pub fn (p: $name) sqlen(): $T { return p.x*p.x + p.y*p.y }
}
$point("Vec2f", f64)
$point("Vec2i", i32)
```

Uzasadnienie: tańsze w implementacji niż pełny system typów
z parametrami; pozwala odroczyć decyzję zamiast podejmować ją
przed pierwszą linią parsera; monomorfizacja i tak jest jedyną sensowną
strategią przy backendzie C.

Ryzyko: czas kompilacji, komunikaty błędów z rozwiniętych makr.

**MVP (026):** [04-makra.md](04-makra.md) — przed/po expand + przykład
[`examples/point.kl`](../examples/point.kl) /
[`point_macro.kl`](../examples/point_macro.kl).

**Po 017 / 057:** `$fn` w stdlib wystarcza (`slice` / `slice_alloc`,
`mem.alloc_i32` / `alloc_u8`). Generyki w gramatyce — **nie teraz**;
ew. cienki cukier → ten sam expand (wariant 2) dopiero przy twardym bólu.
Szczegóły: [034](../issues/034-typy-generyczne.md). Nadal nie obiecywać
`a.alloc(T, n)`.

---

## D4. Mangling nazw

Schemat: `modul_Typ_metoda`, np. `geom_Vec2_translate`.

**Musi być wyłączalny.** Na bare-metal nazwy symboli muszą się zgadzać
co do znaku z tablicą wektorów (`TIM2_IRQHandler`, `SysTick_Handler`).

```
@[codename("TIM2_IRQHandler")]
pub fn on_timer() { counter += 1 }
```

Mangling musi być odporny na kolizje ze wszystkim z `<stdio.h>`
i na słowa kluczowe C.

---

## D5. Receiver metody

`fn (v: Vec2) len()` — kopia. `fn (mut v: Vec2) translate()` — wskaźnik.

**Mutacja widoczna w sygnaturze.** To ulepszenie względem Nelui, gdzie
`function Vec2:translate` daje `self: *Vec2` niejawnie i z wywołania
nie wiadomo, czy obiekt zostanie zmieniony.

`mut` znika w emisji — zostaje `*`. Cała niezmienność to zjawisko czasu
kompilacji, zero kosztu w runtime. **To dobry test dla każdej cechy:
jeśli nie znika w emisji, prawdopodobnie łamie zasadę nadrzędną.**

---

## D6. Inicjalizacja — ZII

Zmienne zadeklarowane bez wartości są zerowane (za Neluą).
Brak konstruktorów i destruktorów (brak RAII).
Ewentualnie adnotacja wyłączająca zerowanie dla mikrooptymalizacji.

---

## D7. Do rozstrzygnięcia później

- Domknięcia — czy w ogóle? Nelua ich nie ma poza top-level. Struct
  z environment + wskaźnik na funkcję to średnia trudność, ale alokacja
  środowiska łamie zasadę nadrzędną.
- Interfejsy — fat pointer `{ void* data; Vtable* vt; }`. Jeśli tak, to
  dispatch dynamiczny **jawny** w składni (`dyn Writer`), domyślny statyczny.
- Slice: `struct { T* ptr; size_t len, cap; }` — wymusza generyki, więc
  zależy od D3.
- Operatory na typach użytkownika — czy w ogóle. Ryzyko ukrytego kosztu.
