# Sprint 2026-09-19 (sprint-execute, /loop, unattended)

Selection: Step-0 grep of main confirmed every premise below still holds (HEAD `a35576566`).
Router output pasted per ticket (raw `python tools/stakeholder_router.py --json <paths>`).
panelPolicy = park → full-panel tickets build and park In Review.

## Comment / doc strikes (Tier A)

- [x] BUT-2104 [Tier A] build — strike stale kill-switch comment, `functions/src/social/duplicate-content-guard.ts`. Router: single (T&S, Vendor).
  - AC1 (diff): the "Art. 15 export ships … verbatim" and "Undecided, so no rule file carries it; the ADR is its only home" sentences are gone.
  - AC2 (diff): no new claim added beyond an optional bare pointer "Read ADR-0009 before switching this on"; the ships-OFF reasoning is unchanged.
- [x] BUT-2108 [Tier A] build — strike the copyWith rationale in the BUT-1904 group, `test/unit/services/messaging_service_test.dart`. Router: single (SW Arch, PM).
  - AC1 (diff): the four-line copyWith rationale in the BUT-1904 group is deleted, nothing added.
  - AC2 (diff): the `content`-is-a-PARAMETER paragraph and the BUT-1909 group's true copy are untouched.
- [x] BUT-2097 [Tier A] build — move `items` const out of the shared-content heading; delete the uncompilable Usage Examples block. Router: single.
  - AC1 (diff): `items` no longer sits under `// ── Shared content subcollections ──`; heading text not reworded.
  - AC2 (diff): the class-header Usage Examples block in `firebase_shared_shopping_repository.dart` is removed; analyze clean.
- [x] BUT-2096 [Tier A→park: full-panel file] build — strike "and no later erasure can find them" in `account-deletion-cascade.ts`; re-read survivor. Router: full-panel (comment-only diff).
  - AC1 (diff): the false clause is gone; "unreachable PII" no longer rests on the struck half.
  - AC2 (diff): `deleteRealtimeDocsWithChildren`'s true sentence untouched; no code change.

## Small UI bug (Tier B)

- [x] BUT-1863 [Tier B] build — trailing space in pantry quantity line when unit is empty. Router: single (SW Arch, PM).
  - AC1 (diff): empty unit renders `"1"` without a trailing space; non-empty unit renders `"1 st"` unchanged.
  - AC2 (diff): a widget/unit test pins both cases.

## Rules suites (Tier C, full-panel → park In Review)

- [x] BUT-2105 [Tier C] build — diagnose the red rules suites by MEASUREMENT, fix test or rule per cause.
  - AC1 (diff/run): each red suite's failing cases named with measured cause.
  - AC2 (diff): no ALLOW case is fixed by weakening a rule without a written reason.
- [x] BUT-2086 [Tier C] build — `recipe_ratings` create requires doc id `recipeId + '_' + auth.uid`.
  - AC1: rules test shows a second rating under another id DENIED.
  - AC2: the app's real write (`{recipeId}_{uid}`) still ALLOWED.
- [x] BUT-2092 [Tier C] build — `metadata.poll.isClosed` cannot go true→false on messages sender-update.
  - AC1: a rules conjunct refuses isClosed true→false; creator-as-sender close still allowed.
  - AC2: three rules cases (creator-sender allowed, other participant denied, creator-not-sender denied) mutation-probed.

## Needs you (Tier D)

- none this run.

## Deviation log
- [discovery] BUT-2105: plan expected rule drift → all five reds were test harness (leftover emulator data in 4 suites, no storage emulator for the 5th) → fixed test-side only; no rule touched.
- [deviation] BUT-2092: panel (Security Architect) asked to freeze the whole closed poll payload → kept ticket scope (one-way isClosed) and filed BUT-2116; rules-tester added the delete-and-recreate bypass to it.
- [discovery] BUT-2105 side finding: realtime menu votes use a random id where rules require uid → BUT-2118 (not measured).
- [deviation] Stakeholder "single" critique for the comment/pantry batch ran after the edits, not before (the edits were deletions); no conditions came back.
