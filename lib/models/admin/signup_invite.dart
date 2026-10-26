import 'package:butlery/core/utils/serialization_utils.dart';

/// One guest-list entry (`signup_allowlist/{email}`, BUT-2452). The document
/// id is the address, normalised the way `beforeCreateAllowlist` looks it up.
class SignupInvite {
  final String email;
  final DateTime? invitedAt;
  final DateTime? expireAt;

  const SignupInvite({required this.email, this.invitedAt, this.expireAt});

  factory SignupInvite.fromFirestore(String id, Map<String, dynamic> data) {
    return SignupInvite(
      email: id,
      invitedAt: SerializationUtils.safeDateTime(data, 'invitedAt'),
      expireAt: SerializationUtils.safeDateTime(data, 'expireAt'),
    );
  }

  /// The TTL sweep can lag, so an expired entry may still be listed; the
  /// blocking function already treats it as no invite.
  bool isExpiredAt(DateTime now) => expireAt == null || !expireAt!.isAfter(now);
}

/// Must stay identical to `normalizeEmail` in
/// `functions/src/account/signup-allowlist.ts`: trim and lower-case only.
String normalizeInviteEmail(String raw) => raw.trim().toLowerCase();

/// The address shape the rules accept for a document id.
final RegExp inviteEmailPattern = RegExp(r'^[^/@\s]+@[^/@\s]+\.[^/@\s]+$');
