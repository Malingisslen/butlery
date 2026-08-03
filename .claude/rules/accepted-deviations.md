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
- **The `shared_content` export sections keep other recipients' UIDs (under BOTH spellings
  `sharedToUserIds` and `sharedWithUserIds`) and the sharer's `sharedByDisplayName`** — scoped to
  rows where the requester is a RECIPIENT. **Malin's explicit call, 2026-08-01.** She was shown
  exactly what leaves the device for one row: the other recipients' UID list, the sharer's display
  name, the recipe title, the share timestamp, and `sharedByAvatarUrl` already stripped. Reasoned on
  its own merits — the requester's own client can already read every one of these documents under
  `firestore.rules` :720-728, and opaque UIDs with no name would fail Art. 12(1). This is **not**
  derived from BUT-1732 or BUT-1772: BUT-1732 decided a different collection and DROPPED other
  members' names, BUT-1772 decided conversation participants; citing either as authority here is the
  precise error the BUT-1732 entry records having made. Both spellings are named deliberately — the
  writers emit the same list twice, and an entry naming one invites a future reviewer to strip the
  other "for consistency". BUT-1798, 2026-08-01
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

## Engineering

- **The free on-device OCR tier ships ON despite losing the measured comparison** — the
  corrected eval (harness preprocessing like production) scores on-device 96.1 vs the paid
  chain 96.6 over 39 verified recipes across 21 pages, so the plan's "at least as good" gate
  is NOT met — and on a LARGER corpus the gap widened (0.3 -> 0.5) rather than averaging out,
  across three consecutive runs.
  **Malin's explicit call, 2026-08-03:** half a point is not worth paying per image for. Do NOT flip `enable_on_device_ocr` off citing the
  gate — the gate was overridden knowingly, and the paid chain still runs behind the tier for
  anything it reads poorly. Revisit if a larger corpus shows a real gap. 2026-08-03


- **Equality-only Firestore filters need no composite index** — automatic single-field
  indexes merge them; only `orderBy`/range combinations need a composite. 2026-06-22
- **The 500-line limit is waived for every file in `ACCEPTED_LARGE_FILES.md`** — read the
  per-file rationale there before proposing a refactor. 2026-06-22
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
