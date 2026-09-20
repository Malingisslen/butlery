# Sprint 2026-09-20 runda 7 (sprint-execute, /loop, unattended)

Round 6's three loose ends, in the code that round already opened. Step-0 measurements,
taken against `main` before planning:

- BUT-2130: `.github/workflows/architecture-validation.yml:154` and
  `build-validation.yml:63` each name `test/architecture/architecture_test.dart` by hand.
  `ls test/architecture/` shows four files; `flutter test test/architecture/` runs 41 tests,
  all green locally. No other lane reaches that directory.
- BUT-2132: `applyGeneratedMenu` passes a fixed `errorPrefix` to `_executeWrite`, which sets
  it on ANY throw in the closure — including a synchronous throw from
  `distributeFromGeneratedMenu` before any publish, and a post-publish refusal whose
  rollback was skipped by `identical(_plan, result.plan)`.
- BUT-2129: `_generateMenu` still reads `applyGeneratedMenu`'s return value to decide the
  toast, so offline it never appears.
- QA's two premises, checked: `stream_subscription_disposal_test.dart` carries
  `@Tags(['architecture'])` and `dart_test.yaml` does not declare that tag; `skip:` IS
  declared there with `skip: true`.

Router on the batch's file union: `{"tier": "single"}` — one blind critique, convened
before the build (QA / Test Engineer, the role the router matched on the workflow files,
which decide what protects everything else). Its must-haves are folded in below and marked
**[panel]**. It also set the ORDER, because widening a lane that has never run on ubuntu
before the guard that depends on it would make that guard decorative.

- [x] BUT-2130 part 1 [Tier A] build — one lane, plus the two things that keep a directory
      from hiding a file.
  - AC1 (diff): `architecture-validation.yml` names the DIRECTORY, not one file.
  - AC2 (diff) **[panel]**: a manifest assertion in `architecture_test.dart` enumerates
    `test/architecture/` recursively and fails on a `.dart` file the runner will not
    collect — the loud failure an explicit path gave and a glob does not. It tests the
    FILENAME, which is a proxy: a `foo_test.dart` whose `main()` registers nothing still
    passes, and the guard's own comment says so.
  - AC3 (diff) **[panel]**: `dart_test.yaml` declares the `architecture` tag with a
    description and no `skip` key.
  - AC4 (run): the whole directory is green locally before the lane is widened.
- [x] BUT-2132 [Tier A] build — the message stops asserting an undo that may not have run.
  - AC1 (diff): the prefix passed to `_executeWrite` is the always-true
    `Veckan kunde inte sparas`.
  - AC2 (run) **[panel]**: three tests, one per path, each asserting the exact prefix — a
    pre-publish sync throw, a post-publish refusal with `_plan` unchanged, and a
    post-publish refusal with `_plan` replaced mid-flight. All three ARE drivable.
- [x] BUT-2129 [Tier A] build — the generate path announces at publish too.
  - AC1 (diff) **[panel]**: `_generateMenu` no longer branches on `applyGeneratedMenu`'s
    return value for the toast; proven by grep.
  - AC2 (diff) **[panel]**: `placement_footer_wiring_test.dart` pins the `_generateMenu`
    callsite the way it pins the footer's — no test mounts `VeckomenyView`, so a source
    lint is what can guard it.
  - AC3 (run): the existing publish-time case still proves `onPublished` fires with the
    right count while the write never acks.
- [x] BUT-2130 part 2 [Tier A] build — `build-validation.yml` stays NARROW, on purpose.
  The reviewer's ruling, taken: no in-suite guard can detect its own deletion, because a
  deleted test file simply stops running. An anchor inside `test/architecture/` is
  removable by an edit confined to `test/architecture/`. The explicit path in
  `build-validation.yml` is the anchor outside that set; the workflow comment carries the
  grep.
  - AC1 (diff): the narrow path carries a comment saying it is the deliberate anchor and
    why, so the next reader does not "finish the job" by widening it.
  - AC2 (diff): nothing in the plan or the code claims the class is closed. The residual
    that stands: a deletion of `architecture_test.dart` itself is caught by this lane, and
    a deletion of any OTHER file in the directory is still silent.

## Needs you (Tier D)
- none this run, unless BUT-2130 part 2's lane has not reported by close-out.

## Deviation log

- [discovery] the code-reviewer ended five consecutive reports on the verdict line and none
  was captured; a message that was only the line recorded on the second. I first wrote that
  the row is written only when the line is the ENTIRE final message, then opened the
  recorder: `workflow-guards/scripts/review-verdict.mjs` reads `last_assistant_message` and
  takes the LAST `REVIEW-VERDICT:` match anywhere in that field, so that is not what
  decides it. The measured practice — ask for the verdict as its own message — stands; the
  explanation was inference and is struck, here and in this morning's lesson.
- [discovery] claim-lint rejected "the only anchor" in the workflow comment. The claim is
  derivable, so remedy 2 applied: the deriving grep ships beside it
  (`git grep -n "architecture_test.dart" -- .github lefthook.yml` returns that line alone).
  The same universals in `tasks/todo.md` were struck instead, since scratch carries no
  command.
- [deviation] BUT-2130 part 2 inverted mid-round — see the entry below it. The reviewer's
  four-case walk killed the mutual-guard alternative I proposed: deleting the checker
  leaves no stray, so the pair moves the hole one file over.
- [discovery] a Low left unfixed on the reviewer's own costing: striking the framing
  sentence in `architecture_test.dart` moved the antecedent of the "It" two sentences
  below, so one binding of that pronoun reads false. Ambiguous rather than wrong, no
  reader action removes a guard, and the group name two lines down settles it — not worth
  a seven-file re-read.

- [deviation] BUT-2130 part 2 inverted during the round. The plan was to widen the second
  lane after the first reported green on ubuntu; the reviewer showed that doing so removes
  the last anchor outside the guarded directory, and that the mutual-guard alternative I
  proposed leaves the same hole one file over — deleting the checker reddens nothing,
  because a deleted file leaves no stray. The narrow path is now the deliberate anchor,
  and the `run` criterion that waited on the ubuntu lane is gone with it.

---

# Sprint 2026-09-20 runda 6 (sprint-execute, /loop, unattended)

Step-0 measurements, taken against `main` before planning:

- BUT-2124: `_onPlaceAutomatically` (`lib/views/veckomeny_view.dart`) awaits the whole of
  `applyGeneratedMenu` before `_setViewMode`. Confirmed present on `main`.
- BUT-2125: `assignFromOverflow` restores on `identical(_overflow, pruned)`. Confirmed.
- BUT-2126: `_publishThenSave` restores on `identical(_plan, updated)`. Confirmed. The
  `isPlacing:` argument in the view has a `false` default on
  `MenuPlacementChoiceFooter`, so deleting it leaves every suite green.
- BUT-2117: the clause the ticket names is false — `_withoutBlockedBallots` has its own
  catch (`lib/services/messaging_service.dart`), which returns the author-filtered list.
- BUT-2128: the parity block still sits in `enforce-group-minor-membership.test.ts`;
  `run-ci-unit-tests.js` excludes only `test:rules*` and `test:integration:*`, so it runs.

Router on the batch's file union: `{"tier": "single"}` — one blind critique, convened
before the build (Product Manager, the role the router matched on the viewmodel). Its
must-haves are folded into the criteria below and marked **[panel]**.

- [x] BUT-2117 [Tier A] build — strike the false clause in the BUT-1909 fixture comment.
  - AC1 (diff): the clause naming `_filterBlocked`'s fail-open catch is gone, nothing added.
  - AC2 (diff): the surviving sentence read alone is true.
- [x] BUT-2128 [Tier A] build — move the cross-language parity block to its own suite.
  - AC1 (diff): the block lives in `functions/src/__tests__/log-safe-conversation-id.test.ts`
    with the pinned literal unchanged.
  - AC2 (run+diff): a `test:log-safe-conversation-id` script exists and
    `check-test-registration.js` passes.
  - AC3 (run): `enforce-group-minor-membership.test.ts` still green and its header
    describes only what is left in it.
  - AC4 (diff): the Dart half names the new TS file.
- [x] BUT-2124 [Tier B] build-review — switch to the calendar at PUBLISH, not at the ack.
  - AC1 (diff): `applyGeneratedMenu` takes an `onPublished` callback fired with the placed
    count immediately after the publish, before the save is awaited.
  - AC2 (diff): the view switches mode and toasts from that callback.
  - AC3 (diff) **[panel]**: on a refusal the success toast — which carries a tappable
    ÄNDRA — is hidden before the error is shown, so neither it nor its action survives the
    rollback.
  - AC4 (diff) **[panel]**: `placed == 0` still shows no toast.
  - AC5 (diff) **[panel]**: the rollback message no longer says the distribution failed,
    because the user watched it happen. **Superseded by Malin 2026-09-20**: she chose one
    short message on every path, so the shipped string is `Veckan kunde inte sparas`.
- [x] BUT-2125 [Tier B] build-review — an overlapping drag no longer loses the first recipe.
  - AC1 (diff): the restore tests MEMBERSHIP of the current tray, not identity of the list.
  - AC2 (diff) **[panel]**: it also refuses when a later distribution PLACED the recipe —
    the test is against `plan.entries[].recipeId`.
  - AC3 (diff) **[panel]**: it refuses when the user has changed week, and the old index is
    clamped.
  - AC4 (run): a test drives two overlapping drags and the refused one gets its chip back.
  - **Detail for Malin**: the ticket called this a product choice. The build keeps the
    recipe rather than the simpler "don't touch a tray someone else changed".
- [x] BUT-2126 [Tier A] build — the negative branch of both restore conditions.
  - AC1 (run): a case per condition where a later change replaces the plan / the tray while
    a refusal is in flight; the old state must not come back.
  - AC2 (run): PARTIAL. The `isPlacing:` wiring in `veckomeny_view.dart` has a killer —
    `test/architecture/placement_footer_wiring_test.dart`, mutation-probed 2026-09-20:
    deleting the argument turns it red, and the restore was md5-verified. But no CI lane
    runs `test/architecture/` except the single named `architecture_test.dart`, so the
    killer only fires locally. Pre-existing — two siblings are equally unrun — and filed
    as BUT-2130. BUT-2126 parks In Review for this reason.

## Needs you (Tier D)
- none this run.

## Deviation log

- [discovery] BUT-2125: the tray is NOT cleared when the week changes, so the
  "another week" case asserts the refused recipe is absent rather than an empty tray.
- [discovery] BUT-2125: of the three new cases, only two redden against the old identity
  guard; the third is the regression control, and the test says so.
- [deviation] BUT-2126 asked for a test driving the footer through a real
  `WeeklyMenuPlanViewModel`. No test mounts `VeckomenyView` — it reaches a dozen services
  through `ServiceLocator` — so the wiring is pinned by a source lint instead, with its
  residual named in the file.
- [discovery] outcome verifier: three findings, all fixed in-run. The `errorPrefix`
  comment claimed the week is always on screen before the message can fire — a synchronous
  throw from `distributeFromGeneratedMenu` precedes the publish, so the sentence is now
  scoped to the SAVE path. The widened restore would have ADDED a chip that was never in
  the tray when `index < 0`; that is now refused. And the BUT-2117 strike left "the catch"
  bound to the wrong antecedent, so that sentence was deleted too.
- [discovery] commit gate round 1 on the menu batch: code-reviewer failed it on two
  written claims, both mine. A comment said "Three things still have to hold" above four
  bullets — the numeral is struck, not recounted, and the exhaustiveness clause beside it
  went with it, because it did not cover a tray `adoptPlan`/`clearWeek` had emptied. And
  the source lint's residual said a `watch`-to-`read` swap "would pass here", which the
  regex makes false; struck.
- [discovery] same round: a throwing `onPublished` would have skipped the save entirely and
  then reported the week as rolled back. The dispatch is wrapped so the save always issues.
- [discovery] testing-specialist failed it on an asymmetry inside this change: BUT-2124's
  view wiring is the same deletable-green shape the `isPlacing` lint was written for, and
  it got no lint. Two more cases added to that file, plus fixtures for the two new
  `assignFromOverflow` conjuncts that had no kill set. Probed 2026-09-20 — deleting the
  `index < 0` guard, the duplicate-chip guard or `onPublished: onPublished` each turns one
  red; every restore hash-verified.
- [discovery] commit gate round 2: the try/catch added in round 1 had an EMPTY kill set —
  deleting it left the whole suite green. A case now passes a throwing callback and asserts
  the save still issued; probed 2026-09-20, the mutant reddens it. The guard arrived from a
  reviewer, which is exactly the shape that feels pre-vetted and is not.
- [deviation] BUT-2124: `_generateMenu`'s own call to `_applyGeneratedToCalendar` still
  toasts after the ack, so offline it is silent in the same way. Left alone rather than
  widened mid-run; filed as a follow-up.

---

# Sprint 2026-09-20 runda 5 (sprint-execute, /loop, unattended)

Two cleanup tickets, both mostly deletions. Step-0 measurements, done before planning
rather than taken from the tickets:

- BUT-1976 says "~15 files"; `grep -rln "unhit lines\|Targets ~" test` says **13**. The
  ticket predicted this and told me to recount — that is what this line records.
- BUT-1899's `logSafeConversationId` now has THREE importing modules, not the two the
  ticket names: `enforce-group-minor-membership.ts` (where it lives),
  `sync-conversation-last-message.ts` and `account-deletion-cascade.ts`.
- The `direct_` prefix is minted in `createDirectConversation` and consumed by
  `LogSanitizer.maskConversationId` (Dart) and `logSafeConversationId` (TS).
- The messaging group-detail view already declares
  `ConversationGroupDetailView`; four files import it.

- [x] BUT-1976 [Tier A] build — strike the coverage numbers from the 13 file headers.
  - AC1 (diff): `grep -rn "unhit lines\|Targets ~" test` returns nothing.
  - AC2 (diff): deletions only — no recounted number, no replacement sentence, and each
    surviving header read alone still says what the file is.
- [x] BUT-1899 [Tier A] build — four cleanups around the log masking.
  - AC1 (diff): the weaker duplicate `test/unit/utils/log_sanitizer_test.dart` is deleted,
    and nothing it covered is lost from the sibling under `test/unit/core/utils/`.
  - AC2 (diff): `logSafeConversationId` lives in `functions/src/shared/` beside
    `hash-uid.ts`; all three importers updated; the CF suites stay green.
  - AC3 (diff): a test binds the `direct_` prefix constant to at least one masker, so
    renaming the id scheme cannot turn every masker into a no-op silently. This is the one
    part with a silent failure mode; the other three are tidying.
  - AC4 (diff): `lib/views/messaging/group_detail_view.dart` is renamed to
    `conversation_group_detail_view.dart` (the class is already
    `ConversationGroupDetailView`), with its four importers updated.

## Needs you (Tier D)
- none this run.

## Deviation log

- [deviation] BUT-1899: the plan counted THREE importers of `logSafeConversationId`;
  the CF unit test imports it by path as a fourth. All four repointed.
- [discovery] BUT-1899: moving the helper falsified two sentences written elsewhere —
  the Dart mirror docstring in `log_sanitizer.dart` named the old file, and the CF test
  header claimed its cases sit "with the code they exercise".
- [discovery] BUT-1899: the rename needed a SIXTH reference nobody imports —
  the hardcoded path in `docs/onboarding/workflow-map.html`. Linter re-run clean.
