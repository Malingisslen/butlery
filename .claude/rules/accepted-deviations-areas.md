---
paths:
  - "lib/repositories/**"
  - "lib/services/unified/**"
  - "lib/services/parsing/sanitizers/**"
  - "functions/src/ratings/**"
  - "lib/theme/**"
  - "firestore.indexes.json"
---

# Accepted Deviations — ratings, shopping, sanitizers, theme and indexes

Decided calls for this area, split out of `.claude/rules/accepted-deviations.md` on
2026-08-17 so they load when you open the code they govern rather than in every
session. **Do not propose them again and do not file review findings against them.**
Full rationale per entry: `docs/architecture/ACCEPTED_DEVIATIONS.md`.

A new deviation in this area is appended HERE and in that document, in the same edit.

- **Equality-only Firestore filters need no composite index** — automatic single-field
  indexes merge them; only `orderBy`/range combinations need a composite. 2026-06-22

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

- **A recipe `sourceUrl` containing `data:` anywhere is blanked in full on write** —
  `sanitizeUrl`'s patterns are UNANCHORED substrings, and `sourceUrl` is a free-text
  PROVENANCE field for a dozen writers, so the value lost is usually a Swedish sentence.
  Accepted knowingly: low probability, and the user-facing protection is the RENDER guard
  (`isSafeExternalUrl`), not storage blanking. The 2026-08-10 security review's
  counter-argument — that the render allowlist now dominates the storage blocklist, so
  anchoring the pattern would keep all the protection at no cost to provenance — is
  recorded in the full entry and needs its own ticket, not a quiet widening. Do not file
  this as a bug; do not "simplify" the discriminator fixture that proves a bare colon is
  harmless. BUT-1819, 2026-08-10

