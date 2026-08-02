# Building, binaries, and Task

## Klin compiler itself as `exe`

```bash
task release
# or: dart compile exe bin/klin.dart -o build/klin
```

On Windows the result is `build/klin.exe`, on macOS/Linux `build/klin`.
At the start `dart run` / `task hello` is enough; `release` when the tool
should go on PATH or be distributed without an installed SDK.

Homebrew (macOS/Linux): [17-homebrew.md](17-homebrew.md) — `Formula/klin.rb`,
tag `v*` → `release` workflow.

## Klin programs → binary

That is the compiler's default path (from step 001):

```
file.kl → out/file.c → gcc/clang/tcc → out/file
```

On Windows the result is `.exe`, on macOS/Linux a normal executable.
Flag `--cc` selects C backend (`tcc` for iteration, `gcc`/`clang` for
release — see `02-architecture.md`, Z6).

---

## Task (go-task) — selected

The repo has `Taskfile.yml`. One command works the same on
**Windows, Linux, and Darwin** (as long as `dart` and a C compiler are on PATH):

```bash
task --list
task check      # analyze + test
task hello      # full hello.kl run
task run -- hello.kl
task release    # build/klin[.exe]
task clean
```

- Binary: `task`, docs: [taskfile.dev](https://taskfile.dev)
- Install: [taskfile.dev/installation](https://taskfile.dev/installation/)
  (`brew install go-task` / `scoop install task` / …)
- Checksum cache: `.task/` (in `.gitignore`)
- `.exe` extension on Windows set by `EXE` variable in Taskfile
  (`{{OS}}` → `windows` | `linux` | `darwin`)

Task **does not install** Dart or gcc — it only unifies commands so you do not
write separate `.sh` / `.ps1` / `.bat` scripts.

---

## Make / just — deliberately not

| Tool | Purpose | Why not now |
|---|---|---|
| **Make** | C / embedded build | returns at bare-metal (010+): linker, `.s` startup |
| **just** | shorter command menu | Task already known; similar features at this stage |

Make out of habit with a dozen phony targets is a mistake Task
avoids. Separate Make/CMake layer for MCU is OK — do not mix with developer
command menu.
