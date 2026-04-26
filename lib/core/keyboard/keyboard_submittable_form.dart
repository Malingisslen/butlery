// lib/core/keyboard/keyboard_submittable_form.dart
//
// BUT-521 follow-up: Cmd/Ctrl+Enter submit override for forms whose Save
// button calls a ViewModel method instead of `Form.save()`.
//
// The default top-level handler in `app_actions.dart` walks
// `Form.maybeOf(focusedContext)` and calls `validate() + save()`. That's a
// no-op in this codebase because no form passes `onSaved` callbacks — saves
// route through explicit Save buttons that invoke ViewModel methods. This
// widget owns the `Form` AND registers an `Actions<SubmitFormIntent>`
// override at the same root, so the keyboard shortcut runs the *same*
// callback the Save button does AND the form key plumbing isn't duplicated
// across both wrappers.
//
// Validation parity: `validateBeforeSubmit` defaults to true because every
// migrated form's Save button gates on `_formKey.currentState.validate()`.
// Skipping validation here would let Cmd+Enter bypass the same checks the
// pointer path enforces — confusing and error-prone.

import 'package:flutter/widgets.dart';

import 'package:butlery/core/keyboard/app_shortcuts.dart';

/// Wraps a form body so Cmd/Ctrl+Enter triggers the same save callback the
/// visible Save button uses. Owns the underlying `Form` widget so callers
/// don't double-pass the same `formKey` to two wrappers.
///
/// `formKey` + `validateBeforeSubmit` together gate the callback: when both
/// are supplied (default behavior), `onSubmit` only fires if `validate()`
/// returns true — matching the pointer path's behavior.
class KeyboardSubmittableForm extends StatefulWidget {
  const KeyboardSubmittableForm({
    super.key,
    required this.child,
    required this.onSubmit,
    this.formKey,
    this.validateBeforeSubmit = true,
  });

  /// Form body. Will be wrapped in a `Form` (with `formKey` if supplied).
  final Widget child;
  final VoidCallback onSubmit;

  /// Optional — only required when `validateBeforeSubmit` is true. Without
  /// it we can't run validation, so we fall through to firing `onSubmit`.
  final GlobalKey<FormState>? formKey;

  /// When true, runs `formKey.currentState.validate()` before firing
  /// `onSubmit`. Defaults true to mirror the visible Save button's gate.
  final bool validateBeforeSubmit;

  @override
  State<KeyboardSubmittableForm> createState() =>
      _KeyboardSubmittableFormState();
}

class _KeyboardSubmittableFormState extends State<KeyboardSubmittableForm> {
  /// Built once in `initState` so the parent's per-keystroke rebuilds don't
  /// re-allocate a fresh `Actions` map + `CallbackAction` instance, which
  /// would force `Actions` to re-register on every rebuild. The closure
  /// reads `widget.*` so it always sees the current callback / formKey /
  /// validation flag without needing rebuild.
  late final Map<Type, Action<Intent>> _actions;

  @override
  void initState() {
    super.initState();
    _actions = <Type, Action<Intent>>{
      SubmitFormIntent: CallbackAction<SubmitFormIntent>(
        onInvoke: (_) {
          if (widget.validateBeforeSubmit &&
              widget.formKey?.currentState?.validate() == false) {
            return null;
          }
          widget.onSubmit();
          return null;
        },
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: _actions,
      child: Form(
        key: widget.formKey,
        child: widget.child,
      ),
    );
  }
}
