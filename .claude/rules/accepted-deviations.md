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
- **The conversations GDPR section keeps other participants' DISPLAY NAMES and UIDs, and strips
  their AVATAR URLs (own avatar kept)** — deliberately the opposite call to the shared-list entry
  above, made with both on the table. A name the requester has seen on screen every time they
  opened the thread discloses nothing new, and stripping it would leave opaque UIDs that fail
  Art. 12(1); an avatar URL is a durable dereferenceable pointer to another person's photo that
  outlives the app and buys the requester nothing. **Malin's explicit call, 2026-07-30.** Governs
  `conversation_info`, the message rows under it, **and — since BUT-1775 — the shared-recipe and
  shared-menu rows' `sharedByAvatarUrl`**, all through one shared helper so the sections cannot
  drift apart. **Now LIVE:** BUT-1767 repointed the query at the top-level `messages` collection the
  same day, so the section ships instead of failing (`messages-export-failed`). The MENU half only
  became live when `exportSharedMenusReceived` was repointed from the top-level `menus` collection
  (which carries neither `sharedToUserIds` nor `sharedByAvatarUrl`) to `shared_content` — until
  then that section had never returned a row, so nothing leaked and nothing was redacted. Do not
  cite this entry as evidence that a menu-avatar leak ever reached a bundle.
  **Extended 2026-08-01 (BUT-1798):** the same avatar strip now also covers the SHOPPING-LIST rows
  in `shared_content`, added to the export the same day. Still one shared helper — the reason this
  clause exists is that three sections implementing one decision separately is how they drift.
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
- **A household member whose profile cannot be READ WIDENS the allergen union with a
  common-allergen floor (and shuts the UNKNOWN hatch) instead of being skipped — and that
  floor is ALLERGENS ONLY, never `defaults.trackedDietary`** — skipping the member would
  filter as if they had no allergies; inheriting the two default diets would make a hard
  requirement out of "vegansk" and empty the menu of an omnivore household. A profile that
  does not EXIST (`missing`) is the opposite call and does not degrade the roster. The user
  is told: `isRosterComplete: false` drives `householdAllergenRosterIncomplete` in the
  opt-out dialog and, since BUT-1685, on the menu itself. BUT-1663, 2026-07-26
  **AMENDED 2026-08-12 (BUT-1693):** the floor is now CONDITIONAL on opt-in — another account
  holder, whose private settings this device may not read (`settingsMerged == false`), gets
  their SHARED list instead of the floor if they have shared one. Three parts of the old rule survive deliberately:
  a member who has not shared is unchanged; the signed-in user is never read from a share;
  and a member whose profile READ FAILED still degrades the roster even when they shared, because until the settings edit and the share
  move in one atomic write a share can lag behind the list its owner already changed. The
  whole read sits behind `enable_household_allergen_sharing`, OFF — with the flag off
  nobody can have shared, which is knowledge, not an outage, so it must never degrade.

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



- **RESOLVED 2026-08-13 (BUT-1838) — the conversation roster's bootstrap branch is GONE, and
  so is the separate read fallback that spelled the same idea a second time.** The entry it
  replaces recorded two accepted holes in
  `parentNames(uid) || (parentDoc() == null && you hold a row)`: (a) **pre-seat** — a stranger
  who knew a never-chatted group's id could seat a row and LIST the roster (test P3B, which
  now DENIES; **that flip is the intended signal, do not "fix" it back**), including the
  internal form where a minor added by a non-friend could list it during the window before the
  first message, because the safety trigger fired on a conversation document that did not exist
  yet; and (b) **orphan** — rules cannot tell "parent deleted" from "parent not written yet", so
  deleting a conversation re-opened the branch over its rows forever.
  Both die for one reason: `createChatGroup` writes the group, the conversation and every
  roster row in ONE Admin-SDK transaction, so the parent exists before any row does and
  attestation alone suffices. The write rule is now `attestedWriter() && !('groupId' in
  parentDoc().data)` — narrower than plain attestation, because a GROUP roster row must come
  from the Admin SDK or a member could seat a peer and route round the minor gate. **Removing
  only `rosterUnclaimed()` would NOT have closed (a):** the read rule carried its own,
  textually separate `parentDoc() == null` fallback. Both went in the same edit; if you ever
  re-introduce one, re-introduce the other's residual too.
  Rows orphaned BEFORE this shipped are still on disk and are now simply unreadable; the
  backfill stays closed unbuilt (BUT-1839). Note the old warning that create and update must
  keep DIFFERENT null-metadata spellings is now stale and was corrected in the rules file the
  same day: the create rule's bare `metadata.creatorId == uid` denies a null cleanly, so it no
  longer leans on a CEL accident. C7B still pins the deny; do not re-introduce the `||` hatches
  to "restore" the old asymmetry. BUT-1795/BUT-1825/BUT-1830, 2026-08-13

- **RESOLVED 2026-08-13 (BUT-1822) — account deletion now erases
  `conversations/{id}/participants/{uid}`, in TWO legs, and one leg alone is not enough.**
  (1) The ≤2-participant branch clears the WHOLE roster with `tryClearRoster` BEFORE
  deleting the parent and **abandons the parent delete** if that fails, taking
  `buildGroupDepartureUpdate` instead — this is what saves the SURVIVING partner's row,
  whose `participantId` is not the erased uid. That branch reports the step INCOMPLETE
  (`gdprCompliant: false`): a `direct_` id IS `direct_<erasedUid>_<survivorUid>`, so a
  conversation left standing keeps the erased uid in its own document id where no
  field-keyed probe can see it. Do not "tidy" that into a success. (2) A capped
  `collectionGroup("participants").where("participantId","==",uid)` sweep takes the rest;
  above `MAX_ROSTER_SWEEP_ROWS` it DECLINES rather than truncating, because a planted roster
  lets somebody else choose the size of a victim's erasure bill (BUT-1830).
  Declining is loud — the probe leg is an uncapped `count()`. Do not fold the two legs into
  one "simpler" query; do not remove the cap; do not let a future edit delete the parent on
  a false answer. A `direct_` conversation id is HASHED in every log on this path
  (`logSafeConversationId`) — it is two raw uids, and BUT-1822 is what first sends direct
  ids into `tryClearRoster`'s logs. The fix is FORWARD-ONLY and stays that way: the
  backfill (BUT-1839) was closed unbuilt by Malin on 2026-08-13 because the app is not live,
  so the leftover rows are all test data. Reopen it at launch, not before. The other
  forward-looking gap — a user's own "delete conversation" orphaning rows — is BUT-1825 and
  is NOT covered by that reasoning. The fix is FORWARD-ONLY: rows orphaned by earlier deletions, and rows
  orphaned by a user's own "delete conversation", are still there (BUT-1825 + a backfill
  ticket). 2026-08-13
  **AMENDED 2026-08-15 — the cap's STATED REASON was stale within two days of being written;
  the cap itself is unchanged and still must not be removed.** This entry, and four comments
  in the code, justified `MAX_ROSTER_SWEEP_ROWS` by the bootstrap write branch — which
  BUT-1838 deleted on 2026-08-13, one day later. That does NOT weaken the cap. Three sources
  of extra rows survive: (1) rows seeded BEFORE BUT-1838, still on disk because the backfill
  is closed unbuilt (BUT-1839); (2) a tampered or non-standard Admin-SDK writer, which rules
  never see; (3) an ATTESTED client write, bounded but LIVE — `attestedWriter()`
  (`firestore.rules`:1706-1708) requires the parent to name the writer AND the subject, and
  `direct_A_B` names both, so A may write B's row with a `displayName` A chooses; A may also
  create that conversation, since two adults need no friendship (`passesMinorDmGate` fires
  only when the other party is a minor) and NOTHING caps the rate — the create rule's
  `rateLimitWrite('conversations', 10)` reads `users/{uid}/rate_limits/conversations`, a
  bucket no writer in `lib/` ever stamps, so `!exists(limitsPath)` is permanently true, and
  the bucket is self-written anyway. **The DECLINE-rather-than-truncate behaviour and the uncapped
  `count()` probe beside it are FROZEN** — they are the Art. 17 completeness signal and do
  not depend on which source is live; do not relax either arguing the bootstrap hole is
  closed. Note also that orphaning is still a one-way door after BUT-1838: every predicate
  that could SURFACE a row reads through the parent, so deleting it makes
  the surviving rows unreadable forever — which is why the ordering in leg (1) is unchanged
  even though the disclosure it originally prevented is gone. NOT un-writable: the `(u1)`
  self-cursor update and `allow delete` are parent-free self checks, so the row's own
  subject could still stamp or delete it (no client flow does). Measured against the live
  rules, orphaned row acting as its own subject: READ denied, UPDATE allowed, DELETE
  allowed. Do not lean an Art. 17 argument on "un-deletable". Raised by the
  whole-range integration gate; the phrase "not a live client write path" is deliberately
  absent from every site, because that is the sentence a future reader would cite to remove
  the cap. BUT-1838, 2026-08-15

- **`tryClearRoster` refuses an implausibly large roster and leaves the conversation
  standing — including as a ZERO-member document that nobody can ever read, update or
  delete** — every rule in the conversations block gates on `uid in participantIds`, so an
  empty list locks the document permanently. Accepted as the safest of three bad outcomes:
  a live parent that names nobody makes the seeded roster unreadable, whereas deleting the
  conversation would re-open the bootstrap branch over those rows, and throwing would loop
  a `retry:true` trigger forever on a deterministic error. Only reachable when a roster has
  been seeded past `MAX_ROSTER_ROWS`. What it leaves needs a sweep that clears the ROSTER
  FIRST: deleting the shell flips `parentDoc()` to null and re-opens the branch over every
  surviving row, including the legitimate members and the evicted minor. The shell is safe
  only while it stands. BUT-1795/BUT-1825, 2026-08-12
  **AMENDED 2026-08-15 (BUT-1838):** "re-open the bootstrap branch", twice above, is stale —
  that branch was deleted on 2026-08-13. The verdict is unchanged, because the consequence it
  guarded against is only milder, not gone: every predicate that could SURFACE a row reads
  through the parent, so deleting the shell leaves every surviving row UNREADABLE forever.
  (Not un-writable — see the AMENDED note above: the self-cursor update and the delete are
  parent-free self checks, measured.) Orphaning is still a one-way door, so the shell is the safer of
  the two, and a sweep must still clear the ROSTER first. See the AMENDED note on the BUT-1822
  entry above for the three sources of rows that keep the caps load-bearing.

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

- **A message whose `metadata` is a MAP WITHOUT a `poll` key accepts a vote — every share card in
  every chat is votable, and that ships knowingly.** `pollIsOpen()` reads
  `.get('metadata', {}).get('poll', {}).get('isClosed', false)`, so a map with no `poll` defaults
  all the way to "open". Four live writers hit it: `Message.recipeShare`, `Message.menuShare`,
  `Message.shoppingListShare` and the group system-message CF. **Malin's explicit call,
  2026-08-17.** She was shown the harm bound before deciding: the row carries only the caller's
  own uid, `isValidVote()` limits it to three keys and ≤20 option ids, reading the tally is
  membership-gated, and `deletePollVotes` erases it by collection group. No UI renders it. The
  defect pre-dates BUT-1832 in kind — the rule is new, but nothing about the salvage created the
  shape — and a rules change inside a salvage is how the previous sprint broke itself.
  **The repair must test `poll` for PRESENCE, not `metadata` for TYPE.** An `is map` guard does
  not close this: a map without the key is still a map, so a repair written from the null case
  alone lands looking finished and leaves the live case open. `poll-votes-rules.test.ts` pins all
  four states (absent / null / map-without-poll / real poll) with one green test each, and the
  owed repair was mutation-probed: it reddens exactly V10e and V10f and nothing else.
  Art. 15/17 note for whoever lands it: the export probes only `metadata['poll'] is Map` while the
  cascade erases by collection group regardless, so such a row is erasable but not exportable —
  cover both sides. BUT-1832, 2026-08-17

- **`inPollConversation()` reproduces only the MEMBERSHIP half of the message read rule, not
  BUT-1838's `memberSince` cut-off.** Measured 2026-08-17 against a group whose `memberSince`
  postdates the poll: the late joiner is DENIED the poll message, and ALLOWED both to read the
  tally and to CAST a vote in it. The write half is the part a read-focused reading misses.
  Deliberately out of scope for the BUT-1801 salvage — it is a rules change, and the fix is the
  same cut-off on the read AND the create/update limbs, not just the read. **Second Art. 15 route, orthogonal to the BUT-1832 entry's:** because a late joiner may CAST a vote in a pre-join poll, and the conversations export applies the `memberSince` filter that drops that message before the vote probe runs, such a row is erasable (the collection-group sweep ignores parent shape) but never exportable. The BUT-1832 entry names the export gap for the map-without-`poll` case only; this is a different way in to the same shortfall, and the repair must cover both. Raised by the
  `firestore-rules-tester` gate. BUT-1832, 2026-08-17
