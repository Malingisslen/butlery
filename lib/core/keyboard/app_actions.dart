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
/// Bound at the top of the widget tree by the app shell.
class AppActions {
  AppActions._();

  static Map<Type, Action<Intent>> dispatch() {
    return <Type, Action<Intent>>{
      CloseDialogIntent: CallbackAction<CloseDialogIntent>(
        onInvoke: (_) => _maybePop(),
      ),
      NavigateBackIntent: CallbackAction<NavigateBackIntent>(
        onInvoke: (_) => _maybePop(),
      ),
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

  static Object? _switchTab(int index) {
    // Always assign — `ValueNotifier` short-circuits identical values, so
    // listeners only rebuild on real changes.
    mainTabSwitchRequest.value = index;
    // Pop back to the root if the user is deep in a pushed route, so the
    // tab switch is actually visible. Safe no-op when already at root.
    appNavigatorKey.currentState?.popUntil((route) => route.isFirst);
    return null;
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
