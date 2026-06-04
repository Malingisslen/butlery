# Sprint Backlog

## Sprint: group-dialog draft widget test — 2026-06-04 (iter-122)

Single-ticket Tier-A: BUT-1207 (my own filed follow-up from BUT-1203). Closes the
codec-unreachable widget glue gap. Test-only, closes to Done.

- [x] **A1. Widget test: restore + friend-resolution + drop-unresolved + save** `[Tier A]` — `test/widget/social/groups/create_group_dialog_draft_test.dart`: 3 tests green. Drop test strengthened per code-reviewer (re-save → assert friendIds filtered, not just resolve-positive). (BUT-1207)

**Note:** clear-on-commit (4th sub-bullet) not widget-driven — disproportionate showDialog/
Navigator.pop scaffolding for a one-line wiring whose clear primitive is unit-proven (codec +
AutoSaveManager.clear) and whose pattern is identical to 3 shipped surfaces. The codec-
unreachable glue (load→setState + friend resolution) IS now covered — that was the gap's purpose.

### Awaiting Malin — In Review (carried)
BUT-904 (epic), BUT-1198, BUT-1199, BUT-1037, BUT-1039, BUT-918, BUT-912, BUT-946, BUT-1079.

---
## ARCHIVED — iter-121 (BUT-1201 a11y announcements — Done; premature pace-down caught by Malin, lesson logged) · iter-120 (BUT-1208 — Done) · iter-119 (BUT-1200 — Done) · iter-118 (BUT-1203 — Done) · iter-117 (CI tooling — Done) · iter-116 (BUT-904 — In Review)
