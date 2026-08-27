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
- **The shared-shopping-list GDPR section keeps other members' UIDs, their permission levels
  and the full `contributorUserIds` array (which includes people who have LEFT), and drops
  their display names** — Art. 15(4) balance; the requester's own client can already read
  every one of these documents under `firestore.rules`, and the export's selectors mirror the
  deletion cascade's. **Malin's explicit call, 2026-07-30** — the entry first shipped arguing
  by analogy from BUT-1450, but that verdict is scoped to notification counterparty ids and
  records a human override, so the analogy did not transfer. Lists the user has LEFT stay out
  because the rules refuse the client that read (BUT-1747). BUT-1732, 2026-07-30
- **The conversations GDPR export KEEPS other participants' display names and UIDs and STRIPS
  their avatar URLs (own avatar kept)** — deliberately the OPPOSITE call to the shared-list
  entry above, made with both on the table. **Malin's explicit call, 2026-07-30.** A name the
  requester has seen on screen every time they opened the thread discloses nothing new, and
  opaque UIDs alone would fail Art. 12(1); an avatar URL is a durable pointer to another
  person's photo that outlives the app.
  Governs `conversation_info`, its message rows, and the shared-recipe, shared-menu and
  shopping-list rows in `shared_content` — **all through ONE shared helper, and that is the
  point**: three sections implementing one decision separately is how they drift.
  Do not cite this entry as evidence that a menu-avatar leak ever reached a bundle; that
  section returned no rows until it was repointed.
  BUT-1772/BUT-1767/BUT-1775/BUT-1798, 2026-07-30

- **The `shared_content` export sections keep other recipients' UIDs and the sharer's
  `sharedByDisplayName`**, scoped to rows where the requester is a RECIPIENT. Membership is
  ONE field, `sharedToUserIds` — the `sharedWithUserIds` dual write was removed 2026-08-03
  because two copies of one fact drifted, costing an invisible export gap and an un-erasable
  uid. (`sharedWithUserIds` remains the legitimate SOLE field on `recipe_comments`; scope any
  change by COLLECTION, never by field name.) **Malin's explicit calls, 2026-08-01 and
  2026-08-03**, both on their own merits — NOT derived from BUT-1732 or BUT-1772, which
  decided different collections; citing either as authority here is the precise error the
  BUT-1732 entry records having made. BUT-1798, 2026-08-01 / 2026-08-03
- **Inside a shared shopping list's nested `listData` copy, other members' DISPLAY NAMES are
  stripped; their UIDs and permission levels are KEPT; the requester's own name is kept** — covers
  `ownerDisplayName`, `lastActivityByDisplayName` and, per item, `addedByDisplayName`,
  `purchasedByDisplayName` and `lastModifiedByDisplayName`. **Malin's explicit call, 2026-08-01.**
  A shopping-list share embeds a whole copy of the sender's list, so the section's top-level avatar
  strip never reached inside it. This deliberately follows BUT-1732 (the same data, seen from the
  same angle: a shopping list someone else controls) rather than the wrapper-level call in the entry
  above, which governs the sharer's single name on the share document, not a roster of everyone who
  ever touched the list. The asymmetry between the two entries is the decision, not an oversight.
  The walk fails CLOSED — an unrecognised shape drops the name. BUT-1798, 2026-08-01
- **Other participants' `perUserSettings` are STRIPPED from the conversations export;
  `lastReadTimestamps` are KEPT** — the two fields BUT-1772 deliberately left open, split rather
  than decided together. **Malin's explicit call, 2026-07-30 (BUT-1774).** Another member's
  mute/pin/archive state is pure third-party behaviour the client never renders for anyone but
  yourself, so the "you have already seen it in the app" argument that saved the names does not
  reach it; a read timestamp sits inside the requester's own thread history and does have a weak
  counterpart on screen (`MessageStatus.read` shows *that* a message was read, not when). Do not
  propose stripping `lastReadTimestamps` "for consistency" — the asymmetry is the verdict.
  BUT-1774, 2026-07-30
- **A colon-terminated bare GLUTEN word rescued into the flat ingredient list must ALSO be
  exempted from `isValidIngredient`, `isGarbage` and the `_deduplicateIngredients` containment
  branch in BOTH directions** — refusing the heading is not sufficient on its own, and the
  rescue is colon-terminated-only. Do not "simplify" the three exemptions back into one flag;
  each one drops the gluten row on its own. BUT-1727, 2026-07-30
- **A household member whose profile cannot be READ widens the allergen union with a
  common-allergen floor (and shuts the UNKNOWN hatch) instead of being SKIPPED — and that
  floor is ALLERGENS ONLY, never `defaults.trackedDietary`.** Skipping would filter as if they
  had no allergies; inheriting the default diets would make "vegansk" a hard requirement and
  empty an omnivore household's menu. A profile that does not EXIST (`missing`) is the
  opposite call and does not degrade the roster. The user is told — `isRosterComplete: false`
  surfaces in the opt-out dialog and on the menu. BUT-1663, 2026-07-26
  **AMENDED 2026-08-12 (BUT-1693): the floor is CONDITIONAL on opt-in** — another account
  holder whose private settings this device may not read gets their SHARED list instead, if
  they shared one. Three parts survive deliberately: a member who has not shared is unchanged;
  the signed-in user is never read from a share; and a READ FAILURE still degrades the roster
  even when they shared, because a share can lag behind the list its owner already changed.
  Behind `enable_household_allergen_sharing`, OFF — with the flag off nobody can have shared,
  which is knowledge, not an outage, so it must never degrade.

- **`socialFeatures` consent gates nothing, by design** — social runs on the GDPR contract
  basis, not consent; wiring it would be consent theatre and would fail closed for every
  existing user. BUT-1523, 2026-07-12
- **Account deletion does not cascade to `parse_events`** — the 30-day TTL residual is
  accepted under Art. 17's reasonable-erasure window. BUT-1570, 2026-07-16
- **RETIRED — `cook_snaps` and `activity_events` creates ARE age-gated, and stay that way.**
  The 2026-07-04 "deliberately ungated" entry was stale; both creates carry `isAgeCompliant()`
  (BUT-1418/ADR-0002) and four rules tests deny a missing or false claim. Malin resolved it in
  favour of the code on 2026-07-24. Never remove either gate citing the old entry. 2026-07-24
- **Feature-retention DAILY AGGREGATES keep a deleted user's contribution, and the per-user
  rows get a cascade step rather than a TTL** — `analytics/feature_retention/users/{uid}_{date}`
  is erased by `deleteFeatureRetentionFlags`; `daily/{date}` holds five integers and a date, no
  uid, so Art. 17 does not reach it and history is never recomputed. A TTL is NOT an option on
  those rows: their collectionGroup id is `users`, the same as the profile collection, so the
  policy would arm over real user documents. BUT-1789, 2026-08-01
- **A colon-terminated bare GLUTEN word stays an INGREDIENT; every other allergen
  keeps colon-wins** — "Mjöl:"/"Råg:"/"Öl:" are as likely a quantity-less OCR row as
  a heading, and a heading leaves the tagging input; "Mjölk:"/"Ägg:"/"Soja:" stay
  headings. The asymmetry is the decision, not a gap. BUT-1714, 2026-07-27

- **Revoking a group does NOT cut a member who also holds a direct share** — and an
  explicit "remove this person" DOES cut them regardless of how many grants they hold. The
  asymmetry is the decision, not a gap: a group share and a direct share are two separate
  decisions about the same person, so undoing one must not undo the other, while an explicit
  removal is the user overriding every reason at once. Provenance lives in
  `socialData.grants` (uid -> `['direct', 'group:<categoryId>']`), which is DESCRIPTIVE only —
  `memberPermissions` stays the sole source of truth for access and `firestore.rules` reads
  only that, so nothing in `grants` can widen what anyone may see. A group share is a
  SNAPSHOT: members are resolved at share time, so joining the group later grants nothing
  retroactively. Do not add a "missing `grants` means everyone is direct" compatibility
  path — the field is written from the start and the only documents without it are test data
  (Malin, 2026-08-03). BUT-1797, 2026-08-04

## Engineering

- **An OFFLINE read of a weekly menu plan trusts a cached "this week is empty", and a
  write may then build on it** — `getDocCacheFirst(acceptCachedAbsence: true)`, passed by
  `FirebaseWeeklyMenuPlanRepository.fetchForWeek` and by nothing else. The flag only
  decides what happens once the server read has FAILED, on any error — so a timeout on a flaky connection can still serve the cached absence. Offline it lets a genuinely
  empty week be planned again, which BUT-1939's refusal had blocked.
  The residual is real and bounded: `fetchForWeek` is NOT display-only —
  `WeeklyMenuPlanService._loadPlanForWrite` and `copyWeek` reach it from write paths, and a
  stale absence there becomes an empty plan that `save()` writes back with `set()`. What
  stops that destroying anything is `firestore.rules`' update limb refusing a changed
  `createdAt`, so the server keeps what another device wrote and the user loses their own
  local edit instead. Do NOT pass this flag on anything an allergen or a permission
  decision reads: a negative cache entry has no expiry and can outlast the install, and on
  the profile path a stale absence returns NULL, which `lookupUserProfile` reads as
  `missing` for anyone but the signed-in user — dropping that member from the allergen union
  rather than falling back to BUT-1663's floor, which a THROW buys.
  BUT-1961, 2026-08-27

- **AMENDED same day (BUT-1961):** the entry above names `_loadPlanForWrite` and `copyWeek`,
  and that list is short. `readWeek` also calls `fetchForWeek` and mints `readFailed: false`
  for any null, so for a cached-absent week the `readFailed` guards on the PERSONAL
  chain do not fire, including BUT-1928's personal poll-close guard, which sits on a
  one-way door. The GROUP chain reads through a repository that does not pass the flag,
  so its guard still fires. Intended
  where the absence is true; where it is stale the same `createdAt` limb denies the write,
  so the server is safe and the user loses their own edit. That limb had NO rules test until
  2026-08-27 — it does now, on both the personal and the group collection
  (`weekly-menu-plans-rules.test.ts`, W2 and G1, both mutation-probed). Do not write any
  further "the server refuses it" sentence without citing them. Malin signed off BUT-1928's
  refusal, so this weakening is hers to know about. The fix also only helps a week fetched
  while ONLINE at some point — a never-fetched week still throws, by design.

- **The recipe GRID card draws no dietary row, and that is a measurement, not a deferral
  (BUT-1906, Malin's explicit call 2026-08-23).** A dietary badge carries its WORD; the
  allergen badges beside it are icon-only. Measured on a 2-column tile: the row has 88
  logical pixels on a 360dp phone and 68 on a 320dp one, while "vegansk" needs 111 and
  "vegetarisk" 145 at NORMAL text size, growing to 188 and 255 at 2x. There is no text size
  and no phone width where it fits. Icon-only was the alternative, and the badge does
  support it (`showLabel: false`, as the allergen row already uses) — it is USELESS, not
  unavailable: `DietaryStatusBadge` takes its icon from the STATUS, so both diets render the
  same green leaf, and dropping the word without first giving each diet its own icon
  replaces the row with two identical marks. Do not propose adding it back "for consistency with the list view":
  the DETAILED layout is full-width and keeps the word, and that asymmetry is the decision.
  (The compact layout draws neither badge row — it is not evidence either way.) `recipe_card_grid_badges_test.dart` pins both halves — the grid draws none,
  the detailed layout still does. BUT-1906, 2026-08-23



- **The conversation roster's bootstrap branch is GONE, and so is the read fallback that
  spelled the same idea twice (BUT-1838, 2026-08-13).** `parentDoc() == null` could not tell
  "parent deleted" from "parent not written yet", so it let a stranger pre-seat a row in a
  never-chatted group AND re-opened over every row of any deleted conversation. Safe to remove
  because `createChatGroup` writes group, conversation and roster in ONE Admin-SDK transaction,
  so the parent always exists first. The write rule is now
  `attestedWriter() && !('groupId' in parentDoc().data)` — narrower than plain attestation on
  purpose: a GROUP roster row must come from the Admin SDK or a member could seat a peer and
  route round the minor gate.
  **Do not** re-introduce either hatch; they were textually separate and only die together.
  Test P3B now DENIES — that flip is the intended signal, do not "fix" it back. C7B pins the
  null-metadata deny; the old "create and update must keep different null spellings" warning is
  stale and was corrected the same day. Rows orphaned before this are unreadable on disk;
  the backfill stays closed unbuilt (BUT-1839).

- **Account deletion erases `conversations/{id}/participants/{uid}` in TWO legs, and one
  leg alone is not enough (BUT-1822, 2026-08-13).** Leg 1: the ≤2-participant branch clears
  the WHOLE roster BEFORE deleting the parent and ABANDONS the parent delete if that fails,
  reporting the step INCOMPLETE (`gdprCompliant: false`). Leg 2: a CAPPED collection-group
  sweep on `participantId`, which DECLINES rather than truncating above
  `MAX_ROSTER_SWEEP_ROWS`, beside an uncapped `count()` probe.
  **Do not** fold the two legs into one query, remove the cap, relax the decline-or-probe
  pair, reorder leg 1, turn its INCOMPLETE report into a success, or let a future edit delete
  the parent on a false answer from either leg. The decline behaviour
  and the probe are FROZEN — they are the Art. 17 completeness signal.
  A `direct_` conversation id is two raw uids and is HASHED in every log on this path.
  The fix is FORWARD-ONLY: rows orphaned earlier, and rows orphaned by a user's own
  "delete conversation" (BUT-1825), are still there. The backfill (BUT-1839) was closed
  unbuilt by Malin 2026-08-13 because the app is not live — reopen at launch, not before.
  **AMENDED 2026-08-15 (BUT-1838): the cap's stated reason went stale one day after it was
  written; the cap is unchanged and still must not be removed.** Do not argue for relaxing
  it from "the bootstrap hole is closed" — three other sources of rows survive, one of them
  a live attested client write. Orphaning remains a one-way door: a deleted parent makes
  surviving rows unreadable forever, though the row's own subject can still update or delete
  it, so do not lean an Art. 17 argument on "un-deletable".
- **`tryClearRoster` refuses an implausibly large roster and leaves the conversation
  STANDING — including as a zero-member document nobody can read, update or delete**, because
  every rule in the block gates on `uid in participantIds`. Accepted as the safest of three bad
  outcomes: deleting the conversation orphans the surviving rows permanently, and throwing
  loops a `retry:true` trigger forever. Only reachable past `MAX_ROSTER_ROWS`.
  **A sweep that cleans this up must clear the ROSTER FIRST** — orphaning is a one-way door,
  since every predicate that could surface a row reads through the parent. The shell is safe
  only while it stands. (The row's own subject can still update or delete it — parent-free
  self checks, measured — so do not argue from "un-deletable".)
  BUT-1795/BUT-1825, 2026-08-12; amended BUT-1838, 2026-08-15

- **A chat message's `sentAt` may sit at most ONE HOUR ahead of the server, and that number
  ships together with the client-side error message that explains a refusal.** Malin's explicit
  call, 2026-08-19 (BUT-1903), shown against the alternative of 24 hours with no app change.
  Do not propose tightening it to minutes: `Message` stamps the DEVICE clock, there is no field
  skew data, and a bound too tight silently locks a real user out of chat entirely. Do not
  propose loosening it either — the residual it buys is a chat-list preview an attacker can
  freeze, and 24 hours of that on a minor's device is what the panel weighed. The two halves are
  ONE decision: a later change that loosens the bound must revisit the message, and vice versa.
  The number lives in THREE languages — `firestore.rules`, `MessageSendErrorMapper.maxSentAtLead`
  and `clockSkewBucket` — and a tightening that finds only two ships a wrong histogram. Full
  reasoning and the five-seat panel: `docs/org/adr/ADR-0008-clock-bound-on-message-timestamps-and-its-error-message.md`.
  **Not closed by it:** `conversations.lastMessage` is a denormalised copy of `sentAt` whose
  update deny-list does not name it, so the preview can still be frozen without touching this
  rule. Own ticket; a tighter number here is not a substitute for it. BUT-1903, 2026-08-19

- **A minor may be added to a group by any of their FRIENDS, and the strangers already in that
  group can then message them** — the gate checks the person doing the inviting, not everybody
  present. **Malin's explicit call, 2026-08-13 (BUT-1838).** She was shown the alternative and
  its cost: requiring every existing member to be a friend of the minor makes a group with a
  teenager in it possible only when everyone knows the teenager, and blocks any later invite of
  someone who does not. Trust & Safety noted that both the DSA and the app stores are moving
  toward testing who may CONTACT a minor rather than who may ADD one, and still recommended
  shipping this now with the stricter variant as its own ticket. This is the same condition the
  code has always enforced (`computeMinorsToRemove`, `passesMinorDmGate`); what BUT-1838 changed
  is that it runs per PERSON per INVITE instead of once per chat, in
  `functions/src/groups/minor-membership-gate.ts`. Do not widen it silently, and do not narrow
  it to "the creator" — that regression is what the ticket existed to fix. 2026-08-13

- **Other members' `memberSince` is STRIPPED from the conversations GDPR export; the
  requester's own is kept** — the group history cut-off, uid-keyed like the two maps beside it.
  It follows `perUserSettings` (dropped, BUT-1774) rather than `lastReadTimestamps` (kept):
  when another member joined is third-party behaviour, and although the "X har lagts till i
  gruppen" system row gives it a weak on-screen counterpart, that row is exported anyway, so
  the map adds nothing the requester is owed. Reasoned on its own merits — citing BUT-1772 or
  BUT-1732 as authority here is the precise error the BUT-1732 entry records having made. The
  export also gains a `chat_groups` PROJECTION (name, creator, admins, and who added YOU),
  never the raw document: a second copy of a redaction decision is how two sections drift.
  **Chosen conservatively without asking Malin; widening it to keep other members' stamps is
  hers to decide.** BUT-1838, 2026-08-13

- **Renaming a group chat is gated by WRITE ORDER, not by a rule on the visible name** —
  `updateConversation` writes the admin-gated `chat_groups.name` FIRST and lets it throw, then
  the any-participant `conversations.title`. That ordering is the whole control: the
  conversations update rule has no conjunct on `title`, so a hand-rolled client that skips the
  group write can rename what members SEE while the group document and the Art. 15 export keep
  the true name. The app's only rename path goes through this method, so the server's refusal
  stops a non-admin before anything visible changes — but it is not a rules-level guarantee.
  Do not "simplify" the two writes into one, and do not reorder them. The real close is a rules
  conjunct (`title` in `affectedKeys()` on a `groupId` conversation ⇒ caller in `adminIds`),
  which needs its own ticket. **The same shape applies to DELETING a group conversation:** the
  deletion module and the list view both refuse one carrying a `groupId`, but `firestore.rules`
  still allows any participant to delete it, so those two are UX, not controls. Raised by the
  `firebase-backend-security` and `integration-reviewer` gates. BUT-1838, 2026-08-14

- **A message whose `metadata` is a MAP WITHOUT a `poll` key accepts a vote — every share
  card in every chat is votable, and that ships knowingly. Malin's explicit call, 2026-08-17**,
  after being shown the harm bound: the row carries only the caller's own uid, `isValidVote()`
  limits it to three keys and ≤20 option ids, reading the tally is membership-gated,
  `deletePollVotes` erases it, and no UI renders it.
  **The repair must test `poll` for PRESENCE, not `metadata` for TYPE.** An `is map` guard does
  NOT close it — a map without the key is still a map — so a repair written from the null case
  alone lands looking finished and leaves the live case open. `poll-votes-rules.test.ts` pins
  all four states with one green test each, and the owed repair was mutation-probed.
  Art. 15/17 note for the repair: the export probes only `metadata['poll'] is Map` while the
  cascade erases by collection group, so such a row is erasable but not exportable — cover
  both sides. BUT-1832, 2026-08-17
- **The chat duplicate guard MARKS a duplicate; the comment guard DELETES one. The asymmetry
  is the decision, not drift (BUT-1904, ADR-0009, Malin's explicit call 2026-08-26).** A
  rejected chat message is emptied (`content: ""`) and stamped `type: "duplicateBlocked"` in
  place; `senderId`, `conversationId` and `sentAt` are untouched, because `sentAt` is the row's
  position in the thread. Its own sender sees a localized row there; every other participant's
  client drops the row. `guardDuplicateComment` keeps `tx.delete`, its global per-author key,
  no length floor and no flag — unchanged since 2026-05-04. Do not "simplify" the two surfaces
  back into one action, and do not describe the client-side row filter as a privacy control:
  the protection is that the SERVER removed the text. That text is gone by the time the filter
  runs, but NOT before the document became readable, because the trigger is
  `onDocumentCreated` and runs after the client's own write.
  **AMENDED 2026-08-26 (BUT-1904 follow-up): the filter does NOT withhold "only the fact that a
  message was stopped".** The sentence that said so assumed every blocked row is empty. It is
  not: no `firestore.rules` limb bounds what `type` is written TO on a create or a sender
  update, so a client can stamp its own full message and the row arrives carrying its text
  (B16/B17 in `cook-snaps-and-message-mod-rules.test.ts`, both ALLOW). For such a row the
  client-side filter withholds the TEXT as well — which does not promote it to a privacy
  control, because the row was readable before any filter ran and a hand-rolled client simply
  does not apply one. The Art. 15 export deliberately DIVERGES here and keeps such a row
  (`isOthersBlockedRow` requires `content == ''`): withholding a record from its own subject is
  the worse failure. Do not harmonise the two. BUT-1954 carries the third surface,
  `searchMessages`, which filters neither. Load-bearing parts, each of which dies alone: the guard uses `tx.update`
  and never a merge-set, so a message its sender deleted first is not resurrected;
  `firestore.rules` refuses a client update to an already-blocked message, or the sender could
  write the duplicate text straight back in; `syncConversationLastMessage` tests `after.type`
  for blocked-ness DIRECTLY, never behind the candidate gate — the mark's own invocation
  arrives already carrying `duplicateBlocked`, so a gated test never runs and the `>=` tie rule
  projects an empty preview; and its re-read covers UPDATES, not only creates, because the
  read-receipt branch every recipient writes carries a PRE-MARK payload and a create-only
  re-read let it put the duplicate's text back in everyone's preview (reproduced on the
  emulator), and gating the UPDATE side on candidacy instead was the same hole again — a sender
  trimming their message to "ok" edits it out of candidacy, skips the re-read and lands last on a
  blocked row. Creates gate on candidacy; updates do not. Do not bound the read by gating on the
  flag either — it caches per isolate for five minutes, so switching it on would leave a window
  where one isolate marks while another skips.
  The duplicate's TEXT is destroyed and is not recoverable from the row; that was weighed.
  **SUPERSEDED the same day, 2026-08-26 — Malin: build the dismiss control.** This entry
  shipped saying "the sender cannot dismiss the row ON ITS OWN … whether the notice needs its
  own dismiss control is Malin's, and open". Both halves are now false: the notice carries a
  `×` (`SystemMessageWidget.onDismiss`, wired through `MessageBubble.onDismissBlocked` to
  `ChatViewModel.deleteMessage`), and it is the per-MESSAGE delete rather than the
  conversation-level one, so it works identically in a group and in a DM. No dialog and no
  undo — a fourth friction class, written into `.claude/rules/ui-conventions.md` §
  "Destructive-action confirmation" rather than here. The control is gated on
  `_isFromCurrentUser`: another participant's notice draws no `×`, because `firestore.rules`
  allows the delete only to the sender.
  Still true and still the reason the row is not merely cosmetic: the long-press menu is dead
  for every message type, so the `×` is the ONLY per-row affordance. What else can remove the
  row depends on the conversation — ADR-0009 has the measurement. BUT-1904, 2026-08-26


- **`inPollConversation()` reproduces only the MEMBERSHIP half of the message read rule, not
  BUT-1838's `memberSince` cut-off.** Measured 2026-08-17 on a group whose `memberSince`
  postdates the poll: the late joiner is DENIED the poll message and ALLOWED both to read the
  tally and to CAST a vote in it. The write half is the part a read-focused reading misses.
  Deliberately out of scope for the BUT-1801 salvage; the fix is the same cut-off on the read
  AND the create/update limbs.
  **Second Art. 15 route, orthogonal to the entry above:** because a late joiner may vote in a
  pre-join poll, and the export's own `memberSince` filter drops that message before the vote
  probe runs, such a row is erasable but never exportable. The repair must cover both.
  BUT-1832, 2026-08-17
