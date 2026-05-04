import 'package:butlery/models/user_profile.dart';

/// Builds a `UserProfile` with sane defaults for the required fields
/// (`uid`, `displayName`, `email`, `joinedAt`, `lastActiveAt`).
///
/// Defaults are stable values — UID-derived email, fixed `joinedAt`, and
/// `lastActiveAt` mirroring `joinedAt` — so tests that don't care about
/// those fields don't need to spell them out.
UserProfile testUserProfile({
  String uid = 'test-uid',
  String displayName = 'Test User',
  String? email,
  DateTime? joinedAt,
  DateTime? lastActiveAt,
  String? avatarUrl,
}) {
  final defaultTime = joinedAt ?? DateTime(2026, 1, 1);
  return UserProfile(
    uid: uid,
    displayName: displayName,
    email: email ?? '$uid@example.com',
    joinedAt: defaultTime,
    lastActiveAt: lastActiveAt ?? defaultTime,
    avatarUrl: avatarUrl,
  );
}
