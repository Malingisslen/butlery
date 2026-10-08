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

- **SUPERSEDES the BUT-1819 `sourceUrl` entry above (2026-09-15): the counter-argument is
  built.** `sanitizeUrl` tests `^[\x00-\x20]*(?:javascript|data|vbscript):` against the value
  it returns (null bytes removed, trimmed, homoglyphs folded) with tab/CR/LF removed, and blanks
  on a match; a `data:` mid-sentence is kept.
  Retired verbatim: "`sanitizeUrl`'s patterns are UNANCHORED substrings, and `sourceUrl` is a free-text"
  **Malin's explicit call, 2026-09-14**, over the literal `^\s*…` pattern, after being shown
  that it would pass a dangerous scheme behind a leading control character or null byte. Keep
  the discriminator fixture.

- "Ersätt listan" offline replaces the personal week list from the copy in memory, so a tick made on a recipe row on another device meanwhile can be lost; an offline add stays safe (`arrayUnion` on `menuItemIds`), and the receipt reports no change on that path. BUT-1683 shape (BUT-2140, B1, 2026-10-08)
- An offline cached-base replay that overwrites another member's change on a shared list keeps no `previous` or `recentlyRemoved` entry for what it overwrote; `recentlyRemoved` is queued as `arrayUnion`/`arrayRemove`, never the cached array, and is pruned only online. BUT-1683 shape (BUT-2140 PR 3, 2026-10-08)
- An app from before BUT-2140 sends a shared list's rows without `previous`, so that list's earlier versions can no longer be restored; no current content and no `recentlyRemoved` entry is lost (BUT-2140 PR 3, 2026-10-08)
