# Sprint 2026-07-11 (serial) — ready-set burndown from the salvage

Serial `/sprint-execute` (parallel engine held — BUT-1569 deny-rule bug). 5 tickets, one
at a time, each its own commit. BUT-1523 held (need-malin, plan-first).

State UUIDs: Todo 5a6d3faa · InProgress f8a3cf05 · InReview 9929b3b0 · Done 57dc8a84

## BUT-1586 — server retention classifier: inDays→ms (Tier A, router: single)
Mirror the BUT-1550 client fix on the server. `functions/src/analytics/track-retention.ts`.
- [ ] Drop `Math.floor` in `classifyLifecycleStageServer`; compare ms (`> 30*MS_PER_DAY`, `>= 14*MS_PER_DAY`) in BOTH active + never-active branches
- [ ] Server test: 30d12h → churned, both branches
- Acceptance: (1) no Math.floor in recency compare; (2) 30d12h→churned; (3) test covers both branches
- Gates: cloud-functions-specialist. Close: Done.

## BUT-1551 — route account-deletion through AuthService (Tier A, router: single)
`onboarding_age_gate_blocked_view.dart:57` calls FirebaseAuth directly.
- [ ] Add `AuthService.deleteCurrentAuthUser()` wrapping the Firebase Auth delete
- [ ] View calls the service method, not FirebaseAuth.instance directly
- [ ] Test asserts routing through the service
- Acceptance: (1) service method exists; (2) view uses it, no direct FirebaseAuth call; (3) test proves it
- Gates: code-reviewer, testing-specialist, firebase-backend-security (auth). Close: Done.

## BUT-1540 — enforce shared-link expiry on live recipe path (Tier A, router: single)
`deep_link_handler.dart` `_handleRecipeLink` navigates with no expiry gate.
- [ ] Wire `isLinkExpired`/`isLinkValid` into the live path before navigation
- [ ] Expired link → rejected + user-facing message, no navigation
- [ ] Test: expired-link rejection on the live path
- Acceptance: (1) live path checks expiry pre-nav; (2) expired link does not navigate; (3) test covers it
- Gates: code-reviewer, testing-specialist. Close: Done.

## BUT-1525 — tokenise PII in shareable-URL slugs (Tier A code, router: FULL-PANEL high-stakes)
`lib/services/llm/pii_scrubber.dart:236`. Malin: tokenise.
- [ ] Phase 1.4 full-panel blind critique (Legal/Privacy/Security/…) → fold must-haves
- [ ] Tokenise slug segments BEFORE the heuristics run
- [ ] Test: name/address in a slug is tokenised before either scrubber sees it
- [ ] No regression to existing non-slug scrubbing
- Acceptance: (1) slug tokenised pre-heuristics; (2) name/addr in slug not leaked (test); (3) existing scrubbing intact
- Gates: code-reviewer, testing-specialist. Close: Done (Tier A) unless panel raises a sign-off item.

## BUT-1524 — age-maturity gate on comment posting (Tier C, router: FULL-PANEL high-stakes, firestore.rules)
Malin: gate comments. `firestore.rules:1056` + wire `AccountMaturityHelper`.
- [ ] Phase 1.5 plan expansion (fires: full-panel + security) + Phase 1.4 panel
- [ ] `isAccountMatured()` on comment create rule (mirror DM/friend-req)
- [ ] Wire `account_maturity_helper.dart` into the comment CTA (block + message pre-maturity)
- [ ] firestore-rules-tester allow/deny: matured can comment, immature cannot
- Acceptance: (1) rule requires maturity; (2) client CTA gated with message; (3) rules-tester proves allow/deny
- Gates: code-reviewer, testing-specialist, firestore-rules-tester. Close: In Review (Tier C security-rule).

## Needs you (Tier D): none in this batch.
## Held: BUT-1523 (consent-toggle removal) — need-malin, plan-first.

## Deviation log

---
(prior sprint plans archived in git history: commit 0db2fbca4 and earlier)
