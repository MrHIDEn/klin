---
name: rcfix
description: >
  Shorthand "rcfix" = Bugbot code review + real fixes for the current branch,
  then update the PR. Use when the user writes "rcfix", "review + fix",
  "CR + fixes", or as the last step of the feature workflow after push + PR.
---

# rcfix — review code + fix

When `rcfix` (or "review + fix" / "CR + fixes") appears, run a Bugbot code
review on the current branch changes, apply real fixes, and update the PR.

This is the last step of the feature workflow in `CLAUDE.md`:
`… → push + PR → rcfix (Bugbot, fixes, scoreboard)`.

## Steps

1. Ensure changes are committed and pushed and a PR exists
   (start with `git status -sb`; if needed — commit/push/`ManagePullRequest`).
2. Run Bugbot (Task, `subagent_type: bugbot`, `description: "Bugbot"`,
   `run_in_background: false`) with prompt:
   ```
   Full Repository Path: /workspace
   Diff: branch changes
   Custom Instructions: <optional: what to focus on>
   ```
3. Triage each finding:
   - real bug → fix it,
   - false positive → note briefly why (do not "fix" forced).
4. For fixes: edit → `dart analyze` + `dart test` (green) → separate commit
   per logical fix (`fix(review): …`) → push → update the PR
   (`ManagePullRequest`).
5. If fixes were material, run Bugbot again — until clean or only consciously
   accepted false positives remain.
6. **Scoreboard**: in the summary report counts: found / fixed / dismissed
   (with reason), plus the PR link.

## Rules

- Do **not** merge the PR and do **not** mark it "ready" unless the user asks
  explicitly.
- Fix only real issues in scope of this change — no scope creep or drive-by
  refactors.
- Keep fixes minimal; each logical change = its own commit; after fixes
  **always** re-run tests.
- Do not commit on `main`/`develop` — fixes go on the feature/fix branch.
- If Bugbot is unavailable, say so plainly (do not fake a review).

## When to use

- Right after `push + PR` for code changes (optional for pure docs PRs, though
  harmless).
- When the user asks explicitly ("rcfix" / "CR + fixes" / "review + fix").

## Output

Brief: scoreboard (found/fixed/dismissed), test status after fixes, PR link.
