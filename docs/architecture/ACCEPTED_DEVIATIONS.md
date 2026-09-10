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

### [Privacy/GDPR] The conversations export keeps other participants' display names and read timestamps, strips their avatar URLs and notification settings (BUT-1772 / BUT-1774 / BUT-1775)
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

**Scope note:** it governs `conversation_info`, the message rows under it, and — since **BUT-1775**,
which is this same decision applied consistently rather than a reopening of it — the
`shared_recipes_received` / `shared_menus_received` rows, whose `shared_content` documents carry
`sharedByAvatarUrl`: when a friend shares a recipe with you, their profile-picture URL landed
verbatim in your bundle three sections below the one that had just been fixed. All three sites now
go through ONE helper (`_dropAvatarUnlessOwn`), because a second copy of the logic is exactly how
two sections implementing one verdict drift apart. Nothing else is governed.

**Extended 2026-08-01 (BUT-1798).** `shared_shopping_lists_received` was added to the export the
same day and routes through that same helper, so the avatar strip now covers all three
`shared_content` content types. Still one helper, for the same reason.

### [Privacy/GDPR] The `shared_content` export keeps other recipients' UIDs and the sharer's display name (BUT-1798)

**Malin's explicit call, 2026-08-01**, taken on its own merits and NOT by analogy.

**What she was shown**, for one row: the other recipients' UID list, the sharer's
`sharedByDisplayName`, the shared item's title, the share timestamp, and `sharedByAvatarUrl`
already stripped by the entry above. She chose to keep the UIDs and the name.

**Reasoning.** The requester's own client can already read every one of these documents under
`firestore.rules` :720-728 — they are in `sharedToUserIds`, which is what grants the read. So the
export discloses nothing the app does not already hand them. Stripping the sharer's name would
leave an opaque UID and fail Art. 12(1) intelligibility, the same argument that carried BUT-1772.
Scoped to rows where the requester is a RECIPIENT.

**Both spellings are named deliberately.** The writers emit the same recipient list twice, as
`sharedToUserIds` and `sharedWithUserIds`. An entry naming only one invites a future reviewer to
strip the other "for consistency" and call it a tidy-up.

**Explicitly not derived from BUT-1732 or BUT-1772.** BUT-1732 decided a different collection and
DROPPED other members' display names; BUT-1772 decided conversation participants. Citing either as
authority for this question is the exact error the BUT-1732 entry records having made, and this
entry exists partly so nobody repeats it.

### [Privacy/GDPR] Inside a shared shopping list's nested copy, other members' names are stripped (BUT-1798)

**Malin's explicit call, 2026-08-01.**

A shopping-list share embeds a whole copy of the sender's list under `listData`, so the section's
top-level avatar strip never reached inside it. That nested copy carries `memberPermissions` keyed
by uid, `ownerId` / `ownerDisplayName`, `lastActivityByUserId` / `lastActivityByDisplayName`, and —
per item — three uid + displayName pairs (`addedBy`, `purchasedBy`, `lastModifiedBy`).

**Verdict:** other members' UIDs and permission levels are KEPT; their display names are STRIPPED;
the requester's own name is KEPT so they can recognise their own entries.

**Why this follows BUT-1732 and not the entry directly above it.** This is the same class of data
seen from the same angle — a shopping list controlled by someone else — which is precisely what
BUT-1732 decided. The entry above governs the sharer's single name on the wrapper document, not a
roster of everyone who ever touched the list. The asymmetry between the two is the decision, not an
oversight; do not "harmonise" them.

The walk fails CLOSED: a display-name field whose paired uid field is missing or unrecognised is
dropped rather than passed through.

**Correction, same sprint — the MENU half of that sentence was not true when it was written.**
BUT-1775 shipped the redaction on `shared_menus_received` and this record asserted a leak there as
fact, but `exportSharedMenusReceived` was reading the top-level `menus` collection filtered on
`sharedToUserIds` — a field `SharedMenu.toFirestore()` does not emit, on documents that never carry
`sharedByAvatarUrl` either. Real shared menus are `shared_content` documents with
`contentType: 'menu'`. So the section had never returned a single row: nothing leaked, and nothing
was redacted. The query is now repointed at `shared_content`, which makes the claim above true
going forward and closes an Article-15 gap (shared menus were missing from the bundle entirely) —
but the record must not read as though the redaction had ever fired. This is the wrong-path-read
class in `.claude/rules/lessons-digest.md`: a syntactically perfect query against a collection or
field nothing writes throws nothing and returns empty, and an empty export section looks normal.

**Related, found in the same pass:** `shared_content` carried membership under TWO field names —
`sharedToUserIds` (written by `BaseSharedContentRepository`, and the only spelling
`firestore.rules`' recipient branch at :722/:727 recognises) and `sharedWithUserIds` (written
directly by `recipe_sharing_manager.dart`, `social_menu_operations.dart` and
`shopping_social_share_module.dart`). Documents written the second way were unreadable by their own
recipients — a recipient's `list` is evaluated against `sharedToUserIds` and denied — and therefore
unexportable. All three direct writers now emit both fields; the export reads the rules-sanctioned
one. Documents written before that fix carry only `sharedWithUserIds` and no client query can reach
them at all; a backfill, not an export change, is the remedy.

**Same sweep, BUT-1775's side-finding:** both writers of those documents
(`recipe_sharing_manager.dart`, `social_menu_operations.dart`) took the name from
`PermissionService.currentUser`, which is synthesized straight from `FirebaseAuth.currentUser` —
the legal name on the user's Google/Apple account. Both now use `UserService.profileDisplayName`
(the BUT-1705/BUT-1736 class): the profile name is what `on-profile-updated.ts` renames and what
account deletion scrubs, so an Auth-sourced stamp on a document every recipient reads would be
both unconsented and un-erasable. **The default MENU TITLE (`menuDefaultTitle`) was left behind in
that pass and is now fixed too** — it reads as content rather than attribution, which is exactly why
it was missed, but it is persisted on the same document, rendered to every recipient, exported
verbatim, and `on-profile-updated.ts` does not rename titles, so it was the one copy neither the
rename propagator nor the deletion cascade could ever reach.

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

**The two fields this entry left open are now decided — DIFFERENTLY (BUT-1774, Malin,
2026-07-30).** The conversation document's key set is not `ConversationDto.toFirestore()`: the
mutation module writes `perUserSettings.<uid>.<key>` by dot-path
(`conversation_mutation_module.dart:416-441`) while the DTO reads back only the current user's
sub-map, so the raw export would carry every other participant's `isMuted`, `isPinned`,
`isArchived`, `pinnedAt` and `archivedAt`.

- **`perUserSettings` for other participants is STRIPPED.** It is pure third-party behavioural
  data that the client never renders for anyone but yourself, so the argument that carried the
  display names — "the requester has seen this on screen every time they opened the thread" — is
  simply false for it. Nothing Art. 15 owes the requester is withheld: another member's
  mute/pin/archive state says nothing about the requester.
- **`lastReadTimestamps` is KEPT.** Zero hits in `lib/views/` and `lib/widgets/`, so it is not
  rendered either — but the app already shows *that* someone read your message via
  `MessageStatus.read` in `message_status_widget.dart`, just not the clock time, and the timestamp
  describes the thread's progression as much as the other person. Weak but real counterpart, and
  it sits inside the requester's own thread history. **Do not propose stripping it "for
  consistency" — the asymmetry between these two fields is the verdict.**

The line is drawn where it does the most good and the least harm. Both halves are pinned by unit
tests in `social_export_manager_test.dart`, in both directions, so neither "strip more" nor "ship
more" can drift in unnoticed. Also kept and not separately argued: `lastMessage.reactions`
(emoji → uids) and poll `metadata.options[].voterIds` — all uids, so covered by the same balance
as the participant ids, but named here rather than left implicit.

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

### [Privacy/GDPR] Feature-retention DAILY AGGREGATES keep a deleted user's contribution; the per-user rows are erased (BUT-1789)
`compute-feature-retention.ts` writes two things per run. The per-user-per-day rows,
`analytics/feature_retention/users/{uid}_{yyyy-mm-dd}`, carry a live uid and a behavioural
profile of that person's day (cooked / imported / shared / meal-planned / shopped) — those
are personal data, and **as of BUT-1789 the deletion cascade erases them**
(`deleteFeatureRetentionFlags`, tier 1, with a matching `probeResidualData` leg on the same
`userId == uid` handle). The daily aggregates, `analytics/feature_retention/daily/{date}`,
are **NOT touched and are NOT recomputed** when an account is erased: the counts a deleted
user contributed stay in every historical `dau` / `wau7d` / `wau28d` figure.
**Why:** an aggregate row holds five integers and a date. It carries no uid, no pseudonymous
key and nothing that singles anyone out — there is no personal data left in it to erase, so
Article 17 does not reach it, and the trailing-window rollups shed the user naturally within
28 days as the window advances. Recomputing history instead would mean re-reading every
deleted user's rows to subtract them — the exact documents Article 17 just required us to
destroy — or rewriting up to 28 aggregate docs per deletion for a number nobody can attribute
to a person. The residual is deliberate, not a gap in the cascade.
**Also decided here: NO TTL on the per-user rows.** They live in the subcollection
`analytics/feature_retention/users`, whose collectionGroup id is `users` — the same id as the
top-level profile collection — so a TTL fieldOverride on that collectionGroup would arm a
delete policy over real user documents. The cascade step is the only safe erasure route here;
a TTL must not be proposed as a "simpler" substitute. — 2026-08-01

### [Tagging/Safety] An unreadable household member WIDENS the allergen union with a common-allergen floor instead of being skipped (BUT-1663)
`HouseholdService._aggregatePreferences` resolves every household member's profile. When a
read FAILS (`ProfileLookupStatus.unavailable` or `foundSettingsUnavailable`), that member is
**not** dropped from the aggregate: the union keeps every allergen that DID resolve, adds
`UserAllergenPreferences.defaults.trackedAllergens` on top as a floor, and closes the UNKNOWN
escape hatch (`includeUnknownInMenu: false`) so only recipes proven free reach the menu. The
same floor is the whole answer on the two total-failure paths (aggregation threw, roster
resolved to no members) and for a member whose profile loaded without its private settings
sub-doc (`settingsMerged == false` — always the case for another account holder, since
`firestore.rules` lets only the owner read that doc). The result is a **superset** of the
household's real preferences: some recipes are hidden from a household nobody in it is
allergic to.
**Why:** the alternative — skipping the unread member — silently filters as if they had no
allergies, which on a children's allergen app is the one failure mode that can hurt someone.
Over-filtering costs dinner variety for as long as the read keeps failing; under-filtering
costs a reaction. The floor is deliberately a WIDENING and never a replacement, so a member
who did resolve never loses an allergen to it. The degradation is not silent: the aggregate
carries `isRosterComplete: false` and `unresolvedMemberIds`, the service logs a warning, the
allergen opt-out dialog appends `householdAllergenRosterIncomplete`, and — since **BUT-1685** —
the generated menu shows that same warning instead of the healthy-run "familjens allergier"
attribution. A profile that simply does NOT exist (`ProfileLookupStatus.missing`) is the
opposite call and does **not** degrade the roster: nobody is at that seat to protect, and
treating a stale roster entry as unknown-forever would hold the household in a safety crouch
it can never leave. Do NOT file "unread members should be excluded from the union", "the floor
over-filters", or "the fallback should trust the resolved members only" — decided. BUT-1693
(part 2 — members sharing their own allergen list) is what makes the guess unnecessary; until
it ships, the floor is the only protection this household has. — shipped 2026-07-26, recorded
here 2026-08-11 (BUT-1685)

### [Tagging/Safety] The common-allergen floor is now CONDITIONAL on opt-in (BUT-1663 → BUT-1693)
Supersedes the "unreadable member widens with the floor" entry ABOVE on one point only, and
leaves the rest of it standing. As of 2026-08-12 a household member can share their own
allergen list (`household_allergen_shares`, Art. 9(2)(a) consent). Where a share exists,
`HouseholdService` uses the member's REAL list and does not add the floor on top — adding it
would put four allergens back that the member has told the household they do not have.
**Three parts of the old rule survive on purpose:**
- a member who has NOT shared is unchanged: floor, exactly as before;
- a member whose profile READ FAILED (`unavailable` / `foundSettingsUnavailable`) still
  degrades the roster **even when they shared**. Their share contributes what it knows, but
  it does not cancel the degradation: until the settings edit and the share move in one
  atomic write (DPIA R4 — not built), a share can lag behind the list its owner has already
  changed, so it is evidence rather than proof that this member is known;
- the signed-in user is never read from a share. Their own device reads their real settings,
  and no document written about them may stand in for that.
**Why:** the floor exists because the app could not read another adult's allergies at all.
Where it now can — because that adult chose to be read — guessing is strictly worse than
knowing: it misses the allergens they actually have (egg, shellfish) and invents four they
may not. **Also decided: a switched-off feature is knowledge, not an outage.** With
`enable_household_allergen_sharing` false, `_sharedListsByMember` returns an EMPTY map
rather than an unknown one, so a household where nobody could possibly have shared is not
reported as incomplete — but a share read that FAILS while the flag is on returns null and
does degrade, because someone may have shared a list the menu is now filtering without.
Do NOT file "the floor is missing for member X" without first checking whether X shared.
— 2026-08-12

### [Tagging/Safety] The safety floor takes allergens only — `trackedDietary` is deliberately NOT inherited from the defaults (BUT-1663)
`HouseholdService._allergenSafetyFloor` is `UserAllergenPreferences.defaults.trackedAllergens`
and nothing else. `defaults` also carries `trackedDietary: {vegetarisk, vegansk}`, and every
floor-applying path above passes `dietary: unionDietary` (or `const {}`) rather than folding
the defaults in.
**Why:** the menu's dietary filter treats a tracked diet as a **hard requirement**, not a
warning. Inheriting the defaults would restrict an omnivore household to vegan dishes the
moment one profile read failed — that is not a safety property, it just empties the menu, and
an empty menu teaches the user to switch the household filter off entirely, which removes the
real allergen protection with it. Widening the ALLERGEN set only ever removes dishes that
might hurt someone; widening the DIETARY set removes dishes nobody objects to. Do NOT
"harmonise" the floor with `defaults` or file "the floor drops the default dietary
restrictions" — the asymmetry is the decision. — shipped 2026-07-26, recorded here 2026-08-11
(BUT-1685)

---

## The free on-device OCR tier ships ON despite losing the measured comparison — 2026-08-03

**Verdict.** `enable_on_device_ocr` is TRUE in production even though the corrected corpus
eval scores the free on-device reader BELOW the paid chain. Malin's explicit call.

**The numbers.** 39 verified recipes across 21 cookbook pages, gold-token recall, both arms
given identical production preprocessing: on-device **96.1**, paid chain **96.6**. Measured
again after the corpus grew from 27 recipes to 39 — and the gap WIDENED, 0.3 -> 0.5. Three
consecutive runs all put the on-device reader behind (-0.3, -0.3, -0.5), so this is a small
consistent deficit, not noise waiting to average out. That is a stronger reason to keep the
paid chain behind the tier than the first, thinner measurement gave. The plan
(`tasks/butlery-ocr-sites-plan.md`, step A3) set the gate at "at least as good as the paid
chain on the same pages". 96.1 < 96.6, so the gate is **not met**. (This read "96.1 < 96.4"
until 2026-08-08. 96.4 is the paid chain's PRE-CORRECTION figure, which the history
paragraph below identifies as artifact-tainted — the comparison must use the corrected 96.6
recorded above, or the two halves of this entry contradict each other.)

**Why it ships anyway.** Half a point of recall, on a metric where both arms sit above 96.
The on-device reader still wins outright on several pages and loses on others. Against that, every photo import currently costs a paid
call, the free tier works offline, and the image never leaves the phone. Malin judged the
quality difference not worth paying for. That is a product call about an economics/quality
tradeoff, which is hers to make; the engineering position (the gate as written) is recorded
above so the override is visible rather than implied.

**What protects the user anyway.** The tier is not a replacement, it is a first pass. A read
that fails either accept gate — the recipe heuristic or the same `confidence >= 0.6` bar every
paid provider must clear — falls straight through to OCR.space → Vision → Tesseract exactly as
before. So the failure mode of a bad on-device read is a paid call, not a bad recipe.

**Do not flip it off citing the gate.** The gate was overridden knowingly, with the numbers on
the table. A future session that finds 96.1 < 96.6 and "fixes" it would be re-litigating a
decided call. Legitimate reasons to revisit: a materially larger gold corpus showing a real
gap (75 more prelabelled pages are available), a user-visible regression in photo import, or
a new ML Kit version worth re-measuring. The re-measure is
`integration_test/ocr_engine_comparison_test.dart` on a device and takes minutes.

**History worth keeping.** The first measurement of this same comparison reported 96.6 vs 96.4
and was used to switch the flag on. It was wrong: the harness fed the recognizer raw photos
while production preprocesses first, and the paid arm it compared against had been captured
through that preprocessing. The artifact was larger than the margin. The harness was fixed and
the eval re-run before this decision was taken.

### [Engineering] `shared_content` membership collapses to one field — supersedes the dual-spelling clause (2026-08-03)

**Supersedes**, in part, the BUT-1798 export entry: the clause reading *"Both spellings are
named deliberately — the writers emit the same list twice, and an entry naming one invites a
future reviewer to strip the other 'for consistency'."* That clause was written precisely to
stop this change being made casually. It is not being overruled casually.

**What changed.** `shared_content` documents now carry the recipient list once, as
`sharedToUserIds` — the field `firestore.rules` grants recipient read on (:722, :727), the
Art. 15 export selects on, and the Art. 17 cascade scrubs.

**Why the earlier reasoning no longer holds.** It rested on a premise: that documents exist
which only the retired spelling can reach, so dropping it would strand them. **Malin,
2026-08-03: the project holds only TEST recipes.** There is no such corpus. The compatibility
field was protecting nothing, while costing a union query in the deletion cascade, a second
residual probe pair, a `legacyOnly` counter, and a standing risk that the two copies disagree
— which they did, producing both an Art. 15 export gap and an un-erasable uid.

**What the collapse actually involved.** Not a deletion. The plan initially recorded the
retired field as write-only; a grep before implementation found **eight readers**, three of
them access checks (`social_menu_operations.dart:330`,
`shopping_social_share_module.dart:292` and `:381`). Deleting the write without repointing
those would have silently denied people access to menus and lists they could legitimately
see. All were repointed.

**The trap, recorded so it is not rediscovered the hard way.** `sharedWithUserIds` remains
the legitimate and sole membership field on an unrelated collection: `recipe_comments`
(`firestore.rules:1247`, BUT-458, plus `recipe_comment.dart` and
`firebase_comments_repository.dart`). A repo-wide rename would silently break who can read a
comment. Scope by COLLECTION, never by field name.

**Consequence for the backlog.** BUT-1809 — the one-off backfill to rescue legacy
`sharedWithUserIds`-only documents — is moot for the same reason this entry exists: there is
no legacy corpus. Close it rather than running it.

### [Safety and privacy] Group revoke keeps a member who also has a direct share (2026-08-04)

**Malin's decisions, 2026-08-03, all three settled before implementation:**

1. The feature is wanted: share to a group, and be able to take that share back.
2. A member who ALSO has a direct share **keeps access** when the group is revoked.
3. A group share is a **snapshot**: it reaches whoever is in the group at that moment.
   Adding someone to the group later does not silently grant them access to recipes shared
   before they joined.

**Why the feature could not be built before.** Access lives in
`socialData.memberPermissions`. A group share expanded the group into individual entries and
recorded nothing about where each entry came from, so a member reached through the group was
indistinguishable from one invited directly. "Remove the group's members" would have silently
cut people who were invited individually. The honest interim behaviour was to drop the display
label only, and to say so in the UI copy — a privacy control that lies is worse than one that
visibly fails, because the user stops looking.

**The provenance.** `RecipeSocialData.grants` maps uid -> `['direct', 'group:<categoryId>', ...]`.
Per-member rather than per-group, because revoking has to answer *"does this person still have
any reason to be here?"*, and that is a question about a member.

**The invariant that keeps this safe.** `grants` is descriptive. `memberPermissions` remains
the sole source of truth for access, `firestore.rules` reads only that, and no rules change was
needed — which is the point: the access model is untouched, so this cannot open a hole.

**The asymmetry is the decision.** Revoking a group removes only that group's reason; an
explicit "remove this person" drops the member's whole entry, every grant included. Leaving a
stale group grant behind after an explicit removal would make a later group-revoke look like it
had already run. Do not "harmonise" the two paths.

**No compatibility path, deliberately.** A missing `grants` is NOT read as "everyone is
direct". Such a document loses only its label on a group revoke. The field is written from the
start and the only documents without it are test data (Malin, 2026-08-03), so the tolerance code
would be dead the day it shipped.

**Three things the implementation found that the plan had not.**

- `GroupRecipeSelectionViewModel.shareSelectedRecipes` never passed `categoryIds` at all, so
  the group id was not merely dropped downstream — it was never supplied. Fixed at the source.
- `UnifiedRecipeService.createCollaborativeRecipe` accepted `categoryIds` and silently dropped
  it, along with `descriptionCollaborative`, `allowGuestViewing`, `allowMemberInvites`,
  `imageUrls`, `mealType`, `rating` and `sourceUrl`. Only `categoryIds` is fixed here; **the
  rest are still dropped** and are not covered by this entry.
- Re-sharing an ALREADY-collaborative recipe wrote only the `shared_recipes` row and sent
  notifications — the new people were never added to `memberPermissions`, so they were told
  about a recipe they could not open. Granting a recorded reason for access that does not exist
  would be meaningless, so `_grantAccessOnReshare` now writes the permission entry too. Members
  already present keep the permission they hold: a re-share must never silently demote an editor.

**There are TWO group-share paths, and both had to be fixed.** The plan named only
`GroupRecipeSelectionViewModel`. `UniversalShareDialogViewModel` reaches
`SocialRecipeSharingService.shareRecipeWithGroups`, an entirely separate implementation that
also recorded no provenance — so a group share would have been revocable or not depending on
which dialog the user happened to open. Found by grepping for the sibling by NAME rather than
trusting the plan's file list; the repo's own lesson about twin classes is what prompted the
grep.

That path needed one extra piece of care: it resolves every group to a union of member ids and
then shares once, which throws away which group each person came through. The attribution is
captured before the union, so a member reached via two groups carries both tokens and survives
either one being revoked.

**The commit gate caught eight defects this plan and its author did not.** Nineteen reviewers
across three specialists read the staged set; six of them independently found the same one.
Recorded because the pattern is the lesson, not the individual bugs:

- **`updateMemberPermission` deleted `grants`.** Three of four `RecipeSocialData` rebuilds in
  that file were updated; the fourth enumerated seven of eight fields. The document is written
  whole, so the field was DELETED, not left alone — one permission change disarmed the revoke
  for the entire recipe, which then cut nobody and reported success. Fixed by rebuilding through
  `copyWith`, which cannot drop a field it never enumerates.
- **A THIRD membership path.** `SocialRecipeMembershipService` add/remove is a sibling to the two
  group-share paths this ticket fixed, and was missed. Its add recorded no grant — so a member
  invited there and later swept into a group share would be CUT by revoking that group, the one
  outcome the decision above forbids. Its remove left a stale grant.
- **The creator was granted, and demoted.** Every friend category contains its own owner, and the
  group-share caller passes the roster straight through — so `initialMembers` contains the
  creator on the ORDINARY path. The loop overwrote their `admin` with `editor` and recorded them
  a revocable grant, while the comment above it claimed the opposite.
- **Three of my own tests were weak or false:** a snapshot test asserting the absence of a uid
  present in neither input map (structurally unfailable), a comment claiming one assertion caught
  a revert in both directions when it caught one, and a `_grantAccessOnReshare` recorder installed
  in the test setup and never asserted on — so that half of the ticket could have been deleted
  with every suite green.
- **The Swedish copy was not idiomatic:** a stranded possessive, a singular subject for what is
  usually several people, and a `{name}s` genitive that breaks on group names ending in s/x/z.
  Both strings now also carry the carve-out at the DECISION point, not only in the snackbar —
  the panel's own rule is that a snackbar cannot undo a promise already made.

**Three review rounds, and each one found more writers of the same field.** This is the part
worth keeping, because the lesson is not any individual bug:

- Round 1 found the field-by-field rebuild that DELETED `grants` (six reviewers, independently).
- Round 2 found a third membership path that recorded none, and the creator being granted and
  demoted on the ordinary path.
- Round 3 found three more — a remove that left a stale grant, and two methods named *update*
  that will happily CREATE a member with no reason recorded. A member created that way is later
  cut by revoking a group they were swept into: the one outcome the decision above forbids.

Each round I believed the list was complete. A comment shipped in round 3 saying "the sixth and
last membership writer" was falsified 25 lines below itself, in the same file. The enumeration
that actually closed it was a reviewer walking EVERY writer of `memberPermissions` in `lib/` and
tabulating them — nine sites, of which two legitimately need no grant write because they refuse
non-members. If a tenth is ever added, it must maintain `grants` too; the invariant is
"`grants` never contains a uid absent from `memberPermissions`", and the reverse is normal
because access can come from ownership.

**Deliberately left, recorded rather than silently dropped:**

- `lib/models/realtime/recipe_serialization.dart` holds a SECOND, hand-rolled `RecipeSocialData`
  deserializer that never learned `grants` (it also already mis-reads `descriptionCollaborative`).
  **Corrected 2026-08-05.** This entry originally said "no live path round-trips a
  collaborative recipe through it". That was asserted, not traced, and a whole-range
  reviewer found one: `firebase_sync_manager.dart:225` deserializes every
  `realtime_recipes` document through this file and hands the result to
  `onRecipeUpdated`, which lands it in the same in-memory list
  `RecipeMemberManager._getRecipes()` reads.

  The write-back is NOT the open question — that half is proven:
  `RecipeMemberManager` writes whatever `_getRecipes()` returns, whole, through
  `saveRecipeForSocialModule`. The genuinely unproven step is one earlier: whether a
  `realtime_recipes` document ever exists for a recipe that ALSO lives under
  `users/{uid}/recipes` carrying `grants` — i.e. whether the grants-less copy can
  shadow the grants-bearing one in that list. That is a data question, not a code
  one, and it is what the ticket should be scoped to.

  Failure direction: fail-safe for ACCESS — a missing `grants` makes a revoke drop
  the label and cut nobody, never the reverse. But not fail-safe for honesty. Since
  BUT-1797 the snackbar on that path reads "Gruppen {name} har inte längre åtkomst
  till receptet", so it asserts a revocation that did not happen. Under BUT-1785 the
  same no-op said the opposite, which is what made failing visibly honest.

  So: still deferred, but on "not proven to round-trip", NOT on "no live path".
  Scope the ticket to that sync path. Do not cite the original wording to close it.
- **A revoke does not trim `shared_content.sharedToUserIds`.** A revoked member loses the recipe
  document but keeps the discovery row — title, description, image — and its Art. 15 export line.
  Pre-existing for `removeMember`; this ticket makes it more visible because the copy now promises
  a revocation. Needs a decision, not a unilateral fix.
- **RULED 2026-08-05 — `grants` never reaches `shared_content`, and the premise of the earlier
  bullet was simply wrong.** Two independent barriers, traced rather than assumed:
  `SharedRecipe.create` takes `recipeSnapshot` but reads only five scalars off it and never
  passes it to the constructor, so `_recipeSnapshot` is null on that path; and
  `SharedRecipe.toFirestore()` — which is what `BaseSharedContentRepository.createSharedContent`
  actually writes — emits no snapshot key at all. Only `toJson()` does, and its one caller is a
  local device cache on a device that can already read the recipe.
  I had recorded this as an open security question on an unverified claim. It was never true.

  **The surface that DOES exist, and the ruling on it: acceptable.** `grants` is persisted on the
  recipe document, which `firestore.rules:360-363` opens to every uid in `memberPermissions`, and
  Firestore has no field-level read control. Acceptable on two verified grounds: `memberPermissions`
  (every co-member's uid) and `categoryIds` (the group-id set) already sit on that same document for
  that same audience, so the only new information is the partition; and `firestore.rules:2213-2216`
  grants `friend_categories` read only to someone already in that group's `friendUserIds`, so a
  recipient can dereference `group:<categoryId>` to a NAME only for groups they are already in —
  where they can already read the whole roster. Every other token is an opaque UUID.

  **EXPIRES if a category NAME is ever denormalized onto `socialData`** (e.g. for the sharing
  panel). The ruling rests on that opacity; adding names lapses it and it must be re-decided.

- **A second copy of an already-unerasable uid, recorded so it is fixed in one edit when the time
  comes.** No cascade step scrubs a deleted user's uid from ANOTHER owner's recipe —
  `deleteRecipes` is own-scoped, and the `memberPermissions.${uid}` sweeps target top-level
  collections, not `users/{other}/recipes/{id}.socialData`. So a foreign uid already survives
  erasure there, and `grants` now holds a second copy in the same document, same audience, no new
  collection or reader. When that pre-existing gap is closed, the scrub must drop `grants` in the
  SAME `update()` — the repo's own "one fact, two spellings" rule.
- The three copies of the (memberIds, groupIds) → tokens loop agree today. The
  `categoryIds` write beside them did NOT: two sites merged the raw argument while
  `mergeCategoryIds` derives from the grants actually written, and they diverged on a
  reachable input (a group whose roster is only the sharer). Fixed 2026-08-05 at both
  sites. Pinning lagged the fix by one commit: the re-share site was pinned
  immediately, the CREATE site — the ordinary path, since a first-time group share of
  a personal recipe never reaches the re-share branch — shipped unpinned, and a
  whole-range reviewer measured that mutant leaving 162 tests green. Both are pinned
  now. The tokens-loop collapse is still owed. Collapsing them into
  `RecipeShareGrants` is right and is its own change, not a fix round for a failed gate.
- The group-share success snackbar reports "0 recept delade" — `clearSelections()` runs before the
  count is read. Pre-existing and unrelated to provenance.
- `FirebaseRecipeRepository.addCollaborator` / `removeCollaborator` are not on the
  `RecipeRepository` interface and have ZERO callers in `lib/`. They were brought in line with the
  invariant anyway, because a writer that ignores it is how the next caller reintroduces the
  split — but the better end state is deleting them, and a test would only pin dead code and make
  that harder. Ticket the deletion. **`RecipeFactory.convertToCollaborative` belongs to the same
  ticket:** it builds members from `initialMembers` with no way to supply grants, and likewise has
  zero `lib/` callers. Its two siblings (`createCollaborative`, `Recipe.collaborative`) are safe
  because the one live caller passes an empty member map and sets members and grants together in
  the same `copyWith`.

**Not done, stated rather than implied.** The panel renders one row per group, as before, but
without a member count ("Familjen (4 personer)" in the plan). Cosmetic, and the count is not
available where the row is built.

## Column ordering for on-device OCR — measured and declined (2026-08-07)

**Decision: do not build it.** Step 8 of the layout plan proposed sorting a photographed
page's lines into reading order (left column fully, then right) before splitting. The plan
already flagged it as the one part of that work that could regress a path already working,
and guessed it might prove unnecessary because ML Kit groups lines into `TextBlock`s.

**Every figure below is a PROXY.** The stored geometry is `layout-winocr.json` — Windows'
offline recognizer, chosen because it runs on a dev machine — so these numbers describe
that engine's line ordering, not ML Kit's. `corpus_paths.dart` says as much where the file
is named, and step 6b's record carries the same label.

That matters for the plan's actual hypothesis, which this does NOT settle: ⑦ guessed ML
Kit's `TextBlock` grouping might already emit a two-column spread column-wise, and
`device_text_recognizer_mlkit.dart` really does flatten blocks in order. **ML Kit's
ordering remains unmeasured** — it needs a device, which is the plan's own open question
#1. The decision below does not rest on it.

**Interleaving is real in the proxy.** Over the 250 stored captures, 208 pages carry at
least 8 lines, 134 of those are two-column by a widest-gutter test, and **49 of the 134
(37 %) come out of capture interleaved**. So for at least one real recognizer, reading
order is not free.

**Fixing it does not pay.** A sorter that splits at the widest horizontal gap and emits
each column top-to-bottom (identity when no clear gutter is found) reorders **116 of the
181 verified pages — 64 %**, and scores:

| arm | right block count | recipes never emitted |
|---|---|---|
| text rules, no geometry | 131/181 (72 %) | 47 |
| layout, as it ships | 138/181 (76 %) | 39 |
| layout + column sort | 139/181 (77 %) | 39 |

**Stale as of 2026-08-08, in the row labelled "as it ships".** `--layout` replays an
UNCROPPED pipeline, and since BUT-1816 the adapter edge-crops before the string is taken, so
the cropped replay scores 139/181 where that row says 138. All three rows share the
crop-blind caveat, so the comparison between them is EXPECTED to survive — but the sorter
arm was not re-run under cropping, so that is an expectation, not a result. Still a PROXY
either way: nothing here says what the phone does. `corpus_split_eval.dart --edge-crop`
prints the cropped pair.

Five pages fixed, four broken. One page net, which is noise — bought by changing the text
of two pages in every three. Only 48 of the 181 are multi-recipe, so at least 68
single-recipe pages were reordered: the sorter necessarily touches the population the
whole plan was gated on not regressing.

**And if ML Kit turns out to order columns correctly, the case is weaker still**, not
stronger: the benefit measured here would shrink toward zero while the risk of reordering
a page that was already right remains.

**A second probe, not part of the plan, fails too.** Deskewing was proposed here rather
than by the plan's ⑦, and an earlier comment wrongly called it step 8's real fix. The
residual error on the motivating page is that an
axis-aligned box around a TILTED word grows with the word's width. Fitting each line's
word heights against their widths and taking the intercept — the width-free estimate —
scores 136/181 with 42 recipes lost, 0 pages fixed and 2 broken. Worse. Within one line
the longest/shortest spread is usually negligible (median 1.02 over 6,280 samples), so the
fit is mostly noise. Reading the numbers rather than measuring: what would constrain such
a fit is the tail of wide-spread lines, and the motivating page's heading is one — but that
is an inference from a single page, not a result, and whether a different estimator could
exploit it is untested.

**What this leaves standing.** The corpus page the feature was designed against
(`blandat-svart/PXL_20260803_204246157`) still yields one heading instead of two, and
there is no known cheap correction. That is recorded as a passing test in
`heading_detector_test.dart` — a known miss with its measured cause — rather than tidied
away or tuned around by loosening `titleSizeSpread`, which was separately measured to cost
a working page.

**How to re-derive this**, since both probes were throwaway and are gone. Baseline:
`dart run tools/corpus_split_eval.dart --layout`, which scores the shipped splitter over
`layout-winocr.json` and prints both arms. For the sorter and the deskew fit, rebuild them
against the same captures — a page counts as two-column when the widest gap between line
lefts exceeds 18 % of the page's **widest ink extent** (`max(line.box.right)`) and both
sides hold at least four lines, and note that this same heuristic defines the 134 AND
drives the sorter, so the two stand or fall together.

**The denominator is load-bearing and this entry got it wrong once**, on 2026-08-07, in the
sentence above. Re-derived on 2026-08-08 over the same 250 captures, twice and by two
independent implementations that agreed to the unit: 208 pages carry >= 8 lines under both
denominators, but the ink extent yields **134** two-column pages and **49** interleaved —
reproducing the figures above exactly — while the DECLARED page width
(`PageLayout.imageWidth`, the `width` key in the capture) yields **124** and **45**. Median
ink extent is ~0.91 of the declared width over those 208 pages, which walks ten of them
across the bar. A session following the wrong denominator would conclude this entry's
numbers are fabricated; matching to the unit is what identifies which probe was really run.

Related trap, but **not** a blocker on the device measurement this entry asks for: if you
re-derive against `PageLayout.imageWidth` instead, note it defaults to 0 (`text_layout.dart`)
and `MlKitTextRecognizer.toPageLayout` never fills it, so on a phone the ratio degenerates
silently — `Infinity` for any non-zero gap, `NaN` for a zero gap, no exception and no empty
result to notice. The ink extent has no such problem, but not for the reason it looks like:
it is a LINE box, which a device fills from ML Kit's own line rect
(`device_text_recognizer_mlkit.dart`) while a replay derives it from the word union
(`OcrLine.fromJson`) — two different mechanisms, both non-zero, so the ratio holds on a
phone either way. They are not guaranteed byte-equal, so do not compare a device figure
against a replay figure at the unit.

Re-open only with a new measurement, not a new argument — and the measurement worth having
is ML Kit's block ordering on a device, which nothing here supplies.

---

## A single surviving layout block does NOT get to stand — measured and declined (2026-08-08)

**Verdict.** `MultiRecipeSplitter._splitByLayout` keeps its closing
`if (blocks.length < 2) return null`. Accepting one block was measured, is safe within a
narrow bound, and buys four tokens across the whole corpus. BUT-1816.

**What prompted it.** Malin photographed a cookbook page and the import carried the NEXT
recipe's heading: *"rubriken identifieras som tillhörande ett nytt recept och plockas bort
från importen."* The obvious reading — the detector misses it — is wrong. The layout path
finds that heading, opens a block on it, discards the block for being under
`_minLayoutBlockChars`, and then throws its own correct answer away because only one block
survived. The text rules take over and put the heading back. So the defect is real and the
diagnosis in the ticket was not.

**Measured** (mutation probe on that one line, `dart run tools/corpus_split_eval.dart
--layout` for the block counts and `--edge-crop` for the tokens):

| discard bound | single pages | spreads | recipes never emitted | pages broken |
|---|---|---|---|---|
| today (>= 2 blocks required) | 122/133 | 16/48 | 39 | 0 |
| one block accepted, discard < 40 / 80 / 120 | 122/133 | 16/48 | 39 | 0 |
| one block accepted, discard < 200 (the live budget) | 122/133 | **15/48** | **40** | **1** |

Those block counts come from `--layout`, and the token pair below them is the `--edge-crop`
arm's BEFORE column — both replay an UNCROPPED pipeline, the same caveat the older entry's
table carries since 2026-08-08. The shipped, cropped baseline is 91.54 % recall and 66.64 %
precision; a re-deriver reading the AFTER column will find neither number quoted here. The
comparison stands because every row shares the caveat.

So it is safe only if the discard budget is tightened to ~120 characters at the same time —
at the live 200 it costs a spread and a recipe. And at any safe bound it is worth nothing:
gold-token recall unchanged at 91.56 %, precision 66.26 -> 66.27 %, **four tokens across 181
pages**. The corpus simply does not hold the case in measurable quantity.

**PROXY figures** — the geometry is `layout-winocr.json` (Windows' offline recognizer), not
ML Kit, exactly as everything else on this path.

**How to re-derive this.** Back up `multi_recipe_splitter.dart`, replace
`if (blocks.length < 2) return null;` with
`if (blocks.length < 1) return null;` plus
`if (blocks.length < 2 && discarded >= N) return null;`, run both eval arms, restore, and
verify the file is byte-identical. Sweep N over 40/80/120/200 — the cliff is between 120 and
200, and it is the discard budget that moves it, not the block rule.

**Why the ticket still shipped something.** Its OTHER half — cropping the neighbouring
column a phone photo catches at the frame's edge — measured positive and was built
(`lib/services/ocr/edge_crop.dart`). Do not read this entry as declining BUT-1816; it
declines one of its two halves.

**But do not read it as "Malin's import is fixed" either.** The crop runs on every tier-0
recognition and only REACHES an import on the geometry arm: with `enable_layout_recipe_split`
off — the code default — `OCRExtractionService` ships `providerText`, which is uncropped and
has no geometry to crop against. So the built half is dark by default until that flag flips,
by construction rather than by oversight.

**CORRECTED the same day, 2026-08-08.** This entry originally closed on "re-open only with a
corpus that contains the case". The corpus DOES contain it, and the corpus is Malin's own
Pixel photos (`PXL_*.jpg`, thumb and cushion visible in frame) rather than the scans an
earlier draft called them — a claim that was never checked against the images and was simply
wrong.

Measured on ALL 247 stored captures — a one-off probe, not the eval arms, which score only
the 181 pages that carry gold: **19 of 247 end their import on a next-recipe heading**
(`Inlagd sill`, `Mandelforell`, `Annas hurtbullar`, plus frame-cut titles like `Provensa`,
`Köttsa/l`). All 19 arrive because the layout path declined — but the gate this entry tested
is not the one that declines:

| why the layout path gave up on those 19 | pages |
|---|---|
| `flat.length < 2` — only the orphan title was detected | **14** |
| the discard budget was blown | 3 |
| only one block survived — **the gate measured above** | **2** |

So the verdict stands for the single-block rule and is worth what it says, but it covers 2 of
19 cases. The generalisation it invited — "the case is not there" — was false, and it would
have stopped the next session from looking.

**What the symptom actually needs is a TRIM, not a split** — and that is now BUILT.
`withoutOrphanTail` (`lib/services/import/layout/orphan_tail.dart`) cuts the page at its
last detected heading when under 120 characters follow it. `ImportManager` applies it
before `split` — **AMENDED 2026-08-12: through `withoutFrameNoise`
(`frame_trim.dart`) since that date, not by calling `withoutOrphanTail` itself, which now
has no production caller. The rule's DECISION (`orphanTailCutRow`) is the old function's
body gate for gate and still reads the untouched page, so every figure in this entry is
unmoved — that is precisely why this shape was chosen over swapping the two trims, which
would have changed this rule's input and silently un-measured it. Choosing the
restructure over the cheaper swap was MALIN'S CALL on 2026-08-12, taken with the swap
and its cost put to her explicitly; this paragraph is the tracked record of it, and
`frame_trim.dart` points here rather than at the gitignored plan snapshot.** So `MultiRecipeSplitter` keeps its "never hands back a single SHORTENED
block" contract untouched (it still drops furniture when it splits — a separate promise,
stated on `split`) and `corpus_split_eval.dart --trim` can still compare two columns.
Shipped: 10 pages trimmed, precision 66.64 -> 66.77 %, recall 91.54 -> 91.52 %, right
block counts unchanged at 139. `--trim` now prints WHICH ten pages, with the heading text
and the character count under it, so the list in `orphan_tail.dart` is verifiable by
command rather than by trust.

**The recall column is biased AGAINST this rule — BUT-1818, filed the same day.** The gold
records frame-cut half recipes as complete ones (>=12 of 242 verified entries, by a screen
that only inspects the last instruction and the title, so a floor). **SUPERSEDED by the
paragraph below:** hand grading against the photographs put it at 14 entries, of which 11
bias recall; the BUT-1847 re-grade of every verified entry put it at 23, of which 13 bias
recall. The `>=12` is the screen's number and is left here as the record of what was
known before the grading. **Two different instruments are involved and must not both be called
"the screen":** the `>=12` came from a screen that inspects only the last instruction and the
title (89 false positives on word shape); a separate terminal-punctuation screen, re-run over
the FINISHED grading, recovers 9 of the 23 with 0 false positives (13 if it also looks for an
explicit `...`). Either way "floor" was the right word twice over. Recall therefore scores
retained frame-cut debris as a hit, and the trim is penalised for removing exactly what it
exists to remove. Read `91.54 -> 91.52` as an UPPER BOUND on the content cost, and the 200
row's `-> 91.33 %` as the figure most exposed — **it was re-measured on de-biased gold in
BUT-1847 and is exposed no longer: see the BUT-1847 budget sweep below.** None of the
verdicts in this entry rest on
that column: all 10 shipped tails and all 9 band tails were graded against the
PHOTOGRAPHS. Comparisons between two arms (column ordering, the single-block rule) scored
the same gold on both sides and survive; the ABSOLUTE percentages are softer than they look.

**BUT-1818 re-measured the recall column, and the trim's content cost is ZERO — BUT-1847
re-graded the gold behind it and the zero held.** The set now stands at **23 marked entries
on 20 pages: 13 `fragment` and 10 `tail`.** BUT-1818 graded 14 on 2026-08-09 from what a text
screen surfaced; BUT-1847 opened all 181 pages as images on 2026-08-19, **confirmed all 14
unchanged** and added nine — two `fragment` and seven `tail`. The two fragments are
`Annas fisks` (`blandat-svart/PXL_20260803_204323606/recipe-02` — the facing page's recipe
sliced lengthwise, its gold carrying a truncated title, 14 of 15 ingredient lines broken
mid-word and 21 of 24 instruction lines) and `Inlagd sill`, the borderline case priced at the
end of this entry. **How an entry is
graded, and the four things that are NOT a frame cut, now live in
`docs/testing/cookbook-corpus-gold-grading.md`** — the reason two gradings in a row undercounted
is that both read TEXT, and that file exists so a third does not.
The 2026-08-09 set was: 11 `fragment` (the whole entry is a frame-cut sliver of the next recipe — `Mästerkockens f`,
`Den gl`, `Enkla fisken`, `Kavling av mandelmassa`, `Mandelforell`, `Mixade vitaminer`,
`Dillstuvad potatis`, `Hasselbackspotatis`, `Sallad med vita bönor`, `Böngryta`,
`Soppa med vita bönor`) and 3 `tail` (a real recipe whose last line the frame took —
`Hembakad pasta`, `Madames saffransfisk`, `Lammstek`). `corpus_split_eval.dart --no-frame-cut`
drops the `fragment` ones — see the next paragraph for why never the `tail` ones. It is OFF
by default so every figure quoted elsewhere keeps reproducing.

The seven `tail`s BUT-1847 added are `Avocadosoppa`, `Provençalska kotletter`,
`Igelkottstårta`, `Potatis- och gurksallad`, `Grekisk bondsallad`,
`Transsylvansk pepparrotssallad` and `Grynigt potatismos med endivsallad`. **Five of them are a
different mechanism entirely** — not the camera frame but the BOOK's own page break, a recipe
that starts at the foot of one page and finishes on a page the photograph does not include
(four in `potatisratter`, plus `Igelkottstårta` at
`blandat-svart/PXL_20260803_204954922/recipe-02` — a tårt book photographed into the
`blandat-svart` slug, not a slug of its own; the other two are ordinary bottom-of-frame cuts). No screen aimed at broken words can see the page-break class — the gold ends on a clean
full stop — which is most of why the earlier count was low.

**Only the `fragment` entries are dropped, never the `tail` ones.** A `tail` gold is a real
recipe the page holds whose ending the capture took, so it is SHORT of tokens, not long —
dropping it removes no bias, only a page. BUT-1818's three were flat single-recipe pages, so an earlier
draft that dropped them moved the population 181 -> 178 and took one TRIMMED page (`Köttsa/l`)
with it; the conclusion survived but the comparison ran across two populations, which is not a
measurement. On a multi-recipe page it would be worse: a dropped `tail` lowers the expected count
while the recipe is still there, marking a CORRECT split as spurious.

Scoped to `fragment`, the two columns are ONE population — same 181 pages, same 10 trimmed:

| arm | biased gold | `--no-frame-cut` |
|---|---|---|
| trim recall | 91.54 -> 91.52 % | **91.64 -> 91.64 %** |
| trim precision | 66.64 -> 66.77 % | 65.83 -> 65.97 % |
| right block counts | 139 of 181 | **145 of 181** |

**Exactly zero, not a rounded 0.00** — the report carries raw integers: `15925 -> 15925 of
17378` gold tokens, against the biased run's `16121 -> 16118 of 17611`. A percentage pair
reading `X -> X` never proves zero on its own. Note also that the 13 are the recall-BIASING
subset; the other 10 (`tail`) bias nothing, and both numbers are floors rather than counts,
since an unfound fragment only makes the trim look worse.
(BUT-1818's own de-biased column read `91.59 -> 91.59 %`, `66.03 -> 66.18 %`, `144 of 181`,
`15974 -> 15974 of 17441` — two fragments fewer in the dropped set. The de-biased column moves
whenever the grading does, so never quote it without naming the grading it came from; the
BIASED column has not moved and still reproduces.)

So the 0.02 points were the biased gold, in full. **The block counts move 139 -> 145 as SEVEN pages
gained and ONE lost, not six clean gains** — an aggregate that hides a swap is the one thing this
tool exists to prevent, so `--trim --no-frame-cut` prints the per-page movement (`gold N -> M, blocks B`)
rather than leaving it to a probe — the table lives in the trim arm, so the flag alone does not
emit it. The seven are pages where the splitter emitted one block fewer
than the biased gold demanded: it correctly declined to make a recipe out of a sliver. The one
lost, `PXL_20260803_204205028`, is the opposite and the more useful case — the splitter emitted 3
blocks on a page holding 1 real recipe — and NOT one per sliver, which is what a block COUNT
tempts you to assume. Read out of the real splitter: block 1 is the recipe with the
`Dillstuvad potatis` sliver swallowed INSIDE it, block 2 is that recipe's own variant subsection
`Med mangold eller nässlor` opened as a second recipe, block 3 is the `Hasselbackspotatis` sliver.
One sliver opens nothing, the false split is INSIDE a real recipe, and the biased gold had been
scoring all of it as RIGHT. (A first draft said "one per sliver", inferred from the count. A count
matching gold never tells you WHICH blocks came out.) So removing the bias
does not only stop punishing correct declines; it stops rewarding a real false split. TEN
pages carry a dropped fragment and only eight of them move: seven gained plus the one lost.
The other two are wrong under BOTH golds and move nothing — `PXL_20260803_204143402` (gold
5 -> 2, the most-biased page in the corpus) and `PXL_20260803_204345256` (gold 3 -> 2) — named
because seven plus one otherwise leaves two cases unaccounted for. **No page is ALL fragment**,
so `--no-frame-cut` never drops a page out of the population; that invariant is what makes the
two columns one population, and it is worth re-checking after any re-grade. The run prints how many entries
it dropped and writes a `-nofc` report file, so the two populations can never be confused after
the fact.

**The 200-budget row is no longer unre-measured, and it is the reason BUT-1847 existed
(2026-08-19).** The whole budget sweep, re-run on the re-graded gold with `--no-frame-cut` —
same 181 pages, same trimmed pages per budget, only the scored population differs:

| budget | pages | precision | recall | right block counts | gold tokens lost |
|---|---|---|---|---|---|
| 60 | 7 | 65.83 -> 65.87 % | 91.64 -> 91.64 % | 145, unchanged | **0** (15925 -> 15925) |
| **120 (shipped)** | **10** | 65.83 -> 65.97 % | 91.64 -> 91.64 % | 145, unchanged | **0** (15925 -> 15925) |
| 200 | 19 | 65.83 -> 66.27 % | 91.64 -> **91.59 %** | **144 — a page lost** | **9** (15925 -> 15916) |

**The shipped budget still costs exactly zero; the 200 budget does not.** Of the 36 gold
tokens it cost on biased gold (`16121 -> 16085 of 17611`), 27 were frame-cut debris and
**9 are real recipe text** — so the band's refusal, which had been argued from nine hand
readings, is now priced, and the two agree. The BIASED rows (`91.54 -> 91.33 %`, `139 -> 138`)
reproduce unchanged, as they must: `frameCut` scopes the population only under
`--no-frame-cut`. (The default arm does READ the field — it tallies the census it prints —
but nothing downstream of that tally touches a score.)

**That 9 rests on one borderline label, and the label is written down rather than assumed.**
Of the nine tails in the 120-200 band, TWO are themselves marked `fragment` — `Mixade
vitaminer` (166 chars) and `Inlagd sill` (159) — so cutting either costs nothing. They are the
same case seven characters apart: the next recipe's opening, taken by the bottom frame edge,
with no ingredient block and a line or two of method. The only thing that differs is that
`Inlagd sill`'s cut landed after a full stop, so its transcription READS finished. Labelling
from that would be the same text-shaped mistake this ticket exists to retire, so both are
`fragment` on the criterion in `docs/testing/cookbook-corpus-gold-grading.md`. **The label that
moves the row is `Inlagd sill` alone** — the one BUT-1847 decided; with it a `tail` the row
reads **23** tokens instead of 9, and that state was measured. `Mixade vitaminer` has been a
`fragment` since BUT-1818 (it is in the eleven listed above), so flipping BOTH is an unmeasured
state and would cost MORE than 23, a `tail` there re-entering the denominator on a page the 200
budget also cuts. Non-zero and a lost block count in every measured state, so the verdict does
not turn on the call, but the magnitude does. The claim
below that every tail in the band carries readable content is right about the ink on the page
and wrong about what the gold is worth, for those two.

**A zero-ingredient gold entry is NOT a defect signal** — `Fisk i ugn` and `Koka piggvar` are
complete recipes that genuinely carry no ingredient list, and the screen that reads only the last
instruction plus the title flags 89 false positives on word-shape alone (`deg`, `cm`, `bär`). The
14 above were each opened as an image, and so were all 242 verified entries in BUT-1847. Do
not re-derive this set from any text screen — a screen run over the FINISHED grading recovers
only 9 of the 23, or 13 if it also looks for an explicit `...`; the remaining ten are clean
prose that simply stops. Exactly ONE of the 13 fragments sits on a page the shipped budget
actually trims (`Mandelforell`), so the other twelve bias the recall LEVEL rather than the
trim's own delta. Procedure and rubric: `docs/testing/cookbook-corpus-gold-grading.md`.


**The gate on the 120-200 band closed.** That band was designed as a third outcome — show
the tail unticked in the picker so Malin could judge it — and the plan pre-committed to
reading the nine tails by hand first, with a sharp threshold: one tail that would lose real
content and the band stays off.

**CORRECTED 2026-08-09, and the correction is the more useful record.** The first reading
was done on 2026-08-08 from the bare TEXT and reported two "subheadings inside a recipe"
(`I stället för sås`, `Chokladkräm`). Both labels were wrong. Re-read against the
PHOTOGRAPHS the next day: `Chokladkräm` is a whole small recipe — title, two ingredients, a
parenthetical note, all of it on the page — so cutting it would delete a recipe outright;
`I stället för sås` is a new SECTION's display heading with its own paragraph and bullet
list under it. Neither is a subheading. The verdict survived; the reason did not.

The right reason is simpler and covers all nine rather than two: **every tail in the band
carries readable content under the heading** — a whole recipe (`Chokladkräm`), an intro
paragraph (`Annas hurtbullar`), the start of the next recipe (`Inlagd sill`,
`Mixade vitaminer`, `Hallonsmoothie`, plus frame-cut `Provensa`, `Pott`, `Indi`), or a tip
section with a list (`I stället för sås`). Below 120 characters the corpus holds only
frame-cut debris. The character budget is a PROXY for that distinction and nothing more; do
not re-derive it from the retracted "subheading" wording. So the band stays `none`, and the
UI half it existed for — `uncertainIndices` through the viewmodel to the picker, an ARB
string, a widget test — was never built rather than shipped dark and untriggerable.

**The same text-only reading also mis-graded the SHIPPED window, in Malin's favour and
against the feature.** It reported 8 of 10 correct, calling the two section headings
(`Olika fyllningar med vaniljkräm`, `Djupfrysning av tårtor`) in-recipe subheadings. Malin
pushed back on the report — "i dessa båda fall ser kapningen rätt ut för mig" — and she was
right. All ten were then opened as images: **10 of 10 are correct cuts**, and two of them
(`Sina ingredienser`, `Sina ingr`) are not from the cookbook at all but from the back-cover
blurb of a different book lying on the table behind it. The per-case record with the
photographs is `claude-reports/butlery/2026-08-09-klippet-fall-for-fall.html`.

**One behaviour deliberately left unpinned, with its failure mode recorded rather than
guessed.** `ImportManager` hands `split` the TRIMMED layout, and nothing at the unit,
wiring or corpus level fails if that is swapped for the stale one — the unit tests never
call the manager, the eval arm builds and passes its own trimmed pair and never calls
`autoParseMulti` at all — so it does not measure that pairing either — and the wiring spy sees
only text. Measured 2026-08-08: with the stale layout, `matchesLineCountOf` refuses the
mismatched pair and `split` returns byte-identically to a run with no geometry at all. So
the whole effect is that the layout path goes DARK on exactly the pages the trim fires on
— silent, but fail-safe: the output degrades to today's shipped text-rule behaviour and
nothing new is lost. A fixture that would pin it exists (two headings whose blocks each
clear `_minLayoutBlockChars` and carry an instruction signal, plus the tail; the tell is
which row the SECOND block opens on, never the block count), and it was priced rather than
written. Write it if this ever stops being fail-safe.

**Re-open the band when the picker can MERGE two blocks (BUT-1817).** The whole reason a
wrong cut is expensive is that `BatchImportPreview` cannot rejoin what it was handed. Make
that undoable and this trade is a different one.

Re-open the single-block rule only with a new measurement of THAT gate.

## BUT-1819 — `sanitizeUrl` blanks a provenance sentence that merely CONTAINS `data:`

**Decision: accepted, and deliberately not fixed in this ticket. 2026-08-10.**

`HtmlSanitizer.sanitizeUrl` matches `javascript:`, `data:` and `vbscript:` as
**unanchored** substrings (`html_sanitizer.dart` :40-44). Turning the recipe
sanitizer on — which BUT-1819 did, after five months in which it silently never
ran — means a `sourceUrl` is blanked in full whenever those five characters
appear anywhere in it. `sourceUrl` is a PROVENANCE field for a dozen writers, so
the value being destroyed is often a Swedish sentence rather than a URL, and the
destruction is total, silent, and repeats on every subsequent write.

Why it stands:

- The plan Malin approved names this consequence explicitly and defers the fix.
  Anchoring the pattern edits `html_sanitizer.dart`, which is shared and has
  other callers, and it is a separate judgement about how aggressive URL
  blocking should be across the app — not a detail of this ticket.
- The probability is low. It needs the literal `data:` inside a free-text
  provenance value.
- The user-facing protection is the render guard, not this. Since BUT-1819 the
  recipe detail view draws a source as a link only when `isSafeExternalUrl`
  accepts it (http/https with a non-empty host), so a hostile value is inert on
  screen whether or not storage blanked it.

**The counter-argument, recorded because it is strong.** The security review of
2026-08-10 pointed out that `isSafeExternalUrl` is a positive allowlist that
strictly dominates this blocklist for the threat it was aimed at, so the
blocklist's only remaining NET effect is destroying provenance. Anchoring to
`^\s*(javascript|data|vbscript):` would keep 100 % of the scheme protection at
zero cost. That is a real improvement and it is written down here rather than
lost; it needs its own ticket, its own sweep of `sanitizeUrl`'s other callers,
and Malin's call — not a quiet widening of this commit.

**One neighbouring effect, recorded so it is a known gap rather than an assumed
one:** `sanitizeUrl` also runs `normalizeHomoglyphs`, so a `sourceUrl`
containing Cyrillic lookalikes is silently rewritten to a DIFFERENT url rather
than blanked. Near-zero probability for Swedish provenance text, and it is not
what this entry decides — but do not read the entry as covering it.

Pinned by `test/unit/repositories/firebase_recipe_repository_sanitize_test.dart`
(`a sentence CONTAINING data: is blanked`), which also carries a discriminator
fixture proving a bare colon is harmless, so a future reader cannot mistake the
rule for "any colon blanks the field". BUT-1819, 2026-08-10

## Messaging — the conversation roster (2026-08-12)

> **SUPERSEDED IN PART, 2026-08-22 (BUT-1831).** The section below describes
> `MessageMutationModule`'s fabricate-a-conversation fallback in the PRESENT tense and
> counts two of its Dart tests as pinning an invariant. **That branch and those two tests
> are deleted.** The fallback's write is refused by `firestore.rules` on both horns as the
> rules stand today — update deny-lists the re-stamped `createdAt`, create requires
> `metadata.creatorId == request.auth.uid`. Read every sentence below about "the module
> falls through to its fallback" as history.
>
> **What still stands, unchanged:** the create rule's behaviour on `metadata: null`, and
> test C7B that pins it. What changed is only WHO sends that shape. It is no longer sent
> deliberately by our own client — but it is not unreachable either: a `merge: true` set is
> a CREATE when the document is absent, so a merge-set carrying a null metadata still
> arrives at that limb. It fails closed.
>
> **What is NO LONGER pinned where this section says.** The claim "the invariant is
> THREE-sided, and all three sides are pinned as of this commit" is now false as written.
> Side 1 (the rule denies `metadata: null`) is still C7B, and C6B covers the key being
> absent. Side 2 (the fallback records no `creatorId`) has no subject any more — there is
> no caller constructing a creator-less conversation on that path, so there is nothing left
> to assert. Side 3 (`ConversationDto.toFirestore` emits the KEY even when the value is
> null) lives in `conversation_dto_test.dart`, untouched by this ticket — what changed is
> that the duplicate in `message_mutation_module_test.dart` was deleted. It sits there as a
> control line inside the BUT-1838 test, so it survives only while nobody trims that control.
>
> **The BUT-1830 squat this section describes is separately stale**, and not by this
> ticket: `directIdBinds` (BUT-1838) requires `participantIds.size() == 2` and an id
> derived from the pair, so the one-participant create at a known group id described below
> is refused. `firestore.rules` says so at that limb. Left in place rather than rewritten,
> per the rule that a decision record is superseded and not deleted.


### The bootstrap branch, and why it cannot just be tightened

`conversations/{conversationId}/participants/{participantId}` had **no `match` block at
all** until 2026-08-12. It fell to the terminal default-deny, which meant
`ConversationParticipantModule.addParticipants` — reached on every group and direct
conversation creation — was denied. LOUDLY, unlike the other four: `addParticipants` has no
local catch, so `batch.commit()` throws up through `createGroupConversation`. That is what
made it the priority of the five `hasOnly`/missing-rule drifts found after the three-week
recipe-save outage — the others were swallowed and merely stopped working.

The obvious rule (`get()` the conversation and check `participantIds`) denies GROUP creation
permanently. `FirebaseMessagingRepository` mixes in `UserScopedFirebaseRepository`, so the
group document is written under `users/{uid}/conversations/{id}`, while the roster goes to
the TOP-LEVEL path — whose parent only materialises when the first message is sent
(BUT-1795). So the shipped rule is `attested || unclaimed`:

    allow read: if isAuthenticated()
      && (parentNames(request.auth.uid)
          || (parentDoc() == null && exists(<own row>)));

`rosterUnclaimed()` additionally excludes `^direct_.*` ids, because a direct id is
guessable from two uids that are readable in `public_profiles`.

### Residual (a): pre-seat

An unattested user who knows a never-chatted group's id can seat a row, and then read the
roster. Pinned by test **P3B**, which is written to PASS — it is the honest record of the
cost, not a hidden hole. If P3B ever starts failing, the bootstrap was removed and group
creation should be re-checked before celebrating.

**A third actor on the same branch, recorded separately because the two lists above do not
reach them.** Between group creation and the first REAL message, every legitimately seated
member can LIST the roster through the unclaimed fallback — including a minor added by a
non-friend who has not been evicted yet. `enforceGroupMinorMembership` is an
`onDocumentCreated` trigger on the TOP-LEVEL `conversations/{id}` document, and that document
does not exist until the first real message: group creation writes only the user-scoped copy,
and the system message `createGroupConversation` sends immediately after is refused twice over: the client's own participant check
rejects `isParticipant('system')` before any write, and the messages create rule would deny it
anyway (`senderId == request.auth.uid` against `Message.system`'s literal `"system"` — already documented at `conversation_mutation_module.dart:226`). So the
child-safety cut cannot fire during that window, and the roster it would have cleaned is
readable to everyone in it.

**And the window is closed by the CREATOR, not by "someone" — but not for the reason it first
appears, and the real reason is fragile.** The first version of this paragraph said a
non-creator's send is "refused before any write" and that the create conjunct
`metadata.creatorId == request.auth.uid` denies it. Neither is what happens.

`readConversation` is the user-scoped `read`, which RETURNS NULL on a missing document rather
than throwing, so the `ResourceNotFoundException` never fires — a non-creator has no
`users/{uid}/conversations/{id}` copy, and nothing refuses before the write. The module falls
through to its fallback, builds `Conversation(participantIds: [senderId], isGroup: false)` with
no metadata, and stages a top-level create. `ConversationDto.toFirestore` emits
`'metadata': conversation.metadata` UNCONDITIONALLY, so the payload carries `metadata: null`,
and the create rule evaluates `!('creatorId' in request.resource.data.metadata)` against null —
an `in` on a null is a CEL EVALUATION ERROR, which denies. The named equality conjunct is never
reached.

**So the barrier is an evaluation error, and the UPDATE rule thirty lines below answers the
same null-metadata question the opposite way, with an `is map` ternary.** Harmonising the two
spellings "for consistency" is an obvious, well-intentioned edit and it would disarm the
child-safety trigger outright: the non-creator's create would land a top-level document with
`isGroup: false` AND a single participant, `enforceGroupMinorMembership` would return early on
it (both halves of its guard, not the flag alone — see below), and
`onDocumentCreated` cannot fire twice — so the cut would never run for that group at all, while
every other member's roster read would die because the parent now exists and names only the
sender. Pinned by test C7B, which is the only test in the suite that puts `metadata: null`
through the CREATE rule; mutation-proven — making the two rules agree reddens exactly it.

**The evaluation error is NOT a security bound, and this record must not be read as claiming
one.** It binds the app's own client, which sends `metadata: null`. It does not bind a tampered
one. Measured against the staged rules: any authenticated caller who knows a group's id can
create `conversations/{id}` with `{participantIds: [self], createdAt, isGroup: false,
metadata: {creatorId: self}}` — no null anywhere, the conjunct satisfied, **ALLOW**. That ends
the window degenerately and IRREVERSIBLY: the trigger returns early on it — that payload trips BOTH halves of its
guard (`isGroup: false` AND a single participant), so do not read the flag alone as sufficient
— and `onDocumentCreated` cannot fire twice, so the child-safety cut never runs for that group; the
real creator's later first message is now an UPDATE against `participantIds: [attacker]` and is
denied, so they cannot repair it; and every member loses roster read, because the parent now
exists and names nobody real. A member who wants the eviction never to run has a one-write way
to guarantee it.

That squat is PRE-EXISTING — the conversations create rule is not changed by this commit — and
is filed separately as **BUT-1830** (Urgent), which also warns against adding an explicit
`metadata is map` to the create rule alone: that removes the accidental barrier stopping our
own client while leaving the deliberate attack untouched. What is recorded here is only this: "only the creator can end the window"
is true of the honest client and false in general, and the thing standing between the two is an
error rather than a rule.

**The invariant is THREE-sided, and all three sides are pinned as of this commit.** C7B proves
the rule denies `metadata: null`. Two Dart assertions in
`message_mutation_module_test.dart` prove the writer keeps sending it: one that the fallback
records no `creatorId` (stamping one — an obvious, well-intentioned fix — makes the create land
and leaves C7B green), and one that `ConversationDto.toFirestore` emits the KEY even when null
(omitting it, the standard "don't write nulls" cleanup, satisfies the rule's
`!('metadata' in data)` disjunct and lands the create just as effectively). Each is
mutation-proven against exactly the edit it exists for, and `conversation_dto.dart` carries a
comment saying why that line is unconditional.

Whether a non-creator's first message SHOULD fail is a product question; today it is a failed
send, not a graceful refusal, and this record should not be read as endorsing it. So for a group whose creator stays silent, `enforceGroupMinorMembership` never fires
at all. In the threat model this trigger exists for, the non-friend adder IS the creator: in the
honest-client model described above — and only there, see the "NOT a security bound" paragraph
— they control whether the child-safety cut ever runs, and this block is what makes the roster
readable in the meantime. Pre-existing (BUT-1626/BUT-1795) but sharper than "until the first
message" suggests, and it should weigh on BUT-1795's priority.

This window is NEW with this block: the path was default-deny before, so a seated row granted
nothing. It is not a regression against a working state — group creation was throwing
outright until this sprint (D2) — but it is a real cost of turning the path on, and it is the
strongest single argument for landing BUT-1795, which removes it along with (a) and (b).

Bounded by the id: `Conversation.group` mints a UUIDv4 and `BaseFirebaseRepository.create`
writes `doc(getId(entity))`, so it is ~122 bits and client-generated. (An earlier version of
this record said "a 20-char Firestore auto-id". That was wrong about the mechanism; the
security conclusion was unchanged, but the sentence was corrected in three places.)

### Residual (b): orphan — and why the scoping does NOT close it

Firestore rules cannot distinguish "the parent has never been written" from "the parent was
deleted". Both are `parentDoc() == null`. So every deletion of a conversation re-opens the
permissive branch over its surviving roster rows, permanently. `allow delete` on the
conversation does not cascade, and the per-row delete rule admits only the row's own subject,
so the deleting client cannot clean up after itself.

The first version of the rule comment claimed the scoping "closes it, and closes the pre-seat
residual with it". It does neither; a five-minute emulator probe disproved both. That
sentence was written in the same edit that created the branch, which is the general hazard:
a claim about a control, authored by the person adding it, at the moment they are most
convinced.

Reachable deleters:

1. **`enforceGroupMinorMembership`** — when evicting non-friend-added minors leaves fewer
   than two members, it deletes the whole conversation. This was the sharp case: the evicted
   MINOR kept roster read on a group they had been removed from, and their own name and
   avatar stayed readable to it. **CLOSED in code, 2026-08-12.** The trigger now enumerates
   the roster with a bounded `.limit(MAX_ROSTER_ROWS + 1).get()` and deletes every row
   BEFORE deleting the parent — order matters, because the parent delete is the write that
   opens the branch. `tryClearRoster` REPORTS rather than throws (a throw inside a
   `retry:true` trigger is a loop); a false verdict makes the caller take the UPDATE branch
   instead, leaving the parent standing, which is what keeps the roster denied. Pinned at three levels, each
   mutation-proven and each proving something the others cannot. The integration suite pins
   the CLEANUP (remove the roster delete and the update and collapse branches redden, the
   keep path stays green) and the CALLER'S INVARIANT (neutralise the gate so the parent is
   deleted despite a false verdict, and the shell test alone reddens — that gate was
   invisible to every fixture until a test staged an unclearable roster, because every other
   fixture's roster clears). Fake-database unit tests pin the helper's READ- and
   DELETE-failure paths, which the emulator cannot reach at all: nothing there can make
   either fail, since the Admin SDK bypasses rules and deleting a missing document succeeds.
   (Its cap refusal is a different matter — the emulator reaches that one, and the shell
   test above is how the false verdict is staged.)
2. **`ConversationMutationModule.deleteConversation`**, from the conversations list view —
   **NOT closed**, tracked as BUT-1825.
3. **`account-deletion-cascade.ts:1185-1191`**, the GDPR erasure — it deletes any
   conversation with **two or fewer participants WHOLE** and never touches the roster.
   **NOT closed.** Two consequences neither the first version of this record nor BUT-1825
   named: a group that has shrunk to two members is deleted this way, so residual (a) is
   reachable without ever needing an unchatted group; and for a DIRECT conversation the
   `direct_` exclusion in `rosterUnclaimed()` blocks the WRITE but not the READ fallback, so
   the surviving partner keeps LIST over a roster still holding the erased user's
   `displayName` and `avatarUrl` — a live read immediately after an Art. 17 erasure, not
   merely stored residue. That is BUT-1822 seen from the other end.

**Consequence for the remedy:** BUT-1825's option 2 (widen the per-row delete rule so a
client can cascade) reaches deleter **2** only — the user's own delete from the conversations
list view, which is the one a client-side rule can see. Deleters **1 and 3** run server-side
under the Admin SDK, where rules do not apply. **Only BUT-1795 closes all three.**

(The numbering above is this section's own: 1 = `enforceGroupMinorMembership`, 2 = the client
delete, 3 = the GDPR cascade. `.claude/rules/accepted-deviations.md` lists the same three in a
different order and refers to them by description rather than number, deliberately — an index
copied between two differently-ordered lists is how this sentence was wrong on its first
writing. **`firestore.rules` numbers them too, in a THIRD order** — 1 client delete,
2 eviction CF, 3 cascade — so those are the two places that both use indices, and they are the
pair a copied number breaks. Never move a "deleter N" between documents; re-read the list you
are writing into.)

### Why this is accepted rather than fixed now

The alternative to the branch is landing BUT-1795 (write the group to the top-level path at
creation), after which the branch can be deleted outright and both residuals go with it.
Widening the roster `delete` rule so a client could cascade is more surface for a residual
that, in practice, shows a former group member the names and avatars of people they already
chatted with.

**Also worth knowing:** nothing in the app reads this path today — `getParticipants`,
`watchParticipants`, `isParticipant` and `updateLastRead` have no callers outside their
module. The read rule ships ahead of its reader. That is a fair argument for `allow read: if
false` until one exists, and it is recorded here rather than acted on.

### The zero-member shell

`tryClearRoster` refuses a roster larger than `MAX_ROSTER_ROWS` (5x the participant cap)
and returns false, whereupon the trigger takes the update branch instead of the delete
branch. When `remaining` is empty — every participant a minor, no `metadata.creatorId` —
that writes `participantIds: []`, and since every rule in the conversations block gates on
`uid in participantIds`, the document becomes permanently unreadable, unupdatable and
undeletable.

Accepted as the safest of three bad outcomes. **A later sweep must clear the roster BEFORE
deleting such a shell** — deleting it flips `parentDoc()` to null and re-opens
`rosterUnclaimed()` plus the own-row read fallback over every surviving row, including the
legitimate members and the evicted minor. The shell is safe only while it stands, so the
naive cleanup performs exactly the disclosure the shell was chosen to avoid. A live parent naming nobody makes the seeded
roster unreadable; deleting the conversation would re-open the bootstrap branch over those
rows; throwing would hand a `retry:true` trigger a deterministic error to loop on forever,
re-billing a ≤501-document roster read plus the ≤100-document participant fan-out each time. The cap exists precisely because rules
let any signed-in user write that path while the parent is absent, with no rate limit — so
an unbounded enumeration inside a retrying trigger was a real self-repeating bill, the same
one the `MAX_GROUP_PARTICIPANTS` guard beside it already refuses.

**AMENDED 2026-08-15 (BUT-1838) — everything above is the 2026-08-12 record, and three of
its present-tense claims are now false. The verdict and the cap are unchanged.**

1. **The caller moved.** This is written as the eviction trigger choosing between an update
   and a delete branch. BUT-1838 removed that collapse branch; `tryClearRoster` is now called
   from `deleteEmptyGroup` (`groups/remove-chat-group-member.ts`) and from `deleteMessages`
   and `deleteChatGroupMemberships` in the account cascade. None of them lives in the trigger.
2. **The branches it fears are gone.** `rosterUnclaimed()` and the own-row read fallback were
   both deleted. Deleting a shell no longer re-opens them — it makes the surviving rows
   UNREADABLE instead (every predicate that could surface a row reads through the parent).
   Not un-writable: the `(u1)` self-cursor update and `allow delete` are parent-free self
   checks, so the row's own subject could still stamp or delete it, and no client flow does.
   The ordering rule survives on the milder consequence: orphaning is still a one-way door.
3. **"The cap exists precisely because rules let any signed-in user write that path while the
   parent is absent" is the sentence this whole amendment exists to retire.** That hole is
   closed. `MAX_ROSTER_ROWS` stays load-bearing for the same three sources as its sibling
   `MAX_ROSTER_SWEEP_ROWS` — rows planted before BUT-1838 and still on disk (backfill closed
   unbuilt, BUT-1839); a tampered or non-standard Admin-SDK writer; and a bounded but LIVE
   attested client write. Do not cite the retired hole as the reason for a live control, and
   do not conclude from its removal that the control can go.

### Art. 17 — CLOSED 2026-08-13 (BUT-1822)

Account deletion erased `users/{uid}/conversation_memberships` and nothing erased the roster
row, which carries the deleted user's `displayName` and `avatarUrl`. Inert until 2026-08-12
(no rows could exist), live from then. Fixed in `deleteMessages`, in two legs, because the
scope note below made one leg insufficient:

1. the ≤2-participant branch now calls `tryClearRoster` BEFORE the parent delete and
   **abandons the delete** if it answers false, applying `buildGroupDepartureUpdate` to the
   surviving document instead. This is what protects the SURVIVING partner's row, whose
   `participantId` is not the erased uid and which no uid-keyed query can find. It is also
   the first path that can leave a `direct_` conversation standing with fewer than two
   participants — no client can leave a direct chat, because the departure callable takes a
   `groupId` and a direct conversation cannot be addressed at all, so no client has rendered
   that state before (it degrades: every "other participant" lookup in `conversation.dart`
   carries an `orElse`). For a DIRECT conversation the seeded-roster route is not reachable:
   only the two attested participants may write rows, `directIdBinds` pins `participantIds`
   to exactly two and the update rule denies any diff touching it, so such a roster holds at
   most TWO client-written rows and can never reach the refusal cap. For a DIRECT id this
   branch therefore means a transient read or delete failure, i.e. an outage. A LEGACY
   non-direct conversation is the other population it serves, and there source 1 (rows
   seeded before BUT-1838) can genuinely hit the cap — so a `gdprCompliant: false` here is
   not necessarily an outage.
   *(Corrected 2026-08-15. This clause used to cite `rosterUnclaimed()`, deleted by
   BUT-1838, and `authorizeDeparture` refusing direct chats — that function survived the
   ticket by moving to `groups/remove-chat-group-member.ts`, where it takes `{memberIds,
   adminIds}` and never sees a direct conversation. See the AMENDED block below.)*
   **That branch reports the step INCOMPLETE** (`deleteMessages` returns false →
   `failedCollections` → `gdprCompliant: false`). A `direct_` id is literally
   `direct_<erasedUid>_<survivorUid>`, so a conversation left standing keeps the erased
   user's identifier in its own document id, where no field-keyed probe can ever see it.
   The erasure is not done and the audit row must not say it is.
2. a `collectionGroup("participants").where("participantId","==",uid)` sweep, capped at
   `MAX_ROSTER_SWEEP_ROWS` (2000) and DECLINING rather than truncating above it, because a
   planted roster lets somebody else choose the size of a victim's erasure bill (BUT-1830). Both outcomes would be
   loud — the probe beside it is an uncapped `count()` — so declining is chosen for being
   strictly less erasure at the same alarm, not for being the only loud one. Its cost: a
   planted roster also blocks the sweep of the victim's LEGITIMATE rows, with no automatic
   retry (the auth user is gone), so recovery is a human running `admin/reset-user-data.ts`.

**AMENDED 2026-09-03 (BUT-1917/BUT-2010) — the recovery this entry names cannot currently
run. The cap and the decline are unchanged; only the sentence about what happens afterwards
is wrong.** `admin/reset-user-data.ts` aborts before it deletes anything: `tag_configs` sits
in both `COLLECTIONS_TO_DELETE` and `COLLECTIONS_TO_KEEP`, and `main()`'s overlap guard
`process.exit(1)`s ahead of Phase 1, in dry-run and live alike. Measured 2026-09-03 while
building BUT-1917's sibling cap; the overlap dates to `b9a95bd02` (2026-03-19), where the
KEEP entry was renamed into collision. Filed as BUT-2010, deliberately NOT fixed inside a
GDPR commit — repairing it revives a destructive whole-project reset that has been inert for
months, which is Malin's call.

The clause is left standing rather than struck, per this file's rule that a decision record is
superseded and never deleted. What it should say once BUT-2010 lands: recovery is a human with
the Admin SDK. Even repaired, that script is a whole-project clean slate (Phase 1 deletes every
auth user, Phase 3 wipes both storage prefixes), so it is a dev-reset tool rather than a
per-user remedy for one declined sweep. The equivalent clauses in
`account-deletion-cascade.ts` were struck in BUT-1917's commit.

**SUPERSEDED 2026-09-05 (BUT-2010) — the overlap is gone.** Malin chose to
fix it rather than delete it, once it emerged that this entry and `MAX_BLOCK_SWEEP_ROWS` name
it as the recovery for a declined Art. 17 sweep, i.e. an Art. 17 promise rather than dead code.
The `tag_configs` entry is out of `COLLECTIONS_TO_DELETE`, and
`scenario_resetScriptListsDoNotOverlap` now reddens if the two lists ever overlap again — the
guard worked for five and a half months and nothing watched it fire, which is what made this
silent.
One clause above is now false and is corrected here rather than in place: the equivalent
clauses in `account-deletion-cascade.ts` were NOT struck in BUT-1917's commit — that docstring names the script to this day and was amended,
not removed.
**What has NOT changed is the part that matters most.** This entry's own reading stands: even
repaired, the script is a whole-project clean slate (Phase 1 deletes every auth user), so it is
a dev-reset tool and not a per-user remedy for one declined sweep. The honest recovery for that
case is a human with the Admin SDK. And making it runnable exposed two dormant defects — its
header claimed to wipe all user data while collections with `firestore.rules` blocks sit in
neither list, and Phase 1 races the live `onUserDeleted` — so BUT-2028 now forbids running it
against real data until those are resolved. BUT-2010, 2026-09-05

**AMENDED 2026-09-05 (BUT-2028), same commit.** The prohibition above is enforced in code, not
in prose: `main()` exits 1 on a live run unless `--but-2028-acknowledged` is passed, ahead of
`initializeAdminApp()` and Phase 1, with `--dry-run` unaffected. Written because repairing the
overlap guard removed the only mechanism standing between `npm run reset-user-data` and a
hardcoded production project — the same shape as the guard it replaced, so
`scenario_resetScriptRefusesLiveRuns` watches this one. The recovery named in this entry is
therefore refused-unless-acknowledged rather than unavailable. BUT-2028, 2026-09-05

**SUPERSEDED 2026-09-06 (BUT-2028) — this entry's PROHIBITION ON LIVE RUNS is lifted, in both
places it is stated: the BUT-2010 block's closing sentence ("BUT-2028 now forbids running it
against real data until those are resolved") and the 2026-09-05 amendment above. Keyed on the
claim rather than on a position, because a supersession that points at "the paragraph above"
leaves the same claim standing wherever else it was written.** These symbols are gone:
`--but-2028-acknowledged`, the `exit 1`, and `scenario_resetScriptRefusesLiveRuns`. The
prohibition was temporary by construction — it existed only while the hazards BUT-2028
records stood open, and they are closed: every collection is now decided (delete / keep /
registered-untouched, with a two-source coverage guard), and the Phase-1 race is NARROWED and
DETECTED — not eliminated — by a kill switch the run sets and clears, **exercised in
production on 2026-09-06 in both directions** (flag set: `onUserDeleted` skipped and logged
`SKIPPED`; flag clear: the cleanup ran). A gen1 trigger has no bounded delivery time, so an
event can still arrive after the flag is cleared; Phase 4 prints `EXPIRED before the run
ended` when the suppression lapsed mid-wipe, and that run is raced.

The last barrier on a live run is now the typed `CONFIRMATION_PHRASE` in `main()`,
`!dryRun`-scoped and above the only `runPhases(` call, watched by
`scenario_resetScriptRequiresTheConfirmationPhrase` — which keeps the check that carried the
BUT-2010 lesson: no npm script may type the phrase for the operator. Note the one ordering
change: the old refusal sat above `initializeAdminApp()` and fired without credentials, while
the phrase prompt sits below it, so a credential failure now pre-empts the prompt. That fails
toward not running.

Still true, and the reason this entry exists: the script is a whole-project clean slate, never
a per-user remedy.

**Malin's instruction, 2026-09-06** — she was shown that the kill switch had been exercised
in production in both directions and said to lift the refusal. She was NOT shown the
alternative of keeping it until the Cloud Scheduler question (BUT-2036) is decided; that
option was never put to her, so reinstating the refusal on that ground is hers to take.
BUT-2028, 2026-09-06

**OPEN:** whether Cloud Scheduler must be paused for a live run. The weekly jobs delete and write in the same collections,
unaware a reset is running. BUT-2036, not a strike. BUT-2028, 2026-09-06

**AMENDED 2026-08-15 (BUT-1838) — the cap's stated reason went stale one day after it was
written; the cap itself is unchanged and still must not be removed.**

This section, and four comments in the code, justified `MAX_ROSTER_SWEEP_ROWS` by the
bootstrap write branch. BUT-1838 deleted that branch on 2026-08-13 — a day after this was
written — and a whole-range integration review caught the code still citing it, including as
the reason for a control this document says must stay. Rewriting a control's rationale is how
the control gets removed later, so the replacement is stated precisely rather than loosely.

What BUT-1838 closed: the UNATTESTED branch, where anyone who guessed a conversation id could
seat rows under a parent that did not exist, on a path carrying no `rateLimitWrite`.

What still puts rows there, and therefore keeps the cap load-bearing:

1. **Rows seeded before BUT-1838 shipped.** Still on disk — the backfill (BUT-1839) was closed
   unbuilt by Malin on 2026-08-13 because the app is not live. Not hypothetical, just test data
   for now.
2. **A tampered or non-standard Admin-SDK writer.** Rules never see it.
3. **An ATTESTED client write — bounded, but live.** `attestedWriter()` (`firestore.rules`
   :1706-1708) requires the parent to name the writer AND the subject. A direct conversation
   `direct_A_B` names both, so A may write B's roster row with a `displayName` of A's
   choosing. A may also create that conversation: the create rule asks only for
   `directIdBinds`, two distinct uids and A's own presence — two adults need no friendship,
   because `passesMinorDmGate` fires only when the other party is a minor. The 10-second
   `rateLimitWrite('conversations', 10)` does NOT cap the rate: it reads
   `users/{uid}/rate_limits/conversations`, a bucket no writer in `lib/` ever stamps — the
   six that exist stamp `activity_events`, `comments`, `social_requests`, `messages`,
   `imports` and `friendSearchMigrated` — so `!exists(limitsPath)` is permanently true. The
   bucket is self-written (`firestore.rules`:522-524), so even a stamped one would not bind
   a tampered client. *(Corrected 2026-08-15: this clause previously credited that limiter,
   which understated the attacker and so understated the case for the cap.)* Against a
   CHOSEN victim this
   yields at most two rows per distinct peer account — `directIdBinds` accepts both
   orderings, so A may create `direct_A_V` and `direct_V_A`, each holding one such row — so
   it is unbounded only against your OWN uid. The write rule constrains a row's id SHAPE not
   at all: attestation requires only that the id APPEAR IN `participantIds`, which is itself
   never shape-validated. Both halves matter — dropping the second makes this bullet say an
   attested writer can seat rows at arbitrary ids, which contradicts leg 1 above.

**Frozen, and not up for simplification:** the DECLINE-rather-than-truncate behaviour and the
uncapped `count()` probe beside it. They are the Art. 17 completeness signal and do not depend
on which of the three sources is live. Raised by the Privacy/DPO seat on the 2026-08-15 panel,
which asked for exactly this sentence so that a future "the threat is gone, let's simplify"
edit cannot quietly weaken an erasure alarm this change never touched.

**Also restated, because it reads like the same fact and is not:** orphaning is still a one-way
door. Every predicate that could SURFACE a row reads through the parent, so deleting a
conversation leaves its surviving rows unreadable forever. It does NOT make them un-writable: the `(u1)` self-cursor update branch
and `allow delete` are parent-free self checks (`firestore.rules`:1860-1862, :1873-1874), so
the row's own subject could still stamp or delete it, and no client flow does. Measured with a
throwaway probe against the live rules, orphaned row acting as its own subject: READ denied,
UPDATE allowed, DELETE allowed. The verdict and the ordering are unaffected — but do not lean
an Art. 17 argument on "un-deletable", which is the sentence this note exists to stop.
Before BUT-1838
that write was worse — it re-opened the bootstrap branch over those rows — but the ordering in
leg 1 (clear the roster first, abandon the parent delete if that fails) is unchanged, because
the milder consequence is still bad.

The phrase "not a live client write path" appears at none of the amended sites, on the Security
Architect's condition: it is the sentence a future reader would cite to remove the cap.

Erasure of the user's OWN `conversation_memberships` rows is untouched by all of this and
already happens in `deleteUserSubcollections` — noted because the same change set stopped
READING that collection, and a later reader should not mistake that for an erasure change.

A third thing changed for the same reason. `tryClearRoster`'s three error logs, and the
new "conversation left standing" warning, HASH a `direct_` conversation id
(`logSafeConversationId`). The helper's code did not change; its key space did — until
BUT-1822 its only caller was a group-only trigger with UUIDv4 ids, and a direct id is two
raw uids in a sink that outlives the account.

`probeResidualData` gained the matching collection-group leg — it could not see this class
at all before, so it certified every such erasure clean. It fails CLOSED while the new
index builds (FAILED_PRECONDITION counts as residual, a false alarm rather than a false
all-clear). Index: a `fieldOverrides` entry on `participants`/`participantId`, both query
scopes, deployed to READY before the function.

**Still open:** the fix is forward-only. Rows orphaned by deletions that ran BEFORE this
shipped have no future deletion event to hang a sweep on, and case 1 of the three deleters
(a participant deleting the conversation from the UI) still orphans rows naming other
people.

The forward-looking half stays open under BUT-1825. The historical half does not: **Malin
closed the backfill (BUT-1839) unbuilt on 2026-08-13** — the app is not live and the project
holds development data only, so every row a pre-BUT-1822 deletion left behind belongs to a
test account. That is a fact about the DATA, not about the code, so it expires the day real
users exist; the ticket records what would have to be built and when to reopen it. Do not
read this entry as saying the roster is clean.

---

## BUT-1838 — group chat becomes a chat with a shared group (2026-08-13)

### The roster bootstrap branch is closed, and so is its twin on the read side

`conversations/{id}/participants` used to authorise a write as
`attestedWriter() || rosterUnclaimed()`, and a read as
`parentNames(uid) || (parentDoc() == null && you hold a row)`. Both permissive halves
existed for one reason: `createGroupConversation` wrote the conversation to
`users/{creatorUid}/conversations/{id}` while the roster went to the top-level path, so the
parent legitimately did not exist when the rows were written. Rules cannot distinguish "not
written yet" from "deleted", which is what made the branch reusable by an attacker and
permanent after any delete.

`createChatGroup` writes the group document, the top-level conversation and every roster row
in ONE Admin-SDK transaction. The parent therefore exists before any row does — for groups
and for directs — so attestation alone is sufficient and both branches are deleted.

Two things about this are easy to get wrong later:

1. **The read fallback was a SECOND, textually separate spelling of the same idea.** Deleting
   `rosterUnclaimed()` alone would have left the pre-seat residual (test P3B) alive through
   the read rule. They went in the same edit.
2. **The remaining write rule is NARROWER than "attested".** It is
   `attestedWriter() && !('groupId' in parentDoc().data)`. Without the second conjunct any
   attested group member could `set()` a peer's roster row directly, bypassing
   `addChatGroupMembers` and therefore the minor-membership gate, while also choosing what
   that peer is called in a roster the whole group reads.

Test P3B flips from ALLOW to DENY. That flip is the intended signal of this change; a future
session finding it red should not restore the branch.

### A client can no longer create a group conversation at all

The `conversations` create rule now requires a `direct_` id bound to its own two participants
(`directIdBinds`, both orderings), a de-duplicated participant list of at least two, the
caller in it, and `metadata.creatorId` PRESENT and equal to the caller. Group conversations
are created only by `createChatGroup` under the Admin SDK.

This closes BUT-1830 rather than bounding it: the squat it recorded — one write at a known
group id that permanently disarmed the child-safety trigger and bricked the group with no
recovery — has no reachable payload left.

`metadata: null` on create still denies (test C7B). **A warning that used to sit here is now
false and was corrected the same day.** The old conjunct was
`!('metadata' in d) || !('creatorId' in d.metadata) || … == uid`, whose `||` hatches allowed an
absent creator, so only a CEL evaluation error stood in the way — hence the standing
instruction never to harmonise it with the update rule's `is map` ternary. Against the new bare
equality that is untrue: a ternary resolving to null still fails `null == uid`. The
`firestore-rules-tester` gate found it by running the forbidden edit as a mutation probe and
watching NOTHING redden. The behaviour is stronger than the accident it replaced; do not
re-introduce the `||` hatches to restore the old asymmetry.

### The minor gate moved from a trigger to the invite path — and the residual is decided

`enforceGroupMinorMembership` was an `onDocumentCreated` trigger on `conversations/{id}`: it
judged the participant list in the instant the chat was born and never ran again, so anyone
added later had been checked by nobody. There was no "was invited" moment to move it to,
because the chat WAS the list.

`chat_groups` supplies that moment. `groups/minor-membership-gate.ts` is now the single
policy, asked BEFORE every membership write by all three callables, and asked again after the
fact by the same trigger — repointed to `onDocumentWritten("chat_groups/{groupId}")` and kept
as belt-and-braces on a child-safety control. Because membership records `memberAddedBy`, the
backstop judges each member against whoever actually seated THEM; the old core could only ask
about the group's creator, which is the defect in one sentence.

**The residual, decided by Malin on 2026-08-13:** the gate checks the INVITER, not everyone
present. A minor invited by a friend can be messaged in that group by adults who are strangers
to them. She was shown the stricter alternative — every existing member must be a friend of
the minor — and its cost: a group containing a teenager becomes possible only when everyone
knows the teenager, and any later invite of a stranger is blocked while they remain. Trust and
Safety observed that both the DSA and app-store guidance are converging on who may CONTACT a
minor rather than who may ADD one, and still recommended shipping this and filing the stricter
variant separately. Do not widen it silently; do not narrow it back to "the creator".

### "A new member sees only from now on" is a rule, not a filter

Malin's decision 2: membership is live, but history before you joined is invisible to you.
The stamp is `conversations/{id}.memberSince.{uid}` — on the CONVERSATION, because that is the
document `firestore.rules` already gets to authorise a message read, so the cut-off costs
zero extra reads.

Two halves, and neither works alone:

* The `messages` READ rule refuses `sentAt < memberSince[uid]` for any conversation carrying a
  `groupId`, spelled `.get('memberSince', {}).get(uid, request.time)` — fail-closed twice, since
  indexing an absent key would be an evaluation error and the default denies everything.
* The `conversations` UPDATE rule adds `memberSince` and `groupId` to its deny-list. That rule
  is a DENY-list, not an allowlist, so without this any group member could rewrite their own
  stamp and read the backlog, or raise someone else's to hide history from them. **The first
  draft of this change shipped the read rule without the update rule and was caught in
  review.** If you add another server-owned field to a conversation, add it to that list in the
  same edit.

The client mirrors the rule as a `sentAt >=` query filter. That is not belt-and-braces: a
Firestore query returning even one document the rules refuse fails ENTIRELY, so a stale client
stamp shows an error rather than silently missing messages.

### Sending a message now requires being in the conversation

The `messages` create rule checked only that you were who you claimed to be, so any signed-in
user who knew a conversation id could inject messages into strangers' chats — unreadable to
them, but written. Direct ids are derivable from two uids and `public_profiles` is readable by
any signed-in user, so the id was never a secret. Fixed in the same change at Trust and
Safety's insistence. It costs one document read per message sent; checking the sender's own
roster row instead would cost the same read and bind the write to a mirror rather than to the
membership.

### Membership has exactly one writer

`groups/chat-group-writes.ts` is the only code permitted to write `memberIds`,
`participantIds`, `memberSince` or the roster's `joinedAt`. The same fact lives in three
documents because three readers need it and none can read the others (the group is the truth,
the conversation is what rules can see, the roster is what the client lists). Three copies is
the shape BUT-1798 and BUT-1732 both punished; the mitigation is not fewer readers but one
writer, one transaction, one computed `Timestamp`. The GDPR cascade imports that writer rather
than re-implementing removal, and `deleteMessages` skips any conversation with a `groupId` so
the two legs cannot race.

### Renaming a group is gated by ORDER, not by a rule on the visible name

`updateConversation` writes `chat_groups.name` first and lets it throw, then
`conversations.title`. That ordering IS the control, and it is worth stating
plainly because it is weaker than it looks: `firestore.rules` gates the group
write on `uid in adminIds`, but the conversations update rule has **no conjunct
on `title`** — any participant may change it. So a hand-rolled client that skips
the group write can rename what members SEE, while the group document and the
Art. 15 export keep the true name.

What holds today: the app's only rename path goes through this method, so the
server's refusal of the group write is what stops a non-admin before anything
visible changes. What does not hold: this is not a rules-level guarantee, and a
future caller reaching `MessagingService.updateGroupTitle` another way would walk
past it.

The same shape applies to DELETING a group conversation: `MessageDeletionModule`
refuses one carrying a `groupId` and the conversation list hides the delete tile
for one, but `firestore.rules` still permits any participant to delete the
document. Both are UX, not controls, and they close with the same kind of rules
change.

Recorded rather than fixed because the real close is a rules conjunct (`title` in
`affectedKeys()` on a `groupId` conversation ⇒ caller in `adminIds`), which is a
rules change with its own test surface and its own ticket. Raised by the
`firebase-backend-security` gate, 2026-08-14, on the grounds that a residual
living only in a code comment is not a decided deviation.

### `adminIds` is immutable, on purpose

Set at creation, denied by every rule and touched by no callable. Promoting or demoting an
admin is a feature that does not exist; when it is built it needs its own gated callable, not
a widened update rule. A widened update rule here is the same mistake as the
`metadata.creatorId` smuggling BUT-1788 had to close.

### GDPR

Erasure gained `deleteChatGroupMemberships`, with its matching `probeResidualData` leg in the
same edit (a leg without a probe is how an erasure becomes silently incomplete), a `createdBy`
re-homing to a surviving admin mirroring `deleteFamilyData`, and a capped sweep that DECLINES
rather than truncating.

Export: other members' `memberSince` is stripped and the requester's own kept — reasoned on
its own merits, following `perUserSettings` (dropped) rather than `lastReadTimestamps` (kept),
because when someone else joined is third-party behaviour. A `chat_groups` PROJECTION was
added for the one fact the conversation does not carry (who added YOU); never the raw
document, because a second copy of a redaction decision is how two sections drift.
**That redaction was chosen conservatively without asking Malin**; widening it to keep other
members' stamps is hers to decide.

## Pantry — the unit dropdown (2026-08-15)

### The unit dropdown keeps its eight units and widens per item (BUT-1858, 2026-08-15)

**Verdict: the pantry sheet offers the same eight units it always has, and a stored unit it
does not offer is added to the list for that one item.** Malin's explicit call, 2026-08-15.

**The defect.** The sheet clamped any stored unit outside `st, g, kg, ml, dl, l, tsk, msk` to
`st`, because `DropdownButtonFormField` asserts in its constructor, on every build, that
exactly one item matches its value — in debug the screen falls, in release the control renders
blank. `_submit` then wrote the clamped value unconditionally, so opening a row stored as
`1 knippe rosmarin`, changing nothing, and pressing Save silently rewrote it to `1 st`.

Off-list units are not hypothetical. The shopping-checkoff flow
(`ShoppingCheckoffPantryService.onItemCheckedOff` → `PantryService.addFromShoppingItem` →
`addFromText`) stores a shopping item's unit verbatim — `UnifiedShoppingItem.unit` is a
non-nullable free-text String, so neither fallback on the way down fires — and that text comes
from a plain input field or from parsed recipe units (`förp`, `påse`, `krm`, and `''` for an
amount-less line). The flow sits behind the `autoAddBoughtToPantry` opt-in, off by default but
shipped.

**Second-order cost, which is what made this worth fixing rather than documenting.** That same
flow dedups on name + exact unit. Once a `förp` row had been clamped to `st`, the next
check-off of the same item no longer matched it and created a duplicate pantry row instead of
aggregating.

**The two rejected alternatives**, both put to Malin with their costs:

1. *Adopt `UnitDefinitions.standaloneUnits` as the menu* (88 entries). No data loss, and it
   looks like the tidy answer — one list instead of two. Rejected because that set exists to
   RECOGNISE what a parser may find in a recipe: it holds `pers`, `personer`, `gallons`,
   `tablespoons`. A set you must recognise is not a set you should offer, and conflating the
   two questions would make the dropdown worse, not just longer.
2. *Keep the clamp for display, write back the original if untouched.* Smallest change, but
   it makes the screen disagree with storage — its own trap, and a harder one to see.

**What shipped.** `AddPantryItemSheet.unitOptions(storedUnit)` returns `(values, selected)`:
an off-list stored unit is prepended and selected, an on-list one leaves the list untouched,
and an EMPTY stored unit selects nothing — `PantryItem.copyWith(unit: null)` then preserves it
rather than inventing `st`. `_unit` became `String?` for that last case.

**The deliberate divergence from `RecipeFormState.mealTypeOptions`.** The two seams solve the
same bug class (BUT-1845) and are keyed
differently BY THEIR CALLERS. The two BODIES are identical apart from the vocabulary each
closes over, so one parameterised helper would serve — what differs is the ARGUMENT each caller
passes, and that is the part test 8 refuses. (They are not interchangeable as they stand:
swapping a call site would offer meal types in the unit dropdown.) Meal type is called with the
CURRENT selection, so its injected row disappears once you
pick something else; this one keys on the STORED unit, so the injected row stays on offer and
a mis-pick is undoable. Do not harmonise them. If a third copy of the seam appears, that is
the moment to extract one helper — not before.

**Pinned by:** `test/unit/views/pantry/pantry_unit_options_test.dart` (the widening rule, and
a literal assertion on the eight-entry vocabulary and its display order — the case whose red
message says WHY, though it is not the only one: half-applying alternative 1 also reddens the
off-list-prepend case and widget tests 7-8, because `knippe` is itself in `standaloneUnits`)
and `test/widget/views/pantry/add_pantry_item_sheet_test.dart` tests **1 and 7-10** (an off-list unit survives an untouched
save; the injected row survives a pick and can be chosen back; an empty unit is preserved; and
both add branches send the picked unit — test 1 for the ingredient path, test 10 for raw text.
Test 1 is the ingredient branch's ONLY guard; do not read the 7-10 range as
complete). Test 7 pins the widening and stays green under the
harmonisation mutant — test 8 is the one that catches it.

**Known and out of scope:** an empty unit renders a trailing space in the pantry list, at
`pantry_item_card.dart`'s `'${item.formattedQuantity} ${item.unit}'`. Filed as BUT-1863, and
that line carries a pointer back. It existed before, but this change makes it durable, because
opening and saving no longer normalises the unit away.

## Poll votes on non-poll messages, and the missing `memberSince` cut-off (BUT-1832, 2026-08-17)

**Decision (Malin, 2026-08-17): ship, fix separately, record it.**

### What the gap is

`match /messages/{messageId}/poll_votes/{voterId}` gates writes on `pollIsOpen()`:

```
pollMessage().data.get('metadata', {}).get('poll', {}).get('isClosed', false) == false
```

A nullable map has four states here and this chain gives three answers. Measured 2026-08-17,
and each row has its own green test in `functions/src/__tests__/poll-votes-rules.test.ts`:

| `metadata` | result | test |
| -- | -- | -- |
| absent | ALLOWS a vote | V10e |
| `null` | DENIES (CEL error on the second `.get`) | V10d |
| a map with no `poll` key | **ALLOWS a vote** | V10f |
| a real open poll | ALLOWS | V1 / V2 |

Row 3 is the live one. `Message.recipeShare`, `Message.menuShare`, `Message.shoppingListShare`
and the group system-message Cloud Function all write a metadata map with no `poll` key, so every
share card and every system row in every chat currently accepts a `poll_votes` row.

Eleven further shapes were swept during review; every one either falls inside row 3's class or
fails closed. Notably `isClosed: "true"` denies, so a tampered client cannot force the branch open
with a non-boolean.

### Why it ships

The harm bound Malin was shown, and decided on:

- the row carries only the caller's own uid — `isValidVote()` pins `data.voterId == voterId` and
  every write verb pins `request.auth.uid == voterId`;
- it is limited to three keys and at most 20 option ids;
- reading the tally is gated on conversation membership;
- `deletePollVotes` erases it by collection group at account deletion;
- no UI renders it.

And the counter-argument against fixing it here: this is a salvage of a batch that was already
held once, and a rules-semantics change inside a salvage is precisely how the preceding sprint
lost three tickets. The rule is new but the *shape* is not a regression this change introduced.

### The repair, and the trap in it

**Test `poll` for PRESENCE, not `metadata` for TYPE.** The obvious repair — the
`x is map ? ... : null` ternary BUT-1788 established for the conversations rule — does NOT close
row 3, because a map without the key is still a map. A repair written from the null case alone
would land, look finished, and leave the live case open.

Mutation-probed during review, all three through a copy (the rules file was never written):

| mutant | result |
| -- | -- |
| the owed repair (`is map && 'poll' in metadata && ...`) | 31/33 — reddens exactly V10e and V10f |
| `is map ? metadata : null` | 33/33 — the gap stays open, silently |
| `is map ? metadata : {}` | 32/33 — reddens V10d; flips null to ALLOW |

So the tests do not *force* the repair; they register which cases it has decided. That is stated
in their own comments rather than left to be discovered.

**Art. 15 / Art. 17 asymmetry to close in the same change:** the export probes only messages where
`metadata['poll'] is Map`, while the cascade erases by collection group regardless of parent shape.
A vote row planted on a share card is therefore erasable but not exportable. Cover both sides.

### The second entry: `inPollConversation()` is not full parity

The helper's own comment introduced it as "the same membership test the message read rule uses,
one document further out". The membership half is the same; the rest is not. BUT-1838's
`memberSince` history cut-off is **not** reproduced. Measured 2026-08-17 on a group whose
`memberSince` postdates the poll:

- late joiner reads the poll MESSAGE → **DENIED** (the cut-off)
- late joiner reads the poll_votes TALLY → **ALLOWED**
- late joiner CASTS a vote in it → **ALLOWED**

The write half is the part a read-focused reading misses; a future editor repairing "the read"
would have no reason to look at `create`. Also deferred out of the salvage, for the same reason,
and the fix is the cut-off on the read AND the create/update limbs.

**Second Art. 15 route, orthogonal to the map-without-`poll` one above.** Because a late
joiner may CAST a vote in a pre-join poll, and the conversations export applies the
`memberSince` filter that drops that message before the vote probe runs, such a row is
erasable (the collection-group sweep ignores parent shape) but never exportable. The entry
above names the export gap for the map-without-`poll` case only; this is a different way in
to the same shortfall, and the repair must cover both. Raised by the
`firebase-backend-security` gate, 2026-08-17.

Both raised by the `firestore-rules-tester` gate during the BUT-1801 salvage review.

## BUT-1906 — the recipe grid card draws no dietary row

**Decided 2026-08-23 by Malin, shown against two alternatives and their costs.**

The ticket asked for the vegansk/vegetarisk row to appear on grid cards, so that a recipe
does not appear to lose its dietary information when the user flips the view toggle. Its
prescribed remedy was to raise the tile's aspect ratio to make room. That remedy was already
refuted by measurement under BUT-1906's first pass: the shortfall is not vertical.

It is horizontal, and it does not close. Measured on a 2-column tile with the production
card:

| | needs | has on 360dp | has on 320dp |
|---|---|---|---|
| `vegansk` at 1.0 | 111 px | 88 px | 68 px |
| `vegetarisk` at 1.0 | 145 px | 88 px | 68 px |
| `vegansk` at 2.0 | 188 px | 88 px | 68 px |
| `vegetarisk` at 2.0 | 255 px | 88 px | 68 px |
| any allergen badge | 28 px | 88 px | 68 px |

A grid tile's whole content column is 68 logical pixels wide on a 320dp phone once the card
margin and the container padding are taken off. The allergen badges fit because they are
icon-only. A dietary badge carries its word, and the word does not fit at any text size on
any phone.

**Alternative 1 — icon-only, matching the allergen row.** Available, and useless. The badge
takes a `showLabel` flag and the allergen row already passes `showLabel: false`, so it is one
argument away — but `DietaryStatusBadge` selects its icon from the STATUS, not from the diet,
so vegansk and vegetarisk both render `Icons.eco_outlined`. Dropping the label would replace the row with
two identical green leaves: not a compact treatment, an information loss. Giving each diet
its own icon is a real option, and a real design decision — it is not this ticket.

**Alternative 2 — ellipsize the word.** Fits by definition, and reads as broken: at normal
text size roughly half of `vegetarisk` survives, and at 2x about two characters do. It also
degrades precisely for the user who most needs the label.

**What was chosen.** Neither. The grid keeps its icon-only allergen row and no dietary row;
the DETAILED layout is full-width, has the room, and keeps the word. The asymmetry between
the two view toggles is therefore the decision rather than the gap the ticket described.

*(Corrected 2026-08-23, before the commit landed: the first draft of this entry, and the two
comments quoting it, offered the COMPACT layout as further evidence that the word survives
outside the grid. It draws neither badge row, so it was never evidence. The decision is
unchanged; only the false half of its supporting sentence is struck. Raised by the
`integration-reviewer` gate.)*

**Pinned by** `test/widget/recipe/recipe_card_grid_badges_test.dart`: one case asserts the
grid draws no `CompactDietaryRow` when the card is handed dietary preferences and the recipe
is FREE on a diet, and its control asserts the detailed layout still does — so a change that
removed the row everywhere cannot pass as satisfying this decision.

---

## The chat duplicate guard marks; the comment guard deletes

**BUT-1904 / ADR-0009, Malin's explicit call 2026-08-26.**

`guardDuplicateMessage` no longer ends a duplicate with `tx.delete`. It empties the message
(`content: ""`) and stamps `type: "duplicateBlocked"` in place. `senderId`, `conversationId`
and `sentAt` are untouched — `sentAt` is the row's position in the thread, and the whole
promise to the sender is a row where the message would have been. That sender sees a
localized notice there; every other participant's client drops the row in
`MessagingService._filterBlocked`.

`guardDuplicateComment` is unchanged and still deletes: global per-author key, no length
floor, no flag, live since 2026-05-04. The two surfaces now differ in five settings, and that
is the decision. A duplicate one-word comment is spam; a duplicate one-word chat message is
conversation, and a chat message that vanishes reads as the app losing it.

**The full reasoning, the alternative it was chosen over, and what it costs are in
[ADR-0009](../org/adr/ADR-0009-the-duplicate-guard-marks-instead-of-deleting.md).** Read it
before arguing with any line here. In one sentence: marking also kills the
`syncConversationLastMessage` race by construction, because nothing on this path is destroyed
any more, and it keeps the row inside the Art. 15 export and the Art. 17 cascade with no new
collection.

### The parts that are load-bearing, and each die alone

1. **The guard uses `tx.update` and never `tx.set(..., {merge: true})`.** A sender who deletes
   the message between the create and the trigger must not have it written back, and a merge-set
   would RESURRECT it — a deleted message reappearing, emptied and stamped, is worse than the
   duplicate ever was. That property comes from the VERB: `tx.update` on a missing document
   throws NOT_FOUND and the document stays absent.

   *(Corrected 2026-08-26, before this landed: this item credited the transactional READ for the
   property and cited D10 as pinning it. Both halves were wrong, and the two other copies of this
   decision already said so — the code at `duplicate-content-guard.ts` and D10's own header, which
   states it pins the OUTCOME and deliberately not the existence check. A future editor reading
   only this file could have swapped the verb for a merge-set believing the read protected them.
   What the read actually buys is a clean no-op instead of a burnt transaction attempt and a
   spurious error log. Raised by the `integration-reviewer` gate.)*
2. **`firestore.rules` refuses a client update to an already-blocked message.** The sender's
   own update branch otherwise places no constraint on `type` and lets `content` become
   anything, so without the conjunct the sender could write the duplicate text straight back
   in and hand it to the other participants after all. Deleting a blocked row stays allowed by
   the rules. Pinned in `cook-snaps-and-message-mod-rules.test.ts` with an ALLOW control on an
   ordinary message by the same sender, and mutation-probed.

   *(Corrected 2026-08-26, before this landed: that sentence read "Deleting a blocked row stays
   allowed: that is how the notice is dismissed", with the test citation attached — which made
   the false half read as proven. The rules test pins that the RULE allows the delete. It cannot
   pin the dismissal, because no screen in the app reaches it: `MessageBubble` returns before it
   installs the long-press gesture, and that menu is dead for every message type anyway. **The
   sender cannot remove the row from inside the app.** See ADR-0009; whether the notice needs its
   own dismiss control is Malin's call.)*

   *(Superseded 2026-08-26, same day, before landing: "cannot remove the row from inside the app"
   is too broad. No PER-ROW dismissal reaches the delete — that part holds — but deleting the
   whole CONVERSATION reaches it in a DIRECT message. In a GROUP it does not: the
   delete-conversation tile is gated on `conversation.groupId == null`
   (`conversations_list_view.dart`), so a blocked row in a group has no removal path from inside
   the app at all. Measured by the `firestore-rules-tester` and `integration-reviewer` gates, in
   that order — the second correcting the first.)*
3. **`syncConversationLastMessage` tests `after.type` for blocked-ness DIRECTLY, never behind
   the candidate gate.** The mark's own invocation arrives already carrying
   `duplicateBlocked`, which is not a duplicate-guard candidate — so a gated test never runs,
   and `shouldReplaceLastMessage`'s `>=` tie rule then projects the blocked row and leaves
   every participant with an empty preview. This was a real defect in the first draft of the
   plan, caught by the plan auditor before any code was written. Pinned by the update-side
   replay case, and mutation-probed.

### What it costs, stated rather than implied

The duplicate's TEXT is destroyed and cannot be recovered from the row. The same text is a
few rows above — that it is the same text is why the row exists — but the copy is gone.
Weighed and accepted.

### Not a privacy control

Hiding the row from the other participants is a UI rule. What protects them is that the
SERVER removed the text; the client-side filter withholds only the bare fact that somebody's
message was stopped.

*(Corrected 2026-08-26, before this landed: that sentence read "removed the text before the
document was ever readable". False — and this was the THIRD copy of it. The other two were struck
first and this one was missed, which is exactly why a false claim gets swept file by file rather
than fixed where you noticed it. `guardDuplicateMessage` is `onDocumentCreated`: the client
commits the full text and the trigger runs after, so a participant with the thread open sees the
duplicate until the mark propagates. Harm nil — it is the same text they received moments
earlier, and it was equally true of the delete behaviour — but the guarantee did not exist.
Raised by the `code-reviewer` gate, twice.)* Do not cite it as a
boundary, and do not move it inside `_filterBlocked`'s fail-open try/catch — it is pure local
logic with nothing to fetch and nothing to throw. Two different moves are possible: into the
catch, or below the `filter == null` exit.

*(SUPERSEDED 2026-08-26 — Malin: build the dismiss control. Two claims in this section are
now false, and each bolded paragraph below quotes the one it retires.

**The sender CAN remove the row, from anywhere.** The notice carries its own `x`:
`SystemMessageWidget.onDismiss` -> `MessageBubble.onDismissBlocked` -> `_dismissBlockedNotice`
-> `ChatViewModel.deleteMessage`. That is the per-MESSAGE delete, not the conversation-level
one, so it works identically in a group and in a direct message. That closes the group gap
this section measured when it said a blocked row in a group had no removal path at all. No confirm dialog and no undo -- a fourth friction class, written
into `.claude/rules/ui-conventions.md` section "Destructive-action confirmation" rather than
here. The control is drawn only on the viewer's OWN row (`_isFromCurrentUser`), because
`firestore.rules` `allow delete` on `messages` is sender-only.

**And "withholds only the bare fact" is false for a client-stamped row.** No `firestore.rules`
limb bounds what `type` is written TO on a create or a sender update -- B16/B17 in
`cook-snaps-and-message-mod-rules.test.ts` both ALLOW, and B17 creates a stamped row still
carrying its full sentence. `_withoutOthersBlockedRows` is type+sender only, so for such a row
the filter withholds the TEXT as well. That does not promote it to a privacy control: the row
was readable before any filter ran, and a hand-rolled client applies none. The conclusion of
this section stands; the reason given for it does not.

The Art. 15 export deliberately DIVERGES here and KEEPS such a row -- `isOthersBlockedRow`
requires `content == ''` -- because withholding a record from its own subject is the worse
failure. Do not harmonise the two. BUT-1954 carries the third surface, `searchMessages`, which
filters neither. Mirrored from `.claude/rules/accepted-deviations.md`, which was amended in the
same change; both files are edited together by this file's own header rule.)*

*(The sentence that stood here explaining why both placement cases exist — "neither kills the
other's" — was STRUCK 2026-08-26. The testing-specialist gate measured it false: on the
into-the-catch move the unregistered-filter case kills the throwing-filter case's mutant as
well. Both cases still earn their place, but not for the reason given, and no replacement
reason is written here — a fresh one would be another unmeasured claim in a ticket that has
already shipped several repairing each other. The tests themselves carry it.)*

### A fourth part, added after the first version of this entry

**The sync trigger's re-read covers UPDATES, not only creates.** `messages` has a second update
path — the read-receipt branch (`status`/`deliveredAt`/`readAt`/`updatedAt`) that every
recipient's client writes seconds after every message it is online for. That invocation carries a
PRE-MARK payload, so a create-only re-read skipped it and re-projected the blocked duplicate's
TEXT to every participant. Reproduced against the emulator by the `cloud-functions-specialist`
gate. Cost is bounded by running the two cheap checks (`sentAt` type, `shouldReplaceLastMessage`)
BEFORE the read, so an invocation that cannot end in a write pays nothing. Do NOT bound it by
gating on `enable_chat_duplicate_guard` instead: that flag caches per isolate for five minutes,
so switching it on would leave a window where one isolate marks while another skips its re-read.

**And do not gate the UPDATE side on candidacy either** — that was the second measured hole in the
same design. The guard decides candidacy from the CREATE payload and marks regardless, while the
sender update branch leaves `content` and `type` writable, so an update edited OUT of candidacy (a
sender trimming their message to "ok", reachable from shipped UI) skipped the re-read and landed
last on a blocked, emptied row. Creates stay gated on candidacy; updates re-read whenever they
survive the cheap pre-read gate.

**Every writer of the `messages` collection wakes this trigger** — client sends, the delayed
`status: "sent"` self-update, receipts, edits, deletes, the guard's own mark, the group system
rows, the profile-rename fan-out, and each leg of the GDPR cascade. That is why the gate is keyed
on the KIND of write (`isDelete` / `payloadBlocked` / `!!before`) and not on a list of writers: a
writer nobody thought of is closed for free. No count is given here on purpose — an earlier
version of this very sentence said "the create, the mark, every read receipt and every edit —
enumerate all four", which was itself a reasoned, incomplete enumeration embedded as the
corrective. Measured 2026-08-26: at least eight writers, and the omitted ones were already safe.

**The cost, accepted knowingly.** Every update that survives the pre-read gate pays one
transactional read — on the newest message that is the delayed `status: "sent"` self-update plus
each recipient's delivered and read receipts, so roughly two to three extra reads per message,
permanently, including while the flag is OFF and nothing can be marked. The bulk writers
(`onProfileUpdated`'s rename fan-out, the GDPR legs) are nearly free by comparison: the pre-read
gate stops them at one read per CONVERSATION rather than one per message. The cheaper shape —
gating on the flag — is refused above and must stay refused.

**Cosmetic consequences, listed so nobody rediscovers them as bugs.** No count: a third was
found the round after this paragraph was written — a reply whose target the guard marks loses its
quote block entirely for every OTHER participant, because the lookup resolves against the
already-filtered list, throws, and is caught. A blocked row shrinks
the loaded page, which can make `chat_message_stream`'s "you joined here" divider draw when the
join point is actually off-screen; and a blocked row sits between two messages from the same
sender, so `shouldShowAvatar` suppresses the avatar across it. These are pre-existing consequences
of BUT-544's block filter that this change widens, not new mechanisms.

## An offline weekly-plan read trusts a cached absence (BUT-1961, 2026-08-27)

**Decision.** `FirebaseWeeklyMenuPlanRepository.fetchForWeek` passes
`acceptCachedAbsence: true` to `BaseFirebaseRepository.getDocCacheFirst`. No other caller
does, and the parameter defaults to `false`.

**What it changes.** Firestore caches negative answers: a document fetched while online and
found missing is remembered as missing. `getDocCacheFirst` used to discard that answer and
re-ask the server, which throws with no connection. Since BUT-1939 that throw mints
`readFailed: true` and the viewmodel refuses to save — so planning a brand-new week offline
stopped working, because an empty week has no document to cache-hit on.

The flag applies ONLY after the server read has already failed. An earlier version of this change returned the cached absence *instead of*
asking, which made a stale "missing" authoritative without asking at all; that was caught in
review and is why the ordering is load-bearing. The catch is on ANY error, so a
`deadline-exceeded` on a flaky-but-connected network can still serve the cached absence —
the ordering narrows the window, it does not close it.

**The residual, stated plainly.** `fetchForWeek` is not a display-only read.
`WeeklyMenuPlanService._loadPlanForWrite` reaches it from the bulk write paths
(`setSlotPresence`, `setDayPresence`, `bulkMoveEntries`, `bulkAssignRecipes`,
`assignRecipeToTargets`), and a `null` there becomes `WeeklyMenuPlan.empty`, which `save()`
writes back as a full `set()`. So offline, a stale absence lets a write build on "empty".
`copyWeek` reaches `fetchForWeek` directly on both its source and destination fetch: the
destination side carries the same residual, and the source side turns a stale absence into a
silent `return 0`, i.e. "there was nothing to copy".

What bounds it is the rules layer, not the client: `firestore.rules`' `weekly_menu_plans`
update limb gates on `cannotModify(['userId','createdAt'])`, and `WeeklyMenuPlan.empty`
stamps a fresh `createdAt`. The write is therefore DENIED at reconnect. The server keeps
whatever another device wrote; what is lost is the user's own local edit, plus an
unexplained failure. That is the same residual shape BUT-1939 already accepted, and it is
why this is a deviation rather than a bug.

**Do not widen it.** A negative cache entry has no expiry — it lives until the cache passes
its configured size limit and LRU evicts it, or until a server read of that document
succeeds. Offline it can outlast the install.

The flag must not reach anything an allergen or a permission decision reads, and the profile
path shows why the direction matters. `UserService.lookupUserProfile` branches on HOW the
read failed: for anyone other than the signed-in user a null return gives
`ProfileLookup.missing()`, while a throw gives `ProfileLookup.unavailable()`. (For the
signed-in user null also gives `unavailable()` — they are definitionally at the table.) Per BUT-1663 those are opposite calls — `unavailable` widens
the union with the common-allergen floor, `missing` does not degrade the roster and the
member is left out of it. A stale cached absence produces the NULL, so it would drop a
member's allergens from the union rather than fall back to the cautious floor. That is the
unsafe direction, and it is the one this flag would take.

**Added 2026-08-27, same day, after the whole-range review.** The entry above named
`_loadPlanForWrite` and `copyWeek` as the consumers that matter, and that enumeration is
short. `WeeklyMenuPlanService.readWeek` also calls `fetchForWeek`, and it mints
`readFailed: false` for ANY null return — its own docstring already warned that a repository
mapping an unreachable week to null "reports `readFailed: false`", which is precisely what
this flag makes it do for a negatively-cached week.

The scope needs no counting and is one grep to check: the flag reaches only
`FirebaseWeeklyMenuPlanRepository.fetchForWeek`, so only the PERSONAL
`WeeklyMenuPlanService.readWeek` guards are weakened — including BUT-1928's PERSONAL
poll-close guard. The GROUP chain is untouched: `GroupWeeklyMenuPlanService` reads through a
different repository, which does not pass the flag, so the group poll-close guard beside it
still fires.

That is intended where the absence is TRUE — the week really is empty and there is nothing
to protect. Where the absence is STALE it means BUT-1928's guard, which sits on a one-way
door (closing a poll writes a winner into the plan), proceeds on a fabricated empty plan.
The same `cannotModify(['userId','createdAt'])` limb denies the resulting write, so the
server keeps what another device wrote. **That limb was unguarded when this entry was
written.** Measured 2026-08-27: neither `weekly_menu_plans` nor `group_weekly_menu_plans`
had any rules test. The protection was a side effect of
`WeeklyMenuPlan.empty` stamping a fresh `createdAt` — while the neighbouring `copyWith`
deliberately preserves it and has a test saying so, which is what a future "symmetry"
cleanup would copy. Both collections are now pinned by
`functions/src/__tests__/weekly-menu-plans-rules.test.ts` (W2 and G1), each mutation-probed
by dropping `createdAt` from its own rule and confirming exactly that one test reddens.
The guard Malin signed off in BUT-1928 is
weaker for this case than its own comment says, and that is worth her knowing rather than
discovering.

**Also not closed:** the fix only helps a week whose document was fetched while ONLINE at
some earlier point. A never-fetched week's `Source.cache` read throws, `cached` stays null,
and `getDocCacheFirst` rethrows — deliberately, and pinned by the test named "a cache MISS
is not a cached absence". So "planning a new week offline works again" is true only for a
week the device has seen before.

**Not closed by this.** The WRITE half of offline planning is a separate question:
`applyGeneratedMenu` awaits a `save()` whose Future does not complete until the server
acknowledges, so a generated week may still fail to render offline. Filed as BUT-1965, and
explicitly unverified on a device.

**SUPERSEDED IN PART 2026-08-29 (BUT-1975).** The paragraph above still describes the
await correctly — `applyGeneratedMenu` does await a `save()` that waits for the server.
Its CONSEQUENCE clause is now narrower rather than gone: while the calendar is ALREADY on
screen (kalender mode) a generated week does render offline. From the lista-mode
"Placera automatiskt" footer it still does not — `_onPlaceAutomatically` awaits the
result before switching the view mode, and the calendar widget is not in the tree until
it does, so offline the published week goes to a widget nobody is rendering. That
view-side half is unbuilt; it is written up in a comment on BUT-1975 (Linear's issue
limit refused a new ticket on 2026-08-29). Two things changed on the VM side, and only both together:
the distributed week is published to
`_plan` BEFORE the save is awaited, and `applyGeneratedMenu` now runs through
`_executeWrite`, which does not raise `isLoading` (`LoadingStateBuilder` consults that
before it looks at `data`, so a pending write used to render as a spinner regardless). Either alone leaves the week invisible offline, which is
why fas 2's reordering measured as no change and was rolled back.
The mechanism the paragraph describes was reproduced first — Chrome plus the Firestore
emulator plus `disableNetwork()`, 2026-08-28, on the WEB SDK: offline `set()` applies
locally
(`hasPendingWrites: true`) and its Future stays uncompleted until the connection returns.
That measurement is on BUT-1965. It was NOT reproduced on a phone; this machine offers only
Windows, Chrome and Edge, so the "unverified on a device" half of the sentence above stands.
A refused save now rolls the calendar back, guarded on the published plan still being the
resident one. Malin's decision, 2026-08-28.

## The weekly-menu `save` audits refusals only (BUT-1981, 2026-08-28)


`logPermissionCheck` moved inside the `if (!canWrite)` branch in both
`FirebaseWeeklyMenuPlanRepository.save` and `FirebaseGroupWeeklyMenuPlanRepository.save`.
Each granted save had written a plan document plus an audit document — two writes where one
would do. **Malin's explicit call, 2026-08-28.**

### The ticket's own framing was wrong, and is retracted

The row was described as a GDPR Art. 30 record. It is not. Art. 30 requires a *register of
processing activities*: controller and DPO details, purposes, **categories** of data subjects
and personal data, **categories** of recipients, third-country transfers, envisaged erasure
limits, and a *general description* of technical and organisational security measures. It
mandates no per-operation access logging, no granted-vs-denied decisions, and no
transaction-level records. Checked 2026-08-29.

Calling it an Art. 30 row turned a house rule into a legal requirement. The real source is
`lib/repositories/CLAUDE.md`, which now says `logPermissionCheck()` is required on a REFUSAL,
that logging grants is the default and right for most repositories, and that this is a
traceability rule rather than a legal one. Art. 32 (security measures) and Art. 5(2)
(accountability) remain arguments for keeping the **refusals** — not for a row per successful
write.

The same retraction was applied to `FirebaseAuditRepository`'s header and
`PermissionValidationMixin`. The sweep is NOT done: `lib/models/audit_log.dart` — the model of the row itself — still
calls it an Art. 30 record, and it is not the only one. **The heaviest survivor is not code:**
`docs/security/audit-logs-retention.md` is titled as the Art. 30 record for `audit_logs`, gives
every field the lawful basis "Art 6(1)(c) — legal obligation (Art 30 record)", and keeps a
deleted user's rows on Art 17(3)(b) on the same ground. That register rests on the premise
retracted here, so it is a legal document to re-derive, not a comment to strike — and it is why
this entry does not point `FirebaseAuditRepository`'s header at it: a citation would re-import
the premise. A retraction that lands in some
places is how the next session re-derives the requirement from a file that still asserts it.

### The two halves are NOT the same trade

**Per-user: the granted row recorded no decision.** `validateUpdatePermission` is
`entity.userId == userId && resourceId.startsWith('${userId}_')`, called as
`validateUpdatePermission(plan.userId, plan.id, plan)` — so the first conjunct is a tautology
and only a mis-keyed doc id can refuse. A cross-user `save` is refused by
`firestore.rules`.

**Group: it is a real reduction.** That gate takes the actor as a separate argument
(`entity.canEdit(userId)`), so its refusals are genuine permission decisions, and dropping the
granted row loses **edit history** on a document more than one person can write —
`lastModifiedBy` keeps only the last writer. Accepted because the only live caller is the
meal-poll close, so the history was thin. Do not re-describe this half as "a redundant row
removed"; the asymmetry is the decision.

### Load-bearing

`requireCurrentUserId()` is resolved **above** the gate in both repositories. It is the only
client-side authentication assertion on `save`, and from inside the refusal branch it
would throw on the way to the audit call — losing the very row this entry keeps. On the group
repo it sits inside the `userId != null` limb; a `save` with no `userId` asserts nothing
client-side, unchanged and bounded by the rules.

Both repositories' granted, refused and signed-out paths are pinned in their unit suites,
each mutation-probed. Before that, the entire change was invisible to the repository suites: they stayed green when the
audit call moved, and both group suites were green against the pre-change bytes, because
neither passed an `auditRepository` at all.

- **AMENDED 2026-08-29 (BUT-1971): the BUT-1981 entry says "the only live caller is the
  meal-poll close". That is no longer true, and the reduction it justified is now larger than
  what Malin weighed.** The group weekly-menu SCREEN adds an interactive write path —
  `GroupWeeklyMenuViewModel._edit` -> `GroupWeeklyMenuPlanService.save` ->
  `FirebaseGroupWeeklyMenuPlanRepository.save` — reached by remove and undo, from two
  entry points (the group chat and the menu tab), by every editor of the plan. The cost the
  entry names is exactly what this screen now produces: edit history on a document more than
  one person can write, unaudited, with `lastModifiedBy` keeping only the last writer.
  Nothing here is a re-filing of the decided call, and the granted-audit row has NOT been
  restored — that is a code change scoped to Malin. **Open for her: does the refusal-only audit
  still hold now that the writers are people rather than one server trigger?** Raised by the
  `integration-reviewer` gate. BUT-1971, 2026-08-29
  **RESOLVED 2026-08-29 — Malin: build an EDIT TRAIL instead. SUPERSEDED 2026-08-30 by
  ADR-0010 — see the BUT-1971 entry at the end of this file: the trail is client-written and
  not durable, so it does not buy what this paragraph claims, and the granted row is
  restored on the GROUP repository. Kept as the record of what was decided that day.** She was shown the
  security review's recommendation (restore the granted row on the GROUP repository only,
  ~1 extra write per interactive remove/undo) and chose the alternative it named beside it:
  an append-only trail on the plan document itself, which buys the same attribution with no
  second write. So the refusal-only audit STANDS as BUT-1981 decided it, and the traceability
  gap is closed by a design change rather than a revert. Not built here; it shares its model
  change, its `firestore.rules` change and its GDPR review with the per-entry provenance
  BUT-1971 needs for "framröstad av", and Malin asked for those to be planned as ONE build.

- **SUPERSEDES the BUT-1981/BUT-1971 audit entry, 2026-08-30 (ADR-0010): the granted audit row IS restored on
  the GROUP repository, and the edit trail ships beside it — both, not either.** That
  entry's RESOLVED clause chose the trail over the audit row on the stated ground that it "buys the
  same attribution with no second write". A full panel measured that the premise is false on
  both axes that made the audit row trustworthy. **(1) The trail can be lied in:** it is
  written by the client and `editTrail` is bounded only by its row cap, never validated
  element-wise, so any editor can write
  `{actorId: <another member's uid>}` and point at a groupmate for an edit they never made;
  the audit row stamps the AUTHENTICATED actor and `audit_logs` refuses a create whose uid
  does not match the caller. **(2) A genuine row can vanish:** `save` writes the whole
  document with `set()`, so of two legitimate editors on the same week the later one
  discards the earlier one's trail row — precisely the multi-editor case the trail was built
  for. Malin was shown both and chose to build both: the trail shows, the audit row proves.
  Cost: ~1 extra write per interactive remove/undo, not per view.
  **GROUP repository only.** The per-user repository keeps BUT-1981's reduction untouched —
  its gate is a tautology that never recorded a decision which could have gone the other
  way. Do not "harmonise" the two repositories. BUT-1971, 2026-08-30

- **A group menu's provenance is FORGEABLE, and that is accepted.** `entries` is not
  validated element-wise anywhere in `firestore.rules` — the name appears in exactly one rule
  expression, inside a `hasAll` presence list — so any editor may write any uid into
  `proposedBy` or `votedInBy`. No permission hangs on either field; they are descriptive.
  Malin's explicit call, 2026-08-29. **Corollary that is NOT covered by this entry and has
  its own dated line:** the same absence lets a trail row name the wrong person, which is a
  different harm. BUT-1971, 2026-08-30

- **A trail row can name someone who did not do it, and that is a different accepted risk
  from the forgeable-provenance entry.** Attribution under a dish is a wrong name on a suggestion;
  a trail row is an accusation about an action. Both are accepted, separately and knowingly
  (ADR-0010), and the mitigation for the second is that the audit row exists beside it. Do
  not cite the provenance entry as authority for this one — a decision about one field does
  not transfer to a field with another purpose, which is the citation error the BUT-1798
  entries already record. BUT-1971, 2026-08-30

- **The edit trail is NOT durable, and must never be used as evidence in a dispute.** Two
  legitimate editors on the same week means the later `set()` silently discards the earlier
  writer's row. Accepted because the alternative — a rules conjunct requiring the list never
  to shrink — would REFUSE the losing writer's whole write, so an ordinary removal would
  start failing. The record that can be relied on is the audit row. BUT-1971, 2026-08-30

- **Art. 15, group weekly menu: other members' per-dish provenance is KEPT.** `proposedBy`
  and `votedInBy` are uids the requester has already seen acted out — the whole group can
  open the week and read who put a dish there and how many voted it in. Malin's explicit
  call, 2026-08-29, **on its own merits**: NOT derived from BUT-1732, BUT-1772 or BUT-1774,
  which decided other collections, and citing any of them as authority here is the precise
  error the BUT-1732 entry records having made. **AMENDED 2026-08-30, same build:** this said "no code implements this — the export
  ships the document whole". That is no longer true: `_redactGroupPlan` now rewrites
  `editTrail`, so the section IS a projection and the keep decision depends on that
  helper leaving `entries` alone. It also gained a `data_minimisation` sentence naming
  what was withheld.
  BUT-1971, 2026-08-30

- **Art. 15, group weekly menu: the edit trail is FILTERED to rows where the requester is
  the ACTOR or the SUBJECT.** Another member's edits are third-party behaviour no screen
  shows; a row where somebody removed the REQUESTER's dish is about the requester, and an
  actor-only filter would drop it. Malin's explicit call, 2026-08-29, revised the same day
  from actor-only after Legal Counsel showed the under-disclosure. That second half is the
  only reason a trail row carries `subjectId` at all. **The asymmetry with the keep decision —
  votes kept, edits filtered — IS the decision.** Do not harmonise them "for consistency";
  that is the same shape BUT-1774 already had to defend once. The filter fails CLOSED: an
  unrecognised row shape is dropped. BUT-1971, 2026-08-30

- **OPEN, named rather than silent: a member who LEAVES a group without deleting their
  account keeps their uid on the plan's dishes and in the trail, indefinitely.** No cascade
  touches it — account deletion does (that is built), leaving does not. Malin has not taken
  a position; this is recorded so it is a known residual rather than a side effect of "we do
  not backfill". Related and equally unclosed: the "already visible on screen" reasoning
  behind the keep decision has NOT been tested against a week that predates a
  requester's membership. BUT-1971, 2026-08-30

- **SUPERSEDES the reasoning, not the decision, of the Art. 15 provenance entry —
  2026-08-30, same build.** That entry rests on "the requester has already seen it
  acted out: the whole group can open the week and read who voted a dish in". The
  screen does not show that. `group_weekly_menu_widget.dart` renders
  `groupMenuVotedInBy(entry.votedInBy.length)` — a COUNT — and no widget in `lib/`
  renders another member's voter uids. So the bundle ships names the app has never
  displayed. The KEEP decision is unchanged and still Malin's; what is withdrawn is
  the sentence justifying it, which was refuted by the same build that wrote it.
  **Open for her: does the keep still hold now that "you have already seen it" is
  false?** BUT-1971, 2026-08-30

- **RESOLVED 2026-08-30 — Malin: make the app show them.** Shown that the keep decision's
  basis was refuted (the screen drew a COUNT, the bundle shipped names), she was offered
  three ways out: keep with an honest new reason, strip the uids, or make the old reason
  true. She chose the third. The provenance row is now a tap target opening a sheet that
  lists the voters by name (`groupMenuVotersTitle`), so "the requester has already seen it
  in the app" is true as written rather than as hoped. Pinned by
  `tapping the row shows who voted`, and the sheet renders a neutral mark rather than a uid
  for a profile it cannot read. The KEEP decision is unchanged; what changed is that the
  app now earns it. BUT-1971, 2026-08-30

- **The edit trail does not explain a dish that was DISPLACED.** `addEntry` on a
  lunch or middag slot drops whatever was there and appends one row saying `added` or
  `pollWinner`; nothing records what went. Out of scope for BUT-1971, and named here
  rather than left to be discovered: it is the one edit a reader of the trail cannot
  account for, and the trail is a reading aid precisely for edits like it.
  BUT-1971, 2026-08-30

- **A client that read the plan BEFORE an erasure can write the uid back.**
  `FirebaseGroupWeeklyMenuPlanRepository.save` writes the whole document from the client's
  cached copy, so a member whose screen holds a pre-cascade snapshot resurrects the erased
  uid in `participants`, `memberPermissions`, `entries[].votedInBy` and the trail on their
  next remove or undo. Narrow — the screen is realtime-subscribed and the poll-close path
  re-reads first — and the roster half of it predates BUT-1971, but this build widened the
  surface beyond the roster field it started with. Named beside the leaving-a-group residual rather than left
  to be discovered; the close is the whole-write ticket, not a wrapper.
  BUT-1971, 2026-08-30

- **`GroupWeeklyMenuPlanService.removeParticipant` drops a uid from the two rosters and
  leaves it on `entries[].proposedBy`, `entries[].votedInBy` and every trail row.** Dormant
  today — the method has no caller in `lib/` — and named here rather than left to be
  discovered, because the person who eventually wires an admin roster control is the one who
  needs to know.
  **AMENDED 2026-08-31:** a leave path now exists and does this correctly —
  `cutGroupMenuPlanAccess` in `groups/group-menu-access.ts`. Wire an admin control through THAT
  shape, not through this dormant method. Raised by the
  `integration-reviewer` gate. BUT-1971, 2026-08-30

- **RESOLVED 2026-08-30 — Malin: a member who LEAVES a group KEEPS their name on the dishes
  and in the trail; only deleting the account erases it.** Closes the first half of the OPEN
  entry above, which said she had taken no position.
  **Does NOT close** the second half of the entry above: the "already visible on screen"
  reasoning has still not been tested against a week predating a requester's membership.
  **AMENDED 2026-08-31 — the DECISION stands, its MECHANISM does not.** As written this entry
  said a leave needs no code because it never touches the plan, that the leaver stays in
  `memberPermissions` and is erasable through it, and that a departed member keeping EDIT
  access was separate and still open. All three were falsified the next day by the entry below
  ("Leaving a group now CUTS…"), which removes the leaver from `participants` on the
  `remaining > 0` branch, closes the edit-access hole, and makes `contributorUserIds` — not
  `memberPermissions` — what keeps the name erasable. The sentences are struck rather than
  rewritten; the decision they were arguing for is unchanged. Raised by the
  `integration-reviewer` gate, the only pass that sees a decision record and the code that
  falsified it in one commit. BUT-1971, 2026-08-30

- **Leaving a group now CUTS the leaver's read and write access to that group's weeks, and
  `contributorUserIds` is what keeps their name erasable afterwards.** Malin's call,
  2026-08-31, chosen over the cheaper alternative of cutting only WRITE. `removeChatGroupMember`
  gains a per-plan step that takes the departing member out of `participants` — the two fields
  `firestore.rules` actually reads, `participantUserIds` and `memberPermissions`, are PROJECTIONS
  the Dart model recomputes from it, so editing only the projections would work until the next
  `save()` regenerated them and handed the access back.
  Their uid stays on the dishes and in the trail (2026-08-30), so removing them from the roster
  would leave it reachable by NO query. `contributorUserIds` — a straight mirror of
  `unified_shared_shopping_lists`' field of the same name (BUT-1725), including its rule shape —
  is the fourth discovery handle for the cascade and the probe. Do not "simplify" it away as a
  duplicate of the roster: the roster is what a departure CLEARS, which is the whole point.
  The rules split follows the precedent: `hasAll` on UPDATE only (there is no prior array on a
  create), the size cap on BOTH — a cap on update alone lets a hand-rolled client seed an
  oversized array at create, the same hole `groupMenuTrailWithinCap` exists to close.
  BUT-1971, 2026-08-31

- **`contributorUserIds` is CLIENT-written, so a hand-rolled client can omit a uid and make it
  un-erasable.** `firestore.rules` refuses a write that DROPS an entry, which stops a remaining
  member stripping a departed one — but nothing forces a uid INTO the array in the first place.
  Same trust model as the already-accepted forgeable provenance on the same document, and named
  rather than left to be discovered. The cascade's other three handles are unaffected.
  BUT-1971, 2026-08-31

- **A remaining member whose screen cached the week BEFORE someone left can write the old roster
  back and restore that person's access.** `save()` writes the whole document from the client's
  copy. **Malin's explicit call, 2026-08-31: accepted, not stopped**, against the alternative of
  re-reading before every write. This EXTENDS the existing stale-client entry from erasure to
  DEPARTURE, which is a much more common event and where the resurrected party is a live account
  that can act on the access. The window is bounded by the screen being realtime-subscribed, and
  it closes the next time anyone leaves. Do not cite the erasure entry as authority for this one
  — it was decided separately, on its own facts.
  BUT-1971, 2026-08-31

- **A week whose ONLY remaining participant leaves is DELETED.** The plan's roster is a
  snapshot taken when the week was built and is never re-synced, so a leaver can be the sole
  participant of an OLD week while the chat group still has members — and `remaining === 0`
  never fires, so no sweep cleans up.
  This entry first said the shell was left standing, on the belief that it merely went
  unreadable. The `cloud-functions-specialist` gate measured otherwise: `save()` is a
  whole-document `set()` on the deterministic `{groupId}_{ISO week}` id, which evaluates the
  UPDATE limb, and every limb of this collection gates on `memberPermissions` — so an empty map
  BRICKS that ISO week for the whole group, poll-close included. The group loses the week for
  good, reachable by ordinary churn.
  Deleting costs the provenance of people who have ALL left, which no remaining member can read
  or export either way, and it takes the un-erasable residual with it. The alternative — a rules
  limb letting anyone adopt an empty-roster plan — hands that provenance to a stranger, because
  the create limb already lets any signed-in account write this doc-id shape. Chosen without
  asking Malin; reversing it is hers. BUT-1971, 2026-08-31

- **When the last ADMIN leaves a plan that still has participants, the lowest remaining uid is
  promoted, and the promotion writes an `adminPromoted` trail row.** Without it the update rule
  leaves nobody able to change that week's membership ever again. Lowest uid is deterministic,
  not meaningful — nothing in the document ranks members. The trail row is not decoration: an
  unaudited privilege grant does not belong in a build whose whole point is attribution
  (ADR-0010), and nobody is notified. BUT-1971, 2026-08-31

- **RESOLVED 2026-08-31 — the "already visible on screen" reasoning CANNOT be reached by a week
  that predates someone's membership, measured.** The open half of the earlier entry asked
  whether it had been tested against such a week. It cannot occur: a plan is created only at
  poll close, for the CURRENT week, with the chat roster of that moment
  (`messaging_service.dart`, "Existing plans keep their membership intact"), and nothing adds a
  member to an existing plan — `addParticipant`/`removeParticipant` have no callers in `lib/`.
  The export discovers on `memberPermissions.<uid>` alone, so a later joiner never receives such
  a week at all. No code was built for it. BUT-1971, 2026-08-31

- **A leaver's Art. 15 export contains a documented GAP, not their rows.** Malin first chose "only
  what concerns her"; the panel then measured that a client cannot deliver it — Firestore refuses
  a WHOLE query the moment it matches one document the caller may not read, and this repo already
  says so about the identical shopping-list probe ("Only an Admin-SDK context can enumerate
  those"). **Her revised call, 2026-08-31.** The export runs a `.limit(1)` probe whose only
  product would be its own refusal.
  **There is no probe.** The `firebase-backend-security` gate caught that the refusal is
  UNCONDITIONAL, and the emulator confirmed it: the contributor query is denied even to a
  CURRENT member of the week it matches, because rules are not filters — a list query is refused
  unless the rule proves every returnable document is readable, and the read rule tests
  `memberPermissions`, which implies nothing about `contributorUserIds`. A probe would have
  thrown for every user on every export, so a note derived from it would have told people who
  have left nothing that they had. The bundle states the gap unconditionally instead, in
  `data_minimisation` — which had to change anyway, because it claimed provenance was included
  "in full", false for a leaver, and a bundle that misdescribes itself is its own Art. 12(1)
  defect. The two MEASUREMENT cases in `weekly-menu-plans-rules.test.ts` are the pin.
  **The same reading applies to the shopping-list precedent** (`exportSharedShoppingListsAsContributor`),
  whose contributor branch therefore also never returns a row and whose note also always fires.
  Pre-existing, not introduced here, and its own ticket.
  Residual, named rather than discovered: a leaver's contribution can vanish from the export
  entirely if the dish is later displaced and the trail row ages past the 50-row cap. That is the
  already-accepted displacement gap, but it weighs more here — the leaver has no in-app fallback.
  BUT-1971, 2026-08-31

- **OPEN, named rather than left to be found: THREE other membership-removal paths do NOT cut
  group-menu access.** `cutGroupMenuPlanAccess` is wired only into `removeChatGroupMember`.
  `stageBackstopRemovals` (`enforce-group-minor-membership.ts`) — the CHILD-SAFETY eviction —
  and the category sync's eviction loop (`ensure-category-chat.ts`) both remove a member and
  leave their read and write access to every one of that group's weeks intact. The minor-safety
  one is the highest-stakes: a minor evicted for their own protection keeps write access to the
  group's menu. Not a regression — nothing cut before this build — but it is now an
  inconsistency rather than a uniform gap. Raised by the `cloud-functions-specialist` gate.
  BUT-1971, 2026-08-31

- **The union can create the only surviving record that a PASSIVE participant was ever on a
  week.** `contributorUserIds` unions every roster member, not only people who wrote something,
  so a member who never proposed, voted or edited gains a durable uid on the document at the
  moment they leave — where previously the roster entry was removed and nothing remained. For a
  contributor the array is belt-and-braces; for a passive participant it is new retention. It is
  what makes erasure able to find them, so it is not removable without giving that up. A
  minimisation question for Malin rather than a defect, and unasked.
  BUT-1971, 2026-08-31

- **The Admin SDK bypasses the 200-row contributor cap, and a plan pushed past it can never be
  saved by a client again.** `cutGroupMenuPlanAccess` unions without measuring, and nothing
  prunes the array client-side — pruning would drop uids, which is the one thing the array
  exists to prevent. Implausible (200 distinct uids on one week), unguarded, and the same
  bricking shape the emptied-roster entry above records; `weekly-menu-plans-rules.test.ts` pins
  the frozen-document behaviour so it is found in a test rather than in production.
  BUT-1971, 2026-08-31

- **`contributorUserIds` is STRIPPED from the Art. 15 bundle.** It is an erasure handle, not
  content: its only job is to let the deletion cascade find a plan after the roster stops
  naming someone, so it accumulates the uids of people who have LEFT the group. **No widget
  renders it**, and that is why the keep decision for other members' per-dish provenance does
  not reach it — that decision was re-grounded on 2026-08-30 precisely on the app now showing
  the voters by name, and the ground does not extend to a field the app never shows.
  Do NOT read the identically named field's keep on `unified_shared_shopping_lists` (BUT-1732)
  as authority: that entry itself records that arguing across collections by field NAME is the
  error it exists to document.
  Chosen conservatively without asking Malin, the way the `chat_groups` projection was;
  KEEPING it is hers to decide. Raised by the `firebase-backend-security` gate.
  BUT-1971, 2026-08-31

- **The contributor union is BOUNDED at 200 and skipped above it, losing erasability on that
  document rather than freezing the week.** The Admin SDK bypasses `firestore.rules`, so an
  unbounded union past `groupMenuContributorsWithinCap` would be accepted and would then refuse
  every subsequent CLIENT save of that week — the same bricking the emptied roster caused, one
  field over. The access cut still happens at the cap; only the recording is skipped, and it is
  logged at ERROR because nothing retries the step. Unlike the edit trail, which the client
  prunes on every write and which therefore heals itself, this array only grows: the freeze it
  would cause is permanent, which is why the bound is a skip rather than a truncation — dropping
  a uid is the one thing the array exists to prevent. The number lives in THREE languages now
  (Dart, rules, the Cloud Function) and all three are pinned against each other.
  BUT-1971, 2026-08-31

- **The append-only conjunct on `contributorUserIds` REFUSES a stale writer's whole save — the
  exact cost Malin was told was unacceptable for the edit trail.** BUT-1971 rejected an
  append-only rules conjunct on `editTrail` because it "would refuse the losing writer's whole
  write, breaking ordinary removals". The same shape now guards `contributorUserIds`, so a
  member whose cached snapshot predates another member's FIRST contribution to that week has
  their remove or undo denied outright rather than merged.
  It is accepted here because the frequency is not comparable: the trail changes on every edit,
  while this array changes only when a person who has never touched that week touches it for
  the first time. The screen is realtime-subscribed, so a retry succeeds. And the alternative
  is losing the handle that makes a departed member erasable at all, which is the whole point.
  Named rather than left to be discovered, because the cost is the one that was refused
  before. Raised by the `code-reviewer` gate. BUT-1971, 2026-08-31

- **`contributorUserIds` is a DISCOVERY handle, never a witness on a destructive gate — and the
  two files that could disagree about that now do not.** For part of the BUT-1971 follow-up the
  account cascade blocked its empty-roster DELETE when a departed contributor remained. That was
  wrong, and reachable by ordinary churn the same build created: B leaves a group, `cutGroupMenuPlanAccess`
  takes B off the roster and unions B into `contributorUserIds`, then A deletes their account —
  every roster empties, the contributor witness blocks the delete, and the document is left with
  an EMPTY `memberPermissions`. Every limb of this collection gates on that map, so nobody can
  read, write, re-plan or delete that ISO week again, on a deterministic id poll-close will mint
  once more. The provenance the block preserved was unreachable by everyone.
  A contributor is not a READER. The gate keeps the three witnesses that name readers, and
  `cutGroupMenuPlanAccess` already answers this shape the same way: a week no one can open is
  deleted rather than left standing. Caught by the `integration-reviewer` gate, which is the
  only pass that could see the two files ship opposite verdicts about one document.
  BUT-1971, 2026-08-31

- **The Art. 15 `delivered_notifications` section exports another user's NAME, inside the text
  of a friend-share win-back push.** `users/{uid}/notifications` is passed through unprojected
  rather than field-projected like its neighbour `exportNotifications`.
  **Why:** the section exists because BUT-1957 made the account-deletion cascade erase that
  subcollection. Projecting named fields would risk dropping a field the cascade erases and
  re-open the gap the ticket exists to close.
  (The export ⊇ erasure invariant is stated SCOPED in
  `docs/security/notification-analytics-retention.md`, per collection and with its one named
  exception. Do not restate it unscoped: it does not hold repo-wide, and this same commit
  falsifies an unscoped version of it twice — `analytics/notifications/effectiveness` is
  erased and deliberately not exported, and ten `users/{uid}` subcollections gained a deleter
  with no export section. That asymmetry is BUT-1992.)
  The first version of this change shipped three sentences asserting that no third party appears
  in these rows. That was FALSE and the `firebase-backend-security` gate measured it:
  `resolveContextualWinbackCopy` builds `"<namn> delade ett recept med dig"` from
  `shared_recipes.sharedByDisplayName` (`functions/src/analytics/winback-context.ts`), stored
  verbatim in `message` and `bodyShown` on `contextKey == 'ctx_friend_share'` rows. It is the
  NAME, not reliably a first name: `firstName()` splits on the first whitespace and falls back
  to the whole trimmed name when there is none. All three sentences were struck, not reworded.
  The name is KEPT because the requester received and read that exact push on their own device,
  so the bundle discloses nothing new, and redacting it would hand them a falsified copy of
  their own record. Decided on these facts alone — NOT by analogy to BUT-1772 (conversations)
  or BUT-1732 (shopping lists), which govern different collections; the BUT-1732 entry itself
  records that arguing across collections by shape is the error it exists to document.
  The section carries a `data_minimisation` sentence saying so, and that sentence is pinned by
  a test, because it is the only thing telling the data subject a third party is in there.
  **Named residual, not closed:** the sharer's name is baked into free text on the RECIPIENT's
  row, so it outlives the sharer's own erasure — `on-user-deleted.ts` tombstones
  `sharedByDisplayName`, but no id-keyed cascade reaches a copy sitting inside a sentence.
  Pre-existing; this change is what makes it exportable, and erasable through the recipient's
  deletion.
  **Chosen conservatively without asking Malin, the way the `chat_groups` projection was —
  STRIPPING the name is hers to decide, and it is open.**
  Residual worth knowing: because this is a pass-through, "every field is safe" is a property of
  two functions' CURRENT field lists, not of the shape. A writer that later stores a counterparty
  uid lands it in a GDPR bundle with no rules change and no red test. Raised by the
  `code-reviewer` gate as a follow-up rather than a blocker. BUT-1957, 2026-09-02

- **`users/{uid}/notifications` needs its own `firestore.rules` read block, and the Art. 15
  export section is dead without it.** Owner-only read; `allow write: if false`.
  **Why:** rules do NOT cascade — `allow read` on `match /users/{userId}` grants nothing on a
  subcollection beneath it. The collection had no block because every writer is the Admin SDK
  and no client had ever read it, so nothing was denied and nothing looked missing. The export
  is the first client read; without the block it returns its failure envelope for every user on
  every export while the retention doc claims the rows are exported — a gap that reads as
  closed. Writes stay `if false` because the rows record what the SERVER sent: a client able to
  write one could fabricate a notification it never received, and that record is now reachable
  through the export. `git log -S` confirms no client has ever written the path, so the closure
  breaks nothing.
  Found by the `firebase-backend-security` and `code-reviewer` gates independently. Three green
  manager tests could not see it: `fake_cloud_firestore` enforces no rules. Proven by
  `delivered-notifications-rules.test.ts`, which tests the LIST shape production actually issues
  — a `get()`-only proof would not have covered it — plus a collection-group deny; both mutants
  killed. BUT-1957, 2026-09-02

- **The `poll_votes` block gate FAILS OPEN on a missing mirror, and absence has FOUR
  meanings the rule cannot tell apart (BUT-1917, 2026-09-05).** `notBlockedByAnyoneHere()`
  permits the vote when `users/{uid}/block_mirror/current` does not exist. Absence means:
  nobody has ever blocked this person; the first block landed but the trigger has not run;
  the account was erased; or `rebuildMirrorFor` deleted the mirror as an orphan. Only the
  first is safe to permit. Failing CLOSED was rejected because it refuses every vote from
  every user until a backfill writes a document for all of them.
  The fourth meaning was CLIENT-REACHABLE and is now closed: the orphan check keyed on
  `users/{uid}`, which `firestore.rules` lets its owner DELETE, so the constrained person
  could delete their own profile and disarm their own mirror — permanently, since the weekly
  pass ran the same check and deleted it again, counting it as `skipped` so the run that
  disarmed the control still logged clean. `rebuildMirrorFor` now asks **Auth**, not
  Firestore. Pinned by `deleting your own PROFILE does not delete your mirror`, mutation-probed.
  That fix trades transactional atomicity for correctness, and the residual it leaves is
  WIDER than the one it replaces on the erasure path, measured: `auth.deleteUser` is the LAST
  step of `requestAccountDeletion`, after the `block_mirrors` sweep, after `deleteUserProfile`
  and after `probeResidualData` — so throughout an erasure the check answers "exists" for the
  user being erased, where the old document-keyed check answered "gone" from tier 3 onward.
  A trigger landing late in the cascade therefore writes a mirror under the erased uid's path.
  The weekly pass does reach it: `reconcileMirrors` no longer fast-paths an EMPTY stored
  mirror, which is exactly that orphan's shape and which it used to skip forever while three
  comments claimed otherwise. Two gates measured that independently.
  Raised by the `firebase-backend-security` and `cloud-functions-specialist` gates, which
  measured the same false sentence independently. BUT-1917, 2026-09-05

- **A TRUNCATED mirror silently under-blocks, and the `truncated` flag has no reader
  (BUT-1917, 2026-09-05).** `sync-block-mirror.ts` caps at `MAX_MIRROR_ENTRIES = 1000` and
  stamps the flag; the rule reads only `blockedByUserIds`. Above the cap a blocker falls off
  and stops being enforced. Both queries use `.limit(cap + 1)` with **no `orderBy`**, so
  truncation keeps the lexicographically lowest `{blockerId}_{blockedId}` document ids — a
  harasser with ~1000 sockpuppet accounts can therefore inflate their OWN mirror until a real
  blocker sorts off the end. Implausible pre-launch, and denying while truncated would refuse
  every vote from anyone blocked by that many people. Pinned GREEN by B11 in
  `poll-votes-rules.test.ts`, so the day somebody adds the conjunct that test reddens and
  names the decision being reversed. Raised by the `cloud-functions-specialist` gate.
  BUT-1917, 2026-09-05

- **READ of a poll tally is deliberately NOT block-gated, and neither is DELETE
  (BUT-1917, 2026-09-05).** Hiding the tally from a blocked person would tell them a block
  exists, turning a silent control into a notification. Delete stays open because erasing
  your own row (Art. 17) cannot depend on somebody else having blocked you. B7 and B8 pin
  both. BUT-1917, 2026-09-05

- **The gate is ONE-DIRECTIONAL in the rules and TWO-DIRECTIONAL in the client tally, and
  message DISPLAY stays one-directional (BUT-1917, 2026-09-05).** The rule refuses the
  blocked person's vote and lets the blocker vote normally — refusing the blocker would
  punish the person who used the safety feature. The on-screen tally and `closePoll`'s winner
  resolution both strip BOTH directions, from one set, because filtering the count but not
  the winner makes the number and the recipe contradict each other. What that person SAYS
  stays visible: hiding it would disclose the block. The asymmetry is the decision; do not
  harmonise it. Pinned by `the ASYMMETRY: their ballot goes, their MESSAGE stays`.
  BUT-1917, 2026-09-05

- **The rule is NOT retroactive, and the client strip is a DISPLAY control, not a server one
  (BUT-1917, 2026-09-05).** Rows written before the rule landed stay on the document; B6
  pins that a blocked voter can no longer STEER such a row, not that it is removed. The
  window between a `blocks` write and the trigger's mirror write is NARROWED by `retry: true`
  and the weekly reconciliation, never closed — closing it would mean reading `blocks` per
  participant, which is the 10-access cap the mirror exists to avoid. Bounded in practice
  because `closePoll` reads `blocks` from the SERVER, so a vote slipping through the lag
  window still cannot decide the week. The reconciliation is LAST in a weekly chain that
  skips tail tasks under budget pressure, so the only net under a silent safety control is
  the first thing dropped. BUT-1917, 2026-09-05

- **The client can now ENUMERATE everyone who blocked it, and that capability is what buys
  the two-directional tally (BUT-1917, 2026-09-05).** `FirebaseBlockRepository` gained three
  readers on `where('blockedId', isEqualTo: uid)`, permitted by the `blocks` read limb's
  second disjunct. This is wider than `isBlockedBy`, which only answers about a uid the client
  already holds: enumeration returns blockers the client has no other way to name, and
  `public_profiles/{uid}` resolves each to a name and avatar. Nothing renders the set — it
  reaches only the ballot strip — so the exposure is to a hand-rolled client.
  It sits ACROSS the grain of this same change's `block_mirror` deny block, which refuses the
  owner that very list, and across the grain of BUT-2018 — where Malin decided on 2026-09-05
  to drop `incoming_blocks` from the Art. 15 bundle entirely. That decision is recorded on the
  ticket and is NOT yet built, so the export still ships the section today.
  **Open for Malin, and named rather than buried:** the rule could be split (`allow get` both
  directions, `allow list` blocker-only), which would kill all three readers and the client
  half of the tally. What that half actually covers is votes cast BEFORE the rule landed, and
  the app is not live, so today it covers nothing. Bounded at `maxIncomingBlocks = 1000`,
  mirroring the server cap, because the incoming set is chosen by OTHER people and nothing
  rate-limits a `blocks` create. Raised by the `firebase-backend-security` gate.
  BUT-1917, 2026-09-05
  **CORRECTED 2026-09-05, same day, by the whole-range push review.** "The client can now
  ENUMERATE" is false as a novelty claim: `FirebaseDataExportRepository.getIncomingBlocks`
  (`lib/repositories/firebase/firebase_data_export_repository.dart:687`) already ran
  `where('blockedId', isEqualTo: userId)` from the Flutter client, under the same read limb,
  before this change. BUT-1917 added three readers on a DIFFERENT repository; it widened no
  permission and introduced no capability.
  This changes what the open question costs, which is why it is corrected rather than left:
  the split it offers Malin (`allow get` both directions, `allow list` blocker-only) would
  also kill the Art. 15 `incoming_blocks` section, not just the ballot strip. That section is
  the one BUT-2018 already decides to remove — so the two questions are the same question,
  and should be put to her together.
  **SUPERSEDED 2026-09-09 by BUT-2018, which is built.** `SocialExportManager.exportBlocks`
  returns only `outgoing_blocks`, and `FirebaseDataExportRepository.exportIncomingBlocks` is
  deleted. Retired verbatim: "That decision is recorded on the
  ticket and is NOT yet built, so the export still ships the section today." Retired verbatim:
  "the split it offers Malin (`allow get` both
  directions, `allow list` blocker-only) would
  also kill the Art. 15 `incoming_blocks` section, not just the ballot strip. That section is
  the one BUT-2018 already decides to remove — so the two questions are the same question,
  and should be put to her together." The split now costs the ballot strip alone. Retired
  verbatim: "`FirebaseDataExportRepository.getIncomingBlocks`
  (`lib/repositories/firebase/firebase_data_export_repository.dart:687`)" — the method was
  named `exportIncomingBlocks` and no longer exists. The correction's own point stands: the
  enumeration capability predates BUT-1917 and that ticket widened no permission.

- **Making the tally two-directional WIDENS an existing provenance gap on the group menu, and
  that is named rather than left to be discovered (BUT-1917, 2026-09-05).** `closePoll`
  resolves `votedInBy` from the FILTERED poll, so the group weekly menu's voter sheet — the
  surface BUT-1971 built specifically to earn its Art. 15 keep — omits anyone the closer has
  blocked, and now anyone who has blocked the CLOSER too. A member can therefore remove their
  own name from that sheet by blocking whoever closes the poll. Pre-existing in the outgoing
  direction (BUT-1909); this change adds the second direction. Not fixed here because the
  winner must stay filtered while the provenance probably must not, which is a decision rather
  than an edit. Raised by the `integration-reviewer` gate. BUT-1917, 2026-09-05

- **`parse_corrections_v2` is DELETED by the reset script while `metrics` is LEFT ALONE, and
  the ground is CONTENT rather than identifiability (BUT-2028, 2026-09-07).** `metrics` sits in
  `COLLECTIONS_DELIBERATELY_UNTOUCHED` — the register, which the script neither deletes nor
  protects — and NOT in `COLLECTIONS_TO_KEEP`, which is the list with runtime teeth. The
  register's own convention is that a collection carrying a verdict is filed per that verdict,
  citing it; this entry is that verdict. Malin's explicit
  call, made with both collections on the table. A correction row carries the user's own
  words — `toValue` is what she typed into the field, `fromValue` is the parser's output over
  a third-party page that she chose to correct — scrubbed by `scrubPii` and truncated to
  `MAX_VALUE_CHARS`, and still text a person wrote or edited. That is the same ground as
  `llm_response_samples`. `metrics` is aggregates with no uid and no text a person wrote
  (the first wording said "integers per ISO week and no text" — struck 2026-09-07, measured
  false: `north-star-weekly.ts` writes ratios, an `isoWeek` string and three timestamps.
  The decision is unaffected; the description was wrong), so a reset that
  takes what people wrote does not reach it.
  **She was shown** that this restarts the parse-quality corpus from zero. **She was NOT
  shown** a measurement of how large that corpus is; nobody has counted it against
  production.
  The uid and recipeId arrive pre-hashed, and the `recipeIdHash` resolves to nothing. That was
  the first mechanism written into the code comment, and it decides nothing — nothing is
  orphaned either way. Do not re-argue the call from it, and do not "harmonise" the two
  collections in either direction.
  (An earlier wording opened this paragraph with "The row also carries no personal data" and
  called it TRUE. Struck 2026-09-07: whether the row is personal data is not settled here, and
  a flat assertion that it is not would have been cited as a finding that the collection is out
  of scope. The decision is unaffected — it never rested on this. A first replacement said the
  hash was recomputable and therefore pseudonymisation; that was struck the same day, measured
  false — `ParseCorrectionUploader.hashId` salts with a per-install `Random.secure()` value held
  in SharedPreferences that is never sent, so the server holds no salt. Settling the legal
  question needs its own ADR, not a sentence here.)

- **The reset script's Phase 4 COUNTS and JUDGES; it does not sweep a second time (BUT-2028,
  2026-09-07).** Malin's explicit call, against the `cloud-functions-specialist` gate's own
  recommendation on the ticket, which was to repeat the Firestore sweep at the end to catch
  what the triggers wrote behind the first one.
  **She was shown** that the kill switch (`shared/reset-kill-switch.ts`) removes the cause
  rather than the symptom, and that a second sweep buys a stronger claim about residue and no
  claim at all about completion — `onUserDeleted` is gen1, with no bounded delivery time and
  no `retry`, so no stopping rule based on elapsed time or number of passes is correct.
  **She was NOT shown** a measurement of how much residue a real run leaves. Do not add the
  sweep back without one, and do not read the absence of a second pass as an oversight.
  (An earlier wording added "no live run has been made since the script became executable".
  Struck 2026-09-07: unmeasured, and contradicted by `reset-user-data.ts` in the same commit —
  whether a run has happened is not answerable from this repo, since the only record is
  `ops/resets/{runId}.json` in the Storage bucket, which nothing here reads.)

- **`ingredient_suggestions` gets BOTH GDPR legs, and that is the decision (BUT-2028,
  2026-09-07).** Malin's explicit call, shown the alternative of
  closing the door instead (`allow create: if false`) and its cost. Nothing in `lib/` creates
  a suggestion, and `onSuggestionCreated` updates rows rather than creating them — so what keeps the
  collection reachable is the `allow create` limb in `firestore.rules`, which lets any
  signed-in client write a row keyed to their own uid.
  `deleteIngredientSuggestions` (with a leg in `probeResidualData`) and the Art. 15 export
  section therefore ship together. The point is that the FIRST client write
  is erasable and exportable on the day it happens rather than the day someone notices it.
  Do not delete either leg as dead code; the pair is what makes the open door safe.

- **The Art. 15 `ingredient_suggestions` section is PROJECTED (BUT-2028, 2026-09-07).**
  `ContentExportManager._ingredientSuggestionFields` is an ALLOWLIST, so the section fails
  closed: a field it does not name is withheld. Two fields the declared type
  (`functions/src/ingredients/on-suggestion-created.ts`) carries are deliberately omitted —
  `reviewedBy`, a moderator's raw uid, and `reviewNotes`, internal moderation text. No widget
  renders either, which is the `chat_groups` precedent rather than the BUT-1732/BUT-1772 keeps: those decided different collections, and
  the BUT-1732 entry itself records that arguing across collections by shape is the error it
  exists to document.
  `userId` is neither kept nor withheld as a decision — it is the requester's own uid and the
  field the query already filters on.
  The cost of failing closed is real and is why the section carries a `data_minimisation`
  line: the collection's create rule uses `hasRequiredFields`, not `hasOnly`, so a client can
  store fields outside the declared type, and the allowlist would then drop the requester's
  OWN content — an Art. 15 defect in the other direction.
  **Chosen conservatively WITHOUT asking Malin, the way the `chat_groups` projection was.
  KEEPING `reviewedBy`/`reviewNotes` is hers to decide, and it is OPEN.**
  **Named residual, not closed:** if a moderator is themselves a user of the app, their uid
  in `reviewedBy` sits on somebody else's row and is reached by no cascade query, no probe
  and now no export. The projection makes it invisible; it does not make it erasable.
  Second residual: `deleteIngredientSuggestions` reads unbounded, on a collection whose create
  limb has no `rateLimitWrite` — same shape as `deleteCookSnaps`, and bounded by BUT-2038
  rather than here.
  Raised by the `firebase-backend-security` and `code-reviewer` gates.
  BUT-2028, 2026-09-07

- **`users/{uid}/rateLimits` INHERITS `rate_limits`' Art. 15 exemption rather than getting a
  decision of its own, and the DPO residual beside it is now measured NON-EMPTY for the first
  time (BUT-2040, 2026-09-08).** The camelCase spelling is one collection under two spellings,
  not two collections: commit `b9a95bd02` (2026-03-19) changed
  `FirestoreCollections.userRateLimits` from `'rateLimits'` to `'rate_limits'`, and
  `firestore.rules` has no block for the camelCase path, so no client can create a new row.
  That rename commit touches the CONSTANTS file, not the writer — the commit touching the
  writer (`7854e2a8a`) renames nothing, and it was cited as the proof before anyone ran the
  two commands. So the inheritance is evidenced by a rename, which is NOT the "arguing across
  collections by NAME" error BUT-1732 exists to record.
  What it inherits is Malin's explicit call of 2026-09-03 (ADR-0011): EXEMPT, made AGAINST the
  recommendation to export it, weighing bundle legibility higher.
  **ASKED AND ANSWERED 2026-09-08: the exemption STAYS inherited.** The entry first shipped
  saying the inheritance was chosen without asking her and that giving the legacy spelling its
  own decision was hers. It was put to her the same day, with the recommendation to leave it
  inherited on the ground that two decision records about one fact are the drift BUT-1732
  exists to document. She took it. There is no separate decision for the camelCase spelling,
  and one must not be written.
  **Named and open:** the exemption group's own header already says that for an account still
  holding legacy rows they are erasable but WERE never exportable, and that whether that is
  worth an export section is Malin's and has not been asked. Until now nobody knew that set
  was non-empty.
  **ASKED AND ANSWERED 2026-09-08: NO Art. 15 export section is built for `rateLimits`.** She
  was shown that the measured set is 5 rows on two pre-launch test accounts (see the
  provenance note below), and that
  `admin/reset-user-data.ts` empties it on its next run because it enumerates rather than
  consulting a list — so the residual is self-clearing before there is any real subject to
  owe a bundle to. The question is REOPENED, not closed, if that set is ever non-empty with
  live users in it. Nobody is watching for that; it rests on the same dry run as everything
  else in this entry.
  **SUPERSEDED 2026-09-08, same day, by the commit-gate review — the MECHANISM in the
  paragraph above is wrong, and it is the premise Malin answered on.** That paragraph says
  `admin/reset-user-data.ts` "empties it on its next run because it enumerates rather than
  consulting a list". The enumeration half is true. The "next run" half is not: a DRY run
  deletes nothing — `deleteCollection` returns a `count()` and `docRef.delete()` sits behind
  `if (!dryRun)` — and the runbook shipped in this same commit instructs a DRY run before
  launch (BUT-2045). Only a LIVE run empties it, and no live run is known to have happened:
  the script was inert 2026-03-19 to 2026-09-05 (BUT-2010), and the only record a run leaves
  is `ops/resets/{runId}.json` in Storage, which nothing in this repo reads.
  **The DECISION is unchanged and still Malin's; what is withdrawn is the sentence saying the
  residual clears itself.** It clears when someone runs the script live, which is a thing a
  person must do, not a thing that happens. Raised independently by the
  `firebase-backend-security` and `integration-reviewer` gates.
  The population figure it rests on — 5 rows, 2 Auth users — was measured by the dry run
  against butlery-app-1 on 2026-09-07 and re-measured 2026-09-08; that output is not
  committed anywhere, so it is attributed, not reproducible from this repo. The set being non-empty does not change the decision; it changes what the
  unasked question is worth.
  The deleter side is NOT a deviation and is simply a defect closed: `probeResidualData`
  enumerates while the deleter walked a hand-written list, so every such erasure reported
  `gdprCompliant: false` about itself, correctly and unclearably. BUT-2040, 2026-09-08

- **A `friend_requests` / `social_requests` row names TWO people, and erasing either
  account deletes the whole row — including the counterparty's record of a request they
  sent or received (BUT-2044, 2026-09-08).** `cleanupSocialRequests` runs two queries
  (`fromUserId`, `toUserId`) and deletes every match, staging one `audit_logs` row per
  delete with `targetUid` set to the OTHER party. BUT-2044 extended that same function to
  the pre-rename spelling rather than copying it, so the behaviour is unchanged and one
  implementation carries it.
  **Written down because it was NOT inherited from a decision — it was inherited from
  CODE.** No entry in this file records that the trade was ever put to Malin for
  `social_requests` itself, so "it inherits" describes what the code does, not a call
  somebody made. Chosen conservatively without asking her; deciding whether a counterparty
  keeps their copy of a request is hers, and it is open.
  Also open, and the reason this is not merely academic: the row carries a free-text
  `message` one person wrote to the other, so the deleted copy is content, not just a
  pointer. BUT-2044, 2026-09-08

- **Moving a `friendCategories` row to the live spelling GRANTS ITS MEMBERS A READ they did
  not have (BUT-2044, 2026-09-08).** `firestore.rules` carries a collection-group rule
  letting any uid in `friendUserIds` read a `friend_categories` row; the pre-rename
  camelCase path has no block at all, so a row sitting there was readable by nobody but the
  Admin SDK. `admin/migrate-friend-categories.ts` moves it, and the members named inside it
  can then read it.
  **Malin's explicit call, 2026-09-08**, taken over the alternative: building a new
  `firestore.rules` read block for the dead spelling so the Art. 15 export could reach it
  there. The export runs on the CLIENT SDK, so without a block every export read of that
  path is denied for every user — the choice was a new rules surface for a spelling nothing
  writes, or moving the row onto the reviewed path. She chose the move.
  Accepted because it is the SAME access every other category of that owner already grants,
  and because it is what makes the row erasable by `cleanupGroupMemberships` — which queries
  `friend_categories` and therefore never reached the orphan, so other people's uids inside
  it survived THEIR erasure too.
  Recorded here rather than only in the script's header, because a plan greps these files
  and not a one-time script. Raised by the `firebase-backend-security` and
  `cloud-functions-specialist` gates. BUT-2044, 2026-09-08

- **A `system_events` row about a report the ERASED USER FILED is DELETED, and the row about
  a report FILED AGAINST THEM is KEPT with the identifier nulled (BUT-2032, 2026-09-08).**
  `deleteModerationSystemEvents` derives both halves from the two outcomes already decided on
  the SOURCE collection rather than inventing a third policy for one event: `deleteUserReports`
  hard-deletes the `reports` document when the reporter erases, and
  `anonymizeReportsByContentOwner` (BUT-781) keeps the row and nulls `contentOwnerId` when the
  reported person erases.
  **The delete half is Malin's explicit call, 2026-09-08 (ADR-0016)**, taken over Trust &
  Safety's alternative of nulling `details.reporterId` and keeping the row for audit symmetry.
  She was shown that under her choice an admin reviewing an old `moderation_threshold_reached`
  alert cannot see that a report was ever filed there — silence and "no report" become
  indistinguishable. She was NOT shown any measurement of how often a reporter erases with
  live reports outstanding; nobody has counted it, and the app is not live. The T&S condition
  rides along: `docs/ops/moderation-runbook.md` states the post-erasure behaviour per row
  shape, so the console reader is not misled by that silence.
  The threshold row is deleted rather than anonymized because its document id IS the uid.
  Both legs are found by QUERY (`details.userId`, `details.reporterId`), never by rebuilding
  the id, so a row whose id ever departs from the convention is still reached and no audit row
  is staged for a document that never existed.
  BUT-2032, 2026-09-08

- **The step runs in the CASCADE and stages its own audit rows — the first
  `stageCascadeAuditEntry` calls in `account-deletion-cascade.ts` (ADR-0014, 2026-09-08).**
  Placement is forced: `probeResidualData` runs BEFORE `auth.deleteUser` and `onUserDeleted`
  after it, so a trigger-owned step with a probe leg turns every affected erasure into a false
  `gdprCompliant: false` — the BUT-2044 defect. The plan then accepted the cascade's
  zero-audit posture on the ground that the step "mirrors BUT-781". The panel measured that
  BUT-781's anonymization runs in the TRIGGER, where it DOES stage a row per mutation, so the
  analogy carries the action and not the record. Decided by the priority order
  (data-integrity above cost), roughly one extra write per mutated row on a path that runs
  once per account. Do not "align" this step with the rest of the cascade by removing the
  audit staging; the rest of the cascade is what is out of line.
  BUT-2032, 2026-09-08

- **`system_events` is NOT in the Art. 15 export, and the decision is recorded HERE rather
  than in `EXPORT_EXEMPT` (BUT-2032, 2026-09-08).** **Malin's explicit call, 2026-09-08**,
  over the alternative of building an export section: `firestore.rules` gives the collection
  `allow read: if isAdmin()` and no write limb at all, so exporting it would mean opening a
  client read on an admin surface. It is an internal ops log.
  The entry cannot live in `EXPORT_EXEMPT`: that map is scoped to `USER_SUBCOLLECTIONS`, and
  `scenario_exportCoversEveryDeletedSubcollection` fails any exemption naming something absent
  from that list — a top-level collection reddens it. The precedent for a Tier-1 top-level
  collection (`ingredient_suggestions`, BUT-2028) is to ship an export section instead, which
  is exactly what this decision declines to do, so there is no registry for it to sit in.
  BUT-2032, 2026-09-08

- **`onReportCreated` has NO ordering relationship to account deletion, so a row naming an
  erased uid can be written AFTER the erasure — accepted, not closed (BUT-2032, 2026-09-08).**
  It is an `onDocumentCreated` trigger on `reports/{reportId}` that re-throws for retry, so a
  report filed seconds before an erasure, or a delivery retried across it, lands a fresh
  `content_report` row afterwards and nothing sweeps it. This is a THIRD category the cascade
  has no concept for: neither cascade-owned nor trigger-owned, both of which are defined by
  their ordering against `auth.deleteUser`.
  **Malin's explicit call, 2026-09-08**, over the alternative the panel named beside it: a
  reconciliation pass, the way `runReconcileBlockMirrors` closes the identical race on the
  block mirror. The window requires a report created in the same seconds as an erasure.
  Nobody has measured how often that happens; the app is not live. Raised by the
  `Codebase Archaeologist` seat, which was the only pass looking for it.
  BUT-2032, 2026-09-08

- **`user_moderation` is deliberately OUT of BUT-2032, and its erasure is a Trust & Safety
  decision before it is a GDPR one (ADR-0015, 2026-09-08).** The document id is the reported
  person's uid and `reportHistory` is an array of maps each carrying a `reporterId`. No
  cascade, no probe, no export reaches it — a real and larger Art. 17 residual than the one
  BUT-2032 closes.
  The plan proposed folding it in; T&S showed that `reportHistory` is the only data surviving
  the REPORTER's own erasure that can answer whether one account repeatedly reports the same
  target (`reports` carries `reporterId` too, but `deleteUserReports` hard-deletes those rows
  — measured), i.e. Butlery's only signal against report-brigading, DSA Art. 23 territory.
  Decided by the priority order: user-safety above the shared-truth consistency argument.
  If it is ever built, the array rewrite must read `reportHistory` INSIDE the transaction that
  writes it, with contention retry — the live writer uses `arrayUnion` in its own transaction,
  and a `get()` followed by a later `update()` silently drops a report landing in between.
  **SUPERSEDED 2026-09-08 by the BUT-2046 entry below, on the same day.** Three sentences here
  no longer describe the code. "`reportHistory` is the only data surviving the REPORTER's own
  erasure that can answer whether one account repeatedly reports the same target" and
  "Butlery's only signal against report-brigading": the field is gone, its rows live in a
  `report_history` subcollection, and `deleteReportHistoryByReporter` erases them on the
  reporter's own erasure. And "the array rewrite must read `reportHistory` INSIDE the
  transaction that writes it": there is no array to rewrite — the hazard it names was removed
  rather than satisfied, and the migration is what carries the transactional requirement now.
  The SCOPE call this entry records was correct when made, and the T&S decision it protected
  was taken.
  BUT-2032, 2026-09-08

- **`user_moderation.reportHistory` becomes a `report_history` SUBCOLLECTION, and the
  brigading signal it could have carried is deliberately NOT built (BUT-2046, 2026-09-08).**
  Each entry names a REPORTER — another person's uid — and Firestore cannot query a uid
  inside an array of maps, so before this the uid was reachable by no erasure path and by no
  read: `deleteUserReports` could delete the document keyed on the erased user's OWN uid and
  nothing more. Same move BUT-1832/1835 made with `voterIds`, for the same reason.
  **Malin's explicit call, 2026-09-08**, over the alternative of building a queryable
  reporter-side counter first (DSA Art. 23) and erasing afterwards. She was shown that the
  GDPR gap stays open until such a counter exists, and that nothing is lost today: measured
  the same day, NO code in this repo reads the collection — the only references are the
  writer itself and the reset list — and the array shape cannot answer the brigading question
  anyway. This ANSWERS the question ADR-0015 deferred rather than reversing it.
  The measurement's limit, stated: the admin dashboard is a separate app this repo cannot
  grep. If it ever read `reportHistory` as an array, the migration breaks it.
  **Measured against butlery-app-1 on 2026-09-08, after the build and before any deploy:
  `user_moderation` holds ZERO documents and `reports` zero rows**, so no legacy array exists
  anywhere and the migration has nothing to move. That output is attributed, not reproducible
  from this repo — it was an Admin-SDK read run by hand, committed nowhere. It does not make
  the migration removable: it is what the erasure path needs the day a first report is filed
  on an account that predates the deploy.
  BUT-2046, 2026-09-08

- **The report rows carry a 180-day TTL (BUT-2046, 2026-09-08).** **Malin's explicit call**,
  over keeping them indefinitely with a dated note. The purpose they were kept for is the one
  deliberately not built, and storage without a purpose is what Art. 5(1)(e) is about. Same
  retention as the audit logs and as `report_processing_markers`, the sibling written in the
  same transaction. It is also what eventually removes a row the late-trigger race writes
  after the cascade's sweep has run.

- **The whole of `user_moderation` stays out of the Art. 15 export, and the two halves rest
  on DIFFERENT grounds — only one of which is strong (BUT-2046, 2026-09-08).**
  Withholding the REPORTERS' identities is a clean Art. 15(4) call: they are third parties,
  and disclosure would expose them.
  Withholding `totalReports`/`lastReportedAt` is NOT. Those are the requester's own aggregate
  about themselves, and Art. 15(4) does not reach a subject's own data. The ground is that
  disclosing an in-progress moderation count tells a reported person that review is under way,
  which invites account-switching and undermines the moderation itself. **That is a weaker
  position and is recorded as one.** **Malin's explicit call, 2026-09-08**, made after the
  panel showed her that the single "whole collection" justification she was first given
  covered only the reporter half; the alternative on the table was exporting the count alone.
  The two grounds must not be merged back into one sentence: that merge is the defect this
  entry exists to record, and it is the same shape as arguing across collections by analogy.
  BUT-2046, 2026-09-08

- **A reported person can erase their way out of an open moderation review, and no legal hold
  stops them (BUT-2046, 2026-09-08).** `deleteModerationRecord` removes the strike record and
  every row beneath it, including when `totalReports` has already crossed the five-report
  threshold and a review is outstanding. Named rather than left to be discovered; not weighed
  by Malin, because Art. 17 has no exception this build could rely on and inventing one is a
  legal question, not an implementation choice.

- **The migration is what makes a reporter's uid erasable at all, and it is not run by
  shipping (BUT-2046, 2026-09-08).** `admin/migrate-report-history.ts` moves each legacy array
  entry into the subcollection; `deleteReportHistoryByReporter` only reaches rows it has
  moved. Until a LIVE run happens, a reporter's uid inside another person's un-migrated
  document is reached by no code path. It must run only AFTER the new writer is deployed —
  an old writer appending to the array while the script clears it loses a report — and the
  per-document transaction covers a write landing DURING the run, not one landing after it.
  A dry run deletes nothing. Do not describe the residual as closed on the strength of the
  script existing: that is precisely the BUT-2010/BUT-2040 failure, where a written-but-unrun
  script was treated as having cleared what it never touched. The completion evidence is a
  live run reporting zero remaining `reportHistory` fields.
  **RAN LIVE 2026-09-09, after the writer deploy:**
  `{"mode":"live","scanned":0,"moved":0,"skippedExisting":0,"emptied":0,"failures":[]}`.
  Measured against butlery-app-1 immediately before it: `user_moderation` held 0 documents,
  0 carrying a legacy `reportHistory` array, and `reports` held 0 rows. The residual is
  therefore closed by there being nothing to migrate rather than by the script having moved
  anything — the gap was real in the code and empty in the data. The output is attributed,
  not reproducible from this repo: a hand run, committed nowhere.
  Deploy order held: indexes (waited to READY), then functions
  (`onReportCreated`, `requestAccountDeletion`, both `ACTIVE`), then rules, then this.
  BUT-2046, 2026-09-08


- **SUPERSEDES the Art. 15 half of the `user_moderation` entry above, same day: the report
  COUNT IS EXPORTED (2026-09-08).** That entry withholds `totalReports`/`lastReportedAt` on the
  ground that "disclosing an in-progress moderation count tells a reported person that review
  is under way", and labels it the weaker of two grounds. It is weaker than that: withholding a
  subject's OWN data to protect an ongoing process is a GDPR Art. 23 restriction, and Art. 23
  requires a legislative measure. None was found for this. **Malin reversed her own call the
  same day, having been told that.**
  What ships: `user_moderation/{uid}` gains a `firestore.rules` read limb for its own subject,
  and the export section projects the two counters through an ALLOWLIST. The REPORTERS stay
  withheld — that half rests on Art. 15(4), which does reach third-party data, and is unchanged.
  **The rules limb's conjunct is a control rather than decoration.** Rules cannot scope a read by FIELD, and before BUT-2046 this
  document carried a `reportHistory` array whose entries each named a REPORTER — so a plain owner
  read on a document the migration has not moved hands the reported person the uid of whoever
  reported them, which is the exact Art. 15(4) disclosure the other half of this decision exists
  to prevent. The `firestore-rules-tester` gate MEASURED that on the emulator before the conjunct
  existed. An un-migrated document is now denied whole, which needs no promise that anybody ran
  `admin/migrate-report-history.ts`.
  The first version of this entry justified the limb by asserting the document "holds NOTHING but"
  the two counters. That was a claim about the WRITER; the collection is what it is about, and
  three gates found it independently. The sentence is struck rather than reworded.
  The reporters themselves live in the `report_history` subcollection, which has no block of its
  own and is therefore denied to everyone including its own subject.
  **The conjunct is `hasOnly(['totalReports','lastReportedAt'])`, not a deny-list naming
  `reportHistory`.** The deny-list covers the shape we know about; `hasOnly` also denies the day
  somebody writes a field nobody has decided about — a moderator uid on a `lastReviewedBy`, say —
  instead of it becoming owner-readable because no human noticed. Both spellings were measured
  against six states by the `firestore-rules-tester` gate; their profiles differ on exactly that
  row.
  It carries a `resource == null` arm, and that arm is not a formality: the document exists only
  once somebody has reported you, so without it the rule denies every user who never has been, and
  the export section would return a FAILURE envelope where it should return "nothing to report" —
  the same BUT-1957 shape the block exists to prevent, reintroduced by the fix for the previous
  finding. Two gates measured that independently on the absent document.
  Pins: UM4 (the subcollection deny, which must never be "simplified" into a wildcard), UM5 (the
  un-migrated document), UM6 (no write limb), UM7 (the collection-group route), UM8/UM9 (the
  absent document, owner and stranger), UM10 (the undecided field), and
  `firebase_data_export_repository_moderation_test.dart` for the projection — which three gates
  found was executed by NOTHING, because every test faked the repository method it lives in.
  **The price, stated where the person who will pay it reads:** `hasOnly` couples the read to
  every WRITER of that document. The day someone legitimately adds a field — the moderator tool
  writing a `lastReviewedBy`, this entry's own example — the whole document becomes unreadable to
  its subject and the Art. 15 section fails closed and LOUD, carrying a warning and a
  `data_completeness` line for every reported user until the rule and the Dart projection are
  updated together. That is the intended direction, and it is easy to meet as an outage first.
  The key set lives in three languages — the rule, the Dart projection and the Cloud Function's
  write payload. The first two are now compared MECHANICALLY by
  `rules_allowlist_drift_test.dart`, which reads both out of their source files; the writer is
  still coupled by prose alone, and a key-set assertion over its payload is its own ticket.
  Three drift directions, and only two are loud: rules wider than the projection leaks a field
  nobody decided about; the projection wider than rules denies the whole document and fails the
  section for every reported user. **The third is SILENT** — rules and the writer widen together
  while the projection does not, and the new field is simply dropped from the bundle with nothing
  reddening. That is the direction the drift test cannot see, because it compares the two halves
  that now agree.
  UM8 was itself VACUOUS when first written: this suite shares one emulator and clears nothing
  between tests, so an earlier test's seed made "absent" a lie, and the case passed with the null
  arm deleted. It deletes the document first now.
  **Deploy order for this change is load-bearing and is NOT the order BUT-2046 states:** the
  functions (the new writer) go BEFORE the rules, or the old writer is still creating the exact
  documents the conjunct then denies.
  ADR-0017 carries the reversal. BUT-2046 follow-up, 2026-09-08

- **A legal hold for open moderation cases is DECIDED and NOT BUILT (2026-09-08).** The
  BUT-2046 entry says "a reported person can erase their way out of an open moderation review,
  and no legal hold stops them … not weighed by Malin, because Art. 17 has no exception this
  build could rely on". **That last clause is false and is retired**: Art. 17(3)(e) covers the
  open-case window and 17(3)(b) the period once a DSA Art. 17 statement-of-reasons duty is live.
  DSA Art. 17 sits in Section 2, which Art. 19 does NOT exempt micro/small enterprises from.
  **Malin's explicit call, 2026-09-08: build the hold.** It is planned (`tasks/todo.md`) and
  reviewed by a four-seat panel, and it is NOT in this commit — the panel measured it as a
  larger change than the plan described, and a half-built erasure path is worse than a named
  gap. Until it ships, the residual stands exactly as the BUT-2046 entry describes it.
  What the panel added, and what the build must carry: a lawful hold must NOT be expressed as
  `gdprCompliant: false` (that field means "something went wrong" throughout the cascade, and a
  disclosed refusal is not that); `probeResidualData` would otherwise flip it false permanently
  with nothing able to clear it; the hold needs an OUTER TIME CAP independent of case-close,
  because a case nobody triages never closes; the notice owes the person the Art. 12(4)
  elements, i.e. the right to complain to IMY and to a judicial remedy; the predicate is
  `status != 'closed'` and nothing narrower; and the hold as scoped is ONE-DIRECTIONAL —
  `deleteUserReports`, the reporter leg of `deleteModerationSystemEvents` (ADR-0016, decided
  hours earlier) and `deleteReportHistoryByReporter` all destroy the same evidence with no
  status check, so a REPORTER's erasure still empties an open case.
  BUT-2046 follow-up, 2026-09-08

- **The legal hold for an open moderation case is BUILT, and it keeps the reported person's
  uid while it stands (2026-09-09).** The entry above says the hold is "DECIDED and NOT
  BUILT". It ships here. What it does: when the erased account is `contentOwnerId` on at
  least one `reports` row whose `status != 'closed'`, the cascade keeps
  `user_moderation/{uid}`, its `report_history` rows, and that uid on both the report and on
  the `system_events` row derived from it. Everything else in the cascade runs unchanged.
  **Malin's explicit call, 2026-09-09: keep the uid while the hold lasts** — a deviation from
  BUT-781, which nulls `contentOwnerId` when the reported person erases. She was shown the two
  alternatives and what each costs: nulling it anyway (the hold then preserves evidence nobody
  can attach to a person, which the Trust & Safety seat called theatre), and not building the
  hold at all (the residual stays named, she is the sole moderator, and the system holds zero
  reports). The uid is nulled when the hold lifts, through the same two anonymizers as today.
  **What she was NOT shown**, stated because an attribution is a claim about a person that no
  test can hold: no measurement of how long a real case stays open (there are no reports to
  measure), that the hold is one-directional, and that the `report_history` TTL was about to
  eat the evidence mid-hold. The last two are the build's responsibility and are closed below.
  **The decision lives in `erasure_holds/{uid}`, NOT as a field on `user_moderation/{uid}`.**
  That document's read limb is `hasOnly(['totalReports','lastReportedAt'])`, and the entry
  above states the price of that allowlist in its own words: "the day someone legitimately
  adds a field … the whole document becomes unreadable to its subject and the Art. 15 section
  fails closed and LOUD". A hold field would have been that day. Worse than the general case,
  because the hold is written BEFORE `auth.deleteUser`: an erasure aborting after that write
  leaves a LIVE account whose Art. 15 moderation section is broken permanently. The new
  collection has no `firestore.rules` block, so the terminal `match /{document=**}` denies
  every client. `firestore.rules`, the Dart projection and `rules_allowlist_drift_test.dart`
  are untouched by this change, and that is the point.
  **`report_history.expireAt` is rewritten to `holdUntil` on the held rows.** The TTL policy
  runs 180 days from when the REPORT was written; the hold runs 180 days from the ERASURE. A
  report filed a month before the account is deleted would have aged out mid-hold and left the
  sweep guarding nothing. Somebody else's rows keep their own clock.
  **`gdprCompliant` is untouched and must stay untouched.** It is driven by
  `failedCollections` alone; `retained` sits beside it. A lawful Art. 17(3) refusal is a
  compliant outcome, and folding it into that flag would report a correct erasure as a broken
  one with nothing able to clear the record. For the same reason `probeResidualData` skips
  the legs a hold KEEPS — `residual own moderation rows`, `residual moderation
  record`, `[system_events, "details.userId", "=="]` (the threshold alert, which carries the
  REPORTED person's uid) and `[system_events, "details.contentOwnerId", "=="]`, whose own
  comment calls it "the only thing that measures whether the ANONYMIZE half ran". The set must
  stay in step with `deleteModerationSystemEvents`'s `legs` array — two spellings of one
  decision, and the day they disagree the erasure lies about itself. Named by LOG LABEL, not by
  collection: `report_history` has two legs, and the other one,
  `residual report rows as reporter`, must NEVER be skipped — it is the reporter side, and
  silencing it would hide a real failure of `deleteReportHistoryByReporter`.
  **TWO anonymizers are held, not one.** `anonymizeReportsByContentOwnerWithDb`
  (`moderation/anonymize-reports.ts`) and the cascade's own `system_events` sweep
  (`account-deletion-cascade.ts`). A first version of this build named only the first; holding
  the report while nulling its ops-log counterpart is a half-held case, and it would also have
  tripped the probe leg above on every held erasure, permanently.
  **The predicate is `status != 'closed'` and nothing narrower, so an `actioned` case is still
  open.** `actioned` reads as finished — the moderator HAS acted — and is deliberately held
  until they close it. The cautious direction, and the consequence is stated rather than
  implied: the close button now decides when evidence is destroyed.
  **ONE-DIRECTIONAL, and this is a gap rather than a subtlety.** `deleteUserReports`, the
  reporter leg of `deleteModerationSystemEvents` and `deleteReportHistoryByReporter` carry no
  status check, so a REPORTER erasing their account still empties an open case. Out of scope,
  named rather than left to be discovered.
  **The Art. 12(4) notice is ONE-SHOT and unrecoverable.** It is shown in a dialog, awaited,
  before the sign-out navigation — the last moment anything can be shown, because the account
  is already gone and there is no signed-in surface afterwards. If the app is killed,
  backgrounded or offline in that moment, the person never receives it, and there is no second
  channel: email infrastructure does not exist (BUT-417).
  **The sweep runs FIRST in `DAILY_ANALYTICS_TASKS`, and that has a cost in both directions.**
  Last would put the only thing that ever ENDS a hold in the tail, which is what gets dropped
  under budget pressure — the mistake this repo has already paid for with a silent safety
  control. First means a slow sweep aborts the whole chain, because `runTaskChain` aborts on a
  timeout. What makes first position survivable is the sweep's own wall-clock budget
  (`SWEEP_DEADLINE_MS`), which stops early and defers the rest a day. `MAX_ERASURE_HOLD_SWEEP_ROWS`
  beside it DECLINES rather than truncating, like every sibling cap in this domain, but it bounds
  what is READ rather than how long the run takes. An unbounded, unbudgeted sweep in first
  position is the combination to avoid. The chain runs `retryCount: 0`, so a failed sweep waits a day —
  acceptable against a 180-day cap.
  **`erasure_holds` is in `COLLECTIONS_TO_DELETE`, not in the register-only list.** A reset
  run removes the reports and the moderation record a hold protects, so a hold left standing
  would point at nothing while keeping a uid past the reset that erased everything it guarded.
  `COLLECTIONS_DELIBERATELY_UNTOUCHED` has no runtime teeth and would have left exactly that —
  the same trap the `metrics` entry records.
  **The hold FAILS CLOSED on an unanswerable question.** If the predicate query or the hold
  write throws — so a case KNOWN to be open whose hold write fails is provisional too —
  `applyErasureHold` records a PROVISIONAL hold rather than resolving
  to "nothing was held"; if the TTL push throws, the hold document is already written and it returns THAT one
  (not a provisional) with `ok: false`. Either way the answer survives the failure — because `held` is what stops the cascade's moderation steps and the trigger from
  destroying the evidence, so a transient Firestore error would otherwise produce exactly the
  outcome Art. 17(3)(e) was invoked to prevent, irreversibly. A provisional hold is not a guess
  that a case is open; it records that we could not tell, and the sweep lifts it on the first
  clean run. The `onUserDeleted` read fails closed the same way, and for a second reason: a
  gen1 trigger has no `failurePolicy`, so an unhandled throw there costs the steps behind it.
  Three gates found the fail-open independently, and all three then found that my fix for it
  had the same shape one level down: the fallback write was itself unguarded, so a read failure
  followed by a write failure — one outage, both calls — would have dropped every cascade step
  behind step 13. It is wrapped, and the doubly-failed case is pinned. That case leaves NO
  handle, which is accepted and named: the uid stays on third parties' `reports` rows, reached
  by no cascade, probe, sweep or export.
  **The TTL push is STRICT and the lift is RE-PROBED**, because `commitInChunks` defaults to
  swallowing a failed chunk with a warn and returns rows MATCHED rather than commits that
  succeeded. Without the strict flag, held rows would silently keep dying on the report's clock
  while the two probe legs that would have seen them are the ones a hold skips. Without the
  re-probe, a swallowed anonymize failure would delete the hold document — after which a report
  still naming the erased uid is reachable by NOTHING: no cascade (the account is gone), no
  probe (it ran months earlier and has no `reports` leg), and no sweep (its only handle was the
  document just removed).
  **`held` is keyed on `resourceType`, not on `retained` being non-empty.** `RetainedRecord` is
  a general shape, so a length test would silently disarm the moderation probe legs the day a
  second Art. 17(3) hold ships over some other collection.
  **The `details.userId` threshold alert is held too.** That field carries the REPORTED
  person's uid, not the reporter's — `on-report-created.ts` writes `userId: contentOwnerId` —
  so deleting it while keeping the report would destroy the alert derived from it. The first
  version of this build got that wrong in code and described it wrongly in a comment; the
  comment was struck rather than reworded.
  **The Art. 12(4) notice renders the cap DATE the server sent**, never a number in the copy: a
  hardcoded "180 days" becomes a false promise to the person it is legally owed to the moment
  `ERASURE_HOLD_MAX_DAYS` changes. A missing date says less rather than saying something
  unmeasured.
  **RESOLVED 2026-09-09 (BUT-2047) — Malin, TWO calls: hedge the provisional wording, and show
  the notice whenever something was KEPT rather than only when the erasure fully succeeded.**
  The second call was not one of the questions put to her. It surfaced because the first answer
  could not be built: a provisional hold returns `ok: false`, `runStep` lands that in
  `failedCollections`, `success` goes false, and the handler showed the ERROR dialog — so the
  hedged wording was unreachable on the only path that sets the flag, and a first version of
  this paragraph claimed it shipped. The `code-reviewer` gate traced it.
  What that uncovered is larger than the wording and predates this build: a person whose hold
  could not be evaluated was told "kontot kunde inte raderas helt" and never told that anything
  had been kept, or why. Malin's call: **Art. 12(4) is owed because data was KEPT, which does
  not depend on the rest of the erasure completing.** The notice now sits OUTSIDE the success
  branch; when both apply the person sees the notice first and the failure notice after, because
  the fact they cannot obtain later is what was kept.
  **But NOT when `auth.deleteUser` itself failed.** The notice opens with "Ditt konto är
  raderat", so showing it while the account is still there would put a false sentence above a
  true one. `AccountDeletionOutcome.owesRetentionNotice` therefore requires BOTH something
  retained and the Auth account gone, and `accountDeleted` is derived from
  `failedCollections` not containing `auth_deletion` — every OTHER failed step still leaves the
  account genuinely deleted, and that distinction is pinned in both directions. Found while
  building Malin's call, not by a gate; the first version of the hoist would have shipped it.
  **Named residual: `auth/user-not-found` is the one auth failure where the account IS gone** —
  a retried callable after a timed-out first run, or an out-of-band deletion. `authDeleted` goes
  false anyway, so a genuinely erased person with a live hold gets the error dialog and no
  Art. 12(4) notice. The direction is the safe one (withhold rather than print a title saying
  the account is deleted when it may not be), and the alternative — answering that code as
  "gone" in the callable — changes `success` on an existing path and is Malin's, not an edit.
  **Second residual, pre-existing and now paired with the notice:** the failure branch never
  navigated to `/auth`, so on the newly reachable combination (erasure incomplete, account gone,
  something kept) the person sees the notice, then the failure dialog. What happens to the
  route after that is NOT measured — `deleteUserAccount` signs out before returning and
  `AuthWrapper` rebuilds on that, which this entry already names as unmeasured below.
  On the wording itself: when the hold is provisional the WHAT line reads
  `profileDeletionNoticeWhatUnclear` instead of `profileDeletionNoticeWhat`. She was shown the
  argument on the other side — a vague line in a rights notice is its own problem — and chose
  the honest one.
  **ASKED AND ANSWERED 2026-09-09, after the build: the hedge stays on ONE line.** The
  `integration-reviewer` gate read the notice as a whole and found that the two lines beneath
  still assert as fact what the first withdraws — "Varför: vi måste kunna hantera anmälningen
  färdigt" and "Hur länge: tills granskningen är klar, senast {date}". Malin was shown that, and
  the two alternatives (provisional variants for all three lines; or one line carrying the whole
  reservation). **Her call: leave it.** The first line already says we do not know, and Art. 12(4)
  also requires the notice to be intelligible — hedging every line reads as a disclaimer rather
  than as information. Named residual, not an oversight.
  **ASKED AND ANSWERED the same day: the wording UNDER-CLAIMS on one branch, and stays.** The
  string says "vi kunde inte slutföra kontrollen", which is true when the predicate query threw
  and false when it succeeded and the hold WRITE threw — there the check did finish and did find
  a case. She was shown a wording covering both ("vi kunde inte bekräfta detta färdigt") and
  chose to leave it: the branch is narrow, and the sentence claims LESS than the truth rather
  than more, which is the only direction a notice like this may err in.
  The flag crosses the whole chain (`RetainedRecord.provisional` in TS, the callable's
  hand-written allowlist, the Dart model, the outcome, the dialog). Probed: the producer's flag
  on the undecidable path, the callable allowlist, the model's parse, and the dialog's string
  choice. The allowlist probe was GREEN first — the assertion was answered by a fixture that
  could only produce a NON-provisional hold — so the orchestration fake gained a
  `throwOnReportsQuery` seam, narrowed to the two-`where` predicate query so it cannot also fail
  `deleteUserReports`. NOT probed: the handler line that passes the flag, which is the same
  unpinned wiring named below.
  Question 2 STANDS as it was, deliberately: "En sak" is true today because the server emits at
  most one record, and the tripwire below is the right size of protection rather than a rewrite
  of a legal notice for a case that does not exist yet.
  **THE ORIGINAL QUESTIONS, kept because the decision is only legible beside them — and note
  that Question 1's premise ("On the PROVISIONAL path the notice speaks in the indicative") was
  itself false when it was put to her: on that path there was no notice at all.**
  **TWO OPEN QUESTIONS FOR MALIN, about the wording of a legal notice — named here rather
  than left in a handoff message, because an open question that lives outside this file is
  invisible to the next grep.** Neither is a mechanism question and neither was decided here.
  (1) On the PROVISIONAL path the notice speaks in the indicative — "En sak har sparats: en
  pågående granskning av innehåll som anmälts" — about a case the code could not determine
  exists. Say it plainly anyway, or hedge that one line? A hedge costs a fifth string, not a
  redesign. (2) The copy says "En sak" and `auth_action_handler.dart` renders
  `retained.first`, while the server is built to be able to hold more than one record. Today
  it emits at most one, so this is consistency rather than a defect — but
  `probeResidualData`'s own comment plans explicitly for a second Art. 17(3) hold, and on the
  day that ships BOTH the copy and the `.first` must change with it. Nothing today would tell
  whoever builds it; that is the tripwire this paragraph is.
  **The trigger's call site is graded in the EMULATOR lane, not the unit lane.** This entry
  first said it was "graded by nothing" and that `cleanupUserSocialData` "has no unit harness at
  all, and building one is a larger job than this build". The second half was false —
  `on-user-deleted.integration.test.ts` already drives that function — and it is the exact shape
  a false coverage pointer takes: the sentence a later run cites to skip writing the test. The
  gap is closed there instead, with a held and an unheld subject.
  **And the replacement sentence was false too, one notch weaker — the third revision of this
  paragraph and the second false coverage claim in it.** It said the guard is graded "in the
  emulator lane", which names a lane that does not contain the file. Measured:
  `functions/scripts/check-test-registration.js` lists
  `on-user-deleted.integration.test.ts` in `KNOWN_UNREACHABLE` ("BUT-1702 — emulator suite,
  unverified in CI"), the CI unit runner excludes every `test:integration:` prefix, and
  `test:rules:all` does not name it. NO automated lane runs it. The pin is real and was run
  (21/21 against a local emulator, and mutation-probed), but it is proven by a HAND run — while
  its `system_events` twin is proven in the unit lane. Wiring the suite up is BUT-1702's
  ticket, not this build's.
  **Not pinned, and said plainly rather than implied by a coverage claim:** the branch in
  `auth_action_handler.dart` that shows the notice has no widget test — and since BUT-2047 that
  same block carries two more decisions: it passes `provisional` through, and it sits OUTSIDE
  the success branch. An edit moving it back inside would restore the exact gap this change
  closed, silently. Both the dialog's own behaviour on the flag and the model's parsing of it
  ARE pinned; it is the wiring between them that is not. Its
  two collaborators are reached through `ServiceLocator` behind a re-auth step, and the setup
  was out of proportion to the line. Also unmeasured: whether `AuthWrapper`'s rebuild on
  sign-out can tear the notice down before it is read. What IS pinned: both halves of the
  hold's server side (`system_events` and `reports`, each with a control arm and, for the
  reports guard, a third arm proving it reads the DECISION rather than re-deriving the
  predicate), the dialog's four Art. 12(4) elements, the rendered date in both directions,
  `hasRetainedRecords` in both directions, the callable's RETURN, and the audit row's
  `retained`.
  **A hold that cannot be LIFTED outlives its own cap.** The 180 days end the PREDICATE, not the
  retention: if `liftErasureHold` keeps returning false — a missing index on the `system_events`
  sweep, say — the hold stands past the cap, logged at ERROR and counted in
  `HoldSweepResult.failed` every day, with nothing else raising it. Named rather than left to be
  discovered.
  **Mutation-probed, and this list is what the word covers**: the deleter's held `details.userId`
  leg, the probe's matching skip, the TTL-push failure still returning the hold, the undecidable
  predicate holding provisionally, the trigger guard leaving a handle, the lift's `reports`
  re-probe, both anonymizers on the lift, the `actioned` predicate, the chain's first position,
  the wrapped fallback write in the trigger guard (the doubly-failed case), the `held` ARGUMENT
  at the cascade's call site, `held` being keyed on `resourceType`, all three bounded branches
  (row cap, wall-clock budget, `report_history` cap), the sweep's per-uid isolation, the
  `cascade_retain` audit row, both Dart hops that carry `retained` out of the callable, and the
  trigger guard at its real call site — that last one against a live emulator (21/21), where
  swapping it back to the unguarded anonymizer reddens the held assertion. Two of them went
  GREEN on the first attempt and were real gaps rather than probe
  errors — the lift's re-probe had no scenario staging a silently-failed anonymize, and the
  `details.userId` leg had no fixture carrying the field. Three MORE probe runs came back INVALID — a mutant that left an unused
  import, so `tsc` aborted before a single assertion ran and the output carried neither
  FAIL nor a crash. Those are probe ERRORS, not results, and are counted separately from
  the two above on purpose: conflating them is how a working pin gets deleted as vacuous. The Dart pins were probed in the
  earlier round; the widget suite's date pair was not re-probed after the fix round.
  BUT-2046 follow-up, 2026-09-09

- **The Art. 15 bundle does NOT report who has blocked the requester — not the uids, not a
  count (BUT-2018, 2026-09-05).** `SocialExportManager.exportBlocks` returns only
  `outgoing_blocks`, the blocks this user PLACED; `FirebaseDataExportRepository.exportIncomingBlocks`
  is deleted rather than left callable, because dead code that looks callable is how a removed
  section returns.
  **Malin's explicit call, 2026-09-05**, over the two alternatives she was shown: keeping the
  uids unredacted with a dated entry here, and keeping a bare count without the uids. She chose
  the strictest of the three. **What she was NOT shown, stated because an attribution is a claim
  about a person no test can hold:** no reason is recorded for refusing the count specifically,
  and the argument that would have supported it was not put to her — a count is not one fact but
  a series, so a requester who exports twice reads the DIFFERENCE against what they did in
  between, which can re-identify the blocker the uids were withheld to protect. That argument is
  the review panel's, made after the decision, and it is written here so nobody later reads it
  back as hers.
  The basis is Art. 15(4): the right to a copy may not adversely affect the rights and freedoms
  of others, and a block is placed by someone wanting distance from — often — the very person now
  requesting the copy. Decided on the `blocks` collection's own facts. NOT derived from BUT-1450,
  BUT-1732 or BUT-1772, each of which says in its own text that arguing across collection
  boundaries is the error it exists to record.
  **The omission is STATED in the section's `data_minimisation` line, and that line is emitted on
  every path including the failure one.** Two separate requirements, and the second is the
  control: an omission the subject cannot see is an Art. 12(1) gap rather than a minimisation
  decision, and a note that appeared — or read differently — only when somebody HAD blocked them
  would reconstruct the withheld fact from its own presence. `exportBlocks` issues no query
  against the incoming direction at all, so it cannot know either way; the byte-identical note
  across an empty read, a populated one and a refusal is pinned.
  **`EXPORT_EXEMPT.block_mirror` is RE-ARGUED by this change, not inherited.** It previously
  excused the server's projection as redundant, retired verbatim: "the SAME facts the bundle
  already reproduces under `incoming_blocks`, which reads the `blocks` collection this mirror
  is derived from". That premise dies with the section. The mirror is now withheld
  by the SAME decision, which is about the FACT and therefore reaches every store of it: withholding
  the source while exporting the copy would hand over the disclosure through a second door. The
  guard test is inverted with it (`scenario_blockMirrorExemptionRestsOnTheSameDecision`): it now
  fails if the section COMES BACK, so the two halves cannot drift apart in silence.
  **Named residual, and the reason this is a disclosure removal rather than a closed door:** the
  `blocks` read rule still permits `blockedId == request.auth.uid`, because
  `FirebaseBlockRepository`'s three list queries need it for BUT-1917's ballot strip. A client —
  the app's own code, or a hand-rolled one — can therefore still enumerate exactly who blocked it,
  and `public_profiles` resolves each uid to a name. What BUT-2018 removes is the export handing
  that list over as a document. Do not read this entry as saying the capability is gone.
  **This makes the open rules question CHEAPER, and it is still Malin's.** BUT-1917's offer to
  split the `blocks` read limb (`allow get` both directions, `allow list` blocker-only) priced
  it as killing both the ballot strip and the Art. 15 section; that pricing is retired in the
  BUT-1917 entry itself. The split now costs only the ballot strip — which covers votes
  cast before the poll-vote rule landed, and the app is not live, so today it covers nothing.
  Measured, not assumed: the three readers are `.where()` LIST queries, so the split does break
  them. Verified in the same review that no privacy-policy or in-app copy claims this data is
  exported — `docs/legal/privacy_policy.md` and its Swedish twin describe the export by right,
  never by section. BUT-2018, 2026-09-05

- **The `blocks` read limb is NOT split, and the sentence that priced the split was false
  (BUT-1917/BUT-2018, 2026-09-09).** `allow read` keeps both disjuncts, so
  `FirebaseBlockRepository`'s three `.where('blockedId', isEqualTo: uid)` list queries keep
  working and a client can still enumerate its own blockers. **Malin's explicit call,
  2026-09-09**, taken twice: once on a price that was wrong, and again on the measured one.
  Retired verbatim, from the BUT-1917 entry: "What that half actually covers is votes cast
  BEFORE the rule landed, and
  the app is not live, so today it covers nothing." Retired verbatim, from the BUT-2018 entry:
  "The split now costs only the ballot strip — which covers votes
  cast before the poll-vote rule landed, and the app is not live, so today it covers nothing."
  Both are true of the OUTGOING direction and false of the INCOMING one, which is the half the
  split would actually remove.
  Measured in `blocked_user_filter.dart` and `firestore.rules`: `notBlockedByAnyoneHere()` is
  one-directional BY DESIGN — it refuses the blocked person's vote and lets the blocker vote
  normally, because refusing the blocker would punish the person who used the safety feature.
  So no server rule has ever covered a BLOCKER's ballot, and none is planned to. The client's
  incoming strip is the only thing that removes it, and it sits on the DECISION path
  (`MessagingService.closePoll` unions `requireBlockedByIds()` into the set it resolves the
  winner from), not only on the display path. That is a permanent case, not a pre-rule
  residue.
  So the split's real price is that a person who has blocked you gets their ballot counted in a
  poll you close, and the recipe it wins lands in your week. Weighed against an exposure that
  reaches only a hand-rolled client — BUT-2018 already stopped the export handing the list over
  as a document — and declined.
  **The open question BUT-1917 left for Malin is therefore CLOSED, not still open.** A future
  reader must not re-offer the split as cheap; if it is ever re-proposed, the incoming half of
  the tally has to be replaced first, and the only shape that does not re-disclose the fact is
  moving poll closure to the Admin SDK. That was offered and declined on cost, 2026-09-09.
  The false pricing was carried from BUT-1917 into BUT-2018 unmeasured, in the same commit that
  claimed "Measured, not assumed" about the neighbouring clause — the measurement covered which
  queries the split breaks, never what the broken half was protecting.
  BUT-1917/BUT-2018, 2026-09-09

- **The Art. 15 bundle does NOT name the block mirror among what it withholds
  (BUT-2018, 2026-09-09).** `EXPORT_EXEMPT.block_mirror` stays exempt and its omission is
  disclosed through the BLOCKS section's `data_minimisation` line, which tells the subject that
  who has blocked them is left out and why. It is deliberately NOT named in
  `PreferencesExportManager.exportAccountSubcollections`' `data_minimisation` text, where
  `rate_limits`, `counters` and `report_throttle` are.
  **Malin's explicit call, 2026-09-09**, over naming it: the bundle already withholds that fact
  and says so, and enumerating our internal copies would tell the subject we keep a list of who
  blocked whom — a disclosure nobody asked for, on the very fact BUT-2018 exists to withhold.
  This is why the universal "each exempt collection is named in that section's own
  `data_minimisation` text" was struck from `docs/security/account-subcollections-retention.md`
  and its twin from `account-deletion-cascade.ts`: the register now names each exemption's own
  disclosure site instead. BUT-2018, 2026-09-09

- **A blocked person MAY READ comments on the blocker's recipe, and that is a decision rather
  than a gap (BUT-2054, 2026-09-09).** The `recipe_comments` read limb carries no blocking
  conjunct — it is author OR `recipeOwnerId` OR `sharedWithUserIds`, plus the admin path — while
  the notification gate denies a blocked caller outright, and the comment and rating gates deny
  one whose payload carries `recipeOwnerId`. What that person may DO is gated; what they may SEE
  of a half-public surface is not.
  **Named residual, measured by the `firestore-rules-tester` gate while recording this:** those
  two gates read `!('recipeOwnerId' in request.resource.data) || isNotBlockedBy(...)`, so a
  hand-rolled client that OMITS the denormalised field is not gated at all. No suite pairs an
  omitting payload with a blocked actor. That is a separate defect from this decision and is
  filed as BUT-2057 — do not read this entry as saying the write side is closed.
  **Malin's explicit call,
  2026-09-09**, over adding the conjunct: hiding the comments would tell the blocked person that
  a block exists, which is the same reasoning that keeps the poll TALLY visible to them
  (BUT-1917) and that makes the ballot strip one-directional.
  Do not read the existing deny test as evidence for the other answer. `recipe_comments: blocked
  user cannot read comments on blocker's recipe` is a DUPLICATE of the stranger deny, measured
  with a fixture mutant: repoint the block document to an unused uid and that case still passes
  while the four cases that do turn on blocking go red (20/24). Its comment claimed
  "defence-in-depth … reading another blocked user's prior comment would still leak", which
  attributed the deny to blocking; that clause is struck rather than reworded. The test itself
  stays — a duplicate of the stranger deny is harmless, and deleting it costs a read-limb case.
  **Named residual, and the direction that would make today's fixture dangerous:** if
  `isNotBlockedBy` ever moves from a bare `exists()` to a FIELD READ, this suite's fixture
  starts deciding verdicts, and a gate written with a defaulting
  `.get('blockerId', '')` would pass silently on the wrong content. Raised by the
  `firestore-rules-tester` gate. BUT-2054, 2026-09-09

- **A `data_minimisation` note that carries a THIRD PARTY's fact is byte-invariant; one that
  reports OUR OWN read failing may vary with the outcome. The asymmetry is the decision
  (BUT-2056, 2026-09-09).** Two sections now answer the same question opposite ways, and nothing
  recorded which rule governs which — so a future "harmonise the export notes" would look like
  tidying and would break a decided privacy control in one direction while reddening nothing.
  BUT-2018's BLOCKS note is deliberately identical across an empty read, a populated one and a
  refusal, and that invariance is pinned: a note that read differently when somebody HAD blocked
  the requester would reconstruct the withheld fact from its own presence.
  BUT-2014's MESSAGES note is deliberately CONDITIONAL on whether the chat-groups leg answered:
  with the payload key now absent on failure, an unconditional sentence would describe a section
  the bundle does not carry, which is an Art. 12(1) defect in the other direction.
  **Malin's explicit call, 2026-09-09.** The criterion is whose fact the sentence bears, not
  which section it sits in — so it does not license arguing across collection boundaries, which
  the BUT-1732 entry records as the error it exists to document. A note reporting a read WE
  attempted and failed discloses nothing about anyone else; `error_code` already says so.
  A future edit that makes a third-party note vary must be caught by a test, not by this entry.
  BUT-2056, 2026-09-09

- **SUPERSEDES the "THREE other membership-removal paths do NOT cut group-menu access" entry
  above (BUT-2005, 2026-09-09).** Retired verbatim: "OPEN, named rather than left to be found:
  THREE other membership-removal paths do NOT cut group-menu access. `cutGroupMenuPlanAccess`
  is wired only into `removeChatGroupMember`." Both named paths call it now —
  `messaging/enforce-group-minor-membership.ts` (the child-safety backstop) and
  `groups/ensure-category-chat.ts` (the category sync's eviction loop) — from their existing
  post-transaction blocks. The function moved to `groups/group-menu-access.ts` and takes a LIST
  of departing uids, doing one scan and one update per plan for all of them.
  **Still open, and NOT closed by this:** `GroupWeeklyMenuPlanService.removeParticipant` in
  `lib/` has no cut. It remains callerless, as its own entry above records.
  **A promotion nobody performed writes NO `editTrail` row. Malin's explicit call, 2026-09-09**,
  against the alternative of a `"system"` sentinel in `actorId`. That value would be written
  only by the backstop, on a document every plan participant can read, in the same update that
  removes the evicted uid from `participants`, with no `memberLeft` row beside it — the same
  durable inference BUT-1856 refused a tombstone to prevent. `creatorId` is the plan's sole
  admin and the creator is whoever closed the poll, so an evicted minor who closed it reaches
  the promotion branch every time. The promotion
  still happens and is logged; only the row is skipped. This deviates knowingly, and on this
  path only, from the rule BUT-1971 set on 2026-08-31: a privilege grant this code makes
  silently belongs in the trail. The two call sites with a human actor still write the row.
  A second reason the sentinel was the wrong shape, measured by the `integration-reviewer` gate:
  `GroupWeeklyMenuPlan.contributorUserIdsForWrite` unions every trail row's `actorId` into the
  erasure handle, which `firestore.rules` makes append-only and caps at 200 — so a non-uid there
  is permanent, unclearable by any `arrayRemove(uid)`, and eats a slot for the document's life.
  The model already excludes the `'deleted'` tombstone for exactly that reason.
  **Widened and named rather than left to be discovered:** the emptied-roster DELETE now fires
  when the whole departing SET empties a plan, so the backstop and the category sync can delete
  an old week outright. The entry accepting that delete was reasoned about ONE leaver on
  `removeChatGroupMember`; the brick argument carries, but these two triggers are not what Malin
  weighed. BUT-2005, 2026-09-09

- **SUPERSEDES the BUT-2005 entry above: the CATEGORY SYNC does not cut group-menu access,
  and the child-safety backstop does (BUT-2005, 2026-09-10).** Retired verbatim:
  "Both named paths call it now —".
  Retired verbatim: "so the backstop and the category sync can delete".
  Retired verbatim:
  "The two call sites with a human actor still write the row."
  `cutGroupMenuPlanAccess` is called from `messaging/enforce-group-minor-membership.ts` and
  from `groups/remove-chat-group-member.ts`. `groups/ensure-category-chat.ts` does not call it,
  and does not import it. So the "THREE other membership-removal paths" entry that BUT-2005
  retired is live again for the category sync, and the emptied-roster DELETE is reachable from
  the backstop and from `removeChatGroupMember`, not from the sync.
  The reason is a contract the sync states three lines above where the call sat: "No tombstone:
  this removal MIRRORS the category. Putting somebody back into the social group must put them
  back into its chat, and a tombstone here would make that impossible." The cut has no inverse.
  Measured: no function under `functions/src` re-adds a plan participant, and
  `GroupWeeklyMenuPlanService.addParticipant` has no caller anywhere, tests included. An owner who removes a friend from a category and re-adds them
  therefore gets the chat membership back and never that person's access to weeks that already
  exist; where the departing set empties an old week's roster the week is deleted outright.
  **Open for Malin, and the reason this half is not built: her call of 2026-09-09 was to build
  both remaining eviction paths, and she was not shown that one of the two mirrors a REVERSIBLE
  admin action while the cut is one-way.** The backstop half is unaffected — an eviction for a
  minor's protection has no re-add that should silently restore write access — and ships.
  The backstop's CALL SITE is pinned by `an evicted minor loses their group weekly menu plan
  access` in `enforce-group-minor-membership.integration.test.ts`, which is named in
  `test:rules:all`; passing `[]` there instead of `toRemove` reddens that case and no other.
  BUT-2060 carries the question.
  Raised by the `integration-reviewer` push gate. BUT-2005, 2026-09-10

- **SUPERSEDES two sentences of the `ingredient_suggestions` Art. 15 entry above
  (BUT-2038, 2026-09-10).** Retired verbatim — note that the two mirrors word this
  decision DIFFERENTLY, a pre-existing drift, so each copy retires its own sentence and a
  grep for one will not find the other: "The cost of failing closed is real and is why the section carries a `data_minimisation` line: the collection's create rule uses `hasRequiredFields`, not `hasOnly`, so a client can store fields outside the declared type, and the allowlist would then drop the requester's OWN content — an Art. 15 defect in the other direction." The create limb now carries `keys().hasOnly(...)` over the SUBMISSION half
  of `IngredientSuggestion` — the five required fields plus `suggestedCategory`,
  `suggestedProperties` and `recipeContext` — so a client cannot store a field the export's
  allowlist would drop. `reviewedAt`, `reviewedBy`, `reviewNotes`, `notifiedAt` and `sourceApp` are outside it:
  every one is written by the Admin SDK — the first three by the console, the last two by
  `onSuggestionCreated` itself — and the Admin SDK bypasses rules. The limb also pins `status == 'pending'` BY VALUE — `hasOnly` admits any
  value of a field that is in the declared type, so only a value check refuses a forged
  approval — and bounds every free-text field and the array.
  Retired verbatim: "Second residual: `deleteIngredientSuggestions` reads unbounded, on a
  collection whose create limb has no `rateLimitWrite`". It reads `.limit(2000 + 1)` and
  DECLINES above the cap, returning false into `failedCollections` so the run reports
  `gdprCompliant: false` rather than silently half-erasing. `probeResidualData` still counts the
  collection unbounded, so deleter and probe cannot agree that nothing is left.
  **`rateLimitWrite` is deliberately NOT added, and that is Malin's call, 2026-09-09.** The
  helper only READS `users/{uid}/rate_limits/{type}`; the WRITING repository stamps that bucket,
  and no code in `lib/` creates a suggestion — so it would bound nothing and read as a control
  that never existed, which this repo already carries one of. She was NOT shown the following, which the `firebase-backend-security` gate measured
  afterwards: the helper FAILS OPEN on a missing bucket and the bucket is
  client-writable, so even after a client path exists it throttles only the app's own repository,
  never a hand-rolled one. Row COUNT therefore remains unbounded; what changed is that the
  cascade's cap turns that into the planter's own degraded erasure rather than a callable
  timeout. A real bound needs a callable-mediated create or a server counter.
  Still open and unchanged: whether `reviewedBy`/`reviewNotes` stay withheld is Malin's, and a
  moderator's uid sitting on somebody else's row is reached by no cascade, probe or export.
  BUT-2038, 2026-09-10
