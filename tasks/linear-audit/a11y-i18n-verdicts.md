# Linear Audit: A11y / i18n / Platform-UX Tickets

Date: 2026-05-28
Repo state evidence:
- `lib/l10n/app_en.arb` ~6503 keys / 9806 lines
- `lib/l10n/app_sv.arb` ~6515 keys / 9826 lines (12-key gap — drift, not divergence)
- `Semantics(` usages: 265 across 128 files (up from "~56 in 27 files" cited in old reports)
- `semanticsLabel:` / `semanticLabel:` usages: 28 across 14 files

Note: Many tickets returned 404 (already deleted/archived hard). Several others show "Done" / "Canceled" / "Duplicate" / "archivedAt" set. Verdicts below treat those as already-closed (no action), only the still-open Backlog ones need triage.

---

## A11y tickets

## BUT-514 [DELETE] — (not found)
**Evidence:** API returns Entity not found — already hard-deleted.
**Reason:** Ticket no longer exists in Linear.
**Action:** none (already gone)

## BUT-521 [DELETE] — (not found)
**Evidence:** API 404.
**Reason:** Already removed.
**Action:** none

## BUT-527 [DELETE] — (not found)
**Evidence:** API 404.
**Reason:** Already removed.
**Action:** none

## BUT-533 [DELETE] — (not found)
**Evidence:** API 404.
**Reason:** Already removed.
**Action:** none

## BUT-539 [DELETE] — (not found)
**Evidence:** API 404. Referenced from BUT-697 as the "form fields" sibling.
**Reason:** Already removed.
**Action:** none

## BUT-547 [KEEP-AS-DONE] — A11y: text-scaling 200% clipping audit
**Evidence:** Status Done, archived 2026-05-04. Completed in iter cycle.
**Reason:** Closed; no action.
**Action:** none

## BUT-551 [KEEP-AS-DONE] — A11y: verify recipe_image_widget semanticsLabel
**Evidence:** Status Done, archived 2026-05-04. Code now has `semanticsLabel:` in `recipe_image_widget.dart` (2 occurrences).
**Reason:** Verified shipped.
**Action:** none

## BUT-557 [KEEP-AS-DONE] — A11y: landmark regions on app bars/nav
**Evidence:** Status Done, archived 2026-05-04.
**Reason:** Closed.
**Action:** none

## BUT-697 [KEEP-AS-DONE] — A11y broad Semantics sweep (Urgent epic)
**Evidence:** Status Done 2026-04-29. Sweep increased Semantics() count from ~56 to 265 across 128 files. This was the de-facto rollup epic.
**Reason:** The big sweep is done. Future a11y work should follow the same pattern as targeted follow-ups.
**Action:** none

## BUT-699 [DELETE] — (not found)
**Evidence:** API 404.
**Reason:** Already removed.
**Action:** none

## BUT-701 [KEEP, IMPROVE TITLE] — A11y: focus traversal
**Evidence:** Status Backlog, P3 Medium. Grep confirms zero `FocusTraversalGroup` / `FocusOrder` / `FocusTraversalPolicy` in lib/ (validated via Grep — none found).
**Reason:** Real, still pending. Solo-dev + beta + Swedish-first → keyboard/switch users on phones are nearly zero. Defer but keep.
**Action:** keep at P4 Low (downgrade from P3); re-title to "A11y: focus traversal — keyboard/switch nav (web/desktop)"

## BUT-702 [KEEP-AS-DONE] — Undo SnackBar for destructive actions
**Evidence:** Status Done 2026-05-06; recipe-delete undo shipped, ticket rescoped + closed.
**Reason:** Closed.
**Action:** none

## BUT-895 [KEEP-AS-DONE] — Semantic labels on loading indicators
**Evidence:** Status Done 2026-05-24.
**Reason:** Closed.
**Action:** none

## BUT-896 [KEEP-AS-DONE] — labelText vs hintText on form fields
**Evidence:** Status Done 2026-05-24.
**Reason:** Closed.
**Action:** none

## BUT-898 [KEEP-AS-DONE] — Cooking-mode title respects textScaleFactor
**Evidence:** Status Done 2026-05-24.
**Reason:** Closed.
**Action:** none

## BUT-900 [KEEP, DOWNGRADE] — Modal/dialog focus-return audit
**Evidence:** Status Backlog, P3 Medium. Genuinely needs manual screen-reader test (TalkBack/VoiceOver). Solo dev, no testers, beta → very low value right now.
**Reason:** Real gap but unactionable solo; needs a real screen-reader user, not code grep.
**Action:** keep at P4 Low; re-title "A11y: dialog focus-return — defer until external a11y review"

## BUT-902 [KEEP-AS-DONE] — Online-status non-color signal
**Evidence:** Status Done 2026-05-24.
**Reason:** Closed.
**Action:** none

## BUT-905 [KEEP, ROLLUP CANDIDATE] — SemanticsService.announce on state changes
**Evidence:** Status Backlog, P3 Medium. Concrete and small (4 sites listed). Cooking-mode already does this; pattern proven.
**Reason:** Real, small, productive. Keep.
**Action:** keep as-is, or roll into new "A11y polish sweep iter-2" epic together with BUT-701 + BUT-900

## BUT-908 [KEEP-AS-DONE] — Semantic labels on avatar components
**Evidence:** Status Done 2026-05-24.
**Reason:** Closed.
**Action:** none

---

## i18n / l10n tickets

## BUT-565 [KEEP-AS-DONE] — RTL: EdgeInsetsDirectional sweep
**Evidence:** Status Done 2026-05-02.
**Reason:** Closed.
**Action:** none

## BUT-585 [KEEP-AS-DONE] — app_strings.dart audit
**Evidence:** Status Done 2026-04-27.
**Reason:** Closed.
**Action:** none

## BUT-609 [KEEP-AS-DONE] — 3 hardcoded Swedish literals
**Evidence:** Status Done 2026-05-01.
**Reason:** Closed.
**Action:** none

## BUT-615 [KEEP-AS-DONE] — hintText/labelText audit
**Evidence:** Status Done 2026-04-30.
**Reason:** Closed.
**Action:** none

## BUT-703 [KEEP-AS-DONE] — sv/en key-gap reconciliation
**Evidence:** Status Done 2026-04-30. Current gap is 12 keys, not the original 488 — drift handled. New small gap should regress through normal commits.
**Reason:** Closed. (Note: current 12-key drift is minor; not worth a fresh ticket.)
**Action:** none

## BUT-704 [KEEP-AS-DONE] — @key descriptions backfill
**Evidence:** Status Done 2026-05-24.
**Reason:** Closed.
**Action:** none

## BUT-705 [KEEP-AS-DONE] — iOS Info.plist localization
**Evidence:** Status Done 2026-04-30.
**Reason:** Closed.
**Action:** none

## BUT-712 [KEEP-AS-DONE] — ICU pluralization audit
**Evidence:** Status Done 2026-04-30.
**Reason:** Closed.
**Action:** none

## BUT-713 [KEEP-AS-DONE] — Native English spot-check
**Evidence:** Status Done 2026-05-02.
**Reason:** Closed.
**Action:** none

## BUT-967 [KEEP-AS-DONE] — Localise route names
**Evidence:** Status Done 2026-05-24.
**Reason:** Closed.
**Action:** none

## BUT-984 [KEEP-AS-DONE] — Pass user locale to LLM
**Evidence:** Status Done 2026-05-24.
**Reason:** Closed.
**Action:** none

## BUT-988 [KEEP-AS-DONE] — Locale-aware currency formatting
**Evidence:** Status Done 2026-05-24.
**Reason:** Closed.
**Action:** none

---

## Platform-specific UX tickets

## BUT-635 [DELETE] — (not found)
**Evidence:** API 404.
**Reason:** Already removed.
**Action:** none

## BUT-706 [KEEP, DOWNGRADE] — iOS CupertinoNavigationBar adoption
**Evidence:** Status Backlog, P3 Medium. 3 days effort. Swedish beta dominantly Android; submission deferred.
**Reason:** Native-feel polish. Defer until iOS store submission active.
**Action:** keep at P4 Low; tag "post-beta / iOS-store-prep"

## BUT-707 [KEEP-AS-DONE] — Windows Runner.rc metadata
**Evidence:** Status Done 2026-04-30.
**Reason:** Closed.
**Action:** none

## BUT-708 [KEEP-AS-DUPLICATE] — in_app_review package
**Evidence:** Status Duplicate, canceled 2026-04-29.
**Reason:** Closed (dup).
**Action:** none

## BUT-709 [KEEP-AS-DONE] — App label capitalization
**Evidence:** Status Done 2026-04-30.
**Reason:** Closed.
**Action:** none

## BUT-710 [KEEP, DOWNGRADE] — Web MouseRegion/onHover
**Evidence:** Status Backlog, P3 Medium. 2 days. App is mobile-first; web is secondary surface.
**Reason:** Real polish for web users; low value pre-monetization.
**Action:** keep at P4 Low; re-title "Web/desktop: hover affordances on custom widgets"

## BUT-711 [KEEP, DOWNGRADE] — Foldable displayFeatures
**Evidence:** Status Backlog, P4 Low. <0.5% addressable market.
**Reason:** Vanishingly small audience. Keep but never prioritize.
**Action:** keep at P4 Low; re-title "Foldable: hinge avoidance (deferred — niche)"

## BUT-714 [KEEP, IMPROVE TITLE] — iOS associated-domains entitlement
**Evidence:** Status Backlog, P2 High. 2 hours.
**Reason:** Blocks Universal Links → app deep linking on iOS. Real bug, small fix. Keep P2 but flag as "iOS-store-prep" since submission is deferred.
**Action:** keep at P3 Medium (downgrade — store submission deferred); re-title "iOS: associated-domains entitlement (blocks Universal Links — needed before iOS submission)"

## BUT-715 [KEEP-AS-DONE] — Android adaptive icon monochrome
**Evidence:** Status Done 2026-05-05.
**Reason:** Closed.
**Action:** none

## BUT-716 [KEEP-AS-DONE] — Android allowBackup decision
**Evidence:** Status Done 2026-05-04.
**Reason:** Closed.
**Action:** none

## BUT-717 [KEEP-AS-CANCELED] — DynamicColorBuilder brand override
**Evidence:** Status Canceled 2026-05-04.
**Reason:** Closed.
**Action:** none

## BUT-718 [KEEP-AS-DONE] — PWA manifest + install prompt
**Evidence:** Status Done 2026-05-05.
**Reason:** Closed.
**Action:** none

## BUT-719 [DELETE] — Keyboard shortcut help overlay
**Evidence:** Status Backlog, P3 Medium. Depends on BUT-521 (deleted — no shortcuts exist). 1 day.
**Reason:** Dependency gone. No shortcuts → no help to show. Solo-dev mobile-first → no demand.
**Action:** DELETE (or close as "Won't do")

## BUT-720 [DELETE] — (not found)
**Evidence:** API 404.
**Reason:** Already removed.
**Action:** none

## BUT-723 [KEEP, DOWNGRADE] — Tablet master-detail layouts
**Evidence:** Status Backlog, P3 Medium. 3-5 days. Depends on go_router migration (BUT-213).
**Reason:** Real tablet improvement but huge effort, blocked on routing migration. Solo beta — single-pane works.
**Action:** keep at P4 Low; mark blocked-by BUT-213

## BUT-724 [KEEP-AS-DONE] — Theme web scrollbars
**Evidence:** Status Done 2026-05-05.
**Reason:** Closed.
**Action:** none

## BUT-725 [KEEP-AS-DONE] — Landscape orientation overflow audit
**Evidence:** Status Done 2026-04-30.
**Reason:** Closed.
**Action:** none

---

## Consolidation Proposal

The a11y/i18n cleanup has effectively already happened. Of the 48 tickets audited:
- **34 Done / Canceled / Duplicate / hard-deleted** — no action needed
- **3 Backlog with real value, downgrade** — BUT-714 (iOS Universal Links — block before iOS submission), BUT-905 (state-change announcements), BUT-701 (focus traversal)
- **5 Backlog low-value, downgrade or delete** — BUT-706, BUT-710, BUT-711, BUT-723, BUT-900 (low priority polish)
- **1 Backlog, recommend DELETE** — BUT-719 (depends on deleted BUT-521)

**Recommended rollup epic — NEW "BUT-XXXX: A11y polish sweep iter-2 (post-beta)":**
Roll BUT-701 + BUT-900 + BUT-905 into one epic. All three are small, share a "after the big BUT-697 sweep, here are the leftovers" theme, and would ship as one 1-day sprint together. Eliminates 3 tickets, replaces with 1.

**Recommended rollup epic — NEW "BUT-YYYY: Web/desktop polish (post-monetization)":**
Roll BUT-706 + BUT-710 + BUT-723 into one deferred epic. All are "we'll fix when web/iOS becomes priority." Don't work them now; track as one card.

Net effect: 9 Backlog tickets collapse to 2 epics + delete BUT-719. Keeps Linear clean.
