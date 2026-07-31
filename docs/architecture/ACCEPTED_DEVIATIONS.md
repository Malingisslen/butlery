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

### [Privacy/GDPR] Shared shopping lists export other members' UIDs but not their display names (BUT-1732)
The `shared_shopping_lists` Article-15 section (`SharedShoppingListExport`) exports a shared list
the requester owns, is a member of, or contributed rows to — including the whole `items` array,
`memberPermissions` and `contributorUserIds`, so every other household member's raw UID appears.
What it strips is the CACHED DISPLAY NAME of anyone other than the requester — all SIX that the
two models persist: `ownerDisplayName`, `lastActivityByDisplayName`, and each row's
`addedByDisplayName`, `purchasedByDisplayName`, `lastModifiedByDisplayName` and
`assignedToDisplayName`. The section states this in a `data_minimisation` field, so the count has
to be exhaustive or the bundle makes a false statement about itself; the first version enumerated
four and shipped the two that every tick of a shared list writes. `nameKeysByOwnerIdKey` is now
pinned against the models' own key sets by a test, so a new attribution field cannot be added
without appearing there.
**Why:** this is the BUT-1450 balancing call applied to a second surface, and it lands the same
way. A shared list is joint household data the requester can already read byte for byte inside
the app, so withholding the list or pseudonymising the counterparty would protect nobody and
would gut the subject's own shopping history; Art. 15(4) is a case-by-case balance, not a blanket
redaction rule. The cached display name is the one field that is purely another data subject's
profile rather than a record of the requester's own activity, and dropping it costs the bundle
nothing — the paired `*UserId` keeps every row attributable. Do **not** file "third-party PII —
must redact member UIDs from the shared-list export" against this path; and do not file "the
export should resolve UIDs to names for readability" either — that is the same bulk UID→name
resolution BUT-1450 declined on cost.
**Known gap, deliberate:** lists the requester has LEFT are NOT in the export. The
`contributorUserIds` probe that finds them is refused by `firestore.rules` (read requires
`ownerId == uid || uid in memberPermissions`), so only the Admin-SDK deletion cascade can reach
them. The section carries a plain-language `note` when the probe is refused — and only on an
actual `permission-denied`; any other failure gets neutral wording plus a
`contributor_probe_failed` flag, because an Art. 15 bundle may say it is incomplete but must not
invent WHY. Closing the gap itself needs a Cloud Function export path, not a client change —
tracked as **BUT-1747**. — 2026-07-30

**Decided by Malin, 2026-07-30 — this is a founder call, not an inherited one.** The paragraph
above originally justified itself by analogy from BUT-1450. The security review at ship refused
that analogy and escalated instead, on two grounds worth keeping: BUT-1450's verdict is scoped to
"the raw notification counterparty id" and records a HUMAN override, and this entry was authored
inside the very change it authorised — a deviation written by the same uncommitted diff it
permits is not prior approval. Malin was shown what leaves the device (every other member's raw
UID **and permission level**, the full `contributorUserIds` array — which by design names people
who have LEFT the list — and the per-row `addedBy`/`purchasedBy`/`lastModifiedBy`/`assignedTo`
UIDs, in a file the requester can forward anywhere) and chose to ship it unredacted. Accepted
rationale: the requester's own client can already read every one of those documents under
`firestore.rules`, so the export packages data they can already see rather than disclosing
anything new, and the export's four selectors deliberately mirror the deletion cascade's — the
Art. 15 "show me" side matching the Art. 17 "erase me" side. Display names are still stripped.

**Process lesson this produced:** a deviation entry authored inside the change it authorises is
not a decided call. Before treating an entry as prior human approval, check `git status` on the
deviation files, and check whether the entry it argues by analogy from actually records a human
override of its own.

### [Privacy/GDPR] The conversations export keeps other participants' display names but strips their avatar URLs (BUT-1772)
**Decided by Malin, 2026-07-30.** The `messages` Article-15 section exports each conversation's
whole document as `conversation_info`, which carries every other participant's raw UID, the
`participantDisplayNames` map, `lastReadTimestamps`, and the embedded `lastMessage` (its
`senderId`, `senderDisplayName` and `content`). What it now strips is every OTHER participant's
`participantAvatarUrls` entry, and `lastMessage.senderAvatarUrl` when the sender is not the
requester. The requester's own avatar stays — it is their data, and Art. 15 is a right to receive
it.

This is deliberately the OPPOSITE call to the shared-shopping-list entry above, which strips names
and keeps ids. The asymmetry is the decision, not an oversight, and it was made with both
sections on the table. A shopping row's cached `addedByDisplayName` is a denormalised copy of
someone's profile that the paired `*UserId` makes redundant — dropping it costs the bundle
nothing. A conversation is the opposite: strip the names and the section becomes a list of
opaque UIDs with no way to tell who said what, which fails the "concise, intelligible" limb of
Art. 12(1) while protecting a name the requester has seen in the app every time they opened the
thread.

**Why the avatar URL is the line, and the name is not.** A display name in a bundle the requester
already reads on screen discloses nothing new. An avatar URL is different in kind: it is a
durable, directly-dereferenceable pointer to another person's photograph, it survives outside the
app in any file the bundle is forwarded to, and it keeps resolving after that person leaves the
conversation or deletes their account. It also buys the requester nothing — nobody reads a JSON
export to look at a thumbnail. That is a clean Art. 15(4) balance: real cost to the other data
subject, no benefit to the requester.

Do **not** file "third-party PII — must redact participant names/UIDs from the conversations
export" against this path; that is the decided call. Do not file "strip the requester's own
avatar" either — withholding the subject's own data is the opposite failure.

**Scope note, so this entry does not read as broader than it is:** it governs `conversation_info`
and the message rows under it, and nothing else.

**Status changed 2026-07-30 (same day):** when this entry was first written the section had NO
production effect — the export read `conversations/{id}/messages`, a subcollection with no `match`
block in `firestore.rules`, so the catch-all `match /{document=**} { allow read, write: if false }`
DENIED the query and `exportMessages` failed the whole section as `messages-export-failed`.
**BUT-1767 repointed it** at the TOP-LEVEL `messages` collection keyed on `conversationId`,
removed the `recipientIds` filter that dropped every RECEIVED message, and fixed the
`orderBy('timestamp')` on a field no message document carries. The section now SHIPS, so this
verdict is live rather than unit-level only. Each message row carries its own
`senderDisplayName` and `senderAvatarUrl`, and the rule applies there too: `_dropOtherSenderAvatar`
strips another sender's avatar from every row and fails closed on an unrecognised shape.

**Fields this entry deliberately does NOT decide, listed so the record cannot be read as
exhaustive:** the conversation document's key set is not `ConversationDto.toFirestore()` — the
mutation module writes `perUserSettings.<uid>.<key>` by dot-path, and the DTO reads back only the
current user's sub-map, so the raw export would carry every other participant's `isMuted`,
`isPinned`, `isArchived`, `pinnedAt` and `archivedAt`. That is third-party BEHAVIOURAL data and the
keep argument above does not reach it — the client never renders another user's sub-map, so "you
have already seen it in the app" is false for it. Escalated to Malin as **BUT-1774**, undecided.

Because BUT-1767 turned this section from a hard failure into a shipping one, "undecided" would
otherwise have silently become "shipped". **Pending BUT-1774 the export narrows `perUserSettings`
to the requester's OWN entry** — the conservative default, not a verdict, and reversible in one
line. Nothing Art. 15 owes the requester is withheld: another member's mute/pin/archive state says
nothing about the requester. Pinned by a unit test in `social_export_manager_test.dart`.
Also kept and not separately argued: `lastReadTimestamps`, `lastMessage.reactions` (emoji → uids)
and poll `metadata.options[].voterIds` — all uids, so covered by the same balance as the
participant ids, but named here rather than left implicit.

**Fail-closed, by construction:** an unrecognised shape for either redacted field drops that field
wholesale and sets `redaction_fell_back: true`, rather than falling through to the untouched copy.
A redaction that silently no-ops on a schema it has not seen ships the data while the bundle's own
`data_minimisation` line claims it was removed, and nothing surfaces it. The `data_minimisation`
line states the DROP and does not enumerate the keeps, for the same reason the shared-list section
learned the hard way: a positive list that must stay exhaustive to stay true will stop being true.
— 2026-07-30

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

### [Security/Age-gate] SUPERSEDES the entry above — both creates ARE age-gated (resolved in favour of the code)
The 2026-07-04 entry directly above is **retired**. It states that `cook_snaps` and
`activity_events` creates are deliberately ungated; the code says otherwise and always did by
the time that entry was written:

- `cook_snaps` create — `isAuthenticated() && request.auth.uid == request.resource.data.userId && isAgeCompliant()`
- `activity_events` create — the same shape on `actorId`

Both carry an inline comment citing BUT-1418/ADR-0002, and four rules tests pin them:
`cook_snaps: owner without ageCompliant claim cannot create a snap`, `…with ageCompliant=false…`,
and the two matching `activity_events` denies. So the gate is enforced, tested, and was never
actually removed — the deviation entry was written against a stale view of the rules.

**Malin decided 2026-07-24: resolve as the code stands.** Both age gates are correct and
required. Do NOT file a "these should be ungated per the accepted deviation" finding, and do
NOT remove either gate citing the retired entry. If a future change genuinely needs to relax
an age gate on a UGC create path, that is a new decision requiring its own entry — not an
appeal to this one.

**Why the mistake mattered enough to record:** the stale entry sat in always-on context for
three weeks telling every session that a live child-safety control was intentionally absent.
It surfaced only because the file was being compressed. A decision record that describes code
is only as good as its last verification — when an entry names a specific rule or predicate,
check it against the file before relying on it. — 2026-07-24

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

### [Shopping/Offline] A shared-list EDIT made offline may still lose another member's concurrent edit (BUT-1665 → BUT-1683)
`ShoppingRepositoryRoutingModule.mutateCollaborativeList` writes through a Firestore transaction
that re-reads the live document — that is what BUT-1665 shipped. When the transaction cannot
reach a server inside its 8-second budget (`unavailable` / `deadline-exceeded`),
`_mutateFromCache` takes over. BUT-1683 split that fallback in two:
- **Appends are now safe.** A mutation that only adds rows is queued as `FieldValue.arrayUnion`
  on `items`, so the replay MERGES with whatever the household did meanwhile. Nothing can be
  lost on the add path any more.
- **Edits of an existing row (tick, amend, remove) still queue the cached base**, and that write
  replaces the whole `items` array on replay. If another member ticked a different item inside
  the same window, their tick is overwritten. **Accepted.**
**Why:** Firestore has no offline-replayable primitive for "change element X of this array" —
`arrayRemove` + `arrayUnion` is not atomic and loses the row if the replay half-lands, and a
transaction by definition needs a server. The only alternative is refusing offline ticks, which
breaks the app's core moment: standing in a shop with poor reception, ticking items off. The
window is narrow (offline device AND another member editing the same list at the same time), the
loss is a single tick rather than the list, and it is no longer silent — the write logs a warning
and BUT-1696 surfaces a rules-rejected replay distinctly in the audit trail. Do NOT file "the
offline fallback re-opens BUT-1665 / client-side merge forbidden by AC2" against
`_mutateFromCache` — decided. Revisit only if `items` becomes a map keyed by item id, which would
make per-row offline writes mergeable. — 2026-07-26

### [Tagging/Safety] A colon-terminated bare GLUTEN word stays an ingredient; other allergens keep colon-wins (BUT-1691 → BUT-1714)
`RecipeSectionDetector.componentSubHeadingLabel` is the single hinge that decides whether an
imported line is a component heading (pulled OUT of the flat ingredient list that tagging reads)
or an ingredient (kept). Its audited contract treats a trailing colon as a strong heading signal,
so a lone word plus a colon — "Deg:", "Fyllning:", "Mjölk:" — is a heading. BUT-1691 fixed the
unit guard's ASCII `\b` (which had matched the trailing `l` of "Kål" and `g` of "Råg" and thereby
kept those lines as ingredients *by accident*), and that correctness fix silently ENLARGED the
heading set to include "Mjöl:", "Vetemjöl:", "Råg:" and "Öl:" — four gluten sources.
**BUT-1714 decision (2026-07-27): carve gluten out. A bare gluten word plus a colon returns null
and stays an ingredient. Every other allergen — dairy, egg, soy, nuts — keeps the colon-wins
contract.** The word list is `HeadingWordLists.bareGlutenWords` plus an `endsWith('mjöl')` suffix
rule; it applies to single-word labels only, so "Till degen:" and "Mjölblandning:" remain
headings.
**Why:** the two errors are not symmetric. Import sources include OCR'd cookbooks where a
quantity routinely sits in another column, so "Mjöl:" is as plausibly a quantity-less ingredient
row as a group name — and reading it as a heading DELETES the gluten from the tagging input,
while reading it as an ingredient only adds a noisy row a user can clear. Gluten-only, not all
fourteen EU allergens, because gluten is where the "heading" reading is least plausible (no
Swedish recipe groups its components under "Råg:"); widening to dairy/egg/nuts would start
turning genuine component groups into phantom ingredient rows and needs its own evidence.
Do NOT file "this is inconsistent — Mjölk: should behave like Mjöl:" or "the gluten list is
incomplete" findings against `heading_word_lists.dart` — the asymmetry is the decision, and it is
pinned in `recipe_section_detector_test.dart`. — 2026-07-27
**Implementation constraint the decision depends on (2026-07-28, verified in code that day):** the
preserved row must be re-inserted COLON-STRIPPED, via
`RecipeSectionDetector.bareGlutenIngredientLabel`, at both re-insertion sites
(`swedish_line_classifier.dart`, `schema_org_tier.dart`). Ingredient lookup folds diacritics but
strips no punctuation, so a re-inserted "Mjöl:" queries `mjol:`, matches no registry document and
leaves the row unmatched — which drops lookup coverage below 1.0 and turns EVERY allergen verdict
on the recipe to UNKNOWN instead of resolving gluten to YES. Measured end-to-end both ways
(raw: coverage 0.5, gluten UNKNOWN; stripped: coverage 1.0, gluten CONTAINS) and pinned in
`swedish_line_classifier_test.dart`. Re-inserting the raw line looks harmless and is not; this
sentence is here because the code cannot say it out loud.
**Third re-insertion site added (BUT-1727, 2026-07-30):** the decision was only ever wired into the
URL/OCR tiers. `TextImportStrategy` — the pasted-caption / photo / voice path — ran its OWN
`_ingredientSubHeading` heuristic, which never consulted the shared list, so "Råg:", "Öl:" and
"Havregryn:" were still pulled out of the flat list on the real import path. It now calls
`HeadingWordLists.isBareGlutenWord` and re-inserts the row colon-stripped like the other two sites.
Two extra facts that path forced and that a future reader will otherwise re-discover the hard way:
refusing the heading is NOT sufficient there (the rescued word is short enough that
`isValidIngredient` drops it as an orphan fragment and `isGarbage` reads it as a section header, so
the row must be added explicitly and exempted from those two filters), and the rescue is
colon-terminated-only — a colon-less bare "Mjöl" keeps its long-standing orphan-fragment handling,
because the decision above is about the colon form. **Corrected in review, 2026-07-30 —** an
earlier draft of this paragraph said "Mjöl:" was "already surviving by accident on this path". That
is true of the HEADING heuristic only and false of the outcome: `looksLikeIngredient` does list
"mjöl", so `_ingredientSubHeading` already refused it as a heading — but the row was then dropped
anyway by `isValidIngredient`'s orphan-fragment rule (`recipe_section_detector.dart:308-312`:
"Mjöl:" is 5 characters, single token, no digit). It never reached the flat list. The carve-out is
therefore a strict improvement here, not the replacement of a working accident. The row that does
ride through colon-and-all is the 6-character "Mjölk:", which is the decided BUT-1714 asymmetry.
**Third filter the rescue must survive (added in review, 2026-07-30):** `_deduplicateIngredients`
also replaces a shorter ingredient NAME with any longer one CONTAINING it. A rescued row is a bare
stem, so "potatismjöl" swallowed "Mjöl", "bovetemjöl" swallowed "Vete" and "majskorn" swallowed
"Korn" — every swallower gluten-FREE, so the recipe lost its only gluten row and could resolve
FREE. Rescued rows are therefore exempt from the CONTAINMENT branch in both directions, but not
from exact-name dedup ("Råg:" still collapses into "2 dl råg"). Do not "simplify" that back to one
exemption flag covering the whole loop.
