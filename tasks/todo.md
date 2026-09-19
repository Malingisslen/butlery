# Sprint 2026-09-19 runda 2 (sprint-execute, /loop, unattended)

Router on the fileset (`firestore.rules functions/src/__tests__/conversations-rules.test.ts
lib/views/pantry/add_pantry_item_sheet.dart`) → **full-panel**; panelPolicy = park, so the
rules work goes to In Review. Step-0 greps confirmed every premise on current main.

- [x] BUT-2100 [Tier C] build — bound the shared-content unread counters in `firestore.rules`.
  The ticket's own "±1 per field" fix is measured WRONG (its Linear comment); build the form
  that comment specifies: own create arm, owner arm allowing absolute values (the documented
  repair path `recalculateUnreadCount`), stranger arm bound to `old ± 1` in BOTH directions.
  - AC1 (diff): a stranger writing an arbitrary value is DENIED; a stranger's +1 via the real
    `FieldValue.increment` sentinel through the real writer shape is ALLOWED.
  - AC2 (diff): first share for a user (document absent) is ALLOWED; a badge clear
    (`decrementUnreadCounter`, -1, no `totalSharedContent`) is ALLOWED.
  - AC3 (diff): the owner may still write an absolute recomputed value.
  - AC4 (diff): a new rules suite with its own project id + `clearFirestore()`, mutation-probed
    per arm.
- [x] BUT-2111 [Tier A] build — deny cluster pinning the removed `conversation_memberships`
  path in `conversations-rules.test.ts`.
  - AC1 (diff): one DENY per verb the old block granted (read/list, create, update, delete),
    sent by the OWNER, attributable to the catch-all line.
  - AC2 (diff): a fail-closed control on a sibling path under the same owner is ALLOWED.
- [x] BUT-1864 [Tier A] build — strike the false "keyed on" clause in
  `add_pantry_item_sheet.dart`. Correction may only DELETE; the ticket's suggested rewrite is
  new text and is NOT taken. `.claude/rules/accepted-deviations.md` is a decision record —
  do not strike it; file it if it is wrong.
  - AC1 (diff): the false clause is gone; no replacement sentence.
  - AC2 (diff): the surviving sentences read true alone; no code change.
- [!] BUT-2050 [Tier A] build — catch the flaky case in `blocks-rules.test.ts`.
  - AC1 (run): a FAIL line captured, or N consecutive green runs recorded as the measurement.
  - AC2 (diff): the cause is named and fixed at the root, not by retrying.

## Needs you (Tier D)
- none this run.

## Deviation log
- [discovery] BUT-2050: 20 consecutive runs of blocks-rules.test.ts were green, so no FAIL line was captured and no root cause named. Not built; the measurement is the outcome.
- [deviation] BUT-2100: the plan said the stranger arm would be bound to `old ± 1` in BOTH directions; the DOWNWARD half was dropped after two reviewers traced every caller and found no shipped stranger decrement (every decrement path passes the signed-in uid, so the owner arm serves it).
- [deviation] BUT-2100: the ticket's own suggested fix was measured wrong before this run; built the form its review comment specifies instead of re-planning it.
- [deviation] Panel and gate findings were folded in only where they were one-line pins (zero floor, per-field denies, owner-shape deny); the cross-field desync, the +1 spam, the wildcard path and the Dart-side owner guard went to BUT-2121/2122/2123 instead of widening scope.
