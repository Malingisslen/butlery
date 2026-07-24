# Accepted Deviations — full rationale

Decision record (doc class 1). The **verdicts** live always-on in
`.claude/rules/accepted-deviations.md`, so no plan can propose something already decided
against. This file holds the reasoning behind each one, and the review gate names it in
every block message — so a reviewer about to file a finding is pointed here at exactly
the right moment.

**Review agents MUST consult this list before filing a finding.** These are decided;
reopening one needs a new decision, not a review comment.

Append-only. Supersede an entry with a newer dated entry; never silently delete. Format
per entry: **what it deviates from** — the deviation — **Why:** rationale — date. A new
entry gets its one-line verdict added to the always-on file in the same edit.

---

### [Firebase] Pure-equality Firestore queries need no composite index
Multi-field **equality** filters do not require a composite index — Firestore's automatic
single-field indexes merge equality constraints. Only `orderBy` or range (`<`, `>`, `!=`,
`in` + sort) combinations need a composite.
**Why:** A reviewer once flagged a missing composite index on an equality-only query as a
Critical; it was a false positive. Don't flag missing composites unless an `orderBy`/range is
involved. (See memory `reference_firestore_equality_index.md`.) — 2026-06-22

### [Code Quality] Files >500 lines listed in ACCEPTED_LARGE_FILES.md
The 500-line limit (CLAUDE.md rule #2) is waived for every file enumerated in
`docs/architecture/ACCEPTED_LARGE_FILES.md`, each with a per-file rationale.
**Why:** Some files are cohesive facades or generated/config and splitting them would hurt
clarity. Don't propose refactoring a large file without first reading its rationale there;
don't file "exceeds 500 lines" findings for listed files. — 2026-06-22

### [UI/UX] Deliberate departures from the mockup
The following intentionally differ from the design mockup — do **not** file
"doesn't match mockup" findings for them:
- **Rating badge** is a green pill, not the gold from the mockup.
- **"Lagat idag" chip** stays in the recipe metadata row even though it's absent from the mockup (it's useful).
- **UNKNOWN allergen status** is intentionally hidden — only FREE and CONTAINS badges render.
- **Cream color scale** is left as-is, intentionally not realigned to mockup values.

**Why:** Each was a considered product/UX call recorded in project memory ("UI/UX Design
Preferences"). The mockup is a reference, not a contract, on these points. — 2026-06-22

### [Privacy/GDPR] notification_delivery counterparty is exported, not anonymised (BUT-1450)
The GDPR data export (`DataExportService`) includes the `notification_delivery` records' raw
counterparty identifier (`senderId` / `targetUserId`) **without anonymisation or redaction**.
A blind Privacy/DPO + Legal panel recommended stripping the counterparty UID; that
recommendation was **consciously overridden by Malin**.
**Why:** Art. 15(4) is a case-by-case *balancing* test, not a blanket "redact all third parties"
rule. Mainstream exports (Facebook, Google) include the counterparty so the subject sees their
own interaction data as they experienced it; the human-readable notification is already in
`notification_history` (joined via `notificationId`). The only thing deliberately *not* exported
is bulk UID→name resolution (cost). Do **not** file a "third-party PII / must redact `senderId`"
finding against the notification-export path — it is a decided product+legal call. (The narrow
exception the panel flagged — a counterparty in a notification the user never saw — does not
apply: all exported notification categories are user-facing.) — 2026-06-30

### [Tagging/Safety] Draft (AI-generated, unverified) ingredients may ground "fritt från X" verdicts
The 2026-07-01 register audit recommended that draft-status ingredients (54% of the register,
AI-generated, never human-verified) should not be able to prove FREE verdicts — only CONTAINS
or UNKNOWN. **Malin decided 2026-07-01: keep full verdict authority for drafts, including
FREE.** The existing draft-warning banner + the 87-row fix-list + register structural hygiene
are the accepted mitigations.
**Why:** Downgrading drafts to UNKNOWN-for-FREE would strip "fritt från" badges from most of
the app pre-launch; the register's structure is clean and the known-bad rows are being fixed
in the Sheet. Do not file findings proposing draft-status downgrades of FREE verdicts or
"drafts are unverified" warnings against the tagging pipeline — decided. — 2026-07-01

### [Ratings] Two accepted rare-edge behaviours in the pooled-ratings mirror CF (v1)
The Stage-A mirror (`functions/src/ratings/canonical-rating-aggregation.ts`) keys each pool
event by `poolKey` in the rater's `users/{uid}/canonical_rating_events` subcollection (doc-ID =
poolKey ⇒ free one-vote-per-user-per-pool). Two rare corners are **consciously accepted**; do NOT
file findings against them (the "correct" fixes each cost an unbounded per-delete read sweep,
which violates the cost-minimisation rule, and both corners are bounded to ±1 vote in a pool that
only displays at n ≥ 5 and self-heal on the user's next rating):
1. **Retraction of a shared-pool-backing copy.** If a user rates *two of their own* recipe copies
   that normalise to the *same* poolKey, they share one event doc (stamped with the last-rated
   recipeId). Deleting that last-rated copy removes the shared doc even though the other copy is
   still rated (or deleting the other is a no-op). Retraction is by stored `recipeId` (edit-proof —
   it must survive poolKey drift after a recipe edit, the common flow); the two-own-copies-same-pool
   case is the rare price. Do NOT propose recompute-the-key-on-delete — it breaks the common
   rate→edit→delete flow (recomputes the *new* dish's key and orphans the frozen event).
2. **Phantom re-pool from a rating touch after a recipe edit.** There is no `skipped_unchanged`
   gate (it was removed because it made a rating first cast while the account was immature never
   pool after maturity — a common miss, review finding #5). Consequence: if a user rates, then
   edits the recipe into a different dish, then touches the rating without changing the star, a
   fresh event is filed at the new dish's pool. Rare (needs all three, in order); the removed gate
   would cost the far more common immature-then-matured pool. **Why:** both fixes trade a rare ±1
   for either unbounded reads or a common systematic under-count. Decided at the 2026-07-03 xhigh
   review rework. — 2026-07-03
3. **No cost gate on unchanged rating writes.** Because the `skipped_unchanged` early-return was
   removed (edge #2), an incidental unchanged rating write (review-text edit, `updatedAt` touch)
   now pays a `users/{uid}/recipes/{recipeId}` read + a pool-event re-write. There is no cheap safe
   gate: skipping requires knowing an event already exists for this rating, which needs the poolKey
   (i.e. the recipe read) — so any gate that avoids the read reintroduces edge #2's #5 miss. The
   cost (one read + one write on a low-frequency action) is accepted over reintroducing a
   systematic pooling miss. Do NOT re-file "unchanged rating write does a redundant read/write." — 2026-07-03

### [Ratings] Pooled ratings have NO edit-triggered detachment (decision 6 superseded)
The pooled-ratings plan's draft decision 6 (`tasks/pooled-ratings-plan.md`) proposed a
recipe-write trigger that removes a user's contribution from the old pool when an edit changes
the recipe's poolKey, plus a one-time user notice. **Malin decided 2026-07-03: NO detachment.**
A rating is frozen to the pool of the dish it judged; editing a recipe never moves or removes a
past rating; the edited dish gets a rating only when the user rates it again.
**Why:** it is the pure form of decision 4 ("an edit never reclassifies past ratings"), simpler,
and strictly harder to game (you cannot remove your vote from a pool by editing). Do NOT file a
"missing edit-detachment trigger" / "recipe edit doesn't update the old pool" / "no one-time
detach notice" finding against the pooled-ratings code — the frozen-only behavior is the decided
design. (GDPR deletion still recomputes affected pools — that is unrelated to edits.) — 2026-07-03

### [Security/Age-gate] cook_snaps + activity_events create paths are intentionally NOT age-gated
The 15+ age gate (`isAgeCompliant()`) is applied to most UGC create paths in `firestore.rules`,
but the `cook_snaps` and `activity_events` create rules deliberately do NOT carry it. A blind
Security-Architect scan (role #4) flagged the omission; **Malin decided 2026-07-04: leave both
ungated — intentional.** Do NOT file a "missing age gate on cook_snaps/activity_events" finding
against `firestore.rules` (create paths ~1137-1153 and ~1230-1242).
**Why:** the age gate governs the account-creation boundary; these two paths are downstream
activity of an already-gated account and don't re-open the age surface. Decided scope call. — 2026-07-04

### [Privacy/GDPR] `socialFeatures` consent is intentionally NOT a gate — social runs on contract basis (BUT-1523 closed, honoring BUT-1395)
The `socialFeatures` field on `ConsentPurposes` (`lib/models/account/user_consent.dart`) exists but
gates NOTHING, and that is deliberate. BUT-1395 removed the social-features toggle from the consent
UI (`lib/views/account/consent_management_view.dart` ~L297) because social features (comments,
sharing, friends, ratings) run on the GDPR **contract** basis — they are part of the service the
user signs up for — not on consent. The field is kept only for Firestore back-compat
deserialization (and its viewmodel getter/setter round-trip stays test-covered for that).
**Malin decided 2026-07-11 (BUT-1523): close it — do NOT wire social writes to
`ConsentService.checkSafely(socialFeatures)`.** Wiring it would (a) re-introduce the
"misleading-consent" pattern IMY (Swedish DPA) has fined for, and (b) — because the consent
defaults FALSE and `checkSafely` fails CLOSED — block all social features for every existing user
until they flipped a toggle that no longer exists in the UI.
**Why:** a control shown as consent for something provided on a contract basis is the consent-theatre
anti-pattern; BUT-1395 already resolved the original "visible control does nothing" risk by removing
the control. Do NOT re-file "socialFeatures gates nothing / wire the consent gate / consent theatre"
against the consent model or social write paths — it is a decided product+legal call. — 2026-07-12

### [Privacy/GDPR] Account deletion does NOT cascade to parse_events — 30-day TTL residual accepted (BUT-1570)
The account-deletion cascade intentionally leaves `parse_events` docs (raw userId + sanitized
import URL) untouched; they self-delete via the Firestore TTL policy on `expireAt` (ACTIVE since
2026-07-16, backfill run the same day). A deleted user's parse events therefore persist at most
30 days after account deletion. **Malin decided 2026-07-16: accept the residual — do NOT wire
parse_events into the deletion cascade.**
**Why:** GDPR Art. 17 permits a reasonable erasure window; 30 days mirrors the accepted storage
noncurrent-version posture, and the cascade addition would be code + test surface for no
compliance need. Do NOT file "account deletion misses parse_events / add to cascade" findings
against the deletion path — decided. — 2026-07-16

### [Tagging/Safety] Weekly-menu presence does NOT scope menu generation (BUT-1611 → BUT-1625)
BUT-1611 added per-meal "who's home" presence to the weekly menu. It deliberately drives
**display, portions, and the who's-eating record only** — it does NOT feed the menu generator
a present-diner set to scope the candidate pool. A high-effort /code-review (2026-07-17) proved
that scoping generation by a present-diner union **narrows allergen filtering below the
whole-household baseline**: övrigt (snacks/baking) is eaten by everyone regardless of who's
present for lunch/middag, and single-section re-rolls reuse a stale union. On a children's
allergen app that is unacceptable, so generation always keeps the safe household-aggregated
filtering (BUT-1464). Safe present-aware generation (per-slot, övrigt-exempt, re-roll-fresh) is
deferred to **BUT-1625**.
**Why:** presence must never under-filter an allergen for a member who might eat. Do NOT file a
"presence should scope generation" / "presentUnionForGeneration missing" / "menu ignores who's
home" finding against the weekly-menu or generator code — it is a decided safety call. — 2026-07-17
