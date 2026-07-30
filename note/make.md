# Budowanie, binarki i Task

## Sam kompilator Klin jako `exe`

```bash
task release
# albo: dart compile exe bin/klin.dart -o build/klin
```

Na Windowsie wynik to `build/klin.exe`, na macOS/Linuxie `build/klin`.
Na start wystarczy `dart run` / `task hello`; `release` gdy narzędzie
ma trafić do PATH albo być rozdawane bez zainstalowanego SDK.

## Programy w Klinie → binarka

To jest domyślna ścieżka kompilatora (od kroku 001):

```
plik.kl → out/plik.c → gcc/clang/tcc → out/plik
```

Na Windowsie wynik to `.exe`, na macOS/Linuxie zwykły plik wykonywalny.
Flaga `--cc` wybiera backend C (`tcc` do iteracji, `gcc`/`clang` do
release'u — patrz `02-architektura.md`, Z6).

---

## Task (go-task) — wybrane

W repo jest `Taskfile.yml`. Jedna komenda działa tak samo na
**Windows, Linux i Darwin** (o ile w PATH są `dart` i kompilator C):

```bash
task --list
task check      # analyze + test
task hello      # pełny przelot hello.kl
task run -- hello.kl
task release    # build/klin[.exe]
task clean
```

- Binarka: `task`, dokumentacja: [taskfile.dev](https://taskfile.dev)
- Instalacja: [taskfile.dev/installation](https://taskfile.dev/installation/)
  (`brew install go-task` / `scoop install task` / …)
- Cache checksumów: `.task/` (w `.gitignore`)
- Rozszerzenie `.exe` na Windowsie ustawiane przez zmienną `EXE` w Taskfile
  (`{{OS}}` → `windows` | `linux` | `darwin`)

Task **nie instaluje** Darta ani gcc — tylko ujednolica komendy, żeby nie
pisać osobnych skryptów `.sh` / `.ps1` / `.bat`.

---

## Make / just — świadomie nie

| Narzędzie | Po co | Dlaczego nie teraz |
|---|---|---|
| **Make** | build C / embedded | wraca przy bare-metal (010+): linker, startup `.s` |
| **just** | krótsze menu komend | Task już znany; funkcje podobne na tym etapie |

Make z przyzwyczajenia do tuzina phony targetów to błąd, którego Task
unika. Osobna warstwa Make/CMake przy MCU to OK — nie mieszać z menu
komend dewelopera.
