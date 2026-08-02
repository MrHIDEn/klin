# rcfix — review code + fix

Gdy pojawi się `rcfix` (lub "review + fix" / "CR + fixy"), wykonaj przegląd kodu
Bugbotem dla zmian bieżącego brancha, nanieś realne poprawki i zaktualizuj PR.

To ostatni krok feature workflow z `CLAUDE.md`:
`… → push + PR → rcfix (Bugbot, fixes, scoreboard)`.

## Kroki

1. Upewnij się, że zmiany są scommitowane i wypchnięte oraz istnieje PR
   (najpierw `git status -sb`; jeśli trzeba — commit/push/`ManagePullRequest`).
2. Uruchom Bugbota (Task, `subagent_type: bugbot`, `description: "Bugbot"`,
   `run_in_background: false`) z promptem:
   ```
   Full Repository Path: /workspace
   Diff: branch changes
   Custom Instructions: <opcjonalnie: na czym się skupić>
   ```
3. Triage każdego znaleziska:
   - realny bug → napraw,
   - false positive → odnotuj krótko dlaczego (nie „naprawiaj" na siłę).
4. Dla poprawek: edytuj → `dart analyze` + `dart test` (zielone) → osobny commit
   per logiczna poprawka (`fix(review): …`) → push → zaktualizuj PR
   (`ManagePullRequest`).
5. Jeśli poprawki były istotne, uruchom Bugbota ponownie — aż będzie czysto albo
   zostaną tylko świadomie zaakceptowane false-positive'y.
6. **Scoreboard**: w podsumowaniu podaj licznik: znalezione / naprawione /
   odrzucone (z powodem), oraz link do PR.

## Zasady

- **Nie** scalaj PR i **nie** oznaczaj „ready", chyba że użytkownik wprost prosi.
- Naprawiaj tylko realne problemy z zakresu tej zmiany — bez rozszerzania zakresu
  ani refaktorów przy okazji.
- Poprawki minimalne, każda logiczna zmiana = osobny commit; po fixach **zawsze**
  ponów testy.
- Nie commituj na `main`/`develop` — poprawki idą na branchu feature/fix.
- Jeśli Bugbot jest niedostępny, powiedz to wprost (nie udawaj przeglądu).

## Kiedy używać

- Zaraz po `push + PR` dla zmian z kodem (nie trzeba dla PR czysto
  dokumentacyjnych, choć nie zaszkodzi).
- Gdy użytkownik prosi wprost ("rcfix" / "CR + fixy" / "review + fix").

## Output

Krótko: scoreboard (znalezione/naprawione/odrzucone), stan testów po fixach,
link do PR.
