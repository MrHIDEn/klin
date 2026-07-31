# 037 — Formatowanie daty/czasu (`strftime`-like)

**Status:** 💭 do rozważenia
**Zależy od:** 016 (interpolacja / model print), ew. 012 / 020

## Cel

Świadome formatowanie czasu **bez ukrytej alokacji** i bez mini-DSL
w slotach interpolacji (`:format-dat` **nie** w 016).

## Propozycja

Moduł stdlib np. `time` / `datetime`:

```klin
var buf: [64]u8
time.format(buf[:], "%Y-%m-%d", instant)
io.println(… )  // po sformatowaniu do bufora użytkownika
```

- Caller owns storage (bufor na stosie / statyczny).
- Host: `strftime` / `localtime_r` (albo cienka otoczka).
- Bare-metal: opcjonalne / wymaga RTC — osobna decyzja w implementacji.

## Poza zakresem (MVP issue)

- Locale-heavy formaty, pełne IANA timezones
- Parsowanie ISO jako obowiązek pierwszego kroku
- Cukier `${t:…}` w interpolacji — dopiero gdy bufor jest w scope (osobna decyzja)

## Powiązanie z 016

Interpolacja zostaje print-only + printf/maski. Daty → ten issue, nie slot `:n3`-style.
