# Sprint 2026-09-20 runda 5 (sprint-execute, /loop, unattended)

Two cleanup tickets, both mostly deletions. Step-0 measurements, done before planning
rather than taken from the tickets:

- BUT-1976 says "~15 files"; `grep -rln "unhit lines\|Targets ~" test` says **13**. The
  ticket predicted this and told me to recount — that is what this line records.
- BUT-1899's `logSafeConversationId` now has THREE importing modules, not the two the
  ticket names: `enforce-group-minor-membership.ts` (where it lives),
  `sync-conversation-last-message.ts` and `account-deletion-cascade.ts`.
- The `direct_` prefix is minted in `createDirectConversation` and consumed by
  `LogSanitizer.maskConversationId` (Dart) and `logSafeConversationId` (TS).
- The messaging group-detail view already declares
  `ConversationGroupDetailView`; four files import it.

- [x] BUT-1976 [Tier A] build — strike the coverage numbers from the 13 file headers.
  - AC1 (diff): `grep -rn "unhit lines\|Targets ~" test` returns nothing.
  - AC2 (diff): deletions only — no recounted number, no replacement sentence, and each
    surviving header read alone still says what the file is.
- [x] BUT-1899 [Tier A] build — four cleanups around the log masking.
  - AC1 (diff): the weaker duplicate `test/unit/utils/log_sanitizer_test.dart` is deleted,
    and nothing it covered is lost from the sibling under `test/unit/core/utils/`.
  - AC2 (diff): `logSafeConversationId` lives in `functions/src/shared/` beside
    `hash-uid.ts`; all three importers updated; the CF suites stay green.
  - AC3 (diff): a test binds the `direct_` prefix constant to at least one masker, so
    renaming the id scheme cannot turn every masker into a no-op silently. This is the one
    part with a silent failure mode; the other three are tidying.
  - AC4 (diff): `lib/views/messaging/group_detail_view.dart` is renamed to
    `conversation_group_detail_view.dart` (the class is already
    `ConversationGroupDetailView`), with its four importers updated.

## Needs you (Tier D)
- none this run.

## Deviation log

- [deviation] BUT-1899: the plan counted THREE importers of `logSafeConversationId`;
  the CF unit test imports it by path as a fourth. All four repointed.
- [discovery] BUT-1899: moving the helper falsified two sentences written elsewhere —
  the Dart mirror docstring in `log_sanitizer.dart` named the old file, and the CF test
  header claimed its cases sit "with the code they exercise". Both corrected by deletion.
- [discovery] BUT-1899: the rename needed a SIXTH reference nobody imports —
  the hardcoded path in `docs/onboarding/workflow-map.html`. Linter re-run clean.
