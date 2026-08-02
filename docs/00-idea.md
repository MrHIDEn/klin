# Klin — overall idea

## What it is

Klin is a systems language compiled **to C**, not to machine code.
The Klin compiler generates one readable `.c` file, which is then
handled by an ordinary C compiler (gcc, clang, tcc, arm-none-eabi-gcc).

The name is not accidental: a wedge (klin) is the oldest simple machine — zero
moving parts, zero overhead. The language is a thin layer **wedged**
between the programmer and C. It does not replace C, does not hide it, does not pretend it is not there.

## Overarching principle

> **No hidden allocation, no hidden control flow,
> no hidden cost. If something allocates or branches, it must be
> visible in the syntax.**

That sentence settles every design dispute. Practical test for every
proposed feature:

> Compile the same thing twice — once in Klin, once by hand in C — and compare
> `objdump -d`. If the instructions are identical, the feature passes.
> If not, drop it or fix it.

C++ broke this rule three times: copy constructors, exceptions,
operator overloading. Each makes an innocent line do something expensive.
Klin must not repeat that.

## Target goal

Programming microcontrollers (STM32, Cortex-M) in a language that gives:

- structures with methods instead of `module_function()` prefixes
- modules and real encapsulation instead of `static` and opaque pointers
- no `null`, errors as values
- immutability by default
- typed access to hardware registers, generated automatically from SVD

...while keeping full control over memory and zero runtime overhead.

## Why a C backend, not LLVM

1. **Reach.** Works on every MCU for which a C compiler exists —
   including archaic PICs and 8051s, for which LLVM will never
   get a backend. That is a real niche Zig and Rust do not cover.
2. **No vendor lock-in.** If the project dies, the user takes
   the generated C and keeps working.
3. **Interop for free.** C headers, C libraries, C tools (gdb,
   objdump, valgrind) work without a middle layer.
4. **Implementation simplicity.** The C backend is the easiest part of the project.
   All the difficulty sits in the frontend — which I would need anyway,
   even targeting LLVM.

## What Klin is NOT (non-goals)

- **Not a superset of C.** It does not parse legal C code. Parsing
  full C (preprocessor, `typedef` vs identifier, "lexer hack") is
  an order of magnitude harder than a clean grammar of your own.
  Interop is done through FFI declarations, not by parsing headers.
- **No GC.** Neither by default nor optionally at the start.
- **No borrow checker.** That is a research problem, not a matter of enthusiasm.
- **No runtime.** No goroutines, no scheduler.
- **No exceptions.**

## Inspirations and what to take from them

| Source | What to take |
|---|---|
| **V** | `mut` (immutability by default), `pub`, no globals, no `null`, `!T` + `or {}` |
| **Nelua** | preprocessor instead of generics in the core, `cimport`/`cexport`/`codename` annotations, ZII |
| **Go** | `defer`, structures with methods without inheritance, composition instead of hierarchy |
| **Zig / Odin** | allocator as an explicit argument, not global magic |

### What to deliberately NOT take

**Autofree from V.** V's flagship promise — the compiler inserts
`free()` at compile time, without GC and without a borrow checker. After years
it is still WIP, the docs discourage using it, and it can be **slower than GC**
(string cloning O(n) to avoid dangling pointers).
That is empirical proof that automatic memory management without GC
and without a type system tracking lifetimes is a research problem.

**Conclusion:** declare the memory model you can actually implement,
not the one that sounds best in the README.

## Neighbors — worth knowing before you start

- **Nelua** — closest reference point. Complete, working
  compiler to C written in Lua. Worth reading its codegen.
- **nesC** — C extension for TinyOS, components and modules. Direct
  predecessor of the idea, though a different era.
- **V** — compiles to C, self-hosted, deliberately small source.
- **TinyGo** `tools/gen-device-svd` — SVD generator pattern.
- **Zig / Odin** — do the same thing better, but through LLVM.
