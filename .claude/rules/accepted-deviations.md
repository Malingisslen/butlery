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
- **A household member whose profile cannot be READ WIDENS the allergen union with a
  common-allergen floor (and shuts the UNKNOWN hatch) instead of being skipped — and that
  floor is ALLERGENS ONLY, never `defaults.trackedDietary`** — skipping the member would
  filter as if they had no allergies; inheriting the two default diets would make a hard
  requirement out of "vegansk" and empty the menu of an omnivore household. A profile that
  does not EXIST (`missing`) is the opposite call and does not degrade the roster. The user
  is told: `isRosterComplete: false` drives `householdAllergenRosterIncomplete` in the
  opt-out dialog and, since BUT-1685, on the menu itself. BUT-1663, 2026-07-26

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

- **TRIMMING a trailing orphan heading is BUILT at a 120-character budget; the
  120-200 band is MEASURED AND DECLINED.** `withoutOrphanTail` cuts a page at its last
  detected heading when under 120 characters follow it, applied by `ImportManager`
  BEFORE `split` — so `MultiRecipeSplitter` keeps its "never hands back a single
  SHORTENED block" contract (it does drop furniture when it splits; that is a separate
  promise on `split`) and the eval arm can still measure. Shipped figures over 181 gold pages,
  on top of the edge crop, from `corpus_split_eval.dart --trim`: 10 pages trimmed,
  precision 66.64 -> 66.77 %, recall 91.54 -> 91.52 %, right block counts unchanged
  at 139 (fixed 0, broke 0 — the arm prints the split, so "unchanged" is not a
  masked swap). The arm also prints WHICH ten pages, with each heading and its
  character count, so `orphan_tail.dart`'s list is checkable by command.
  **RECALL IS BIASED AGAINST THIS RULE (BUT-1818):** the gold records frame-cut half
  recipes as complete ones (14 of 242 graded, of which 11 bias recall — both FLOORS, not
  counts, since an unfound fragment only makes the trim look worse), so retained
  debris scores as a hit and the
  trim is penalised for doing its job. **RE-MEASURED 2026-08-09 (BUT-1818): the cost is
  ZERO.** 14 gold entries were graded against their photographs and marked `frameCut`;
  `--no-frame-cut` drops the 11 `fragment` ones — never the 3 `tail` ones, which are real
  recipes and whose removal would only cost a page — and over the SAME 181 pages the trim
  then scores 91.59 -> 91.59 %, with block counts moving 139 -> 144 BETWEEN THE TWO GOLDS
  (the trim itself moves them 144 -> 144) as SIX pages gained
  and ONE lost — the arm prints the per-page movement, because the lost one is the
  informative case (the splitter made 3 blocks of a 1-recipe page and the biased gold
  called that right). The table's `91.54 -> 91.52` keeps the bias
  and is an upper bound. A zero-ingredient gold entry is NOT a defect signal, and no text
  screen reproduces the 14 — each was opened as an image.
  **Dark until the geometry flag is on:** with
  `enable_layout_recipe_split` false — the code default — no layout reaches the
  splitter, so `withoutOrphanTail` returns its input untouched and nothing is cut.
  Do not read "BUILT" as "live for every user".
  **The 120-200 band was designed as a third outcome (show it unticked in the picker)
  and then declined by its own gate.** Every tail in that band carries READABLE CONTENT
  under the heading — a whole small recipe (`Chokladkräm`), an intro paragraph
  (`Annas hurtbullar`), the start of the next recipe (`Inlagd sill`, `Mixade vitaminer`),
  a tip section with its own list (`I stället för sås`). Below 120 there is only
  frame-cut debris. The budget is a PROXY for exactly that, so the band stays off and
  the UI half (`uncertainIndices` through the viewmodel to the picker, an ARB string, a
  widget test) was never built.
  **CORRECTED 2026-08-09 — the verdict stands, the stated reason was wrong.** The
  2026-08-08 reading was done on the bare TEXT and called those two "subheadings inside
  a recipe"; re-read against the PHOTOGRAPHS, `Chokladkräm` is a complete little recipe
  and `I stället för sås` is a new section's display heading. The same text-only pass
  mis-graded the SHIPPED window too (reported 8 of 10; Malin objected; all ten opened as
  images are 10 of 10 CORRECT, and two are the back-cover blurb of a different book
  lying behind the cookbook). Never re-judge either set from the text — open the images.
  Do not raise the budget above 120 without re-reading those nine that way; the corpus
  measurement at 200 shows the cost — recall 91.33 %, one page lost. That row has NOT
  been re-measured against the corrected gold and is the most bias-exposed figure in this
  entry; do not cite it as a clean cost when re-opening the band.
  Re-open the band the day the picker can MERGE two blocks (BUT-1817): a wrong guess
  becomes undoable and the trade changes. PROXY — Windows offline OCR, not ML Kit.
  BUT-1816, 2026-08-08, corrected 2026-08-09

- **Letting a SINGLE surviving layout block stand, instead of falling back to the text
  rules, is MEASURED AND DECLINED — do not build it.** `MultiRecipeSplitter._splitByLayout`
  ends on `if (blocks.length < 2) return null`, so a page whose orphan trailing heading was
  correctly discarded still falls through to the text rules, which put it back. Relaxing
  that to accept one block is SAFE while the discard budget stays under ~120 characters
  (single pages 122/133, spreads 16/48, 39 lost — all identical to today) and BREAKS at the
  live 200-char budget (spreads 15/48, 40 lost, one page broken). It is also worth nothing:
  gold-token recall unchanged at 91.56 %, precision 66.26 -> 66.27 %, **four tokens across
  181 pages**. **CORRECTED 2026-08-08, same day:** that last figure is right but its
  generalisation was wrong. The entry originally read "the corpus does not contain the case
  in measurable quantity" — it does. 19 of 247 captures END their import on a next-recipe
  heading (`Inlagd sill`, `Mandelforell`, `Annas hurtbullar`), and ALL 19 reach the import
  because the layout path declined. This gate is simply not the one that declines: 14 of the
  19 bail on `flat.length < 2` and only **2** on the single-block rule. So the verdict
  below stands for THIS gate and says nothing about the symptom — see the trim entry.
  Re-derive with a mutation probe on that one line, reading the BLOCK counts off
  `corpus_split_eval.dart --layout` and the TOKEN figures off `--edge-crop`. (That arm also
  prints the paired block report, because it implies `--layout`; `--layout` alone prints no
  tokens.) PROXY figures — Windows offline OCR, not ML Kit. BUT-1816, 2026-08-08

- **Column ordering for on-device OCR is MEASURED AND DECLINED — do not build it.**
  A sorter putting the left column before the right rewrites two of every three corpus
  pages (116 of 181), including single-recipe pages that already work, and buys 139
  correct block counts against 138, the same COUNT of recipes never emitted (39), 5 fixed and
  4 broken. One page, which is noise. A per-line height-vs-width fit (deskew), proposed
  separately and not by the plan, scores strictly worse: 136/181, 42 lost, 0 fixed, 2
  broken. **All PROXY figures — Windows offline OCR, not ML Kit**, so they say what the
  algorithm does, not what the phone does. ML Kit's own block grouping is still
  UNMEASURED: the plan hoped it made a sorter unnecessary, and this does not refute that;
  it makes it moot, because the sorter does not pay either way. Consequence: the corpus
  page the feature was designed against still does not split, recorded as a passing
  known-miss test in `heading_detector_test`, not tidied away. Note the interleaving is
  REAL in that engine — 49 of its 134 two-column pages (37 %) come out of capture
  out-of-order — so the case for re-opening is a device measurement showing ML Kit behaves
  the same AND a bigger gain than one page. An engineering call under the plan's ⑦
  ("check it against real geometry before writing a line"), reported to Malin in the
  2026-08-07 session summary; no founder override sought or given. 2026-08-07


- **SUPERSEDES the "both spellings are named deliberately" clause of the BUT-1798 export
  entry.** `shared_content` now carries membership under ONE field, `sharedToUserIds`. The
  dual write existed so rows predating the writer fix stayed readable; **Malin, 2026-08-03:
  the project holds only TEST recipes**, so it protected nothing and two copies of one fact
  could only drift — which is exactly what they did, at the cost of an invisible export gap
  and an un-erasable uid. The earlier entry stands as the record of why it was ever dual; do
  not read it as still requiring both. Note `sharedWithUserIds` remains the legitimate, sole
  field on `recipe_comments` (firestore.rules:1247, BUT-458) — scope any future change by
  COLLECTION, never by field name. 2026-08-03


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
