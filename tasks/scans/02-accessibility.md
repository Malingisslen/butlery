# Scan — Role #2 Accessibility Specialist

Lens: WCAG 2.1 AA (semantic labels, touch targets >=48, contrast, text-scale, focus return).
Owned paths scanned: ui-conventions.md, lib/core/utils/**, app_en.arb, app_sv.arb, lib/theme/**,
auth_view.dart, test/widget/common/dialogs/**, tools/audit_unwrapped_tap_targets.dart.

Dossier watch-items already tracked (NOT re-filed): footer ToS/Privacy `Semantics(link:true)`
without `label:` in auth_view.dart (lines 548-562, 569-582) + recipe_detail_shared_widgets.dart
source link (lines 65-79); 1.4x text-scale clamp tradeoff. BUT-900 manual SR pass tracked.
Tracker already covers: BUT-697 InkWell/GestureDetector Semantics sweep, BUT-514 cream contrast,
BUT-1380 "Glömt lösenord?" sub-48 link, BUT-699 heading hierarchy, BUT-701 focus traversal,
text-scaling, avatar/loading/form-field semantics.

---

### Enlarge registration checkbox tap targets to >=48dp (age + terms) on auth_view
- type: Bug  area: accessibility  priority: Medium
- pass: 1
- finding: Both registration checkboxes are hard-constrained to a 24x24 box —
  `SizedBox(width: 24, height: 24, child: Checkbox(...))` at lib/views/auth_view.dart:308-311
  (age-confirm) and :347-350 (terms-accept). 24dp is exactly half the WCAG 2.5.5 / project
  `minTouchTarget = 48.0` (AppDimensions) floor.
- why: Motor-impaired users miss the toggle. The age checkbox is partly mitigated by an adjacent
  label GestureDetector (:325) that flips `_ageConfirmed`, but the TERMS checkbox has no such
  fallback — its label (:361-390) uses inline `TapGestureRecognizer` TextSpans that only hit the
  link words, so the 24px box is the sole toggle affordance for accepting terms. Distinct from
  BUT-1380 (that ticket is the "Glömt lösenord?" link, a different widget).
- fix: Remove the 24x24 SizedBox or replace with the Material default 48dp target
  (`MaterialTapTargetSize.padded`), or wrap both checkbox+label rows in a single InkWell that
  toggles state with a >=48dp hit area. file:line lib/views/auth_view.dart:308-311, 347-350

### Add link Semantics to inline ToS/Privacy TextSpan recognizers on auth_view
- type: Bug  area: accessibility  priority: Medium
- pass: 1
- finding: The terms-acceptance sentence renders ToS and Privacy Policy as inline `TextSpan`s with
  `recognizer: _tosRecognizer` / `_privacyRecognizer` (lib/views/auth_view.dart:368-386). These
  carry NO Semantics — no link role, no separate accessible name. A screen reader announces the
  whole sentence as flat body text; the tap regions are tiny inline word-runs.
- why: WCAG 4.1.2 (Name, Role, Value) — SR users cannot discover or activate these links. Separate
  surface from the dossier's tracked FOOTER links (:548-582, which use InkWell) and a different
  pattern: TextSpan `TapGestureRecognizer` is invisible to both BUT-697's scope (InkWell/
  GestureDetector) and to tools/audit_unwrapped_tap_targets.dart (its regex only matches
  `InkWell(`/`GestureDetector(`), so it slips every existing net.
- fix: Either replace the inline recognizers with `Semantics(link: true, label: context.l10n...)`-
  wrapped tappable spans, or move the two links out of the Text.rich into labeled InkWell/TextButton
  affordances like the footer. file:line lib/views/auth_view.dart:368-386

### Extend audit_unwrapped_tap_targets.dart to flag TextSpan TapGestureRecognizer links
- type: Improvement  area: accessibility  priority: Low
- pass: 2
- finding: The a11y audit scanner only matches `\b(InkWell|GestureDetector)\(`
  (tools/audit_unwrapped_tap_targets.dart:41). Tappable `TextSpan`s built with
  `TapGestureRecognizer` (e.g. auth_view.dart:375, 385) are a real, used tap-target pattern in the
  codebase but are invisible to the audit and to the ui-conventions.md tap-target rule.
- why: The scanner is the systemic guard for missing tap-target Semantics; a whole class of
  interactive text (inline links) escapes it, so gaps like the finding above won't surface in the
  pre-sprint audit. Closing the blind spot is what keeps the rule self-enforcing.
- fix: Add `TapGestureRecognizer`/`recognizer:` detection (and a Semantics-anchor check for the
  enclosing span) to the audit, and note the inline-link pattern in
  .claude/rules/ui-conventions.md. file:line tools/audit_unwrapped_tap_targets.dart:41,
  .claude/rules/ui-conventions.md:32-72

---

COVERAGE:
Pass 1 (semantics / touch targets / contrast / text-scale / focus return) — found 2 NEW: two
registration checkboxes pinned to a 24x24 (sub-48) tap target on auth_view, and the inline ToS/
Privacy TextSpan recognizer links lacking any link Semantics; the dossier-tracked footer-link
`label:` gap, the 1.4x clamp tradeoff, contrast tokens (all documented with WCAG ratios), and
dialog focus-return (test-pinned) were verified and are already tracked, not re-filed.
Pass 2 (l10n a11y-key parity / hygiene / regression risk) — a11y key parity is clean (169 keys in
both app_en.arb and app_sv.arb); no TODO/FIXME in owned theme/utils; the two owned files >500 lines
(auth_view.dart 746, app_dimensions.dart 745) are both in ACCEPTED_LARGE_FILES.md (recorded sizes
692/693 are stale but the waiver stands); 1 NEW process finding: the audit scanner has a blind spot
for TextSpan/TapGestureRecognizer inline links, which let pass-1's inline-link gap slip through.
