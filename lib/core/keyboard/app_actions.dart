// lib/core/keyboard/app_actions.dart
//
// BUT-521: action handlers for the keyboard navigation layer.
//
// Wires each `Intent` declared in `app_shortcuts.dart` to a concrete
// callback. All navigation goes through `appNavigatorKey` (the same global
// the FCM/feedback layers use) so we don't need a `BuildContext` here.
//
// Tab switching: the bottom-nav `_selectedIndex` lives in private state
// inside `_MainMenuLayoutState`. Rather than refactoring that whole
// scaffold, we expose a tiny `mainTabSwitchRequest` `ValueNotifier` that
// the layout listens to. This keeps the bridge to one shared symbol —
// any future refactor (e.g. moving the index into a real ViewModel) can
// drop the listener and remove the notifier without touching consumers.

import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/keyboard/app_shortcuts.dart';
import 'package:butlery/core/observers/route_tracker.dart';
import 'package:butlery/widgets/common/feedback_fab.dart' show appNavigatorKey;

/// Shared notifier read by the main scaffold (`_MainMenuLayoutState`) to
/// switch its bottom-nav tab. Indices must match the scaffold's order:
/// 0 = recipes, 1 = menu, 2 = shopping.
///
/// We use a `ValueNotifier<int>` rather than a `Stream` so listeners only
/// pay a setState when the index actually changes; same value re-emits
/// (e.g. Cmd+1 pressed twice) are short-circuited by the notifier itself.
final ValueNotifier<int> mainTabSwitchRequest = ValueNotifier<int>(0);

/// Maps every `Intent` in `app_shortcuts.dart` to a callable action.
/// Bound inside `MaterialApp.builder` (`lib/app/butlery_app.dart`), which is
/// below the framework's own text-editing shortcuts — see `_NavigateBackAction`.
class AppActions {
  AppActions._();

  static Map<Type, Action<Intent>> dispatch() {
    return <Type, Action<Intent>>{
      CloseDialogIntent: CallbackAction<CloseDialogIntent>(
        onInvoke: (_) => _maybePop(),
      ),
      NavigateBackIntent: _NavigateBackAction(),
      OpenSearchIntent: CallbackAction<OpenSearchIntent>(
        onInvoke: (_) => _pushSearch(Routes.ingredientSearch),
      ),
      GoToRecipesIntent: CallbackAction<GoToRecipesIntent>(
        onInvoke: (_) => _switchTab(0),
      ),
      GoToMenuIntent: CallbackAction<GoToMenuIntent>(
        onInvoke: (_) => _switchTab(1),
      ),
      GoToShoppingIntent: CallbackAction<GoToShoppingIntent>(
        onInvoke: (_) => _switchTab(2),
      ),
      GoToMoreIntent: CallbackAction<GoToMoreIntent>(
        onInvoke: (_) => _switchTab(3),
      ),
      SubmitFormIntent: CallbackAction<SubmitFormIntent>(
        onInvoke: (_) => _submitFocusedForm(),
      ),
    };
  }

  static Object? _maybePop() {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return null;
    // `maybePop` returns false when there's nothing to pop — that's the
    // intended no-op behavior (Esc on the home screen does nothing).
    navigator.maybePop();
    return null;
  }

  static Object? _pushSearch(String route) {
    // Dedupe Cmd+K spam: if the search route is already on top, don't push
    // another copy. `appRouteTracker.currentRouteName` is fed by the
    // observer registered in `main.dart`. Without this, repeated Cmd+K
    // stacks N copies and the user presses Back N times to escape.
    if (appRouteTracker.currentRouteName == route) return null;
    appNavigatorKey.currentState?.pushNamed(route);
    return null;
  }

  /// Lands on Hem's recipe tab by unwinding to the existing first route.
  ///
  /// Never push [Routes.home]: `/` resolves to `MaterialApp.home`, so a push
  /// builds a second `InitializationWrapper` whose `AuthWrapper` reuses the
  /// first one's static GlobalKey. Release builds leave the old copy black
  /// under the new one, which back then reveals.
  ///
  /// `popUntil` skips PopScope on purpose: callers are "done, go home" exits,
  /// where an unsaved-input veto has nothing left to protect.
  static void returnToHome(NavigatorState navigator) {
    mainTabSwitchRequest.value = 0;
    var firstIsHome = false;
    navigator.popUntil((route) {
      if (!route.isFirst) return false;
      firstIsHome = route.settings.name == Routes.home;
      return true;
    });
    if (!firstIsHome) navigator.pushReplacementNamed(Routes.home);
  }

  static Object? _switchTab(int index) {
    // Always assign — `ValueNotifier` short-circuits identical values, so
    // listeners only rebuild on real changes.
    mainTabSwitchRequest.value = index;
    unawaited(_popToRoot());
    return null;
  }

  // `maybePop` rather than `popUntil`: popUntil skips every PopScope, so a
  // form with unsaved input would be dropped without its confirmation.
  // `maybePop` returns true for a route that vetoed the pop too, so a veto is
  // read off the route that is still on top.
  static Future<void> _popToRoot() async {
    final navigator = appNavigatorKey.currentState;
    while (navigator != null && navigator.mounted && navigator.canPop()) {
      final before = _topRoute(navigator);
      if (!await navigator.maybePop()) return;
      if (!navigator.mounted || identical(before, _topRoute(navigator))) return;
    }
  }

  static Route<dynamic>? _topRoute(NavigatorState navigator) {
    Route<dynamic>? top;
    navigator.popUntil((route) {
      top = route;
      return true;
    });
    return top;
  }

  static Object? _submitFocusedForm() {
    // Default fallback for forms that haven't opted in to a custom submit
    // path: walk up from the focused element to the nearest `Form`, run
    // `validate()` + `save()`. In this codebase most saves go through
    // ViewModel methods triggered by explicit Save buttons (so `Form.save`
    // is a no-op there) — those forms wrap themselves in
    // `KeyboardSubmittableForm` to register their own Save callback as the
    // canonical override. See `lib/core/keyboard/keyboard_submittable_form.dart`.
    final focused = FocusManager.instance.primaryFocus;
    final ctx = focused?.context;
    if (ctx == null) return null;
    final form = Form.maybeOf(ctx);
    if (form == null) return null;
    if (form.validate()) {
      form.save();
    }
    return null;
  }
}

/// Backspace is bound to "go back", and this app's `Shortcuts` layer sits
/// inside `MaterialApp.builder` — below `DefaultTextEditingShortcuts` and
/// therefore CLOSER to a focused field, so it wins the key before the
/// framework's own delete binding. Left enabled, a hardware Backspace would
/// silently do nothing in every text field on web and desktop instead of
/// erasing a character (found on the login screen's password field).
///
/// Disabling the action rather than handling it is what makes the key fall
/// through: `ShortcutManager` treats a disabled action as unhandled and keeps
/// propagating up to the text-editing shortcuts.
///
/// Accepted consequence: in a `readOnly` field Backspace becomes a dead key —
/// disabled here, nothing to delete there. That matches how browsers have
/// treated Backspace since 2016 and is preferred over navigating away from a
/// field the user is reading.
class _NavigateBackAction extends Action<NavigateBackIntent> {
  @override
  bool isEnabled(NavigateBackIntent intent) => !_focusIsInsideTextField();

  @override
  Object? invoke(NavigateBackIntent intent) => AppActions._maybePop();

  static bool _focusIsInsideTextField() {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return false;
    return ctx.findAncestorStateOfType<EditableTextState>() != null;
  }
}
