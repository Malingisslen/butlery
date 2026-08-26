---
paths:
  - "lib/views/**"
  - "lib/widgets/**"
---

# UI Conventions

> Sibling design-system decisions not covered here — square-FAB primary-action placement
> (BUT-964), the favourite/featured/saved icon convention (BUT-944), date/time formatting
> tiers (BUT-961), web hover (BUT-710), and platform-adaptive top bars (BUT-706) — live in
> [`docs/design-system/CROSS_CUTTING_RULES.md`](../../docs/design-system/CROSS_CUTTING_RULES.md).

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
5. **`Semantics(label:)` does NOT block the descendant `Text` — the two are CONCATENATED into one announcement.** Measured 2026-08-26 on a built semantics node and pinned by `message_bubble_duplicate_blocked_test.dart` ("announces its action ONCE"). This line asserted the opposite until it was measured, so **name the ACTION in the label and let the visible text carry the noun** — a label that restates the visible text makes a screen reader say the same sentence twice. Labels written under the old belief are not audited; BUT-1953 sweeps them.
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

## Long-press semantics (BUT-948)

On **list-selection surfaces**, long-press enters multi-select (mirrors the pantry /
shopping / personal-tags / group-member pattern: long-press → `enterSelection`, then a
contextual bulk-action bar replaces the FAB). Canonical implementations:
`pantry/pantry_item_card.dart`, `unified_shopping/widgets/shopping_item_tiles.dart`,
`personal_tags/personal_tag_widgets.dart`, `social/group_detail/group_member_card.dart`.

**Documented exceptions** (long-press is a contextual menu or feature affordance, NOT
multi-select — each carries a `// BUT-948 exception:` code comment):
- **Conversations list** (`messaging/conversations_list_view.dart`) — opens the conversation
  action menu (mute/delete/mark-read).
- **Chat messages** (`messaging/chat_view/chat_message_stream.dart`) — opens the message
  action menu.
- **Cooking mode** (`cooking_mode_view.dart`) — long-press on an ingredient opens
  substitutions; on an instruction step opens the step timer.

When adding a new long-press: if the surface is a selectable list, wire it to multi-select.
Otherwise, add a `// BUT-948 exception:` comment explaining the contextual/feature intent.

## Dialog focus return (BUT-900)

**Input-focus return after a dialog or bottom sheet closes is automatic — do NOT
hand-plumb it.** Both `showDialog` and `showModalBottomSheet` build on Flutter's
`ModalRoute`, which records the primary focus before the route is pushed and
restores it to the trigger control on pop. This holds for button-close,
barrier-dismiss, and bottom sheets alike. Adding a `FocusNode` + `requestFocus()`
to each call site (as an old audit proposed) is plumbing against a non-bug.

The contract is pinned by `test/widget/common/dialogs/dialog_focus_return_test.dart`,
which asserts `FocusManager.primaryFocus` returns to the trigger across all three
patterns **and** through the app's own `ConfirmationDialog.show`. Keep new shared
dialog helpers flowing through `showDialog`/`showModalBottomSheet` (or add a case
to that test) so the guarantee survives refactors — a custom `Navigator.push`
route would silently lose it.

The one part code can't prove is the **screen-reader accessibility-focus** layer
(TalkBack/VoiceOver), which the platform manages on top of input focus. That stays
a manual screen-reader pass (per the tap-target section's "manual screen-reader
passes" note) — it is the only open item on dialog a11y focus.

## Destructive-action confirmation (BUT-954)

Severity classes decide the friction pattern. Pick by **recoverability**, not by how scary the verb sounds:

1. **Reversible-destructive** — the item is trivially recreatable or restorable (pantry row, image attachment, own comment): **swipe/tap deletes immediately + snackbar with "Ångra" (7s, `SnackBarUtils.showSuccessWithAction` + a `restore`/undo path). NO confirm dialog** — a dialog on a recoverable action is friction without protection.
2. **Hard-destructive** — user-authored content that is gone (or expensive to rebuild) after the undo window closes (recipe delete, bulk recipe delete, personal-tag delete which untags recipes): **confirm dialog AND, where a restore path exists, snackbar undo.** Recipe single + bulk delete are the canonical implementations (dialog → optimistic delete → 5-7s undo).
3. **Light action** — reversible state flips with an obvious inverse (claim/release shopping item, mark step done, favorite): **no friction at all.** Never add a dialog or undo snackbar to these.
4. **Dismissing a notice** — the app told the user something and they are clearing the message, not deleting their own content (BUT-1904's duplicate-guard row): **no dialog, no undo.** It looks like a class-1 delete and is not: nothing the user authored is lost, and the notice reappears if the same condition recurs. Class 1 MANDATES an undo and class 3 FORBIDS one, so a notice straddles them until you apply the recoverability test — which here returns "nothing to protect". Do not reach for this class for anything the user wrote.

Reference implementations: `mina_recept/recipe_card_widget.dart` + `recipe_delete_manager.dart` (class 2), `pantry/pantry_item_card.dart` (class 1), `collaborative_shopping_items.dart` claim flow (class 3), `messaging/components/system_message_widget.dart` + `message_bubble.dart` (class 4).

A class-4 control still needs a real tap target: the notice pill is shorter than `AppDimensions.minTouchTarget`, so the hit region carries its own `minHeight` and is sized to the pill rather than to the row. Both halves are pinned in `message_bubble_duplicate_blocked_test.dart`; an unbounded `Center` once made that gesture cover most of the screen.

When adding a new destructive action: classify first, then copy the matching reference. If undo is impossible for a class-2 action, say so in the confirm dialog body ("Detta går inte att ångra").
