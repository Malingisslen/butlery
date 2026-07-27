# Accepted Deviations — the verdicts

Decided calls. Do not propose them again, and do not file review findings against them.
**Full rationale per entry: `docs/architecture/ACCEPTED_DEVIATIONS.md`** — the commit
review gate names that file in every block message, so a reviewer is pointed at it at the
moment it matters. Read it before arguing with any line below.

This list stays always-on because the costly mistake is a *plan* re-proposing a decided
no, which happens long before any review gate fires. A new deviation is appended in both
files in the same edit.

## Safety and privacy (decided, not open)

- **Draft ingredients keep full verdict authority, including FREE** — no downgrade to
  UNKNOWN for unverified rows; the draft banner + fix-list are the accepted mitigation. 2026-07-01
- **Weekly-menu presence never scopes menu generation** — presence drives display,
  portions and the who's-eating record only; scoping the candidate pool would under-filter
  allergens for a member who might still eat. Safe version deferred to BUT-1625. 2026-07-17
- **GDPR export includes the raw notification counterparty id, unredacted** — Art. 15(4)
  is a balancing test; Malin overrode the panel's redaction recommendation. BUT-1450, 2026-06-30
- **`socialFeatures` consent gates nothing, by design** — social runs on the GDPR contract
  basis, not consent; wiring it would be consent theatre and would fail closed for every
  existing user. BUT-1523, 2026-07-12
- **Account deletion does not cascade to `parse_events`** — the 30-day TTL residual is
  accepted under Art. 17's reasonable-erasure window. BUT-1570, 2026-07-16
- **RETIRED — `cook_snaps` and `activity_events` creates ARE age-gated, and stay that way.**
  The 2026-07-04 "deliberately ungated" entry was stale; both creates carry `isAgeCompliant()`
  (BUT-1418/ADR-0002) and four rules tests deny a missing or false claim. Malin resolved it in
  favour of the code on 2026-07-24. Never remove either gate citing the old entry. 2026-07-24

## Engineering

- **Equality-only Firestore filters need no composite index** — automatic single-field
  indexes merge them; only `orderBy`/range combinations need a composite. 2026-06-22
- **The 500-line limit is waived for every file in `ACCEPTED_LARGE_FILES.md`** — read the
  per-file rationale there before proposing a refactor. 2026-06-22
- **Pooled ratings: three rare edge cases are accepted** — shared-pool retraction, phantom
  re-pool after an edit, and no cost gate on unchanged writes. Each "fix" costs unbounded
  reads or a systematic under-count. 2026-07-03
- **Pooled ratings never detach on a recipe edit** — a rating is frozen to the dish it
  judged; there is no edit-triggered detachment and no detach notice. 2026-07-03
- **Four mockup departures are intentional** — green rating pill, the "Lagat idag" chip,
  hidden UNKNOWN allergen badge, and the cream colour scale. 2026-06-22
- **A shared-list EDIT made offline may still lose a concurrent edit** — appends are merged
  via `arrayUnion` (safe); tick/amend/remove queues the cached base, because Firestore has
  no offline-replayable per-row primitive and refusing offline ticks breaks the shop-aisle
  case. BUT-1683, 2026-07-26
