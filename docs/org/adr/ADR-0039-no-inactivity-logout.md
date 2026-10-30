# ADR-0039: No automatic logout on inactivity

- **Date:** 2026-10-30
- **Status:** Accepted
- **Trigger:** `tasks/session-timeout-removal-plan.md`
- **Blast-radius tier:** full-panel
- **Stakeholders seated:** Security Architect, Privacy / Data Protection Officer (GDPR), Legal Counsel, Product Manager, Software Architect. Financial Controller / FinOps, Information Architect / Wayfinding and Monetization / Subscriptions Lead have no stake: no cost, no paywall, and the return path is removed.

## The disagreement
Security and Privacy value the 45-minute logout as a control on an unlocked, unattended
device (GDPR art. 32; household data includes children's allergies). Product
wants the user signed in until she signs out herself.

## Decision
Malin, 2026-10-30: the user stays signed in until she signs out herself. The inactivity
logout, its warning dialog, its activity detection, the "signed out while the app lay still"
notice and the return path after a new sign-in are removed. Malin accepted the risk below.

Accepted risk: an unlocked phone left unattended keeps the app open. The device screen
lock is the remaining protection. Google/Apple sign-in users have no "sign out
everywhere" action; follow-up ticket: BUT-2481.

## Consequences
- The code signs the user out only for server-side or account reasons: blocked, deleted or
  revoked accounts, password change, scheduled deletion, backup-code recovery, and
  the user's own sign-out. No path depends on elapsed time.
- `test/architecture/no_inactivity_logout_test.dart` guards the names, the set of files that
  sign out, and the absence of timers in those files. It cannot prove that no indirect call
  chain ties a sign-out to time.
- The forced-logout analytics event `session_timeout_logout` is renamed
  `session_invalidated_logout`; four timeout events are removed.
- `TR::FLOW::06::session::utgang` is RESTING (decision `BUT-2480-ingen-timeout`).
- Older app versions still sign out after 45 minutes until they are updated.
