import 'package:firebase_auth/firebase_auth.dart';

/// What a profile created on its first load starts with. A guest has no
/// e-mail and gets one too (BUT-920).
class NewProfileDefaults {
  const NewProfileDefaults._({
    required this.displayName,
    required this.isSearchable,
    required this.completedOnboarding,
  });

  /// [registrationName] is the name typed at registration, when the device
  /// still holds it for that address.
  factory NewProfileDefaults.forUser(
    User user, {
    required String? Function(String? email) registrationName,
  }) {
    final email = user.email;
    if (user.isAnonymous || email == null) {
      return NewProfileDefaults._(
        displayName: user.displayName ?? guestDisplayName,
        // People search would only list a guest nobody can befriend.
        isSearchable: false,
        // The guest start takes onboarding's place.
        completedOnboarding: true,
      );
    }
    return NewProfileDefaults._(
      displayName:
          user.displayName ?? registrationName(email) ?? email.split('@')[0],
      isSearchable: true,
      completedOnboarding: false,
    );
  }

  /// The name a guest's profile is created with; the guest chooses a real one
  /// when creating an account.
  static const String guestDisplayName = 'Gäst';

  /// Whether [user] gets a profile created when none exists.
  static bool appliesTo(User user) => user.email != null || user.isAnonymous;

  final String displayName;
  final bool isSearchable;
  final bool completedOnboarding;
}
