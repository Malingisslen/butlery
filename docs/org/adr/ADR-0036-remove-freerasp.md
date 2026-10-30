# ADR-0036: Remove freeRASP instead of disclosing Talsec

- **Date:** 2026-10-29
- **Status:** Escalated to Malin
- **Trigger:** `tasks/butlery-policy-1.24-plan.md` (privacy policy 1.24 and Play Data Safety)
- **Blast-radius tier:** single
- **Stakeholders seated:** Legal Counsel

## The disagreement
Legal Counsel approved the policy plan with conditions, and flagged two calls as interpretive and
Malin's: whether freeRASP's telemetry to Talsec falls under the LEK 9 kap. 28 § "strictly
necessary" exemption, given that Talsec's DPA also lets it use the data to improve its own
products; and whether that own-purpose use makes Play's Data Safety answer "shared" rather than
the "not shared" Malin chose earlier the same day.

## Decision
Escalated to Malin → remove freeRASP. In the code, freeRASP's result is only written to the
local log (`lib/core/bootstrap/stages/core_stage.dart`); no caller acts on it. App Check with
Play Integrity (`lib/main.dart`) stays as the backend protection. Both escalated questions lapse
with the SDK.

## Consequences
- The policy plan gains a removal step before the policy edit; 1.24 states that versions before
  the removal sent integrity data to Talsec, rather than describing Talsec as a current recipient.
- Play Data Safety drops approximate location once the new versionCode is the only one in
  distribution.
