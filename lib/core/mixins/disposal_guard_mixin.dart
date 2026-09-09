import 'package:flutter/foundation.dart';

/// Makes `notifyListeners()` a no-op once the host has been disposed.
///
/// BUT-1641 gave five state holders this guard by hand and BUT-2015 measured
/// two more that need it. The shape it replaces was already written out
/// verbatim across the viewmodel layer, so another hand-copy is the wrong
/// direction: the guard is one behaviour and belongs in one place.
///
/// The notification is SWALLOWED, not thrown. Whoever reaches here is a
/// callback or continuation landing after the screen closed, and crashing the
/// app is the wrong answer to that.
///
/// Apply it to a [ChangeNotifier] that can notify AFTER its `dispose()` has
/// run. An `await` between an entry point and a notification is one such path;
/// a live `StreamSubscription`, a `Timer` body and a listener the host
/// registered elsewhere are others, and none of those involves an `await` in
/// the notifying method. Decide per host by asking what can still call back,
/// not by grepping for `await`.
///
/// A host that owns subscriptions or timers still writes its own `dispose()`
/// body — this mixin's override flips the flag and chains, it does not replace
/// that cleanup. Call `super.dispose()` from the host's own override so the
/// flag is still set. Put `with DisposalGuardMixin` last when another mixin on
/// the same host overrides `dispose()` or `notifyListeners()`, so this one's
/// versions win; with mixins that override neither, the order does not matter.
///
/// Other `isDisposed` flags exist, and a host can end up carrying more than one.
/// Worth knowing before combining mixins:
///
/// `ErrorHandlingMixin` breaks its two retry loops on `StateNotifierMixin`'s
/// flag by name (`this is StateNotifierMixin && (this as StateNotifierMixin)
/// .isDisposed`), so this mixin's flag does not reach them.
///
/// `StreamManagementMixin` declares `isStreamDisposed`, which
/// `disposeStreamResources()` sets; a host that cleans its streams up by hand
/// leaves it false.
///
/// For a host that notifies, guard on this mixin's flag — it is the one this
/// mixin wires into `notifyListeners()`.
mixin DisposalGuardMixin on ChangeNotifier {
  bool _isDisposed = false;

  bool get isDisposed => _isDisposed;

  @override
  void notifyListeners() {
    if (_isDisposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
