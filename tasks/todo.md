# Sprint Backlog

## Sprint: a11y announce harness + comment audience dialog — 2026-06-08 (iter-127)

Focused 2-ticket batch — both complete recently-shipped work. Clean Tier A is scarce
(iter-103→105 drain confirmed: of 22 "Tier A" candidates most carry ops/release tails:
BUT-1169 needs a prod CF backfill, BUT-828's acceptance is an iOS CI build, BUT-877
changes a security contract needing a coordinated client release).

### Agent A: testing-specialist — a11y announce coverage
- [x] **A1. Announce-channel test harness + per-site tests** `[Tier A]` — harness at `test/infrastructure/helpers/announce_channel.dart` (real `flutter/accessibility` interception, live-l10n assertions); `test/widget/a11y/` (8 tests: 4 harness + 4 photo_import OCR announce-once/re-arm guard). 3 seam-blocked sites → follow-up BUT-1212. (BUT-1210) → **Done**

### Agent B: flutter-developer — comment audience dialog
- [x] **B1. Tappable "Synlig för:" label → full audience dialog** `[Tier B]` — `recipe_detail_comments.dart`: line is `Semantics(button)`+InkWell → AlertDialog listing the COMPLETE audience + unresolved count (privacy: never under-states). Testability extraction `resolveCommentAudienceNames` in `comment_visibility.dart` → 6 new unit tests (17/17 green). l10n `recipeCommentAudienceTitle`/`recipeCommentAudienceOthers` sv/en. Preview: `docs/design/previews/comment-audience-dialog-preview.html`. (BUT-1211) → **In Review**

### Follow-ups filed
- BUT-1212 — announce-channel tests for the 3 seam-blocked sites (BUT-1210 follow-up)

### Post-Sprint Steps
- [ ] Run `dart analyze --fatal-infos`
- [ ] Run relevant unit tests
- [ ] Commit, push
- [ ] BUT-1210 → Done; BUT-1211 → In Review + notify

### Awaiting Malin — In Review (carried)
BUT-904 (epic), BUT-1198, BUT-1199, BUT-1037, BUT-1039, BUT-918, BUT-912, BUT-946, BUT-1079, BUT-914.

---
## ARCHIVED — iter-126 (BUT-914 comment-visibility label — In Review) · iter-125 (triage) · iter-124 (BUT-1209) · iter-123 (BUT-1204) · iter-122 (BUT-1207)
