import 'package:firebase_auth/firebase_auth.dart';

import 'package:butlery/models/user_profile.dart';

/// Minimum account age before high-friction social actions are unlocked.
/// Mirrors the constant used in `firestore.rules` (`isAccountMatured()`),
/// kept in one place so changes can't drift.
const Duration kAccountMaturityWindow = Duration(minutes: 60);

/// Client-side mirror of the `isAccountMatured()` rule predicate. Lets
/// the UI pre-disable CTAs and surface the verification message before
/// the user takes the action — Firestore rules remain the authoritative
/// gate; this is a UX optimization, not a security control.
class AccountMaturityHelper {
  AccountMaturityHelper({
    Duration window = kAccountMaturityWindow,
    DateTime Function() now = _defaultNow,
  })  : _window = window,
        _now = now;

  final Duration _window;
  final DateTime Function() _now;

  /// Returns `true` when the current user can perform high-friction
  /// social actions (friend requests, DMs, group invites). Treats a
  /// missing email-verification flag and missing `joinedAt` as "not
  /// matured" so an incomplete profile cannot bypass the gate.
  bool isMatured({
    required UserProfile? profile,
    required User? firebaseUser,
  }) {
    if (firebaseUser?.emailVerified == true) return true;
    final joinedAt = profile?.joinedAt;
    if (joinedAt == null) return false;
    return _now().difference(joinedAt) >= _window;
  }

  static DateTime _defaultNow() => DateTime.now();
}
