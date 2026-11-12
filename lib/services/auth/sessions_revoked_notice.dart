import 'package:shared_preferences/shared_preferences.dart';

/// BUT-2481: tells the owner, once per device, that their other devices were
/// signed out.
class SessionsRevokedNotice {
  SessionsRevokedNotice({required SharedPreferences prefs, DateTime? now})
    : _prefs = prefs,
      _now = now;

  static const String seenKey = 'sessions_revoked_seen_ms_v1';
  static const String checkedSignInKey =
      'sessions_revoked_checked_signin_ms_v1';

  /// Older than this is history, not news.
  static const Duration maxAge = Duration(days: 30);

  /// The device that pressed the button knows already. The margin covers a
  /// server clock a little ahead of this one.
  static const Duration ownPressMargin = Duration(minutes: 5);

  final SharedPreferences _prefs;
  final DateTime? _now;

  DateTime get _clock => _now ?? DateTime.now();

  /// True once per sign-in on this device: the server stamp can only have
  /// changed the story since the person last signed in here, so one read per
  /// sign-in is enough. A null [lastSignIn] never checks.
  bool needsCheck(DateTime? lastSignIn) =>
      lastSignIn != null &&
      _prefs.getInt(checkedSignInKey) != lastSignIn.millisecondsSinceEpoch;

  /// Call after the read succeeded, so an offline start tries again.
  Future<void> markChecked(DateTime lastSignIn) =>
      _prefs.setInt(checkedSignInKey, lastSignIn.millisecondsSinceEpoch);

  /// The time to announce, or null. Marks it as seen either way it is returned.
  Future<DateTime?> due(DateTime? revokedAt) async {
    if (revokedAt == null) return null;
    if (_clock.difference(revokedAt) > maxAge) return null;
    final seenMs = _prefs.getInt(seenKey);
    if (seenMs != null &&
        !revokedAt.isAfter(DateTime.fromMillisecondsSinceEpoch(seenMs))) {
      return null;
    }
    await _prefs.setInt(seenKey, revokedAt.millisecondsSinceEpoch);
    return revokedAt;
  }

  Future<void> markPressedHere() => _prefs.setInt(
    seenKey,
    _clock.add(ownPressMargin).millisecondsSinceEpoch,
  );
}
