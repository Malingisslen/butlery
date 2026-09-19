# testing-specialist — chapter: widgets-ui

- **A busy-state widget test cannot use `pumpAndSettle`** — an indeterminate spinner animates
  forever, so settling times out and the timeout reads like a broken fixture. Single `pump()`.
  A spinner in a BUTTON's `icon:` slot IS reachable by semantics label; whether the EXACT form
  works depends on whether that host merges the label with its own text. An exact
  `bySemanticsLabel` returning 0 therefore measures the MERGE, not an absent live region — do
  not conclude the branch is unobservable and fall back to `find.byType`. Prefer the RegExp
  form, which held on both hosts, and scope the finder to the control: an unscoped one also
  matches unstubbed fixture text starting with the same word. See the 2026-09-07 archive
  entries (BUT friend-requests spinner) for the per-host figures and the superseded wordings.
- **An UNSCOPED `find.byType(<SpinnerClass>)` count on a busy screen is the never-TWO pin, and
  reads as incidental** — `findsOneWidget` reddens when a second surface gains the same busy
  ternary. Grade such a count before writing a dedicated "no second spinner" test; it is usually
  already the pin. Note the class is platform-branched (`AdaptiveActivityIndicator` draws
  Cupertino on an iOS host), so the count holds on the CI hosts and not by construction.
  **SCOPING that finder DESTROYS the pin while the count still reads as one**: once it becomes
  `find.descendant(of: byType(TheOneSignalWidget), matching: ...)` it can never exceed 1 — the
  widget is mounted once and yields one indicator — so `findsOneWidget` vs `findsWidgets`
  distinguishes nothing and a rival signal elsewhere is invisible. Settle it ANALYTICALLY from
  the finder's range, not by a probe. The carrier is a round that MOVES a signal and rewrites the
  count's rationale comment to match the new finder, dropping the old `(measured)`: the pin is
  lost and the comment claims it is kept. Keep the never-TWO assertion unscoped and SEPARATE from
  the "the one signal is present" assertion — they need different finders (BUT-2041, 2026-09-07).
- **A widget test driving a real screen can be blocked by an unrelated RENDER assertion in a
  sibling branch of that same screen** — satisfy the tested condition through a branch that does
  not reach it, then FILE the render defect. Weakening a fixture to dodge a crash is legitimate
  only when the dodged branch is provably not what the test claims to prove (BUT-1982).
  **At N=3 in a VIEW handler the suite drives the FIRST sibling only, and the ARB is the cheap
  tell**: each copy-paste sibling owns its own new l10n key, so grep the NEW KEYS across `test/` —
  a key typed by no test names the untested twin, and a verb repoint between siblings then
  survives the whole suite (batch friend requests, 2026-09-06).
- **A path ending in `Navigator.pop()` of the ROOT route also destroys the lane for the
  feedback shown JUST BEFORE the pop** — the messenger loses the popped `Scaffold`, so a
  `find.text` on that snackbar returns 0 widgets while a SIBLING test in the same file reads
  a `SnackBar` happily (measured, BUT-1951). So "a sibling reads one, therefore the lane
  exists" is not transitive across tests, and such an item must not be split into "the pop is
  unpinned, the snackbar is closeable": both halves need a route-pushed harness. The
  consequence for grading is the useful half — an assertion sitting after such a pop that
  reads ANY snackbar text is a CONTROL by construction, not a discriminator.

- **A SHARED user-facing message CONSTANT is the same shape inside ONE language** — every
  consumer writes `find.text(kMessage)`, so the SYMBOL is pinned at N call sites and the STRING at
  none. Grep the literal across `test/`; zero hits IS the finding (BUT-1962). **The worst form has
  NO constant at all**: an action string typed twice (emitting `PopupMenuItem(value:)` and
  receiving `switch` arm) with a `default:` that only logs — a typo degrades to a dead menu entry,
  nothing red. The CLOSING shape is one widget test pumping the real app bar with `onMenuAction`
  wired to the real handler and tapping the visible label, so both copies die to one mutant. Scope
  that follow-up to the whole WIRING (the emitting side also carries a VISIBILITY filter, the
  receiving arm an ARGUMENT decision) (BUT-1971). **The same string emitted from SEVERAL ARMS of
  ONE method is the third form**: a `find.text` pin cannot say which arm fired, so a mutant that
  drops through to a sibling early-return stays green. The discriminator is a SECOND observable on
  the same node — the snackbar's theme-resolved colour (`showError` paints `cs.secondary`, a
  hand-rolled bar `cs.error`) — which makes such a colour assertion load-bearing rather than
  cosmetic, and its comment must say what it READS, never why it exists (BUT-1951).
  **The same colour is the ONLY discriminator when a call is REROUTED through the shared
  helper**: the string is unchanged, so every `find.text` pin stays green under a revert, and
  the change is real (colour, duration, action button). When one copy of the message already
  carries a colour pin, that pin covers the OTHER copy — grade per CALL SITE, and add the
  assertion to whichever existing test already reaches the rerouted arm (BUT-2025).
  **The mirror is the danger: harmonising the colour HOLLOWS every existing test using it as
  an ARM discriminator, silently and while green.** Sweep `backgroundColor` across the suites
  reaching any arm of the rerouted method. Its replacement must be an observable the shared
  helper cannot satisfy — a COUNTER on the collaborator seam, incremented ABOVE the success
  branch — never a state field, because a fake recording only SUCCESSES is empty both when
  the action was refused and when it was never reached (BUT-2025).
- **A GENERATED `app_localizations*.dart` carries no logic — its only reviewable question is which
  new ARB strings a suite types VERBATIM.** Read the answer as a table. The unpinned ones cluster:
  arms of an enum→l10n `switch` whose ENUM is asserted at VM level, tooltips, sheet titles, and
  snackbar bodies whose test taps a DIFFERENT literal in the same widget. **The killing mutant is
  ONE-DIRECTIONAL, never a swap** — swapping two arms reddens the pinned sibling, so write the
  finding as "repoint arm X" or the fix round proves the wrong mutant. Rewriting the generated file
  is never the repair. When no UI path can reach the state that renders the arm, drive the VM
  DIRECTLY under a real pump — that is the pin, not a shortcut (BUT-1971).
- **A refusal that REPLACES a whole body ships an ESCAPE HATCH nobody asserts** — "message shown"
  + "the thing it replaced is gone" are entailed by the same branch; the third observable
  (`StateWidget.error(onAction:)`) is untouched. Pin first-read-fails/second-answers plus a CALL
  COUNT, which also kills a no-op callback (BUT-1962).
- A COPY test stopping at the confirmation dialog pins the words, not the branch.
  `MaterialApp(routes:{...})` never reads `settings.arguments` — push through `onGenerateRoute`.
- Two l10n keys with the SAME string make `find.text` unfalsifiable — grep the ARB for EXACT value
  equality, since `find.text` is whole-`Text.data` equality, never substring (BUT-1831). **A NEW
  arm's string merely SHARING the discriminating SUBSTRING of a pinned sibling hollows every
  `contains`/`textContaining` pin on that sibling, with nothing red and in files the round never
  opened** — when a round adds an enum→l10n arm, run the NEW string through every existing matcher
  for its siblings, and expect the sibling's test NAME to carry a stale count too (BUT-1922).
- **A dropdown widened to keep an off-vocabulary value needs FOUR fixtures**: off-list-untouched;
  pick-something-then-pick-back (only killer of keying the list off current vs stored selection);
  empty-stored; literal vocabulary pin (BUT-1858).
- **A `StyledInput` with `keyboardType: TextInputType.number` silently gets
  `FilteringTextInputFormatter.digitsOnly`**, so any `replaceAll(',', '.')` decimal parse below it
  is DEAD and "1,5" reaches the model as 15. A suite that never types a DECIMAL cannot see it.
  **RUN the OLD formatter's regex before choosing the fixture that proves its replacement** —
  `allow(RegExp(r'^\d*\.?\d*'))` TRUNCATES at the comma while `digitsOnly` CONCATENATES, and the two
  failures need OPPOSITE fixtures (truncation lands INSIDE any range the true value satisfies).
  Assert the parsed VALUE, or bound BETWEEN the truncated prefix and the true value (BUT-1920).
- `SemanticsService.announce` in a fire-and-forget handler is skippable UNTIL the view gains a DI
  seam — dated, not permanent. **A comment-only CORRECTION owes a grep of the CORRECTED SENTENCE
  across `test/`**: a covering suite's group header quotes production prose, so the false claim has a
  third copy there (BUT-1883). **A premise ANOTHER gate measured false mid-round gets the same
  concept sweep, and it is the one that gets skipped** — the fix lands on the copy that gate
  quoted while paraphrases survive in sibling comments and in a TEST NAME the same round wrote,
  leaving one file carrying both verdicts (BUT-1922: "scope pop"/"Reachable"/"signing out"
  against an APP-scope singleton `popUserScope()` never disposes).
- **A SNACKBAR SEVERITY swap owes no test AT THE CALL SITE** — every discriminator belongs to
  `SnackBarUtils`, not the screen, and a call-site pin reddens on edits to a shared helper the screen
  does not own. If severity is a contract it earns ONE test in `snackbar_utils_test.dart`. **The
  narrower surviving rule (BUT-1971, same ticket): what is banned is pinning a THEME TOKEN a screen
  does not own; an ICON IDENTITY is stable and does kill the swap, so that assertion stands.**
- **A blanket `FlutterError.onError = (_) {}` near `matchesGoldenFile` makes every golden a PERMANENT
  PASS** — the comparator reports by THROWING, `runAsync` catches it and returns `null`, and `null`
  is the matcher's word for "matched". The on-disk symptom is a golden whose DIMENSIONS disagree with
  the helper's pinned surface. Filter on `details.library == 'image resource service'` instead.
  Pinning the FILTER is not pinning the CALL SITE — the durable guard is a source lint in
  `test/architecture/`, which must strip comments first. **Re-check every claim written while a check
  was silenced** (BUT-1931).
- **A control that DISABLES ITSELF after one tap makes every later negative-tap assertion in the same
  test unfailable** — order the negative tap FIRST and assert zero (BUT-1904).
- **ONE parameter feeding TWO axes is pinned on the easy axis only** (a grid's `spacing` used between
  rows AND columns) — enumerate the axes the parameter's own doc claims, one assertion each
  (BUT-1911).
- **A guard wrapping [spacer + a child that self-collapses to `SizedBox.shrink()`] is pinned ONLY by
  `find.byType(<ChildWidget>)`** — the child-CONTENT assertion is vacuous, because deleting the guard
  rebuilds the child, which draws nothing and leaves the dead spacer (BUT-1869).
- **A "resolves through the l10n key, not a literal" test whose BOTH sides resolve the SAME locale
  cannot kill a same-text revert** — pin routing by switching the accessor
  (`AppLocale.initialize(const Locale('en'))`, restored in `addTearDown`) and asserting the OTHER
  locale's text (BUT-1984).
- **A "renders identically for a foreign/other-user row" case is vacuous when its fixture omits the
  callback the real call site passes UNCONDITIONALLY** — build the "should not occur" fixture with
  the PRODUCTION wiring, or the identity claim is about the harness (BUT-1904).
- **An `inputFormatters:` line is mutation-dead until one fixture types a string the formatter CHANGES
  and the test reads the RENDERED text** — `initialValue` never runs formatters. On an
  `initialValue`-seeded `TextFormField`, `.controller` is NULL: read the descendant `EditableText`'s
  controller (BUT-1910).
**Semantics / a11y vacuity (all measured; `.claude/rules/ui-conventions.md` rule 5 was the origin of
the wrong belief and has been corrected in place):**
- **`Semantics(label:)` does NOT suppress a descendant `Text` — the two labels CONCATENATE into ONE
  node's label, parent first, `\n`-joined.** Three consequences: `find.bySemanticsLabel(exactString)`
  returns 0 for THAT reason (the RegExp form finds it); "this label is the ONLY thing a screen reader
  hears" is false, so a label restating the visible text ships a STUTTER; and the widget-property
  workaround the 0-hit provokes is strictly weaker (it cannot see `container`, `button`, the RECT or
  the merge). **Assert `tester.getSemantics(<scoped finder>)` instead.** The correct label for a
  tappable row naming its own content is the ACTION ALONE. **Assert the stutter by counting the CHILD
  SENTENCE inside `node.label`** (`'<row text>'.allMatches(node.label).length == 1`), never the
  label's own words — a word-count reads a restating label as "more words" and stays green
  (BUT-1904/1953/1971).
- **`Semantics(label:, button:)` at `container: false` gets NO node** — the config is absorbed by the
  nearest node-forming ancestor (usually `RenderView`), so the label lands on a screen-sized node that
  owns every other control and takes their taps. `find.bySemanticsLabel` and `matchesSemantics` PASS
  under that mutant; only the node's RECT and its non-adoption of a neighbouring labelled control
  discriminate, and only in a harness mirroring the REAL mount point. **An assertion green under the
  mutant BY CONSTRUCTION is ZERO evidence about the harness, both directions** — a probe spec must say
  which way each observation cuts. **`container` is NOT what a rect assertion discriminates once the
  child forms its own node** (a `GestureDetector` with `onTap` does); what it DOES kill is HOISTING
  the `Semantics` above a wider ancestor. Say which of the two a rect pin covers (BUT-1837).
- **The ROLE carrier is a fixture builder that hardcodes the PERMITTED role** — a widget-test builder
  pinned to `edit` cannot reach the viewer state, so every `if (vm.canEdit)` affordance guard has zero
  widget coverage while the suite reads complete. A VM-level refusal test does NOT substitute: it
  proves the DATA is safe and says nothing about offering a control that can only fail. Parameterise
  the widget fixture by role, and diff the two builders' SIGNATURES when a unit suite and a widget
  suite share a subject (BUT-1971).
### Multi-select / bulk-action wiring
- VM tests + card tests can pass while the GLUE (snapshot/order/callback) is untested at widget level.
  Selection-guard tests need the owner's OWN tile, not all-strangers.
- Clear-on-cancel: assert the count returns to the ORIGINAL, not zero. Copy-paste id-field mismatches
  are invisible unless a fixture makes the fields DIFFER.
- Async error stubs: `thenAnswer((_) => Future<T>.error(...))` with production's `T` — never
  `thenThrow`, and never `(_) async => throw`, which infers `Future<Never>`: a `.catchError((_)
  => [])` swallow in production then throws a type error instead of swallowing, so that
  regression stays green (measured, BUT-2076).

- An optional nullable callback seam is invisible when every harness omits it — grep the seam's name
  across `test/`; zero hits IS the finding. **Hits are not the answer either: split them by LAYER** —
  all hits inside the widget's own suite means the view that WIRES it is unpinned, and deleting the
  production lines that pass it leaves every suite green with the feature absent from the app. A
  callback seam owes one test at the CALL SITE'S layer (BUT-1904).
- A `didChangeDependencies` retry on a widget that renders `SizedBox.shrink()` on failure is DEAD —
  the early return happens before any `Theme.of`, so only a REMOUNT recovers.

- **An overflow probe MUST mount `AppTheme.lightTheme`** — the bare `MaterialApp`'s smaller default
  typography can hide a real overflow. Pin with SYNTHETIC tall content, never real ARB copy.
  `expect(takeException(), isNull)` is ALSO satisfied by a tile that rendered nothing, so co-assert the
  content under test is present — **and that co-assert must reach the DIMENSION the geometry depends
  on, not the container type** (`find.byType(<Row>)` is satisfied by a one-item row; assert the CHILD
  COUNT). A ladder that SKIPS cases per fixture is honest only if the skipped ones are MEASURED;
  register them as NAMED `skip:` (the runner prints the name every run), never a `continue`. Two
  residuals survive: the co-assert closes only "the ADDED content vanished", and a named skip goes
  stale GREEN the day the residual is fixed (BUT-1895/1911).
- **A SCROLLABLE ancestor makes the whole overflow class structurally unfailable** — inside a
  `SingleChildScrollView` the child gets unbounded height, so no content can overflow and
  `takeException(), isNull` is green at any size. It still kills a fixed-slice mutant, so keep the
  tests — but a group NAMED "the week fits" then asserts something nothing measures. Read
  `ScrollableState.position.maxScrollExtent` before writing "fits" (a `> 0` IS the finding), and
  strike the claim rather than re-scope it (BUT-1971).
- A page-size guard is only testable on a TALL surface (`tester.view.physicalSize = Size(800,14000)`,
  dpr 1.0) — a short surface auto-scrolls and hides item 0.
- A semantics assertion must be bracketed with `ensureSemantics()`/`handle.dispose()`; on a tooltip'd
  button match with `RegExp`, for the concatenation reason in the Vacuity section.
