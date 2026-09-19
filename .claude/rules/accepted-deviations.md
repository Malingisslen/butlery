# Accepted Deviations — the verdicts

Decided calls. Do not propose them again, and do not file review findings against them.
**Full rationale per entry: `docs/architecture/ACCEPTED_DEVIATIONS.md`** — the commit
review gate names that file in every block message, so a reviewer is pointed at it at the
moment it matters. Read it before arguing with any line below.

This list stays always-on because the costly mistake is a *plan* re-proposing a decided
no, which happens long before any review gate fires. A new deviation is appended in both
files in the same edit. Each entry below is its current verdict, cut to one line (or a few for the heaviest) on
2026-09-19; the long form each entry had then is in `tasks/archive/accepted-deviations-long-form.md`.

## Safety and privacy (decided, not open)

- Draft ingredients keep full verdict authority, including FREE — no downgrade to UNKNOWN for unverified rows; the draft banner + fix-list are the accepted mitigation (2026-07-01)
- Weekly-menu presence never scopes menu generation — presence drives display, portions and the who's-eating record only … Safe version deferred to BUT-1625. (BUT-1625, 2026-07-17)
- GDPR export includes the raw notification counterparty id, unredacted — Art. 15(4) is a balancing test; Malin overrode the panel's redaction recommendation. (BUT-1450, 2026-06-30)
- The shared-shopping-list GDPR section keeps other members' UIDs, their permission levels and the full `contributorUserIds` array … and drops their display names (BUT-1732, 2026-07-30)
- The conversations GDPR export KEEPS other participants' display names and UIDs and STRIPS their avatar URLs (own avatar kept) … all through ONE shared helper, and that is the point (BUT-1772, BUT-1767, BUT-1775, 2026-07-30)
- The `shared_content` export sections keep other recipients' UIDs and the sharer's `sharedByDisplayName` … Membership is ONE field, `sharedToUserIds` (BUT-1798, 2026-08-03)
- Inside a shared shopping list's nested `listData` copy, other members' DISPLAY NAMES are stripped; their UIDs and permission levels are KEPT … The asymmetry between the two entries is the decision, not an oversight. (BUT-1798, 2026-08-01)
- Other participants' `perUserSettings` are STRIPPED from the conversations export; `lastReadTimestamps` are KEPT … Do not propose stripping `lastReadTimestamps` "for consistency" — the asymmetry is the verdict. (BUT-1774, 2026-07-30)
- A colon-terminated bare GLUTEN word rescued into the flat ingredient list must ALSO be exempted … Do not "simplify" the three exemptions back into one flag; each one drops the gluten row on its own. (BUT-1727, 2026-07-30)
- A household member whose profile cannot be READ widens the allergen union with a common-allergen floor (and shuts the UNKNOWN hatch) instead of being SKIPPED — and that floor is ALLERGENS ONLY, never `defaults.trackedDietary`. (BUT-1663, BUT-1693, 2026-09-16)
  - A profile that does not EXIST (`missing`) is the opposite call and does not degrade the roster.
  - the floor is CONDITIONAL on opt-in — another account holder whose private settings this device may not read gets their SHARED list instead
  - Three parts survive deliberately: a member who has not shared is unchanged; the signed-in user is never read from a share; and a READ FAILURE still degrades the roster even when they shared
  - with the flag off `_sharedListsByMember` returns an EMPTY map without reading anything, so the app treats it as a known-empty result rather than an outage, and the roster is not degraded.
- `socialFeatures` consent gates nothing, by design — social runs on the GDPR contract basis, not consent; wiring it would be consent theatre and would fail closed for every existing user. (BUT-1523, 2026-07-12)
- Account deletion does not cascade to `parse_events` — the 30-day TTL residual is accepted under Art. 17's reasonable-erasure window. (BUT-1570, 2026-07-16)
- `cook_snaps` and `activity_events` creates ARE age-gated, and stay that way. … Never remove either gate citing the old entry. (ADR-0002, BUT-1418, 2026-07-24)
- Feature-retention DAILY AGGREGATES keep a deleted user's contribution, and the per-user rows get a cascade step rather than a TTL … A TTL is NOT an option on those rows (BUT-1789, 2026-08-01)
- A colon-terminated bare GLUTEN word stays an INGREDIENT; every other allergen keeps colon-wins … The asymmetry is the decision, not a gap. (BUT-1714, 2026-07-27)
- Revoking a group does NOT cut a member who also holds a direct share — and an explicit "remove this person" DOES cut them … Do not add a "missing `grants` means everyone is direct" compatibility path (BUT-1797, 2026-08-04)
- The Art. 15 `delivered_notifications` section exports another user's NAME, inside the text of a friend-share win-back push … Malin explicitly decided to RETAIN the name. (BUT-1957, 2026-09-10)
- `users/{uid}/notifications` needs its own `firestore.rules` read block, and the export section is dead without it … Writes stay `if false` (BUT-1957, 2026-09-02)

## Engineering

- The GROUP repository audits grants again; only the per-user half of what follows still stands. (ADR-0010, BUT-1971, 2026-08-30)
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
- SUPERSEDED 2026-08-30 by ADR-0010: the trail's premise did not hold, and the granted row is restored on the GROUP repository. (BUT-1971, 2026-08-30)
- An OFFLINE read of a weekly menu plan trusts a cached "this week is empty", and a write may then build on it … Do NOT pass this flag on anything an allergen or a permission decision reads (BUT-1961, 2026-08-27)
- `readWeek` also calls `fetchForWeek` and mints `readFailed: false` for any null … Do not write any further "the server refuses it" sentence without citing them. (BUT-1961, 2026-08-27)
- The recipe GRID card draws no dietary row, and that is a measurement, not a deferral … Do not propose adding it back "for consistency with the list view" (BUT-1906, 2026-08-23)
- The conversation roster's bootstrap branch is GONE, and so is the read fallback that spelled the same idea twice … Do not re-introduce either hatch (BUT-1838, 2026-08-13)
- Account deletion erases `conversations/{id}/participants/{uid}` in TWO legs, and one leg alone is not enough (BUT-1822, BUT-1838, 2026-08-15)
  - Do not fold the two legs into one query, remove the cap, relax the decline-or-probe pair, reorder leg 1, turn its INCOMPLETE report into a success, or let a future edit delete the parent on a false answer from either leg.
  - The decline behaviour and the probe are FROZEN — they are the Art. 17 completeness signal.
  - A `direct_` conversation id is two raw uids and is HASHED in every log on this path.
  - the cap is unchanged and still must not be removed. Do not argue for relaxing it from "the bootstrap hole is closed"
  - so do not lean an Art. 17 argument on "un-deletable".
- `tryClearRoster` refuses an implausibly large roster and leaves the conversation STANDING … A sweep that cleans this up must clear the ROSTER FIRST (BUT-1838, 2026-08-15)
- A chat message's `sentAt` may sit at most ONE HOUR ahead of the server, and that number ships together with the client-side error message that explains a refusal. … Do not propose tightening it to minutes (BUT-1903, 2026-08-19)
- A minor may be added to a group by any of their FRIENDS, and the strangers already in that group can then message them … Do not widen it silently, and do not narrow it to "the creator" (BUT-1838, 2026-08-13)
- Other members' `memberSince` is STRIPPED from the conversations GDPR export; the requester's own is kept … The export also gains a `chat_groups` PROJECTION (name, creator, admins, and who added YOU) (BUT-1838, 2026-08-13)
- Renaming a group chat is gated by WRITE ORDER, not by a rule on the visible name … Do not "simplify" the two writes into one, and do not reorder them. (BUT-1838, 2026-08-14)
- A message whose `metadata` is a MAP WITHOUT a `poll` key accepts a vote — every share card in every chat is votable, and that ships knowingly. … The repair must test `poll` for PRESENCE, not `metadata` for TYPE. (BUT-1832, 2026-08-17)
- The chat duplicate guard MARKS a duplicate; the comment guard DELETES one. The asymmetry is the decision, not drift (BUT-1904, ADR-0009, BUT-1954, BUT-2103, 2026-09-17)
  - Do not "simplify" the two surfaces back into one action, and do not describe the client-side row filter as a privacy control: the protection is that the SERVER removed the text.
  - The Art. 15 export deliberately DIVERGES here and keeps such a row (`isOthersBlockedRow` requires `content == ''`) … Do not harmonise the two.
  - Load-bearing parts, each of which dies alone: the guard uses `tx.update` and never a merge-set
  - `firestore.rules` refuses a client update to an already-blocked message
  - `syncConversationLastMessage` tests `after.type` for blocked-ness DIRECTLY, never behind the candidate gate
  - Creates gate on candidacy; updates do not. Do not bound the read by gating on the flag either
- `inPollConversation()` reproduces only the MEMBERSHIP half of the message read rule, not BUT-1838's `memberSince` cut-off. … the fix is the same cut-off on the read AND the create/update limbs. (BUT-1832, 2026-08-17)
- the granted audit row IS restored on the GROUP repository, and the edit trail ships BESIDE it. … the per-user reduction is untouched and must not be "harmonised". (BUT-1971, 2026-08-30)
- A group menu's `proposedBy`/`votedInBy` are FORGEABLE by any editor — `entries` is not validated element-wise and will not be. No permission hangs on them. (2026-08-29)
- A trail row can name the wrong person — a SEPARATE accepted risk from the forgeable-provenance entry … Do not cite one as authority for the other. (BUT-1971, 2026-08-30)
- The edit trail is NOT durable — the later of two concurrent `set()` writes discards the earlier writer's row. … An append-only rules conjunct was rejected because it would refuse the losing writer's whole write (BUT-1971, 2026-08-30)
- Art. 15 (group weekly menu): other members' per-dish provenance is KEPT; the edit trail is FILTERED to rows where the requester is ACTOR or SUBJECT. … The asymmetry is the decision; do not harmonise it. (BUT-1971, 2026-08-30)
- leaving a group without deleting the account leaves your uid on the dishes and in the trail forever. (BUT-1971, 2026-08-30)
- SUPERSEDES the reasoning, not the decision, of the Art. 15 provenance entry … The KEEP decision is unchanged and still Malin's (BUT-1971, 2026-08-30)
- RESOLVED 2026-08-30 — Malin: make the app show them. … The provenance row is now a tap target opening a sheet that lists the voters by name (`groupMenuVotersTitle`) (BUT-1971, 2026-08-30)
- The edit trail does not explain a dish that was DISPLACED. … nothing records what went. (BUT-1971, 2026-08-30)
- A client that read the plan BEFORE an erasure can write the uid back. … the close is the whole-write ticket, not a wrapper. (BUT-1971, 2026-08-30)
- `GroupWeeklyMenuPlanService.removeParticipant` drops a uid from the two rosters and leaves it on `entries[].proposedBy` … Wire an admin control through THAT shape, not through this dormant method. (BUT-1971, 2026-08-31)
- RESOLVED 2026-08-30 — Malin: a member who LEAVES a group KEEPS their name on the dishes and in the trail; only deleting the account erases it. … the DECISION stands, its MECHANISM does not. (BUT-1971, 2026-08-31)
- Leaving a group now CUTS the leaver's read and write access to that group's weeks, and `contributorUserIds` is what keeps their name erasable afterwards. … Do not "simplify" it away as a duplicate of the roster (BUT-1971, 2026-08-31)
- `contributorUserIds` is CLIENT-written, so a hand-rolled client can omit a uid and make it un-erasable. (BUT-1971, 2026-08-31)
- A remaining member whose screen cached the week BEFORE someone left can write the old roster back and restore that person's access. … Malin's explicit call, 2026-08-31: accepted, not stopped (BUT-1971, 2026-08-31)
- A week whose ONLY remaining participant leaves is DELETED. … Chosen without asking Malin; reversing it is hers. (BUT-1971, 2026-08-31)
- When the last ADMIN leaves a plan that still has participants, the lowest remaining uid is promoted, and the promotion writes an `adminPromoted` trail row. (BUT-1971, 2026-08-31)
- RESOLVED 2026-08-31 — the "already visible on screen" reasoning CANNOT be reached by a week that predates someone's membership, measured. (BUT-1971, 2026-08-31)
- A leaver's Art. 15 export contains a documented GAP, not their rows. … There is no probe. (BUT-1971, 2026-08-31)
- The Admin SDK bypasses the 200-row contributor cap, and a plan pushed past it can never be saved by a client again. (BUT-1971, 2026-08-31)
- `contributorUserIds` is STRIPPED from the Art. 15 bundle. … Do NOT read the identically named field's keep on `unified_shared_shopping_lists` (BUT-1732) as authority (BUT-1971, 2026-08-31)
- The contributor union is BOUNDED at 200 and skipped above it, losing erasability on that document rather than freezing the week. … the bound is a skip rather than a truncation (BUT-1971, 2026-08-31)
- The append-only conjunct on `contributorUserIds` REFUSES a stale writer's whole save — the exact cost Malin was told was unacceptable for the edit trail. (BUT-1971, 2026-08-31)
- `contributorUserIds` is a DISCOVERY handle, never a witness on a destructive gate … A contributor is not a READER. (BUT-1971, 2026-08-31)
- The `poll_votes` block gate FAILS OPEN on a missing mirror, and absence has FOUR meanings the rule cannot tell apart … `rebuildMirrorFor` now asks Auth, not Firestore. (BUT-1917, 2026-09-05)
- A TRUNCATED mirror silently under-blocks, and the `truncated` flag has no reader … denying while truncated would refuse every vote from anyone blocked by that many people. (BUT-1917, 2026-09-05)
- READ of a poll tally is deliberately NOT block-gated, and neither is DELETE … Hiding the tally from a blocked person would tell them a block exists (BUT-1917, 2026-09-05)
- The gate is ONE-DIRECTIONAL in the rules and TWO-DIRECTIONAL in the client tally, and message DISPLAY stays one-directional … The asymmetry is the decision; do not harmonise it. (BUT-1917, 2026-09-05)
- The rule is NOT retroactive, and the client strip is a DISPLAY control, not a server one … `closePoll` reads `blocks` from the SERVER, so a vote slipping through the lag window still cannot decide the week (BUT-1917, 2026-09-05)
- The correction's own point stands: the enumeration capability predates BUT-1917 and that ticket widened no permission. (BUT-1917, 2026-09-09)
- Making the tally two-directional WIDENS an existing provenance gap on the group menu … the winner must stay filtered while the provenance probably must not, which is a decision rather than an edit. (BUT-1917, 2026-09-05)
- `parse_corrections_v2` is DELETED by the reset script while `metrics` is LEFT ALONE … The pre-hashed ids decide nothing either way — do not re-argue the call from them. (BUT-2028, 2026-09-07)
- The reset script's Phase 4 counts and judges; it does NOT sweep a second time. … She was NOT shown a measurement of real residue. Do not restore the sweep without one (BUT-2028, 2026-09-07)
- `ingredient_suggestions` gets BOTH GDPR legs before any client has written a row. … Do not delete either leg as dead code (BUT-2028, 2026-09-07)
- The Art. 15 `ingredient_suggestions` section is PROJECTED: `reviewedBy` and `reviewNotes` are stripped. (BUT-2028, 2026-09-07)
- `users/{uid}/rateLimits` INHERITS `rate_limits`' Art. 15 exemption rather than getting a decision of its own … There is no separate decision for the camelCase spelling, and one must not be written. (BUT-2040, 2026-09-08)
- A `friend_requests` / `social_requests` row names TWO people, and erasing either account deletes the whole row … deciding whether a counterparty keeps their copy of a request is hers, and it is open. (BUT-2044, 2026-09-08)
- Moving a `friendCategories` row to the live spelling GRANTS ITS MEMBERS A READ they did not have … Malin's explicit call, 2026-09-08 (BUT-2044, 2026-09-08)
- the row about a report filed AGAINST them is KEPT with `details.contentOwnerId` nulled … Both legs are found by QUERY, never by rebuilding the id. (BUT-2032, 2026-09-08)
- `user_moderation.reportHistory` is now a `report_history` SUBCOLLECTION with a 180-day TTL, and the brigading signal is deliberately NOT built (BUT-2046, 2026-09-09)
- the report COUNT IS EXPORTED … The REPORTERS stay withheld (BUT-2046, ADR-0017, 2026-09-08)
  - The conjunct is `hasOnly(['totalReports','lastReportedAt'])`, not a deny-list naming `reportHistory`.
  - It carries a `resource == null` arm, and that arm is not a formality
  - UM4 (the subcollection deny, which must never be "simplified" into a wildcard)
  - The key set lives in three languages — the rule, the Dart projection and the Cloud Function's write payload.
  - The third is SILENT — rules and the writer widen together while the projection does not, and the new field is simply dropped from the bundle with nothing reddening.
  - Deploy order for this change is load-bearing and is NOT the order BUT-2046 states: the functions (the new writer) go BEFORE the rules, or the old writer is still creating the exact documents the conjunct then denies.
- Malin's explicit call, 2026-09-08: build the hold. … a lawful hold must NOT be expressed as `gdprCompliant: false` (BUT-2046, 2026-09-08)
- The legal hold for an open moderation case is BUILT, and it keeps the reported person's uid while it stands (BUT-2046, BUT-2047, 2026-09-09)
  - when the erased account is `contentOwnerId` on at least one `reports` row whose `status != 'closed'`, the cascade keeps `user_moderation/{uid}`, its `report_history` rows, and that uid on both the report and on the `system_events` row derived from it.
  - The uid is nulled when the hold lifts, through the same two anonymizers as today.
  - The decision lives in `erasure_holds/{uid}`, NOT as a field on `user_moderation/{uid}`.
  - `report_history.expireAt` is rewritten to `holdUntil` on the held rows.
  - `gdprCompliant` is untouched and must stay untouched. It is driven by `failedCollections` alone; `retained` sits beside it.
  - For the same reason `probeResidualData` skips the legs a hold KEEPS … The set must stay in step with `deleteModerationSystemEvents`'s `legs` array
  - `residual report rows as reporter`, must NEVER be skipped
  - TWO anonymizers are held, not one.
  - The predicate is `status != 'closed'` and nothing narrower, so an `actioned` case is still open.
  - The sweep runs FIRST in `DAILY_ANALYTICS_TASKS` … An unbounded, unbudgeted sweep in first position is the combination to avoid.
  - `erasure_holds` is in `COLLECTIONS_TO_DELETE`, not in the register-only list.
  - The hold FAILS CLOSED on an unanswerable question.
  - A provisional hold is not a guess that a case is open; it records that we could not tell, and the sweep lifts it on the first clean run. The `onUserDeleted` read fails closed the same way
  - The TTL push is STRICT and the lift is RE-PROBED
  - `held` is keyed on `resourceType`, not on `retained` being non-empty.
  - The `details.userId` threshold alert is held too.
  - The Art. 12(4) notice renders the cap DATE the server sent, never a number in the copy
  - Art. 12(4) is owed because data was KEPT, which does not depend on the rest of the erasure completing. The notice now sits OUTSIDE the success branch
  - But NOT when `auth.deleteUser` itself failed. … `AccountDeletionOutcome.owesRetentionNotice` therefore requires BOTH something retained and the Auth account gone
  - the hedge stays on ONE line.
  - the wording UNDER-CLAIMS on one branch, and stays.
  - A hold that cannot be LIFTED outlives its own cap.
- The Art. 15 bundle does NOT report who has blocked the requester — not the uids, not a count … that line is emitted on every path including the failure one. (BUT-2018, 2026-09-05)
- The `blocks` read limb is NOT split … A future reader must not re-offer the split as cheap (BUT-1917, BUT-2018, 2026-09-09)
- The Art. 15 bundle does NOT name the block mirror among what it withholds … It is deliberately NOT named in `PreferencesExportManager.exportAccountSubcollections`' `data_minimisation` text (BUT-2018, 2026-09-09)
- A blocked person MAY READ comments on the blocker's recipe, and that is a decision rather than a gap … hiding the comments would tell the blocked person that a block exists (BUT-2054, 2026-09-09)
- A `data_minimisation` note that carries a THIRD PARTY's fact is byte-invariant; one that reports OUR OWN read failing may vary with the outcome. The asymmetry is the decision (BUT-2056, 2026-09-09)
- A promotion nobody performed writes NO `editTrail` row. Malin's explicit call, 2026-09-09 … against the alternative of a `"system"` sentinel in `actorId` (BUT-2005, 2026-09-09)
- the CATEGORY SYNC does not cut group-menu access, and the child-safety backstop does (BUT-2005, 2026-09-10)
- RESOLVED 2026-09-10 (BUT-2060) — Malin: LEAVE IT. The category sync does not cut group-menu access … if it is ever re-proposed, the restore path is the half that has to exist first. (BUT-2060, 2026-09-10)
- The create limb now carries `keys().hasOnly(...)` over the SUBMISSION half of `IngredientSuggestion` … `rateLimitWrite` is deliberately NOT added, and that is Malin's call, 2026-09-09. (BUT-2038, 2026-09-10)
- The reset run PAUSES every enabled Cloud Scheduler job for its duration, and a run that cannot pause them REFUSES before Phase 1 … No escape flag (BUT-2036, 2026-09-10)
- The Art. 15 comments and ratings sections are PROJECTED through a fail-closed allowlist, and four fields on a comment are withheld … This is MINIMISATION, not an access control (BUT-2062, 2026-09-10)
- The block gate on `recipe_ratings` stays CONDITIONAL on `recipeOwnerId`, on BOTH limbs … The key is OMITTED when the owner is null OR EMPTY, never written as either. (BUT-2057, 2026-09-11)
- The UPDATE limb carries the same conjunct, and that is not tidying (BUT-2057, 2026-09-11)
- `recipeOwnerId` is deliberately NOT in `cannotModify`, so the field stays FORGEABLE and mutable … Pinning it would therefore REFUSE re-rating of every rating row written before this change. (BUT-2057, 2026-09-11)
- Forward-only: rating rows written before this change carry no `recipeOwnerId` … No backfill, and one was considered and refused (BUT-2057, 2026-09-11)
- the stamp puts the recipe owner's uid on a row ANY signed-in account can read, and no erasure path reaches it … The ERASURE half is open (BUT-2072). (BUT-2057, 2026-09-11)
- The refusal is deliberately SILENT and generic, and must stay so … A refusal that named the block would turn a silent safety control into a notification (BUT-2057, 2026-09-11)
- The control ships UNMEASURED … Nothing counts how often a rating is refused for blocking. (BUT-2057, 2026-09-11)
- `FirebaseRatingsRepository.rateRecipe` now writes `recipeOwnerId` on every rating the app creates … The BUT-2062 STRIP decision is unchanged and still correct (BUT-2057, 2026-09-11)
- SUPERSEDES the BUT-2054 entry's coverage claim … The DEFECT that entry records is unchanged and still open — a hand-rolled client omitting the field is still ungated (BUT-2057, 2026-09-11)
- an UNRESOLVABLE recipe owner keeps writing the rating ungated, and the open question is answered by MEASURING rather than by a refusal. … Do not re-propose the refusal without that figure (BUT-2057, BUT-2073, 2026-09-11)
- The `recipe_comments` and `recipe_ratings` create limbs in `firestore.rules` carry `keys().hasOnly([...])` over the key set of their client writer's map (BUT-2079, 2026-09-11)
- `firebase_ratings_repository.dart` has no `ACCEPTED_LARGE_FILES` row; deleting `updateRating` took it under the 500-line limit. (BUT-2080, 2026-09-11)
- A total failure on the who's-eating menu path filters for the whole household plus the common-allergen floor, even when the user has turned household allergens OFF (BUT-2076, 2026-09-11)
- A reset KEEPS the `analytics` measurement series and DELETES the per-person rows beneath them … `parsing/corrections` and `ingredients/unmatched` are DELETED (BUT-2044, 2026-09-12)
- A member may remove their OWN key from a shared shopping list's `memberPermissions`, and the owner may no longer remove theirs … Do not re-gate the "Lämna listan" button on `canManageShoppingList`/`_canManageSharing` (BUT-1718, 2026-09-12)
- A leave does NOT union the departing member into `contributorUserIds` … Unioning them anyway would create a new durable record that a PASSIVE member was ever there (BUT-1718, 2026-09-12)
- A list a member has LEFT is not in their Art. 15 export, and self-service leaving makes that gap common rather than rare … BUT-1747 carries that, open since 2026-07-30. (BUT-1718, 2026-09-12)
- Leaving is SILENT, and the asymmetry with being ADDED is now a filed gap … Do not add one "for symmetry". (BUT-1718, 2026-09-12)
- after the OWNER erases their account, the remaining members can leave one by one until `memberPermissions` is `{}`, and the document is then unreachable by every client … Not an Art. 17 gap (BUT-1718, 2026-09-12)
- a list already past the 200-contributor cap cannot be LEFT … Only reachable through the Admin SDK today (BUT-1718, 2026-09-12)
- leaving is impossible offline and says the wrong thing about why … The REFUSAL is correct and inherited deliberately (BUT-1718, 2026-09-12)
- Closing a meal poll LOCKS the poll first and writes the winning dish after, so a close can be spent with nothing planned … A future edit that moves a read INSIDE that closure gives the guarantee up silently. (BUT-1925, 2026-09-12)
- `readWeek` mints `readFailed: false` for a cached absence, so BUT-1928's guard does not fire, the one-entry week is built and refused by the update limb — and that refusal now lands AFTER the close (BUT-1925, 2026-09-12)
- The cascade erases `shared_content/{id}/items` attribution, and the Art. 15 bundle carries no item rows from that collection — erasable, not exportable (BUT-1716, 2026-09-12)
- `shared_content/{id}.listData` is a THIRD storage shape for the same item attribution, and NOTHING maintains it (BUT-1716, 2026-09-12)
- BUT-1716's item scrub has no probe leg, deliberately … If it is ever built it must be a `.get()` filtered by the same `isSharedContentParent` predicate. (BUT-1716, 2026-09-12)
- The shared-list item subcollection API is gone … Do not rebuild it. The erasure half BUT-1716 step 1 added stays (BUT-1716, 2026-09-12)
- SUPERSEDES three clauses of BUT-1716 step 1's entries above … The DECISIONS they record are unchanged; the premises are not. (BUT-1716, 2026-09-12)
- The Art. 12(4) notice now survives a missed dialog — on THIS DEVICE only (BUT-2046, ADR-0019, 2026-09-12)
  - The moderation read goes to the SERVER (`Source.server`)
  - It is claimed before the WRITE, not merely before the dialog
  - Device-local was Malin's explicit call, over a server record keyed on the email address
  - The write sits OUTSIDE the `context.mounted` gate in `handleDeleteAccount`, and that placement IS the mechanism
  - The RE-SHOWN notice opens COLLAPSED; the LIVE one does not … Do not harmonise the two; both halves are pinned.
  - ONE method with `startCollapsed`, never two dialogs, and the expansion state is per CALL
  - `ownReportStatus` returns THREE values, not a bool … Do not "simplify" it back.
  - `profileDeleteAccountMayHaveReview` must never be edited into a statement of fact.
  - there is no per-person delivery receipt and there must not be one
- Burst guards are stamped in the same request, and messages carry none … Do not re-add a guard to a struck path without its writer's stamp in the same change (ADR-0020, 2026-09-14)
- A burst stamp's `lastDocId` can hold another person's uid, normally for a few days … the Art. 15 exemption for `rate_limits` STANDS for stamps carrying this key. (ADR-0020, 2026-09-14)
- Leaving or being removed from a household does NOT delete that member's `household_allergen_shares` row … the change that first lets a household gain or lose a member must delete the departing member's share (2026-09-15)
- The feature flag gates the APP, not the server: a hand-rolled client can write a `household_allergen_shares` row before `enable_household_allergen_sharing` is on … Malin's explicit call, 2026-09-15 (BUT-1693, 2026-09-15)
- The Art. 15 bundle no longer names Article 30, and the code comments claiming the audit log IS an Art. 30 record are struck … Deliberately untouched: every `docs/security/*-retention.md`. (BUT-1981, 2026-09-16)
- `getByHousehold` DECLINES above its cap; it must never clip or skip a member … NOT BUILT. (BUT-1693, 2026-09-16)
- A failed audit write must not cost the data subject their Art. 15 bundle … it rides with the next change that touches `data_export_service.dart` (BUT-1693, 2026-09-16)
- `recipe_ratings.review` is bounded at 2000 UTF-16 CODE UNITS and must be a string, on BOTH limbs … The update limb is deliberately NOT scoped to `affectedKeys()`. (BUT-2079, 2026-09-17)
- The `conversation_memberships` collection is GONE, and so is its Art. 15 export section … Do NOT delete the three surviving references as dead code. (BUT-1850, 2026-09-17)
- all four open Art. 15 withholding questions are now DECISIONS, and every one of them keeps the code as it ships. … it is a PRE-LAUNCH gate, because the Art. 12(3) deadline starts the day real rows exist. (BUT-1838, BUT-1971, BUT-2028, 2026-09-17)
- `contributorUserIds` on the group weekly menu plan records uids that left a trace on the week, not the roster. … Forward-only. (BUT-2006, 2026-09-18)
- A REPORTER's erasure keeps an OPEN case's report, without their uid and WITH their free text, until the case closes or 180 days pass … the REPORTER's cap still wins (ADR-0016, 2026-09-18)
- the server can now keep TWO kinds of record, and the client folds them … the three new ones say "en eller flera anmälningar" (BUT-2047, 2026-09-18)
- She approved `GDPR Art. 17(3)(b)` for the reporter side (`REPORTER_RETENTION_BASIS`) … the WHAT line no longer opens with a count (2026-09-19)
