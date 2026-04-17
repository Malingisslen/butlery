import 'dart:async';

import 'package:flutter/foundation.dart';

/// Debounce helper for any [ChangeNotifier] (including [BaseViewModel]).
///
/// Each key gets its own timer; calling [debounce] with the same key
/// before the delay elapses replaces the pending run. Timers are
/// cancelled automatically on [dispose]. Errors raised by the action
/// are swallowed — debounced operations are background work and must
/// surface errors themselves if they need user visibility.
mixin DebounceMixin on ChangeNotifier {
  final Map<String, Timer> _debouncers = {};
  bool _debounceDisposed = false;

  void debounce(
    String key,
    Duration delay,
    FutureOr<void> Function() action,
  ) {
    if (_debounceDisposed) return;
    _debouncers[key]?.cancel();
    _debouncers[key] = Timer(delay, () async {
      _debouncers.remove(key);
      if (_debounceDisposed) return;
      try {
        await action();
      } catch (_) {
        // Background work — callers opt into error reporting inside [action].
      }
    });
  }

  void cancelDebounce(String key) {
    _debouncers.remove(key)?.cancel();
  }

  void cancelAllDebounces() {
    for (final t in _debouncers.values) {
      t.cancel();
    }
    _debouncers.clear();
  }

  @override
  void dispose() {
    _debounceDisposed = true;
    cancelAllDebounces();
    super.dispose();
  }
}
