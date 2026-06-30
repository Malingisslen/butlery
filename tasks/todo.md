# Sprint Backlog

## Sprint: compliance quick wins (need-malin, interactive) — 2026-06-30

Autonomous lane drained (BUT-889/1240 ops-blocked, BUT-1176 deprioritized). Malin present this
session and chose the GDPR/compliance cluster from the need-malin lane. Two decisions taken live:
- BUT-1395 → REMOVE the social-features toggle (social runs on GDPR contract basis, not consent).
- BUT-1399 → switch appeals@butlery.app → appeals@butlery.se (no .app mailbox).

All four are router single/full-panel (account/security/legal paths). Phase 1.4 stakeholder
critique (firebase-backend-security as owning role) runs at commit via the Tier-2 gate.

### Agent A: GDPR right-of-access + accountability — Stakeholders: Privacy/DPO, Legal (single→panel)
- [ ] **A1. Add 3 erased-but-unexported PII collections to the Art.15 export** `[Tier A]` (BUT-1396) — `data_export_service.dart` + export managers
  - Add export sections: `reports` (reporterId==uid), `pings` (fromUserId==uid), `realtime_recipes` (userId==uid); wire the already-implemented `exportGroupWeeklyMenuPlans` into the orchestrator futures map.
  - Acceptance:
    - `exportUserData()` output contains top-level keys `reports`, `pings`, `realtime_recipes`, and group weekly-menu participation — each scoped to the calling user's id.
    - Each new export path is read-only and ownership-scoped (mirrors existing managers; no cross-user read).
    - `exportGroupWeeklyMenuPlans` is no longer dead code — it is referenced in the futures map.
    - A test asserts the new sections appear for a user with such data and are empty/absent-safe when they have none.
  - Negative constraint: do NOT change existing export sections' shape/keys; do not weaken ownership scoping.
- [ ] **A2. Persist a Terms-acceptance record at signup** `[Tier A]` (BUT-1400) — auth signup path + `terms_of_service_{en,sv}.md`
  - Write `termsAcceptedAt` + `termsVersion` at account creation (every signup path); add a `Version:` field to both ToS headers so the record pins to something semantic.
  - Acceptance:
    - A new account creation persists `termsAcceptedAt` (timestamp) and `termsVersion` (matching the ToS header version) to the user's record/Firestore.
    - Both `terms_of_service_en.md` and `terms_of_service_sv.md` carry a `Version: 1.0` header line.
    - The version written is sourced from a single constant, not hardcoded at the call site twice.
    - A test proves the record is written on signup with the expected version.
  - Negative constraint: do not block/break the existing signup flow if the record write fails (best-effort, logged) — acceptance-record gap must not become an onboarding outage.

### Agent B: misleading-consent + dead-contact fixes — Stakeholders: Privacy/DPO, Legal (single)
- [ ] **B1. Remove the unenforced socialFeatures consent toggle** `[Tier A]` (BUT-1395) — `consent_management_view.dart`
  - Remove the social-features toggle from the consent screen; social features run on the contract basis. Model field preserved for Firestore back-compat.
  - Acceptance:
    - The consent screen no longer renders a social-features toggle.
    - `ConsentPurpose.socialFeatures` field/enum stays in the model (no serialization break); only the UI toggle is gone.
    - A code comment records why (unenforced consent → contract basis, IMY misleading-consent risk).
  - Negative constraint: do not remove the enum case or change `toMap`/`fromMap` (would break stored docs).
- [ ] **B2. Fix appeals contact domain** `[Tier A]` (BUT-1399) — `terms_of_service_{en,sv}.md`
  - Replace `appeals@butlery.app` with `appeals@butlery.se` in both language ToS.
  - Acceptance:
    - Neither ToS file contains `butlery.app`; both use `appeals@butlery.se`.
  - Negative constraint: only the appeals address changes; no other contact addresses touched.

### Needs you (Tier D — flagged, not worked this session, from earlier scan)
- BUT-889 — 4 paid-API LLM golden corpora: needs CI Vertex AI/Mistral credentials + budget.
- BUT-1240 — NER real-signal lane: needs a device-capable/emulator CI runner provisioned.

### Post-Sprint Steps
- [ ] `dart analyze --fatal-infos`
- [ ] Relevant unit tests (data_export, consent, auth/terms)
- [ ] code-reviewer + testing-specialist + firebase-backend-security gates (touches lib/services + export)
- [ ] Commit, push to main
- [ ] Linear: all four Tier A → Done (or In Review if a criterion fails)

---

## Sprint: autonomous-lane (deploy rollback + coverage floor) — 2026-06-30

(archived — BUT-1424 shipped `9df35297b` → In Review; BUT-1149 stays Backlog, measured 56.76% < 60.0 floor)
