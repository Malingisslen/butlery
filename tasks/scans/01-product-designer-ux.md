# Role #1 — Product Designer / UX — scan findings

Scope: docs/design/**, lib/theme/**, lib/widgets/common/state/**, lib/widgets/common/state_widget.dart, lib/widgets/styled/**

Note on already-known watch-items (NOT re-filed): the dossier already tracks the 389
`BorderRadius.circular()` usages, the `loading_states.dart` skeleton-card radius wraps, and
the `styled_card.dart` image() radius — all resolve to `0.0` via the documented constants in
`app_dimensions.dart` (lines 89-112), so they are cosmetically inert and decided. Skipped.

---

## PASS 1 — primary domain scan

### Localize the hardcoded Swedish fallback titles in the shared state facade
- type: bug  area: settings (cross-cutting / all screens)  priority: High
- pass: 1
- finding: `lib/widgets/common/state/message_states.dart:47` defaults the error title to the
  literal `'Ett fel uppstod'` and `:110` defaults the success title to `'Klart!'`. These are
  the fallback strings rendered whenever a caller invokes `StateWidget.error(...)` /
  `StateWidget.success(...)` without an explicit `title:` — which is the common case (the
  factory only passes `message`, never `title`; see state_widget.dart:179-204).
- why: This is the single shared state facade every screen routes its error/success states
  through. An English-locale user sees a Swedish error/success heading on essentially every
  error and success screen. Localization keys already exist — `commonErrorOccurred`
  ("Ett fel uppstod"), `errorGeneric`, and `commonDone` ("Klar") are all in the ARBs — so the
  hardcoded literals are pure regression, not a missing-translation gap. Distinct from the
  closed hardcoded-string tickets (BUT-609/615/1381), which targeted other call-sites.
- fix: Replace the two literals with `context.l10n.commonErrorOccurred` and a localized
  "done"/"klart" key (add `stateSuccessDefault` to both ARBs if `commonDone` reads wrong as a
  heading), then `flutter gen-l10n`. message_states already imports a `BuildContext`, so no
  signature change is needed.

### Localize the "(obligatorisk)" required-field marker in StyledFormField
- type: bug  area: account (forms — auth, profile, recipe edit)  priority: Medium
- pass: 1
- finding: `lib/widgets/styled/styled_input.dart:411` builds the screen-reader label as
  `'$label (obligatorisk)'` — a hardcoded Swedish word concatenated onto every required
  field's a11y label in the shared form-field wrapper.
- why: English VoiceOver/TalkBack users hear "Email obligatorisk" instead of "Email required".
  It is in the a11y layer (label:), so it is invisible to sighted QA and easy to miss, but it
  directly violates the ui-conventions rule that all a11y labels be `context.l10n.<key>`.
  StyledFormField is the canonical required-field wrapper, so the bug is systemic across forms.
- fix: Add an `a11yRequiredFieldSuffix`/`fieldRequiredSuffix` key to both ARBs and build the
  label via a placeholder string (e.g. `a11yRequiredField(label)`); drop the literal.

---

## PASS 2 — second sweep (edge cases, hygiene, cross-cutting design-debt)

### Collapse the dead identical branch in StateWidget._buildLoadingState
- type: tech-debt  area: settings (state layer)  priority: Low
- pass: 2
- finding: `lib/widgets/common/state_widget.dart:305-322` — the `if (centerContent)` branch and
  its `else` return byte-identical calls to `LoadingStates.buildLoadingState(...)` with the
  same arguments. The `centerContent` flag is read but never affects the loading output; the
  comment "For skeleton lists that shouldn't be centered" describes behavior the code does not
  implement.
- why: `StateWidget.skeletonRecipeList()` passes `centerContent: false` expecting the skeleton
  list NOT to be centered, but the flag is a no-op for loading states — the skeleton is built
  the same either way. Either the centering intent is silently broken or the flag is vestigial;
  either way it misleads future edits to the shared loader.
- fix: Either honor `centerContent` (wrap centered variants in `Center`, leave skeleton lists
  unwrapped) or delete the dead branch + flag from the loading path and document that loading
  centering is owned by the individual `LoadingStates` builders.

### Replace the Icons.clear sentinel that suppresses empty-state illustrations
- type: tech-debt  area: settings (state layer)  priority: Low
- pass: 2
- finding: `lib/widgets/common/state/empty_states.dart:52` gates the illustration/icon block on
  `if (icon != Icons.clear)` — a magic-value sentinel meaning "pass Icons.clear to render no
  illustration". No current caller uses it (the only `Icons.clear*` callers pass
  `Icons.clear_all` to a different API), so the branch is dormant and the contract is
  undiscoverable.
- why: A caller who legitimately wants a "clear" icon in an empty state would silently get no
  illustration at all. An undocumented sentinel in the shared empty-state builder is a latent
  surprise and contradicts the explicit `useIllustration` bool that already exists on the same
  method for exactly this purpose.
- fix: Remove the `icon != Icons.clear` guard and route suppression through the existing
  `useIllustration: false` parameter (or an explicit `showIllustration` bool). No behavioral
  change for current callers.

---

COVERAGE: Pass 1 read every state-layer file (loading/empty/error/success/info/warning + skeleton + StateWidget facade) and both styled widgets plus the theme token/borderRadius constants — found 2 real localization bugs (Swedish hardcoded in the shared error/success facade and in the required-field a11y label) while confirming the square-corner BorderRadius.circular usages are decided/inert; Pass 2 swept hygiene (line counts vs ACCEPTED_LARGE_FILES — only app_dimensions drifted +52, already an accepted category; zero TODO/FIXME; zero direct-Firebase/mixed-data-source violations) and surfaced 2 low-priority dead-code/sentinel cleanups in the shared state widgets.
