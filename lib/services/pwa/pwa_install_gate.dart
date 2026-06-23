/// Pure, platform-agnostic gating logic for the PWA install prompt.
///
/// Holds the session counter and dismiss flag and decides whether the
/// install prompt should be shown. No web/JS imports — fully VM-testable.
/// The web service delegates the decision here and supplies the
/// deferred-prompt availability it reads from `web.window`.
class PwaInstallGate {
  /// Show the prompt only from this session onward (1-based).
  static const int minSessions = 3;

  int _sessionCount = 0;
  bool _dismissed = false;

  int get sessionCount => _sessionCount;
  bool get dismissed => _dismissed;

  /// Restores persisted state. Returns true if already dismissed (callers can
  /// short-circuit and skip incrementing the session counter).
  bool restore({required int sessionCount, required bool dismissed}) {
    _dismissed = dismissed;
    _sessionCount = sessionCount;
    return _dismissed;
  }

  /// Increments and returns the new session count.
  int incrementSession() => ++_sessionCount;

  /// Marks the prompt as permanently dismissed.
  void markDismissed() => _dismissed = true;

  /// Whether the install prompt may be shown given the current state.
  bool canPrompt({required bool hasDeferredPrompt}) => shouldPrompt(
    hasDeferredPrompt: hasDeferredPrompt,
    sessionCount: _sessionCount,
    dismissed: _dismissed,
  );

  /// Pure decision: prompt only on/after [minSessions], never once dismissed,
  /// and only when a deferred browser prompt is actually available.
  static bool shouldPrompt({
    required bool hasDeferredPrompt,
    required int sessionCount,
    required bool dismissed,
  }) {
    if (dismissed) return false;
    if (sessionCount < minSessions) return false;
    return hasDeferredPrompt;
  }
}
