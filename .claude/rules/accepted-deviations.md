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

- **The Art. 15 `delivered_notifications` section exports another user's NAME, inside
  the text of a friend-share win-back push (BUT-1957, 2026-09-02).** `users/{uid}/notifications`
  is passed through unprojected. Measured by the `firebase-backend-security` gate after the
  code shipped claiming the opposite: `resolveContextualWinbackCopy`'s highest-priority signal
  builds `"<namn> delade ett recept med dig"` from `shared_recipes.sharedByDisplayName`
  (`functions/src/analytics/winback-context.ts`), and that string is stored verbatim in
  `message` and `bodyShown`. Only `contextKey == 'ctx_friend_share'` rows are affected; the
  activity-digest rows carry counts of the requester's own ACTIVITY and nothing else — a
  comment they authored may sit on someone else's recipe, but only the integer travels.
  KEPT, because the requester received and read that exact text on their own device, so the
  bundle discloses nothing new and a redaction would hand them a falsified copy of their own
  record. Decided on THESE facts — not by analogy to BUT-1772 (conversations) or BUT-1732
  (shopping lists), which govern different collections; the BUT-1732 entry itself records that
  arguing across collections by shape is the error it exists to document.
  The section carries a `data_minimisation` sentence saying so.
  **Chosen conservatively without asking Malin, the way the `chat_groups` projection was —
  STRIPPING the name is hers to decide, and it is open.**
  **Decision 2026-09-10 — Malin explicitly decided to RETAIN the name.** She was shown that
  the current implementation already retains it as a pass-through and that stripping the name
  was the remaining open choice. No code change is required. This supersedes the open question
  above.
  It is the NAME, not reliably a first name: `firstName()` splits on the first whitespace and
  falls back to the whole trimmed name when there is none, so a single-token display name is
  exported in full.
  **Named residual, not closed:** the sharer's name is baked into free text on the RECIPIENT's
  row, so it outlives the sharer's own erasure — `on-user-deleted.ts` tombstones
  `shared_recipes.sharedByDisplayName`, but no id-keyed cascade reaches a copy sitting inside a
  sentence. Pre-existing; this change is what makes it exportable, and erasable through the
  RECIPIENT's deletion.
  Three sentences in the first version of this change asserted that no third party appears in
  these rows. All three were struck rather than reworded. BUT-1957, 2026-09-02

- **`users/{uid}/notifications` needs its own `firestore.rules` read block, and the export
  section is dead without it (BUT-1957, 2026-09-02).** Rules do NOT cascade: `allow read` on
  `match /users/{userId}` grants nothing on a subcollection beneath it. The collection had no
  block because every writer is the Admin SDK and no client had ever read it, so nothing was
  denied and nothing looked missing. The Art. 15 section is the first client read, and without
  the block it returns its failure envelope for every user on every export while the retention
  doc claims the rows are exported — a gap that reads as closed. Writes stay `if false`: the
  rows record what the SERVER sent, so a client able to write one could fabricate a
  notification it never received, and that record is now reachable through the export.
  Found by two gates independently; three green manager tests could not see it, because
  `fake_cloud_firestore` enforces no rules. BUT-1957, 2026-09-02

## Engineering

- **PARTLY SUPERSEDED 2026-08-30 (ADR-0010) — see the BUT-1971 entry at the end of this
  file BEFORE acting on this one. The GROUP repository audits grants again; only the
  per-user half of what follows still stands.**
- **The two weekly-menu-plan repositories' `save` audits only REFUSALS, not grants** —
  `logPermissionCheck` moved inside the `if (!canWrite)` branch. Each granted save had
  written a plan document plus an audit document, two writes where one would do.
  **Malin's explicit call, 2026-08-28 (BUT-1981).** The ticket's own framing was wrong and
  is retracted: this row is NOT a GDPR Art. 30 record. Art. 30 is a register of processing
  CATEGORIES and purposes — it mandates no per-operation access logging, no granted-vs-denied
  decisions, no transaction-level records (checked 2026-08-29). The requirement came from
  `lib/repositories/CLAUDE.md`, a house traceability rule, which now says so.
  **The two halves are NOT the same trade.** On the per-user repo the granted row was
  a row that recorded no decision: its gate
  (`entity.userId == userId` called with `plan.userId`) is a tautology that can only fail on a
  mis-keyed doc id — so it never recorded a decision that could have gone the other way. On the
  GROUP repo the gate takes the actor as a separate argument and its refusals are real, and
  dropping the granted row loses EDIT HISTORY on a document more than one person can write
  (`lastModifiedBy` keeps only the last writer). That reduction is accepted because the only
  live caller is the meal-poll close.
  `requireCurrentUserId()` is resolved ABOVE the gate in both, and that is load-bearing twice:
  it is the only client-side authentication assertion on `save`, and from inside the
  refusal branch it would throw on the way to the audit call and lose the very row this keeps.
  Both repositories' granted, refused and signed-out paths are pinned and mutation-probed — before
  this, the whole change was invisible to the repository suites. BUT-1981, 2026-08-28

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
  ADR-0010: the trail's premise did not hold, and the granted row is restored on the GROUP
  repository. The paragraph below is kept as the record of what was decided that day.** She was shown the
  security review's recommendation (restore the granted row on the GROUP repository only,
  ~1 extra write per interactive remove/undo) and chose the alternative it named beside it:
  an append-only trail on the plan document itself, which buys the same attribution with no
  second write. So the refusal-only audit STANDS as BUT-1981 decided it, and the traceability
  gap is closed by a design change rather than a revert. Not built here; it shares its model
  change, its `firestore.rules` change and its GDPR review with the per-entry provenance
  BUT-1971 needs for "framröstad av", and Malin asked for those to be planned as ONE build.

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

- **SUPERSEDED 2026-08-30 (ADR-0010): the granted audit row IS restored on the GROUP
  repository, and the edit trail ships BESIDE it.** The BUT-1981/BUT-1971 entry
  chose the trail instead, on the premise that it buys the same attribution for free. A full panel refuted that: the
  trail is client-written, so a member can put another member's uid in a row (the audit row
  stamps the authenticated actor and `audit_logs` refuses a mismatched uid), and `save`
  writes the whole document, so a legitimate row is lost when two people edit the same week.
  Malin chose both — the trail shows, the audit row proves — at ~1 extra write per
  interactive remove/undo. **GROUP repository only**; the per-user reduction is untouched
  and must not be "harmonised". BUT-1971, 2026-08-30
- **A group menu's `proposedBy`/`votedInBy` are FORGEABLE by any editor** — `entries` is not
  validated element-wise and will not be. No permission hangs on them. Malin, 2026-08-29.
- **A trail row can name the wrong person — a SEPARATE accepted risk from the forgeable-provenance entry**,
  because an accusation about an action is not a wrong name on a suggestion. Do not cite one
  as authority for the other. BUT-1971, 2026-08-30
- **The edit trail is NOT durable** — the later of two concurrent `set()` writes discards the
  earlier writer's row. Never evidence in a dispute; the audit row is the reliable record. An
  append-only rules conjunct was rejected because it would refuse the losing writer's whole
  write, breaking ordinary removals. BUT-1971, 2026-08-30
- **Art. 15 (group weekly menu): other members' per-dish provenance is KEPT; the edit trail
  is FILTERED to rows where the requester is ACTOR or SUBJECT.** Malin's explicit calls,
  2026-08-29, each on its own merits — NOT derived from BUT-1732/1772/1774. The asymmetry is
  the decision; do not harmonise it. The subject half is why a trail row carries `subjectId`.
  **AMENDED 2026-08-30, same build:** the keep half was described as needing no code
  because the document shipped whole. The section is a projection now, so the keep
  depends on `_redactGroupPlan` leaving `entries` alone. BUT-1971, 2026-08-30
- **OPEN and named: leaving a group without deleting the account leaves your uid on the
  dishes and in the trail forever.** No cascade covers it; account deletion is built, leaving
  is not. Malin has taken no position. Also unclosed: "already visible on screen" has not
  been tested against a week predating someone's membership. BUT-1971, 2026-08-30

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

- **`parse_corrections_v2` is DELETED by the reset script while `metrics` is LEFT ALONE — on
  CONTENT, not identifiability.** (`metrics` is in `COLLECTIONS_DELIBERATELY_UNTOUCHED`, the
  register, not in `COLLECTIONS_TO_KEEP`, the list with runtime teeth — so a reader grepping
  the keep list for it finds nothing.) Malin's explicit call, 2026-09-07, with both on the table:
  the row carries the user's own words (`toValue` is what she typed, `fromValue` the parser
  output she corrected), scrubbed but still text; `metrics` is aggregates with no uid and no
  text a person wrote. She
  was shown that this restarts the parse-quality corpus from zero; she was NOT shown how
  large that corpus is, because nobody has counted it. The pre-hashed ids decide nothing
  either way — do not re-argue the call from them. BUT-2028, 2026-09-07

- **The reset script's Phase 4 counts and judges; it does NOT sweep a second time.** Malin's
  explicit call, 2026-09-07, against the gate's own recommendation on the ticket. She was
  shown that the kill switch removes the cause rather than the symptom, and that a second
  sweep can prove residue EXISTS but never that the trigger is finished (`onUserDeleted` is
  gen1, no bounded delivery, no `retry`). She was NOT shown a measurement of real residue.
  Do not restore the sweep without one — and note that whether any live run has happened is
  not answerable from this repo at all. BUT-2028, 2026-09-07

- **`ingredient_suggestions` gets BOTH GDPR legs before any client has written a row.** Malin's
  explicit call, 2026-09-07, shown the alternative of closing the door
  (`allow create: if false`). No code in `lib/` creates a suggestion; the `allow create` limb
  in `firestore.rules` is what keeps the collection reachable. `deleteIngredientSuggestions`
  (plus its `probeResidualData` leg) and the Art. 15 export section ship together, so the FIRST
  client write is erasable and exportable the day it happens. Do not
  delete either leg as dead code — the pair is what makes the open door safe.
  BUT-2028, 2026-09-07

- **The Art. 15 `ingredient_suggestions` section is PROJECTED: `reviewedBy` and `reviewNotes`
  are stripped.** A moderator's raw uid, and internal moderation text, neither of which any
  widget renders. (`userId` is not in the allowlist either — it is the requester's own uid and
  the query's own filter, not a withholding decision.) The
  section fails CLOSED — an allowlist, so a field nobody has declared is withheld — and says so
  in a `data_minimisation` line, because the create rule uses `hasRequiredFields` rather than
  `hasOnly`, so a client can store fields outside the type and have its OWN content dropped.
  **Chosen conservatively WITHOUT asking Malin, the way the `chat_groups` projection was;
  KEEPING the two fields is hers to decide, and it is open.** Named residual: if a moderator is
  themselves a user, their uid in `reviewedBy` is reached by no cascade, no probe and no export —
  the projection makes it invisible, not erasable. Second residual: `deleteIngredientSuggestions`
  reads unbounded, on a collection whose create limb has no `rateLimitWrite`, so a user who plants
  many rows under their own uid degrades their own erasure — same shape as `deleteCookSnaps`, and
  bounded by BUT-2038 rather than here. Raised by the `firebase-backend-security`
  and `code-reviewer` gates. BUT-2028, 2026-09-07

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

- **A `system_events` row about a report the ERASED USER FILED is DELETED; the row about a
  report filed AGAINST them is KEPT with `details.contentOwnerId` nulled (BUT-2032,
  2026-09-08).** Both halves are derived from the two outcomes already decided on the SOURCE
  collection — `deleteUserReports` hard-deletes the `reports` row when the reporter erases,
  `anonymizeReportsByContentOwner` (BUT-781) keeps it and nulls the field when the reported
  person erases — rather than inventing a third policy for one event. **The delete half is
  Malin's explicit call, 2026-09-08 (ADR-0016)**, over Trust & Safety's alternative of nulling
  `details.reporterId` and keeping the row; she was shown that an admin then cannot tell
  "no report was filed" from "the reporter erased", and the runbook says so. The
  `moderation_threshold_<uid>` row is deleted because its document id IS the identifier. Both
  legs are found by QUERY, never by rebuilding the id.
  Three more parts of this ship together and each dies alone: the step runs in the CASCADE
  (the probe runs before `auth.deleteUser`, the trigger after — BUT-2044) and stages its own
  audit rows, the FIRST in that file, because BUT-781's analogy carries the action and not the
  record (ADR-0014); the collection is NOT in the Art. 15 export, and that decision cannot be
  recorded in `EXPORT_EXEMPT`, which is scoped to `USER_SUBCOLLECTIONS`; and `onReportCreated`
  has NO ordering relationship to deletion, so a retried or late delivery can write a fresh row
  naming an erased uid — accepted as a named residual over building a reconciliation pass.
  **`user_moderation` is deliberately OUT of scope** (ADR-0015): its `reportHistory` is the only
  data surviving the REPORTER's erasure that can answer whether one account repeatedly reports
  the same target, so stripping it is a Trust & Safety decision, not a tidying-up.
  **SUPERSEDED 2026-09-08 by BUT-2046, below.** That sentence — "its `reportHistory` is the only
  data surviving the REPORTER's erasure that can answer whether one account repeatedly reports
  the same target" — is no longer true of the code: the field is gone, the rows live in a
  `report_history` subcollection, and `deleteReportHistoryByReporter` erases them. The T&S
  decision it protected was taken and is recorded below; the scope call it records was correct
  when made.
  BUT-2032, 2026-09-08

- **`user_moderation.reportHistory` is now a `report_history` SUBCOLLECTION with a 180-day
  TTL, and the brigading signal is deliberately NOT built (BUT-2046, 2026-09-08).** An entry
  names a REPORTER, and a uid inside an array of maps is unqueryable — so it was reachable by
  no erasure path and no read. **Malin's explicit calls, 2026-09-08**, over building a
  queryable reporter-side counter first: measured the same day, nothing in this repo reads the
  collection, and the array could not answer the brigading question anyway. This ANSWERS
  ADR-0015's deferred question rather than reversing it.
  **The Art. 15 exemption rests on TWO grounds, and they must not be merged**: the reporters'
  identities are third-party data (Art. 15(4), strong); `totalReports` is the requester's OWN
  data, withheld on the weaker ground that disclosing an in-progress moderation count
  undermines the moderation. Malin decided the second half separately after the panel showed
  that the first ground did not cover it.
  Three residuals, named: a reported person can erase their way out of an open review, and no
  legal hold stops it; the migration (`admin/migrate-report-history.ts`) is what makes a
  reporter's uid erasable at all and must run LIVE, after the new writer is deployed, before
  the gap is closed; and `onReportCreated` has no ordering relationship to deletion, so a late
  or retried delivery writes a fresh row after the sweep — which the TTL, not the cascade,
  eventually removes.
  **The migration RAN LIVE on 2026-09-09, after the writer deploy, and moved nothing:**
  `{"mode":"live","scanned":0,"moved":0,"skippedExisting":0,"emptied":0,"failures":[]}`.
  Measured immediately before it, against butlery-app-1: `user_moderation` held 0 documents,
  0 of them carrying a legacy `reportHistory` array, and `reports` held 0 rows. So the second
  residual is closed by there being nothing to migrate rather than by the script having moved
  anything — the gap was real in the code and empty in the data, which is the order you want.
  That output is attributed, not reproducible from this repo: it was a hand run, committed
  nowhere. The other two residuals stand unchanged.
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

- **RESOLVED 2026-09-10 (BUT-2060) — Malin: LEAVE IT. The category sync does not cut
  group-menu access, and that is now a decision rather than an open question.** Retired
  verbatim, from the entry above:
  "Open for Malin, and the reason this half is not built: her call of 2026-09-09 was to build"
  — the question was put to her and answered the same day. No code changed: this is what
  already ships.
  What STAYS open as a consequence, stated because it is the price of the call: the original
  "THREE other membership-removal paths do NOT cut group-menu access" gap is permanent for
  `groups/ensure-category-chat.ts`. Somebody an owner removes from a friend category keeps
  READ and WRITE access to every weekly menu plan of that category's chat group that already
  exists, indefinitely, until the group loses them by some other path.
  She was shown: the three options; the concrete case (remove a friend from a category by
  mistake, re-add them, the chat returns and the menus never do, silently); that a departing
  set emptying an old week's roster would delete that week; and that the app is not live, so
  the gap reaches nobody today.
  **What she was NOT shown**, stated because an attribution is a claim about a person no test
  can hold: no measurement of how often a category removal is undone in practice — there are
  no users, so it is not measurable — and no enumeration of how many existing weeks a given
  category's group typically has. The choice was made on the shape of the trade, not on
  frequency data.
  The alternative she declined, and what it would have cost: cutting anyway (a reversible
  admin action becomes partly one-way, with no error shown), and building a restore path (the
  correct fix, but no such code exists at all today and it reaches `firestore.rules` and the
  Art. 15 surfaces, so it needs its own plan). Reversing this is hers; if it is ever
  re-proposed, the restore path is the half that has to exist first.
  The pin is `an eviction leaves group-menu access alone — the sync is reversible` in
  `ensure-category-chat.test.ts`: it reddens the day somebody wires the cut in, so the decision
  is enforced by a test rather than by this paragraph. BUT-2060, 2026-09-10

- **SUPERSEDES two sentences of the `ingredient_suggestions` Art. 15 entry above
  (BUT-2038, 2026-09-10).** Retired verbatim — note that the two mirrors word this
  decision DIFFERENTLY, a pre-existing drift, so each copy retires its own sentence and a
  grep for one will not find the other: "The section fails CLOSED — an allowlist, so a field nobody has declared is withheld — and says so in a `data_minimisation` line, because the create rule uses `hasRequiredFields` rather than `hasOnly`, so a client can store fields outside the type and have its OWN content dropped." The create limb now carries `keys().hasOnly(...)` over the SUBMISSION half
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

- **The reset run PAUSES every enabled Cloud Scheduler job for its duration, and a run that
  cannot pause them REFUSES before Phase 1 (BUT-2036, 2026-09-10).** This closes the question
  the BUT-2028 entry left open in `docs/architecture/ACCEPTED_DEVIATIONS.md`; retired verbatim
  from there: `**OPEN:** whether Cloud Scheduler must be paused for a live run. The weekly jobs delete and write in the same collections,`
  The jobs are ENUMERATED at run time across every region — a hand-written list is the failure
  BUT-2040 and BUT-2043 record — and only what the run itself paused is resumed, so a job a
  person paused by hand stays paused. Release happens in the same `finally` as the kill switch
  and in the signal handler, which is registered BEFORE the first pause — the kill-switch
  write sits between the pause and the `try`, outside `finally`, and is itself guarded so a
  failure there resumes and refuses. Phase 4 re-reads Cloud Scheduler rather than the resume step's
  own report, and a job left paused makes the verdict NOT CLEAN.
  **Malin's explicit call, 2026-09-10**, taken over writing the risk down as accepted, and
  again on the refusal rather than warn-and-continue — she was told it blocks a live run until
  the operator holds `roles/cloudscheduler.admin`. No escape flag: that shape was removed from
  this script on 2026-09-06.
  Named residuals: an execution already in flight when the pause lands runs to completion,
  and a job enabled between the enumeration and the pause (the confirmation prompt sits
  between them) is in no list.
  BUT-2036, 2026-09-10

- **The Art. 15 comments and ratings sections are PROJECTED through a fail-closed allowlist,
  and four fields on a comment are withheld (BUT-2062, 2026-09-10).** `exportCommentsByAuthor`
  and `exportRatingsByUser` returned the raw `doc.data()`, so a comment author's own bundle
  carried `recipeOwnerId`, `sharedWithUserIds` and the `reactions` uid map. Withheld now, on
  THESE two collections' facts and no other's — no part of this is derived from BUT-1732,
  BUT-1772 or BUT-1450, which each record that arguing across collections is the error they
  exist to document.
  **This is MINIMISATION, not an access control, and a later reader must not cite it as
  having closed a leak.** The author's own client may read their whole comment document, and
  `firestore.rules`' `recipe_ratings` read limb is `allow read: if isAuthenticated()` — any
  signed-in account already reads every rating whole. What the projection changes is what
  goes into a durable, forwardable file.
  KEPT and decided rather than defaulted: `authorAvatarUrl` and `imageUrls`, both the
  requester's own. The image links are `getDownloadURL()` values carrying a `?token=` BEARER
  credential — anyone holding the string fetches the file unauthenticated — so a forwarded
  bundle forwards that access. Kept anyway; it is their own content.
  STRIPPED: `authorId`/`userId` (the requester's own uid AND the query's own filter — not a
  withholding); `recipeOwnerId`; `sharedWithUserIds`; `reactions`.
  **`sharedWithUserIds` is DECIDED, not open.** It was going to Malin as a question and three
  seats measured that it should not: no widget renders it, no re-share or unshare updates it
  (so it is a frozen snapshot), and routing a denormalised
  uid list to her by default is the over-flagging the disposition rule exists to prevent.
  `recipeOwnerId` on RATINGS is a decided strip although `FirebaseRatingsRepository` never
  writes it — `RecipeRating.toFirestore` emits it when set and the rules permit it on create,
  so BUT-2057 cannot widen this bundle by accident.
  The `rating_id` is `{recipeId}_{userId}`, so the requester's own uid still travels. The
  FIELD is dropped; never write that the uid is gone.
  **Layer: the projection lives in the MANAGER, not the two repositories.** The Security
  Architect seat argued for the repositories; the Software Architect seat objected, and the
  objection carries on two measurements — the interface doc comments already state that raw
  is returned so the export pipeline can shape it, and `firebase_comments_repository.dart` is
  479 lines with no `ACCEPTED_LARGE_FILES` row (a projection there trips the 500-line guard)
  while `firebase_ratings_repository.dart` is already 536 against a row saying 507. The
  future-second-caller risk that motivated the repository is answered by the obligation now
  written into both interfaces and by the writer-derived drift test.
  Named residuals: a reactor's uid inside `Map<emoji, List<uid>>` is unqueryable, so no
  cascade can erase it and it is now not exportable either — un-erasable AND un-exportable,
  the BUT-1832 shape running the other way. And neither create limb carries
  `keys().hasOnly`, so a hand-rolled client can store a field of its own and have its OWN
  content dropped; the `data_minimisation` sentence says so, and tightening the limbs is its
  own ticket. BUT-2062, 2026-09-10
