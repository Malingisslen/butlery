// lib/core/keyboard/app_shortcuts.dart
//
// BUT-521: keyboard navigation layer for web/desktop (WCAG 2.1.1).
//
// Defines the `Intent` subclasses that the app's keyboard layer dispatches,
// plus the `Shortcuts` map that binds physical key combinations to those
// intents. The matching `Actions` map lives in `app_actions.dart` so this
// file stays a pure declaration of "what key triggers what intent" — easy
// to scan for the a11y review.
//
// Platform handling: `meta: kIsMacOS` + `control: !kIsMacOS` so Mac users
// press Cmd while everyone else presses Ctrl. We use `defaultTargetPlatform`
// (compile-time + runtime) rather than `Platform.isMacOS` so the bindings
// also work on Flutter web running on a Mac browser.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Pop the topmost dialog or pushed route. No-op when only the root remains.
class CloseDialogIntent extends Intent {
  const CloseDialogIntent();
}

/// Pop the current route via `Navigator.maybePop`. Bound to Backspace when
/// no text input has focus — text fields receive Backspace before the
/// shortcuts layer (Flutter focus order), so this never deletes characters.
class NavigateBackIntent extends Intent {
  const NavigateBackIntent();
}

/// Open the global ingredient-search view. Currently the only first-class
/// search surface; recipe-list filtering is inline in the list view.
class OpenSearchIntent extends Intent {
  const OpenSearchIntent();
}

/// Switch the main bottom-nav to the recipes tab (index 0).
class GoToRecipesIntent extends Intent {
  const GoToRecipesIntent();
}

/// Switch the main bottom-nav to the menu tab (index 1).
class GoToMenuIntent extends Intent {
  const GoToMenuIntent();
}

/// Switch the main bottom-nav to the shopping tab (index 2).
class GoToShoppingIntent extends Intent {
  const GoToShoppingIntent();
}

/// Trigger form submission. The default top-level handler walks
/// `Form.maybeOf(focusedContext)` and runs `validate()` + `save()`, which
/// only works for forms whose state is reflected back via `onSaved`.
/// Most forms in this codebase save through ViewModel methods bound to an
/// explicit Save button — those wrap themselves in `KeyboardSubmittableForm`
/// (see `lib/core/keyboard/keyboard_submittable_form.dart`) to override
/// this intent with the same callback the Save button calls.
class SubmitFormIntent extends Intent {
  const SubmitFormIntent();
}

/// Static binding map consumed by the top-level `Shortcuts` widget in
/// `main.dart`. Built once at process start — the platform doesn't change
/// during the app lifetime, so allocating a fresh map per build would be
/// wasted work.
class AppShortcuts {
  AppShortcuts._();

  /// Web on Mac counts as macOS so Cmd+K behaves natively in Chrome/Safari
  /// running on macOS.
  static final bool _isMac = defaultTargetPlatform == TargetPlatform.macOS;

  static final Map<ShortcutActivator, Intent> bindings = _build();

  static Map<ShortcutActivator, Intent> _build() {
    final useMeta = _isMac;
    final useCtrl = !_isMac;

    return <ShortcutActivator, Intent>{
      // Esc closes dialogs/sheets/pushed routes.
      const SingleActivator(LogicalKeyboardKey.escape):
          const CloseDialogIntent(),

      // Backspace navigates back when not consumed by a text field.
      const SingleActivator(LogicalKeyboardKey.backspace):
          const NavigateBackIntent(),

      // Ctrl/Cmd+K opens search.
      SingleActivator(
        LogicalKeyboardKey.keyK,
        meta: useMeta,
        control: useCtrl,
      ): const OpenSearchIntent(),

      // Ctrl/Cmd+1 / 2 / 3 switch primary nav tabs.
      SingleActivator(
        LogicalKeyboardKey.digit1,
        meta: useMeta,
        control: useCtrl,
      ): const GoToRecipesIntent(),
      SingleActivator(
        LogicalKeyboardKey.digit2,
        meta: useMeta,
        control: useCtrl,
      ): const GoToMenuIntent(),
      SingleActivator(
        LogicalKeyboardKey.digit3,
        meta: useMeta,
        control: useCtrl,
      ): const GoToShoppingIntent(),

      // Ctrl/Cmd+Enter submits the focused form.
      SingleActivator(
        LogicalKeyboardKey.enter,
        meta: useMeta,
        control: useCtrl,
      ): const SubmitFormIntent(),
    };
  }
}
