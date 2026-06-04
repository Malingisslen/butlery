# Sprint Backlog

## Sprint: a11y announcements (shopping + OCR) — 2026-06-04 (iter-121)

Single-ticket Tier-A: BUT-1201 (BUT-905 follow-up). Closes to Done — extends the
just-shipped `SemanticsService.announce` pattern (BUT-905, iter-112/this session) to
the two deferred sites. No new visual.

**Selection note:** this iteration started with a premature "backlog drained" pace-down
after a 6-ticket spot-check — Malin caught it. A full-backlog classification scan found
~11 actionable A-CLEAN tickets (incl. my own session-filed follow-ups). Lesson logged
(tasks/lessons.md + memory). Resumed on BUT-1201 (genuinely actionable).

### Agent A: direct — BUT-1201 a11y announcements `[Tier A]`

- [x] **A1. Announce shopping-item bought/un-bought** `[Tier A]` — `collaborative_shopping_view.dart _toggleItem`: after a successful `toggleItemCompletion`, `SemanticsService.announce` bought vs un-bought from `completedItemsList.any(id)`. (BUT-1201)
- [x] **A2. Announce OCR-extraction complete** `[Tier A]` — `photo_import_view.dart`: VM listener fires `a11yOcrComplete` once on the `hasOcrResult && !isProcessing` transition; resets for the next extraction; `removeListener` in dispose. (BUT-1201)
- [x] **A3. l10n keys** `[Tier A]` — `a11yItemBought` / `a11yItemUnbought` / `a11yOcrComplete` (sv+en), gen-l10n. (BUT-1201)

**Verification:** analyze clean; `?? ''` grep clean; `architecture_test.dart` +18 green.
No new unit test — matches the BUT-905 precedent (announcement wiring is manual-screen-
reader-pass territory per `ui-conventions.md`, not heavy widget-pump tests).

### Awaiting Malin — In Review (carried)
BUT-904 (epic), BUT-1198, BUT-1199, BUT-1037, BUT-1039, BUT-918, BUT-912, BUT-946, BUT-1079.

### Post-Sprint Steps
- [x] analyze + arch test green
- [ ] Commit, push; BUT-1201 → Done

---
## ARCHIVED — iter-120 (BUT-1208 text-import banner — Done) · iter-119 (BUT-1200 — Done) · iter-118 (BUT-1203 — Done) · iter-117 (CI tooling — Done) · iter-116 (BUT-904 — In Review)
