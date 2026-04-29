---
paths:
  - "lib/views/**"
  - "lib/widgets/**"
---

# UI Conventions

## Responsive Design
- Center + ConstrainedBox with responsive max width
- See `responsive-layout-validator` skill for breakpoints and patterns

## Terse Prompt Signals
User prompts are bimodal: detailed plans OR ultra-short commands.

| Signal | Meaning | Response |
|--------|---------|----------|
| `"continue"` | Resume at next step in current task | Don't ask "continue what?" - check plan/context and proceed |
| `"try it out"` / `"test it"` | Run the app and verify | Execute `flutter run -d chrome`, test, report result |
| Bare screenshot path | "Look at this" | Analyze proactively - describe what you see, don't ask what to look for |
| `"The issue remains"` | Previous fix failed | Try a DIFFERENT approach. Don't retry the same thing. |
| `"But..."` at start | Your previous claim was wrong | Stop and verify your claim before responding |
| `"are you really?"` | User doubts your statement | Actually verify (run command, check file) before confirming |
| `"what about X?"` | You missed/skipped something | Go check X immediately |
| `"Implement the following plan:"` | Complete spec, execute it | Don't ask clarifying questions. Parse and execute. |

## UI Mockup Comparison
- Be EXHAUSTIVE: check search box accents, avatar initials/images, icon colors, spacing, border radius, opacity, typography weight, and all small details
- List ALL differences, not just obvious ones
- Don't declare match until every element is verified

## Accessibility (a11y) — Tap-target Semantics

Every tappable widget that isn't already a self-labeling Material/Cupertino primitive (`IconButton`, `TextButton`, `ElevatedButton`, `Switch`, `Checkbox`, `Radio`) MUST be wrapped in `Semantics` for screen-reader support. Verified by `find.bySemanticsLabel` in widget tests and audited by `tools/audit_unwrapped_tap_targets.dart`.

### The pattern

```dart
Semantics(
  label: context.l10n.a11y<DescriptiveKey>,  // OR with placeholder: a11yPickTime(label, time)
  button: true,
  // For toggle UIs (expand/collapse, mark-done, select-one-of-many):
  toggled: <bool>,                            // preferred when state is boolean
  child: InkWell(...) /* or GestureDetector(...) */,
)
```

### Rules

1. **`button: true`** — required. `InkWell` does NOT set `button: true` natively (verified Flutter 3.35.1). Without it, screen readers announce the element as a generic touch target.
2. **`label:` is always a localized `context.l10n.<key>`** — never a hardcoded string. Add the key to BOTH `app_sv.arb` and `app_en.arb` (matching descriptions + placeholders), then run `flutter gen-l10n`.
3. **For toggle UIs use `Semantics(toggled: <bool>)` with a SINGLE label key** — Flutter announces "expanded/collapsed", "on/off", "selected" automatically from `toggled:`. Don't create two keys (`a11yXOn` + `a11yXOff`) and a ternary — that's the chunk-7 anti-pattern that the simplify pass caught.
4. **For radio-style pickers use `Semantics(selected: <bool>)`** — emoji picker, content-type toggle, etc. (See `group_dialog_components.EmojiSelector` for the canonical example.)
5. **The visible child Text often duplicates the label — that's fine.** `Semantics(label:)` blocks descendant Text from being merged into the screen-reader output, so the parent label wins. Don't omit a meaningful label just because the visible text says the same thing.
6. **Never wrap `IconButton`/`TextButton` etc.** — they already carry Semantics. Wrap only `InkWell` / `GestureDetector` / bare `onTap` containers.

### l10n key naming

- Prefix with `a11y` so the keys cluster in the ARB file and are easy to grep.
- Verb-first when the action is the focus: `a11yRemoveIngredientChip`, `a11yToggleStepDone`.
- Noun-first when it's a stable label: `a11yCommentsToggle` (the toggled state is the variable, not the noun).
- Use placeholders for dynamic content: `a11yShowSubstitutionsFor(ingredient)`, `a11yPickTime(label, time)`.

### Audit tool

Before shipping a sprint that adds tappable widgets, run:

```sh
dart tools/audit_unwrapped_tap_targets.dart
```

The script greps `lib/views/` and `lib/widgets/` for `InkWell(` / `GestureDetector(` not preceded (within 10 lines) by `Semantics(label:`. It's not a strict CI gate — it surfaces candidates for manual review. Acceptable false positives: `InkWell` inside an `IconButton`/`TextButton` body (already wrapped), and tap-handlers on widgets whose only purpose is decorative (e.g. swipe-to-dismiss).

### Tests

Per-chunk widget tests live at `test/widget/widgets/chunkN_semantics_a11y_test.dart` and use:

```dart
final handle = tester.ensureSemantics();
expect(find.bySemanticsLabel(RegExp(r'^...')), findsOneWidget);
handle.dispose();
```

Skip tests that need heavy ViewModel scaffolding — those are covered by the audit script + manual screen-reader passes.
