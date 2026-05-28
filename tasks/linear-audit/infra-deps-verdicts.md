# Infra / CI / Analytics / Deps / Backend audit (2026-05-28)

Solo founder context. Store submission deferred. Push-direct-to-main workflow. Most "Done" tickets are confirmed against current repo state (`.github/workflows/`, `pubspec.yaml`, `functions/src/`).

---

## CI / Build

## BUT-397 [KEEP] — Tighten CI coverage floor once ≥5 runs log a real baseline
**Evidence:** `.github/workflows/test.yml` still has matrix (unit/widget/views/golden) — coverage floor logic present. BUT-1149 just lowered floor; BUT-494 closed 2026-05-24.
**Reason:** Iter-loop on coverage gates. Still relevant — but recent commit BUT-1149 *reduced* floor (opposite direction). Premise drifted: instead of tightening, we're loosening.
**Action:** IMPROVE — rewrite scope: "After BUT-1149 stabilization, re-tighten floors once views shard is unblocked (BUT-1155)."

## BUT-420 [KEEP] — Build automated deploy pipeline (Fastlane)
**Evidence:** No `fastlane/` directory; no `firebase deploy` workflow.
**Reason:** Real gap, but store submission deferred. Solo dev does manual releases fine. Demote.
**Action:** DEPRIORITIZE to LOW. Couple with store-submission tickets.

## BUT-449 [NOT_FOUND]
**Evidence:** Linear returned `Entity not found`.
**Reason:** Issue doesn't exist / renumbered.
**Action:** DELETE from tracking.

## BUT-450 [NOT_FOUND]
**Evidence:** Linear returned `Entity not found`.
**Reason:** Issue doesn't exist.
**Action:** DELETE from tracking.

## BUT-451 [KEEP] — Staging Firebase project
**Evidence:** `firebase.json` single project; no `.firebaserc` for aliases.
**Reason:** Real risk of destructive dev mistakes on prod. Solo dev with no staging is dangerous for rules/functions changes.
**Action:** KEEP at HIGH. Still relevant.

## BUT-452 [DONE-CONFIRMED] — Runbooks
**Evidence:** Status=Done, archived 2026-05-22.
**Reason:** Closed.
**Action:** No action.

## BUT-486 [KEEP] — Automate Firebase rules+indexes+functions deploy in CI
**Evidence:** No `deploy-firebase.yml`; only `firestore-rules.yml` for tests.
**Reason:** Manual deploys = rollback friction. Worth doing, but solo workflow tolerates manual today.
**Action:** DEPRIORITIZE to MEDIUM-LOW. Pair with BUT-420.

## BUT-488 [KEEP] — Auto-bump pubspec version
**Evidence:** `pubspec.yaml` at `0.9.0+1` — premise already corrected in ticket.
**Reason:** Low value pre-store-submission.
**Action:** DEPRIORITIZE to LOW. Couple with BUT-420.

## BUT-489 [DONE-CONFIRMED] — Emulator health check gate
**Evidence:** Status=Done 2026-05-04.
**Action:** No action.

## BUT-490 [DONE-CONFIRMED] — AAB + web bundle artifacts upload
**Evidence:** Status=Done 2026-05-04.
**Action:** No action.

## BUT-491 [KEEP] — Desktop platform builds in CI
**Evidence:** `build-validation.yml` only builds Android + web; pubspec advertises macOS/Windows.
**Reason:** Real gap; tied to differentiator positioning (BUT-677).
**Action:** KEEP at MEDIUM.

## BUT-492 [KEEP] — Firebase + GCP cost alerts
**Evidence:** No `docs/operations/COST_MONITORING.md`; depends on `alerts@butlery.app`.
**Reason:** Solo dev with LLM costs — runaway-cost insurance is high-value.
**Action:** IMPROVE — promote to HIGH given LLM cost surface. Doesn't need code, just billing config.

## BUT-493 [DONE-CONFIRMED] — Staged rollout policy doc
**Evidence:** Status=Done 2026-05-05.
**Action:** No action.

## BUT-494 [DONE-CONFIRMED] — Tighten coverage floors
**Evidence:** Status=Done 2026-05-24; reverted by BUT-1149 (current iter).
**Reason:** Done but immediately partly reversed. Flag for BUT-397 rewrite.
**Action:** No action; superseded by BUT-397 IMPROVE.

## BUT-495 [DONE-CONFIRMED] — CI build duration telemetry
**Evidence:** Status=Done 2026-05-05.
**Action:** No action.

## BUT-496 [KEEP] — DORA metrics tracking
**Evidence:** Backlog, depends on BUT-420 (deploy pipeline).
**Reason:** Aspirational for solo dev — DORA only meaningful with automated deploys.
**Action:** DEPRIORITIZE to LOW. Blocked on BUT-420.

## BUT-497 [DONE-DUPLICATE] — Maintenance kill switch
**Evidence:** Status=Duplicate, canceled 2026-05-04.
**Action:** No action.

## BUT-535 [DONE-CONFIRMED] — SBOM CycloneDX
**Evidence:** Status=Done 2026-05-04 (sbom.yml workflow exists).
**Action:** No action.

## BUT-558 [KEEP] — Install DCM
**Evidence:** No `dart_code_metrics` in `pubspec.yaml`.
**Reason:** Tooling overhead for measurement. Solo dev can spot-check; DCM is nice-to-have.
**Action:** DEPRIORITIZE — already LOW; leave as is or DELETE if no upcoming complexity push.

## BUT-619 [DONE-DUPLICATE]
**Evidence:** Canceled as duplicate 2026-05-04.
**Action:** No action.

---

## Analytics (rollup recommended)

## BUT-436 [DONE-CONFIRMED]
**Evidence:** Done 2026-05-04.

## BUT-437 [DONE-CONFIRMED]
**Evidence:** Done 2026-05-05 (AnalyticsNavigatorObserver wired).

## BUT-518 [DONE-CONFIRMED]
**Evidence:** Done 2026-05-04.

## BUT-523 [DONE-CONFIRMED]
**Evidence:** Done 2026-05-03.

## BUT-532 [NOT_FOUND]
**Action:** DELETE.

## BUT-538 [DONE-CONFIRMED]
**Evidence:** Done 2026-05-04.

## BUT-545 [DONE-CONFIRMED]
**Evidence:** Done 2026-05-04.

## BUT-552 [NOT_FOUND]
**Action:** DELETE.

## BUT-560 [DONE-CONFIRMED]
**Evidence:** Done 2026-05-02.

## BUT-569 [DONE-CONFIRMED]
**Evidence:** Done 2026-04-27.

## BUT-576 [NOT_FOUND]
**Action:** DELETE.

## BUT-584 [NOT_FOUND]
**Action:** DELETE.

## BUT-588 [DONE-CONFIRMED]
**Evidence:** Done 2026-05-02.

## BUT-593 [NOT_FOUND]
**Action:** DELETE.

## BUT-599 [DONE-CONFIRMED]
**Evidence:** Done 2026-05-01.

## BUT-605 [DONE-CONFIRMED]
**Evidence:** Done 2026-04-30.

## BUT-612 [DONE-CONFIRMED]
**Evidence:** Done 2026-04-27.

## BUT-618 [NOT_FOUND]
**Action:** DELETE.

## BUT-623 [DONE-CONFIRMED]
**Evidence:** Done 2026-05-01.

## BUT-626 [KEEP] — Bucket-based A/B prompt infra
**Evidence:** Backlog. Depends on BUT-621 (Done).
**Reason:** Future-state. No value until prompts get a regression worth testing.
**Action:** DEPRIORITIZE to LOW. Trigger condition: first reported parse regression.

**Analytics rollup verdict:** All 20 listed analytics tickets are already either DONE or NOT_FOUND, *except* BUT-626 (LOW). **No rollup needed** — the instrumentation epic effectively already completed itself. Going forward, future analytics tickets should be batched under one epic.

---

## Store/listing (deprioritize per memory)

## BUT-415 [KEEP-LOW] — Publish privacy policy + store listings
**Evidence:** Backlog, High priority. Memory says deferred but will return.
**Action:** DEPRIORITIZE to LOW. Re-prioritize when store-submission unblocks. Note: partially overlaps with BUT-890 (host privacy policy URL).

## BUT-416 [NOT_FOUND]
**Action:** DELETE.

## BUT-541 [NOT_FOUND]
**Action:** DELETE.

## BUT-561 [NOT_FOUND]
**Action:** DELETE.

## BUT-583 [NOT_FOUND]
**Action:** DELETE.

## BUT-590 [NOT_FOUND]
**Action:** DELETE.

## BUT-624 [NOT_FOUND]
**Action:** DELETE.

**Store/listing rollup verdict:** Only BUT-415 exists in the listed batch. The remaining six IDs are phantom. The real active store-submission tickets (BUT-646 Data Safety, BUT-890 host privacy policy) live elsewhere and already self-document as "deferred until go-live."

---

## Dependencies (preserve Dart SDK chain)

## BUT-434 [DONE-CONFIRMED] — receive_intent → app_links
**Evidence:** `pubspec.yaml:87` confirms `app_links: ^6.4.1`. Done 2026-05-02.

## BUT-435 [KEEP] — Dart SDK 3.5 → 3.10 bump
**Evidence:** `pubspec.yaml:7` still `sdk: ^3.5.0`. Gates BUT-503, BUT-507, BUT-509.
**Reason:** SDK bump unblocks 3+ pinned majors. Real dependency hub. Keep.
**Action:** KEEP at MEDIUM. **Gating chain**: BUT-435 → BUT-503 + BUT-507 + BUT-509.

## BUT-500 [DONE-CONFIRMED]
**Evidence:** Done 2026-05-05.

## BUT-502 [KEEP] — file_picker 10→11
**Evidence:** `pubspec.yaml:74` `file_picker: ^11.0.2` — **already done**, ticket premise stale.
**Reason:** Premise gone — pubspec is on 11.x already.
**Action:** DELETE (or mark Done).

## BUT-503 [KEEP] — archive 3→4 (blocked on BUT-435)
**Evidence:** `pubspec.yaml:96` `archive: ^3.6.1`. Blocked.
**Action:** KEEP at MEDIUM. Chain dependent on BUT-435.

## BUT-507 [KEEP] — csv 6→7/8 (blocked on BUT-435)
**Evidence:** `pubspec.yaml:81` `csv: ^6.0.0`. Comment: "Blocked: 7.x/8.x needs Dart 3.10+".
**Action:** KEEP at MEDIUM. Chain dependent on BUT-435.

## BUT-509 [KEEP] — flutter_local_notifications 20→21 (blocked on BUT-435)
**Evidence:** `pubspec.yaml:33` `flutter_local_notifications: ^20.1.0`. Comment confirms block.
**Action:** KEEP at MEDIUM. Chain dependent on BUT-435.

## BUT-513 [DONE-CONFIRMED]
**Evidence:** Done 2026-05-04.

## BUT-529 [DONE-CONFIRMED]
**Evidence:** Done 2026-05-04. Comment in `pubspec.yaml:113` confirms the rationale doc landed.

## BUT-554 [KEEP] — Tracking ticket build_resolvers/build_runner_core
**Evidence:** Tracking only. Discontinued transitive deps.
**Action:** KEEP at LOW. No active work; revisit when drift_dev ships a new major.

## BUT-555 [DONE-CONFIRMED]
**Evidence:** Done 2026-05-04.

## BUT-562 [DONE-CONFIRMED]
**Evidence:** Done 2026-05-05.

## BUT-564 [DONE-CONFIRMED]
**Evidence:** Done 2026-05-05.

## BUT-571 [DONE-CONFIRMED]
**Evidence:** Done 2026-05-05.

## BUT-578 [DONE-CONFIRMED]
**Evidence:** Done 2026-05-05.

**Dep chain summary:** Active = BUT-435 (gate) → BUT-503, BUT-507, BUT-509. BUT-502 stale (already on 11.x). BUT-554 dormant tracking ticket. All others Done.

---

## Backend / Cloud Functions

## BUT-439 [NOT_FOUND]
**Action:** DELETE.

## BUT-446 [DONE-CONFIRMED]
**Evidence:** Done 2026-05-04.

## BUT-466 [DONE-CONFIRMED]
**Evidence:** Done 2026-05-04.

## BUT-482 [DONE-CONFIRMED]
**Evidence:** Done 2026-05-04.

## BUT-499 [NOT_FOUND]
**Action:** DELETE.

## BUT-510 [DONE-CONFIRMED]
**Evidence:** Done 2026-05-04.

## BUT-515 [DONE-CONFIRMED]
**Evidence:** Done 2026-05-04.

## BUT-566 [DONE-CONFIRMED]
**Evidence:** Done 2026-05-02.

## BUT-589 [DONE-CONFIRMED]
**Evidence:** Done 2026-05-04.

## BUT-621 [DONE-CONFIRMED]
**Evidence:** Done 2026-04-29.

## BUT-627 [DONE-CONFIRMED]
**Evidence:** Done 2026-05-04.

---

## Recommended priority changes (action list for Linear)

| Ticket | From | To | Reason |
|---|---|---|---|
| BUT-397 | Low | Medium + IMPROVE title | Re-tighten after BUT-1149 stabilizes |
| BUT-420 | High | Low | Store submission deferred |
| BUT-415 | High | Low | Store submission deferred (per memory) |
| BUT-486 | High | Medium | Manual deploys acceptable for solo |
| BUT-488 | Medium | Low | Couple with BUT-420 |
| BUT-492 | Medium | High | LLM cost insurance — high ROI |
| BUT-496 | Low | Low (blocked) | Note blocked-on dependency on BUT-420 |
| BUT-626 | Medium | Low | Trigger-gated |
| BUT-502 | Medium | DELETE | pubspec already on 11.x |

**NOT_FOUND tickets to remove from tracker:** BUT-449, BUT-450, BUT-532, BUT-552, BUT-576, BUT-584, BUT-593, BUT-618, BUT-416, BUT-541, BUT-561, BUT-583, BUT-590, BUT-624, BUT-439, BUT-499 (16 phantom IDs).
