# PLAN 2026-08-22 — sprint (--pick malin): six tickets Malin chose in session

Selected interactively 2026-08-22 via `/delivery:sprint-execute --pick malin`. Malin picked
all four offered clusters, which resolve to six tickets. Every premise below was checked
against CURRENT `main` (working tree at 52a6f8e9e), not against the ticket text.

Router (`python tools/stakeholder_router.py --json`) returned tier **single** for all five
path-groups — no `full-panel`, so nothing is pulled from the sprint on the dispatch gate.
Panel policy is `park`: a contested outcome goes to In Review rather than auto-closing.

## Selection record

| Ticket | Disposition | Tier | Router | Owning role(s) |
| --- | --- | --- | --- | --- |
| BUT-1908 poll shows "0 röster", closes on real votes | build | C (repo + service + VM + widget) | single | Trust & Safety |
| BUT-1909 blocking does not reach poll votes | build | C (same module, security) | single | Trust & Safety |
| BUT-1915 raw uid into Crashlytics via MenuOperationError | build | A | single | Localization / i18n |
| BUT-1910 rating field drops the comma | build | A | single | Localization / i18n |
| BUT-1906 diet badges missing in grid view | build-review | B (UI-visual) | single | Creative Director / Brand Lead |
| BUT-1894 real-time-guard costs 859 s per commit | build | A | single | Software Architect |

BUT-1894 carries a **recorded decision** (Linear comment, 2026-08-18): the earlier rewrite
was torn down because it failed OPEN on two cases. Those two cases are copied into its
acceptance criteria below and are binding.

### Step-0 premise check (grep of main, not of `git log`)

* BUT-1908 — `maxHydratedPolls = 20` at `message_query_module.dart:23`, `_pollIds` still
  `.take()`s, `poll_message_widget.dart:98-100` still gates only on
  `poll.isActive && poll.creatorId == currentUserId`. **Premise holds.**
* BUT-1909 — `_tally()` at `:194` reads every `poll_votes` row with no block filter;
  `BlockedUserFilter` is applied only in `messaging_service.dart:254 _filterBlocked`, on
  `m.senderId`. **Premise holds.**
* BUT-1915 — `menu_participants.dart:112` still throws
  `MenuOperationError(message: l.validationUserNotParticipant(userId))` with the raw uid.
  **Premise holds.**
* BUT-1910 — `skriv_sjalv_recept_view.dart:677` still calls `double.tryParse(value)`;
  `lib/core/utils/swedish_decimal_input.dart` exists. **Premise holds.**
* BUT-1906 — `lib/widgets/recipe/recipe_card.dart` still carries the "deliberately NOT
  here" note in the grid layout. **Premise holds.**
* BUT-1894 — `scripts/check_test_real_time.sh` unchanged since 2026-06-22. **Premise holds.**

## Risky-ticket plan expansion (Phase 1.5 fired for 1908, 1909, 1915, 1894)

### BUT-1908 + BUT-1909 — one implementation, two tickets

They touch the same tally and must agree on one answer, so they ship together.

**Blast radius:** `lib/repositories/firebase/modules/message_query_module.dart`,
`lib/services/messaging_service.dart`, `lib/viewmodels/chat_viewmodel.dart`,
`lib/widgets/messaging/poll_message_widget.dart`,
`lib/widgets/messaging/builders/message_content_builder.dart`, the two ARB files,
plus tests.

**Design — hydration state (1908).** The client cannot today tell "zero votes" from "the
votes were never read". Both are `voterIds == []`. A boolean is not enough: past-the-cap is
a client choice a re-read repairs, a failed read may be permanent, and the two need
different Swedish text. So hydration writes a marker into the IN-MEMORY metadata only:

    metadata['pollVoteHydration'] = 'ok' | 'capped' | 'failed'

Safe to add because nothing round-trips a hydrated `Message` back to Firestore: the repo's
`closePoll` (`message_mutation_module.dart:475-497`) re-reads the raw document and writes
`isClosed` alone, and no other writer sends a hydrated metadata map. Verified by grep of
every `'metadata':` write under `lib/repositories/`.

**Design — blocked voters (1909).** Filtering belongs in the SERVICE, not the repository:
blocking is viewer-scoped, `MessagingService` already owns `BlockedUserFilter`, and the
repository has no business knowing who the viewer blocked. One helper strips blocked uids
from every option's `voterIds`, and it runs on BOTH surfaces so the number on screen and
the winner can never disagree:

1. `_filterBlocked` (covers the live stream at `:222` and the page at `:239`), and
2. `closePoll`, which reads through `_messagingRepository.getMessage` directly and would
   otherwise bypass the filter entirely.

**Design — the close path (1908 items 3-5).** `closePoll` refuses when the tally was not
read: no plan write, no `isClosed` flip, throw a typed failure. `ChatViewModel.closePoll`
returns a result instead of swallowing, and the chat view shows the Swedish reason. The cap
logs when it excludes a poll.

**Rollback shape:** every change is additive and in-memory; reverting the commit restores
the previous behaviour with no data migration, because nothing new is persisted.

**Acceptance criteria**

BUT-1908
1. `diff` — Hydration records three distinguishable states, and a poll excluded by the cap
   or failed on read is NOT reported as `ok`. Pinned by a test per state.
2. `diff` — `PollMessageWidget` does not draw an ENABLED close button on a poll whose votes
   were not read, and shows Swedish text saying so instead of a bare "0 röster". Two tests:
   capped and failed.
3. `diff` — `MessagingService.closePoll` throws rather than flipping `isClosed` or writing a
   plan when the poll it read was not hydrated. Test asserts BOTH omissions, not just one.
4. `diff` — `ChatViewModel.closePoll` no longer swallows: it surfaces the failure to the
   caller. Test asserts the failure reaches the viewmodel's consumer.
5. `diff` — The cap logs the ids it excluded. **Negative constraint:** the log must not
   print a raw conversation id or uid.

BUT-1909
1. `diff` — A blocked voter is excluded from the tally on the DISPLAY path and on the CLOSE
   path, proven by one test each.
2. `diff` — Displayed count and resolved winner are computed from the SAME filtered tally.
   A test with a blocked majority asserts the number on screen and the winner agree.
3. `diff` — Fail-open is preserved: a block-list lookup error serves the unfiltered tally
   rather than blanking the poll, matching `_filterBlocked`'s existing contract.
4. `diff` — **Negative constraint:** the repository module gains no knowledge of blocking.
   `message_query_module.dart` must not import or reference `BlockedUserFilter`.

### BUT-1915 — raw uid into a crash report

**Blast radius:** `lib/services/realtime/modules/menu_participants.dart`, the two ARB files
(if the placeholder is dropped), plus a test.

Scope is the FIRST item of the ticket only — mask at the throw, as the neighbouring
`AppLogger.info` line already does. The ticket's item 2 (should `MenuOperationError`,
`RepositoryException` and `StorageUploadException` mask in their own `toString()`) is a
design decision that belongs with BUT-1907's architecture-test arm; it gets a follow-up, not
a guess inside this sprint.

**Acceptance criteria**
1. `diff` — The uid in `validationUserNotParticipant` is masked at the throw site, using the
   same masking the neighbouring log line uses.
2. `diff` — A test proves `MenuOperationError.toString()` on that path contains no raw uid.
3. `diff` — **Negative constraint:** no change to `permission_exceptions.dart` and no new
   masking added to `MenuOperationError.toString()` itself — that is BUT-1907's call, and
   deciding it here would pre-empt the architecture test that is meant to find the rest.

## Stakeholder critiques folded in (Phase 1.4, tier `single`)

Each is ONE blind critique from the owning role, run before any code was written. Every
MUST-HAVE below is now a binding acceptance criterion.

### Creative Director / Brand Lead — BUT-1906

* **Badge-weight mismatch, not in the original plan.** The grid's allergen row draws
  ICON-ONLY compact chips (`recipe_card.dart:372-376`, `showLabel: false`), while the
  dietary row is called elsewhere with `showLabel: true` (`recipe_card.dart:258-262`),
  i.e. full Swedish words. Stacking narrow icon chips over wide text chips on a ~160-180dp
  tile is two densities on one card. Either the grid's dietary row also goes icon-only, or
  the two-labelled-badge case is explicitly tested and accepted. Not decided implicitly by
  `CompactDietaryRow`'s default.
* Fixtures must include the TWO-badge worst case (`maxBadges: 2`), not one diet tag — that
  is the case that wraps at 1.75-2x and eats BUT-1895's remaining margin.
* Row order stays allergen (hazard) above dietary (preference), matching the detailed
  layout at `recipe_card.dart:237-263`.
* Badges are not shrunk to fit. Reaffirmed: a shrunk badge is worse for a colour-blind user
  who relies on its shape than a slightly taller card.
* `_buildCompactLayout` staying badge-free is accepted for this ticket, and is noted as a
  standing third-spelling drift risk rather than a fix owed here.

### Localization / i18n — BUT-1910 and BUT-1915

* **BUT-1910: the rating validator is not in conflict.** `FormValidators.rating()`
  (`form_validators.dart:160-166`) delegates to `numberRange(min: 0, max: 5)`, which does
  its OWN comma-aware parse at `:116`. So `"4,5"` passes the validator today while
  `setRating` gets `null` from `double.tryParse` — the validator owns range, the parser
  only has to read the value. No bounds work is owed to `parseSwedishDecimal`.
* **BUT-1910: the pantry display round trip is safe, verified.** `formattedQuantity`
  (`pantry_item.dart:154-156`) is read back into an editable field at exactly one site,
  `add_pantry_item_sheet.dart:99`, and `_submit()` at `:176-178` already comma-normalises.
  A comma round-trips.
* **BUT-1910: the selection sentence must be falsifiable, and the load-bearing fact is
  DEFAULT-vs-NULL.** `parseSwedishNumber`'s silent `1.0` fallback would corrupt a rating
  field invisibly. The sentence says: `parseSwedishDecimal`/`formatSwedishDecimal` for any
  hand-typed, round-tripped field, because they return `null` and let the caller decide;
  `TextFormatting.parseSwedishNumber`/`formatFractional` only for non-interactive recipe-text
  parsing, where the `1.0` fallback is an accepted default rather than a form value;
  `formatRatingComma` only for pooled-rating display, which needs a fixed decimal place.
* **BUT-1915: the Swedish sentence question is moot — the string never reaches a user.**
  `RealtimeMenuViewModel._onServiceStateChanged` (`:361-364`) runs the error through
  `sanitizeErrorForUser`, which returns a generic localized message. The interpolated uid's
  only destinations are `AppLogger.error` and `MenuOperationError.toString()`. So the ARB
  placeholder STAYS and no ARB edit is needed; this is a log/crash-report fix only.
* **BUT-1915 MUST-HAVE: the twin class is outside the plan's stated blast radius.**
  `lib/services/realtime/modules/recipe_participants.dart:92-96` and `:121-125` throw
  `RecipeOperationError(message: l.validationUserNotParticipant(userId), ...)` — identical
  unmasked-uid shape, same family. Both throw sites join the diff with their own test.
  This is the repo's standing "a boundary bug has a TWIN CLASS" rule, met head-on.

### Software Architect — BUT-1894

* **Root cause MEASURED, and it is not the grep.** The two `grep -rEn` calls
  (`check_test_real_time.sh:89`) finish in ~0.4 s total. `DateTime.now()` alone matches
  **1,066 lines** under `test/unit`, and every matched line spawns `is_suppressed` (an `awk`,
  `:60-63`) plus, in baseline mode, `is_baselined` (`echo|sed|sed` + `grep -qxF`, `:49-55`)
  — about **four processes per match, ~4,300 in total**. On Windows/Git-Bash process
  creation is the expensive primitive, and 4,300 spawns lands in the measured 646-859 s
  band. **Binding: the rewrite must remove per-match subprocess spawns** (one `awk`/`perl`
  pass per file, reading suppression and baseline once), not "optimise the grep".
* **Shape verdict: the check stays pre-commit; the full-tree scan is what is wrong.**
  `lefthook.yml:93-95` already glob-gates on `*_test.dart`, then greps all of `test/`
  anyway. Every other gate in that file takes `{staged_files}`. Moving it to CI would only
  delay the same design flaw. Scope it to the staged files.
* **Fixture layout is binding**, at `scripts/__tests__/check_test_real_time/fixtures/`:
  (a) a real BINARY `*_test.dart` blob → exit 1; (b) a baselined file holding only comments
  and blank lines → exit 0, not a `set -e` death; (c) a suppressed violation → exit 0;
  (d) an un-baselined `DateTime.now()` → exit 1; (e) a long `Future.delayed` inside each
  `DELAYED_SCOPE` dir → exit 1 regardless of baseline. Driven by
  `scripts/__tests__/check_test_real_time_test.sh`, which runs the REAL script and asserts
  exit codes. Confirmed by the reviewer: no fixture test for this script exists anywhere in
  the repo today, which is how the fail-open rewrite got as far as it did.
* **Strike the false comment at `lefthook.yml:87`**, do not soften it. "Usually fast" is the
  same false claim restated. It carries the measured number and a date.

### Trust & Safety / Content Moderation — BUT-1908 + BUT-1909

Verdict: the service-not-repository layering is right and the negative constraint stands.
Two binding changes, because as first written the design shipped a DISPLAY fix labelled as
a blocking fix, and its fail-open clause let a blocked person decide a household artifact.

* **MUST-HAVE — fail-open is SPLIT BY SURFACE. This REPLACES BUT-1909's acceptance
  criterion 3 as originally written.** Fail-open is correct on DISPLAY. On the CLOSE path it
  means: the block-list fetch fails, `BlockedUserFilter._cached` stays `{}`
  (`blocked_user_filter.dart:52-55`), the blocked ballot resolves the winner at
  `messaging_service.dart:689`, and it lands in a plan other members see. So when the block
  list is UNKNOWN — `ServiceLocator.tryGet` returned null, or the fetch threw — `closePoll`
  REFUSES: no plan write, no `isClosed` flip, and the retry reason is surfaced. One test
  asserts both omissions.
* **MUST-HAVE — no disclosure of the filtering in group-visible output.** The winner write
  stays recipe-id-only (it is today, `:853-893`). Nothing in the plan entry, the share
  message or any log may say the tally was filtered or by how much — publishing that leaks
  who the creator has blocked. This is a negative constraint beside BUT-1908's criterion 5.
* **MUST-HAVE — say plainly, in the ticket, that this is NOT block enforcement.**
  `firestore.rules` still lets a blocked user write `poll_votes` on my message, every OTHER
  member's screen still counts them, and `getBlockedUserIds`
  (`firebase_block_repository.dart:112-127`) is one-directional, so someone who blocked ME
  is unfiltered in my own poll. Store policy (Apple 1.2, Play UGC) reads "block" as CANNOT
  INTERACT. A follow-up ticket for rules-level enforcement on `poll_votes` create is owed.
  BUT-1832's accepted deviation covers the VOTABILITY of share cards, not this.
* Creator's-list-decides is endorsed: the closer is the actor, and the alternative
  reproduces the exact BUT-1908 harm of screen and write disagreeing. The residual — other
  members cannot reproduce the margin — is smaller than the harm avoided.
* On the three states: as a SAFETY control they are ceremony, because `capped` and `failed`
  must disable close identically. So the close gate tests `ok` / not-`ok`, and the third
  value survives to drive the Swedish text and the log, not the gate.
* Noted, not owed here: `closePoll` re-reads at `:670` rather than acting on the displayed
  tally, so a vote landing between render and tap still writes a winner the creator never
  saw; and `searchMessages` (`:495-511`) applies no block filter at all. Both get follow-ups.

## Non-risky tickets

### BUT-1910 — rating field drops the comma

1. `diff` — `skriv_sjalv_recept_view.dart` parses the rating through `parseSwedishDecimal`;
   typing `8,5` sets the rating to 8.5. Test pins it.
2. `diff` — `add_pantry_item_sheet.dart` uses the same helper, so `,5` and `1,5,5` behave as
   they do on the shopping surface. Test pins both.
3. `diff` — `pantry_item.dart:154` displays the quantity with a comma, so a shopping item and
   a pantry item no longer spell the same number two ways.
4. `diff` — `swedish_decimal_input.dart` states in one sentence which of the three formatters
   applies when and why they are not merged.

### BUT-1906 — diet badges in the grid card (Tier B, parks In Review)

1. `diff` — The dietary row renders in `_buildGridLayout`, after the allergen row.
2. `diff` — `recipe_card_grid_badges_test.dart` fixtures carry diet tags and the overflow
   cases pass up to 2x text scale.
3. `diff` — If it does not fit, `_gridAspectRatio` in `mina_recept_view.dart` is raised and
   the new number is pinned by a test. **Negative constraint:** the badges are not shrunk.
4. `diff` — The "deliberately NOT here — see BUT-1906" comment is removed, not reworded.

## Needs you (Tier D)

None in this batch. BUT-1894's timing measurement is a `run` criterion, not Tier D.

## Deviation log


---

# ARCHIVED — previous sprint plan (2026-08-20)

# PLAN 2026-08-20 — sprint (--pick malin): four tickets Malin chose in session

Selected interactively 2026-08-20 via `/delivery:sprint-execute --pick malin`. Malin picked
all four offered candidates. Every premise below was checked against CURRENT `main`, not
against the ticket text.

The router (`python tools/stakeholder_router.py --json`) returned tier **single** for all
four, so each gets ONE blind critique from its owning role before implementation. Panel
policy is `park`, so a contested outcome goes to In Review rather than auto-closing.

## Selection record

| Ticket | Disposition | Tier | Router | Owning role |
| --- | --- | --- | --- | --- |
| BUT-1891 decimal quantity | build | A | single | Product Designer / UX |
| BUT-1895 grid allergen badges | build-review | B (UI-visual) | single | Creative Director / Brand Lead |
| BUT-1897 PII via exception object | build | C (security, multi-file) | single | Trust & Safety |
| BUT-1883 poll cap / closePoll | build | A | single | Trust & Safety |

Closed during selection: **BUT-1887** — Malin recorded the close decision in a comment on
2026-08-19; the ticket had simply never been transitioned out of Backlog.

Not selected, and why: the `need-malin` lane (BUT-1878, 1885, 1880, 1904, 1731, 1838, 1848)
is Phase 3.6 decision-queue material, not build material.

---

## BUT-1891 — you cannot type a decimal in a shopping quantity  [Tier A]

**Premise: HOLDS.** `lib/widgets/styled/styled_input.dart:297-301` still applies
`FilteringTextInputFormatter.digitsOnly` whenever `keyboardType == TextInputType.number` and
no explicit `inputFormatters` is passed. Both quantity fields in `shopping_item_dialogs.dart`
(`:199`, `:333`) hit that default.

**Blast radius — CORRECTED after review, and the first version was wrong.** The plan listed
eight call sites as reaching `StyledInput`'s digits-only default. Measured properly, only
ONE production file does: `skriv_sjalv_recept_view.dart:584,598` (portions and time). The
others — `edit_recipe_view`, `heirloom_section`, `mfa_settings_view`,
`assisted_import_dialog`, `rule_condition_card` — set `TextInputType.number` on a bare
`TextField`/`TextFormField` and never touch `StyledInput`, so that default protects nothing
in them. `StyledInput.number` has no production caller at all.

The two shopping quantity fields are the third and fourth, and they are the bug.

Callers already on `numberWithOptions(decimal: true)` do NOT satisfy the
`== TextInputType.number` equality, so they get `null` formatters today and no option below
touches them.

**Chosen shape — do NOT change the shared default.** Add a decimal-permitting formatter and
pass it explicitly from the two shopping quantity fields. Changing `StyledInput`'s default
would admit a decimal point into servings, minutes and an MFA code.

**Acceptance criteria**
1. (diff) Typing `1,5` into a shopping-item quantity field leaves `1,5` in the field and
   `1.5` reaches the save call.
2. (diff) A test proves an integer-only field still refuses both a comma and a period.
3. (diff) `replaceAll(',', '.')` in the dialogs is reachable — proven by the AC1 test — or
   deleted. It is not left as dead code that looks like handling.
4. (diff) NEGATIVE CONSTRAINT: `StyledInput`'s default formatter branch is byte-identical
   to main.

---

## BUT-1895 — the allergen marks are missing in grid view  [Tier B — parks In Review]

**Premise: HOLDS.** `recipe_card.dart` draws the allergen row, the dietary row and the
unassessed indicator ONLY inside `_buildDetailedLayout` (`:237-260`). `_buildGridLayout`
(`:323-346`) and `_buildCompactLayout` (`:288-321`) draw none of them.
`MinaReceptRecipeCard` (`recipe_card_widget.dart:47-57`) selects `ContentCardStyle.grid`
whenever `viewModel.isGridView`, and it passes the preferences correctly — so the data
arrives and the layout drops it.

**The product decision inside this ticket** (its item 1): nothing in the code says whether
grid-without-badges was a design call or an oversight. Best guess to build: allergen
information is safety-visible and must not depend on which view toggle happens to be saved,
so the grid gets the allergen row. This is exactly the case where the outcome is Malin's to
sign off → In Review, never auto-Done.

**Scope**
- Item 1: allergen badges in `_buildGridLayout`. The COMPACT layout stays out of scope this
  run (a 60px row is a separate design call) — stated in the close-out, not left silent.
- Item 2: first tests for `MinaReceptRecipeCard` — pin `showOnCards == false` ⇒ no badges and
  `showOnCards == true` ⇒ badges. It lives under `lib/views/`, so the tests belong to
  `e2e-test-specialist` and `test/views/`; the ticket records that this drifted past the
  wrong agent twice already.
- Item 3: a distinguishing test that `TagResultDisplay._getAllergensToShow` drops UNKNOWN.
- Item 5: correct the over-promising `reason` string in `compact_tag_rows_test.dart`.
- Item 4 (the producer-less `coveragePercent` arm on `AllergenStatusBadge`): comment it as
  producer-less rather than deleting it. Deleting is its own call and the widget test still
  guards the widget.
- Point 8 from the ticket's comment thread (the `recipeAllergensUnassessedA11y` screen-reader
  label) is included: it is the only user-visible surface of the BUT-1780 change with no
  coverage at all.

**Acceptance criteria**
1. (diff) A widget test renders `RecipeCard` in grid style with a tracked allergen and finds
   the badge; the same assertion in detailed style still passes.
2. (diff) A test file for `MinaReceptRecipeCard` exists and reddens if `showOnCards` stops
   gating `userAllergenPrefs`.
3. (diff) A test feeds a `TagResult` carrying an UNKNOWN allergen status and asserts no badge
   is drawn for it.
4. (diff) `find.bySemanticsLabel` covers `recipeAllergensUnassessedA11y`.
5. (diff) NEGATIVE CONSTRAINT: `_buildCompactLayout` is unchanged, and the change is reported
   as grid-only.

---

## BUT-1897 — a crash report can carry a person's id  [Tier C — security, multi-file]

**Premise: re-verified at Step 0 before anything is written**, because the ticket was last
edited 2026-08-19 and the tree has moved since. Two claims to check: (a) `AppLogger` still
hands the raw `error` object to `recordError`, (b) the six repositories the ticket names
still pass `userId: currentUser` raw into `PermissionDeniedException`.

**The decision the ticket leaves open** is one choke point (wrap the error object before
`recordError`) versus N throw sites. A wrapper loses the exception TYPE, which is what makes
a Crashlytics report groupable. Planned shape: fix the throw sites AND add the
architecture-test arm — the arm is what stops the next one, and a runtime choke point cannot
be proven by a test that only reads source.

**Acceptance criteria**
1. (diff) The architecture test gains an arm over exception CONSTRUCTION: raw identifiers
   passed to `resourceId:` / `resource:` / `userId:`, or interpolated into a `StateError(` /
   `Exception(` message, under `lib/repositories/` and `lib/services/`.
2. (diff) That arm is proven to fire — it reddens against the `message_deletion_module`
   `StateError` exactly as that line stands on main today, before any fix.
3. (diff) Every site the arm flags is either masked or explicitly allow-listed with a written
   reason.
4. (diff) NEGATIVE CONSTRAINT: no change to what `AppLogger` sends as the error OBJECT unless
   the critique asks for it — the type is load-bearing for Crashlytics grouping.

---

## BUT-1883 — a poll past the cap can close on the wrong option  [Tier A]

**Premise: PLAN-STALE — half of it already shipped, and the ticket does not say so.**
Checked on `main` 2026-08-20:

- The cap still exists (`message_query_module.dart:23`, `:177`).
- A test DOES now exist (`message_query_module_test.dart:604`). It pins that the cap keeps
  the NEWEST polls rather than the oldest, which closes the "0 röster on screen" half: the
  dropped poll is now one scrolled off the top.
- **Still open, and it is the dangerous half:** nothing stops `closePoll` from acting on a
  poll whose votes were never hydrated. The module's own comment (`:150-158`) still names the
  consequence — the wrong recipe written into the week's plan.

So the remaining work is one guard plus its test, not the two items the ticket lists. The
ticket body is corrected before implementation (Phase 2 "plan-stale" branch).

**Acceptance criteria**
1. (diff) `closePoll` refuses to resolve a winner from a poll whose votes were never
   hydrated, instead of falling through to the first option.
2. (diff) A test proves the refusal, and it reddens if the guard is removed.
3. (diff) The refusal is visible to the user in Swedish, not a silent no-op.
4. (diff) The Linear ticket body is corrected to record that the newest-first half already
   shipped.

---

## Needs you (Tier D)

None in this batch — all four are code-only.

## Post-sprint steps

1. Full `dart analyze --fatal-infos` on the changed files.
2. File follow-up Linear tickets BEFORE the commit.
3. Commit through the review gates (`code-reviewer`, `testing-specialist`,
   `firebase-backend-security` where repositories are touched, `integration-reviewer`).
4. Push to main.
5. Transition: BUT-1891 / BUT-1897 / BUT-1883 → Done on an all-pass; BUT-1895 → In Review.
6. Phase 3.6 decision queue (`malin` was passed).

## Outcome verification (Phase 2.7)

Graded by fresh-context verifiers that saw only the criteria, the scoped diff and the tests
— not by the implementer.

- **BUT-1891** — 5/5 PASS. Also confirmed independently: `StyledInput` is byte-identical to
  main, `formattedAmount` has exactly one consumer and it is display-only, and the
  `replaceAll(',', '.')` dead code is gone rather than left looking like handling.
- **BUT-1895** — 6/6 PASS. The verifier found one real gap the criteria did not cover: the
  tile's aspect-ratio formula was hardcoded a second time inside its own test, so a retuned
  production value would have left the test green against its own stale copy. Moved to
  `AppDimensions.recipeGridAspectRatio` and imported — which immediately reddened, because
  the delegate had been reading `MediaQuery` from a context ABOVE the test's own override.
  Every "2x" case had been measuring a 1x tile.
- **BUT-1897** — 7/8 PASS, one FAIL, fixed. `SecurityViolationException` and
  `AuthenticationException` were in the same file and were not masked, and both have throw
  sites that put an id in `details:`. The verifier also found the composite-id hole
  (`<uid>_2026-W34` escapes a `\b`-bounded rule) and two false-positive regressions
  (the type label, and class names in web stack frames). All four fixed and pinned.
- **BUT-1883** — NOT GRADED, because nothing was built. See the deviation log.

## Review gate

Seven specialist runs. Two blocked and were fixed rather than argued with:

- `code-reviewer` on the widgets: a doc comment I inserted swallowed the neighbouring
  function's, and a "correction" I wrote made a positional claim that was false. Both fixed;
  re-review passed.
- `firebase-backend-security` on the web sink: the stack carve-out re-exported the message it
  had just masked, because under dart2js the first line of a stack IS the exception's
  `toString()`. Split at the first frame instead; re-review passed, then found that Firefox
  and Safari emit a third frame shape the splitter did not know, which is now covered.

Every fix in this sprint was mutation-probed — the fix is reverted and the test watched to
redden — including one test that turned out VACUOUS on the first probe (the UNKNOWN-allergen
case passed with the filter deleted, because an UNKNOWN badge draws a third icon the
assertion never named).

## Deviation log

- [discovery] BUT-1891: plan said "add a formatter at the two call sites" → found the
  DISPLAY half open too (`formattedAmount` returned `amount.toString()`, i.e. "1.5", under a
  doc comment promising "1,5 l Mjölk") → fixed both, because the input fix alone is undone
  one screen later. Raised by the Product Designer critique, verified in the code.
- [discovery] BUT-1891: `StyledInput.number` has NO production caller — only tests. The
  shared default is still untouched, and now has a case pinning that it refuses both
  separators.
- [deviation] BUT-1895: plan said "add the allergen row to the grid" → the grid tile
  ALREADY overflowed its own box by 70px at 1x and 175px at 2x, for every recipe, measured.
  Adding a row to a container that clips was not possible → the image became the layout's
  slack (`Expanded`) and the tile height now scales with the text size
  (`_gridAspectRatio`). Conservative in the sense that it fixes the container rather than
  shrinking the content, which is what the Creative Director's must-have required.
- [deviation] BUT-1895: the unassessed marker was NOT in the plan's grid scope. Added on the
  Creative Director's blocking condition — shipping the badges without it recreates, in the
  grid, the "silence reads as safe" bug the marker exists to close.
- [discovery] BUT-1895 item 5 (the over-promising `reason` in `compact_tag_rows_test.dart`)
  was already corrected on main. Nothing done; recorded so it is not re-filed.
- [deviation] BUT-1897: plan said "fix the throw sites AND add an architecture-test arm" →
  the Trust & Safety critique showed the arm is the WEAKER control (it reads source; the
  leak is a runtime value) and that ~50 sites is the wrong count anyway (53 across 22 files).
  Took the choke point instead: the exception classes mask inside their own `toString()`.
  That also covers two paths no throw-site sweep reaches — an uncaught exception going
  straight to `recordError` from `main.dart`, and the web sink where Crashlytics is skipped.
  The arm is filed as BUT-1907 with the conditions it must meet.
- [discovery] BUT-1897: masking the whole joined string turned `PermissionDeniedException`
  into `Perm***` — the class name is 25 alphanumeric characters, the exact shape of a uid.
  Caught by the existing tests on the first run; the type label now sits outside the mask
  and a case pins it.
- [needs-human] BUT-1883: the ticket's premise is REFUTED, not stale. `closePoll` re-reads
  the single message on an uncapped path, and `_resolveWinner` returns null on a zero-vote
  poll — so the "wrong recipe in the week's plan" it specifies cannot happen. No guard was
  built. The two false comments that caused the ticket were corrected, the real (inverted)
  defect is BUT-1908, and the blocking gap the critique found is BUT-1909.
- [discovery] A `\b` written through a Python heredoc landed as a literal BACKSPACE byte in
  `log_sanitizer.dart` — the exact shape of the BUT-1901/1902 lesson. Caught by reading the
  bytes back, repaired with `chr(92)`, and the file is control-byte clean.



---

# PLAN 2026-08-17 — get the functions deploy through, then remove the dead functions

Approved by Malin in-session (AskUserQuestion, 2026-08-17): "Sätt tak på 10 instanser".
The cleanup half is her follow-up ask ("men kanske också radera gamla engångsgrejer när vi
ändå håller på?") and is scoped below with one question left to her.

## Background — what is actually broken

The `firestore:indexes` deploy succeeded earlier today (19/19 TTL policies ACTIVE, verified).
The `functions` deploy then failed on 53 of 71 functions. Every failure reported
`Container Healthcheck failed`, which reads like broken code and is not — the real line is:

    Quota exceeded for total allowable CPU per project per region.

Measured, not assumed:
- 71 Cloud Run services in europe-west1, every one at `cpu=1`.
- `maxInstances` is set **nowhere** in `functions/src` (grep: 0 hits), and
  `setGlobalOptions` sets only `region`. Unset means the platform default of 100.
- So the project reserves ~7100 vCPU of admission headroom before a single request arrives.
- Nothing was deleted or corrupted by the failed deploy. The three new BUT-1838 group
  callables DID get created and are ACTIVE (`createChatGroup`, `addChatGroupMembers`,
  `removeChatGroupMember`); every other function still runs its previous revision.
- `leaveGroupConversation` is still deployed. Firebase skipped the delete because the
  updates failed ("Deploys failed. Skipping deletes.").

Honest gap: the quota value gcloud reports for `CpuAllocPerProjectRegion` in europe-west1 is
20000, which does **not** obviously conflict with 7100. I could not reconcile the exact
accounting from the quota API, so the deploy itself is the test of the fix rather than a
calculation I can show. If step 1 does not clear it, the fallback is a quota increase
request, and I will say so rather than keep guessing.

## What the review changed (recorded here because two of my claims were wrong)

`cloud-functions-specialist` passed with 0 blocking, having dumped the compiled
`__endpoint` manifest rather than reasoning about the SDK. It corrected two things:

- **70 gen2 services, not 71.** `onUserDeleted` is a gen1 auth trigger — v2
  `setGlobalOptions` cannot configure it and it consumes no Cloud Run CPU. That also answers
  the open question below about its blank `state`: gen1 reports `status`, not `state`, so the
  blank is the API shape, not a failed deploy. The reservation is ~7000 vCPU, not ~7100.
- **"10 concurrent" was the wrong mental model in my own head.** `concurrency` is a separate
  option defaulting to 80 at cpu >= 1, so the real ceiling is ~800 in-flight requests per
  function. Verified there is no fan-out victim: scheduled sweeps get one invocation per tick,
  notification fan-out is in-process (`MAX_PER_RUN = 200` under one `Promise.all`), and the
  two ingredient triggers that could genuinely queue both carry `retry: true`, so throttled
  events are redelivered rather than dropped.

It also found the change was pinned by no test, which turned out to matter more than it
sounded — see below.

## Step 1 — cap the instances (unblocks the deploy)

1. `functions/src/index.ts`: `setGlobalOptions({ region: "europe-west1", maxInstances: 10 })`,
   with a comment stating the RULE (an unset ceiling reserves 100 per function and the wall
   only appears mid-deploy), not just the current numbers.
1b. `functions/src/__tests__/deploy-manifest.test.ts` (new) pins BOTH invariants against the
   compiled deploy manifest: every gen2 export in `europe-west1`, and every one carrying an
   instance ceiling. The region hazard was previously guarded by a comment in `index.ts` and
   nothing else, and a comment does not redden.
   **The first version of this suite contained a vacuous assertion and the mutation probe is
   the only thing that caught it.** `firebase-functions` does not leave an unset
   `maxInstances` as null — it stores a sentinel object whose `toJSON` renders as `null`, so
   `JSON.stringify` printed "null", `"maxInstances" in endpoint` was true, and `x == null` was
   FALSE. The presence check stayed green under a mutant that stripped the option from all 70
   functions. Now tested as `typeof x === "number"`. Do not "simplify" it back to a null check.
   Probed 2026-08-17: healthy 4/4; ceiling removed reddens the presence check naming all 70;
   region changed reddens the region check naming 64; `index.ts` restored byte-identical
   (md5 compared).
1c. `functions/src/ingredients/on-ingredient-soft-deleted.ts:40` said `setGlobalOptions` "sets
   the region and nothing else" — true when written, false as of this change, and it is the
   recorded BUT-1781 rationale for a local timeout. Rewritten to state the rule. Grepped the
   whole tree for the same phrasing: one occurrence, fixed.
   - Per-function options win over global ones, so any function that later needs more
     concurrency raises its own. None sets `maxInstances` today, so nothing is overridden.
   - Pre-launch, zero users: 10 is far above real demand and doubles as a cost ceiling
     (CLAUDE.md cost principles).
2. `npx tsc --noEmit` in `functions/`.
3. `cloud-functions-specialist` review (commit gate for `functions/src`).
4. Commit, push to main.
5. `firebase deploy --only functions --force --project butlery-app-1`.
   `--force` is required for two reasons, both verified as intended:
   - `onIngredientPropertiesChanged` now carries `retry: true`, which is deliberate and
     documented in its own source with an event-age guard bounding the retry window.
   - it auto-confirms deleting `leaveGroupConversation`, removed on purpose in BUT-1838 and
     replaced by the three group callables. Verified zero callers anywhere in the repo.
6. **Verify per-function `state` from the API, not from `functions:list` names** — a deploy
   that removes Cloud Run services can leave a replacement `FAILED` while the name still
   lists (repo lesson, 2026-08-03). Expect 71 ACTIVE and no `leaveGroupConversation`.
   Note `onUserDeleted` reports an empty `state`; confirm whether it is a 1st-gen function
   (which reports `status`, not `state`) rather than treating the blank as a failure.

## Step 2 — CORRECTED: none of the five is safe to delete, and my evidence was bad

I told Malin these five were "one-shot migrations, safe to remove" on the strength of a
whole-repo grep showing zero callers. She approved on that basis. **The premise was wrong**,
and the error is the one the digest already names: "unreferenced" proven against code cannot
see a function a HUMAN invokes. An admin callable has zero callers BY DESIGN.

Reading what each one actually is, rather than counting references to it:

- **`bulkMarkForRetagging` / `getRetagStatus`** — not a migration at all. Its own header calls
  it "the operator escape hatch that DRAINS the `stale-ingredient` / `stale-properties`
  markers the ingredient cascades write". That is the manual recovery path for exactly the
  failure `concurrency: 1` was added tonight to prevent, and `on-ingredient-soft-deleted.ts:63`
  names it as such. Deleting it would remove the repair tool in the same change that hardened
  the thing it repairs.
- **`seedSiteConfigs` / `getSiteConfigStats`** — an ongoing ops tool, not a one-shot. It seeds
  the CSS selectors that let a new Swedish recipe site be supported WITHOUT an app release.
- **`backfillCanonicalRatings`** — carries a hard gate refusing to run until
  `enable_pooled_ratings` is on in prod and the privacy-policy pooling disclosure has shipped.
  It has never run, so it is PENDING, not spent.
- **`backfillRecipeCommentsDenorm`** and **`backfillSharedListContributors`** — the only two
  that really are one-shot, and both carry an explicit lifecycle contract naming the two
  conditions for their own deletion: a successful invocation returning `hasMore: false`, then
  a 30-day soak. Neither has been invoked (the only log lines are today's deploy). By their own
  written rule they must NOT be deleted yet.

Two of the five also share a module with a function I had put in the KEEP column, so "delete
five files" was never the shape of the change either.

**Recommendation: delete nothing.** The reason to delete was quota pressure, and that is gone
— the reservation went 7100 -> 700 vCPU, and these five cost 50 of it. Deleting now trades a
real recovery path and a pending migration for no benefit.

The five were removed from PRODUCTION earlier tonight to break the quota deadlock, and the
deploy has since recreated all of them. Production and source agree again.

## Open questions

Blast-radius ranked. Only one, and it is deferrable without blocking step 1:

1. **Does 2b go or stay?** Highest blast radius of the two, because it deletes working
   admin tooling rather than spent migrations. Asked after step 1 ships; default is KEEP.

No architecture-changing unknowns. Assumptions stated: (a) `maxInstances: 10` is above any
real pre-launch demand — the app has no users; (b) the failed deploy left production
consistent, which was verified by reading every function's state, not inferred.

## Step 1½ — a red GDPR test, found on the way, fixed here

`test:request-account-deletion` was RED on main before this change (it came in with
`a329de0f5`, today's salvage commit). It is not caused by this work and it is not a
production defect, but it had to be understood before deploying, because the cascade code it
covers is on main and NOT yet in production — the deploy is what would make it live.

Root cause: the suite's local fake Firestore had no `limit()` on its query object, so the
`chat_groups` and `messages` steps threw `where(...).limit is not a function`. The production
code is correct; real Firestore has `.limit`. But the consequence was real — **those two GDPR
erasure steps were being exercised by nothing in that suite**, and the failure was reported as
"step failed", which reads like a broken cascade.

Fixed by giving the fake a `limit()` (the same precedent the file's own `listDocuments` note
records), and by making the assertion print `result.errors` instead of only the collection
names — the old message sent the reader to the whole cascade rather than to the line that
threw. Suite is 4/4 and the full CF lane is 88/88.

## Acceptance criteria

- [x] `npx tsc --noEmit` clean.
- [x] Full CF unit lane green: **88/88 suites (346s)**, up from 87/88 with
      `test:request-account-deletion` red.
- [x] The new deploy-manifest suite is non-vacuous — mutation-probed both ways, `index.ts`
      restored byte-identical (md5 compared).
- [ ] `cloud-functions-specialist` opened the FINAL bytes and passed (the first review graded
      an earlier version; every later edit un-proves it).
- [ ] `firebase deploy --only functions` exits 0 with zero failed functions.
- [ ] Per-function `state` read back from the API: every function ACTIVE, count matches
      source exports, `leaveGroupConversation` gone.
- [x] `onUserDeleted`'s blank state explained: it is gen1, which reports `status` rather than
      `state`. Not a failed deploy.
- [ ] BUT-1792 closed (its two remaining criteria were the TTL deploy, now done).
