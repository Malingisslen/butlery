import 'package:butlery/models/admin/signup_invite.dart';

/// Admin-only guest list (BUT-2452). Firestore rules are the gate; entries are
/// created or removed, never edited.
abstract class SignupAllowlistRepository {
  /// Every entry, newest invite first.
  Future<List<SignupInvite>> listInvites();

  /// Adds [email] (already normalised). Throws [SignupInviteExistsException]
  /// when an entry for it is already there.
  Future<void> invite(String email);

  Future<void> remove(String email);
}

class SignupInviteExistsException implements Exception {
  const SignupInviteExistsException();
}
