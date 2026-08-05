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
chain on the same pages". 96.1 < 96.4, so the gate is **not met**.

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
the table. A future session that finds 96.1 < 96.4 and "fixes" it would be re-litigating a
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
  reachable input (a group whose roster is only the sharer). Fixed 2026-08-05 and
  pinned; the tokens-loop collapse is still owed. Collapsing them into
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
