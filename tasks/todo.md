# Sprint Backlog

## Sprint: iter-75 — BUT-1081 obsolete + BUT-1082 docs-only re-scope — 2026-05-25 (Mon)

Theme: Two-ticket sprint. BUT-1081 closed as obsolete (parallel-session commit `3225954f6` already added the requested sibling test files). BUT-1082 re-scoped to docs-only after Step 0 found zero production callers of the wrapper-forwarding contract.

### Step 0 — premise verification

**BUT-1081**: Both `test/unit/viewmodels/shared_content/shared_menu_viewmodel_test.dart` (994 lines) and `shared_shopping_viewmodel_test.dart` (743 lines) already exist with the exact contract the ticket called for. Added in commit `3225954f6` "intent-test sprint batch 4 — sibling shared-content VMs + coordinator (126 tests)" by a parallel session. **Premise gone** → close, skip implementation.

**BUT-1082**: Grep `\.errorStream` in `lib/` returns ZERO production callers. The wrappers' inability to re-expose `RealtimeSyncService.errorStream` therefore breaks nothing in production. The ticket's prescribed fix (add forwarding getters) is speculative plumbing for hypothetical future consumers. CLAUDE.md says: don't design for hypothetical future requirements.

**Re-scope**: switch to option (b) from the original ticket ("document the contract change loudly"):
- Add doc comments on the two wrapper `watch*` methods noting that the returned stream carries data + main-stream errors only, NOT the side-channel.
- Update `RealtimeSyncService.errorStream` docstring to call out the wrapper-non-forwarding contract.
- File a single trigger-based follow-up: "when a production consumer of errorStream is added, decide whether to forward through wrappers".

Classification: **plan-stale + re-scoped inline** per Step 0.

### Design choices

- Doc-only changes. No new code paths, no new tests (nothing to pin since no consumer exists).
- Three docstring touches:
  1. `RealtimeRecipeService.watchRealtimeRecipe` — note side-channel limitation
  2. `realtime_watching_module.watchRecipe` — same
  3. `RealtimeSyncService.errorStream` getter — call out wrapper non-forwarding

### Ship this sprint

- [x] **A1 (obsoleted). BUT-1081** — closed without code change; resolving commit `3225954f6`.
- [ ] **A2. Document wrapper errorStream boundary** — 3 docstring updates across `realtime_sync_service.dart`, `realtime_recipe_service.dart`, `realtime_watching_module.dart`. (BUT-1082)

### Acceptance

- [ ] `flutter analyze` clean (doc-only changes can't break this, but verify).
- [ ] No new tests required — nothing to pin.

### Post-Sprint Steps

- [ ] Commit + push
- [ ] Close BUT-1082 with re-scope note
- [ ] File trigger-based follow-up: "Forward errorStream through realtime wrappers when first consumer arrives"

---

## Archived iter-74 (commit `3fee0e11a`) — 2026-05-25 (Mon)

BUT-1083 P3 — added test/unit/core/utils/logger_test.dart (8 tests) pinning async-absorption + PII-redaction contracts. +160 / −12.
