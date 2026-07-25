/// Result of a profile read that keeps "absent" and "failed" apart (BUT-1663).

import 'package:butlery/models/user_profile.dart';

/// Why a profile read did not produce usable preferences.
///
/// `UserService.getUserProfile` collapses every outcome into a nullable
/// profile, so a deleted account, a dropped connection and a user who simply
/// never opened a settings screen all arrive as `null`. That is fine for
/// rendering a name; it is not fine for deciding whether to filter a menu for
/// allergens, where "I could not read this" and "there is nothing to read"
/// must lead to different behaviour.
enum ProfileLookupStatus {
  /// Profile read, and nothing failed.
  ///
  /// What an absent field MEANS still depends on whose profile this is:
  ///
  ///  - **The signed-in user.** Their private settings were merged, so an
  ///    absent field really is unset — a declaration.
  ///  - **Anyone else.** Their settings sub-doc is owner-read-only
  ///    (`firestore.rules`: `allow read: if isOwner(userId)`) and is never
  ///    merged, so settings-backed fields — `allergenPreferences` above all —
  ///    are ALWAYS absent no matter what that person declared. Reading that as
  ///    "they have no allergies" is exactly the bug BUT-1663 exists to close.
  ///
  /// This status means "the read succeeded", never "the data is complete".
  found,

  /// Profile read, but its private settings sub-doc could not be. Every
  /// settings-backed field is missing due to a failure — treat none of them as
  /// a declaration.
  foundSettingsUnavailable,

  /// The profile document does not exist. A deleted account, or a member id
  /// left behind in a roster. Not a transient condition.
  missing,

  /// The read itself failed — offline, permission denied, timeout. Transient;
  /// the profile may well exist and carry preferences.
  unavailable,
}

/// A profile read together with why it produced what it did.
class ProfileLookup {
  const ProfileLookup._(this.status, this.profile);

  const ProfileLookup.found(UserProfile profile)
    : this._(ProfileLookupStatus.found, profile);

  const ProfileLookup.foundSettingsUnavailable(UserProfile profile)
    : this._(ProfileLookupStatus.foundSettingsUnavailable, profile);

  const ProfileLookup.missing() : this._(ProfileLookupStatus.missing, null);

  const ProfileLookup.unavailable()
    : this._(ProfileLookupStatus.unavailable, null);

  final ProfileLookupStatus status;

  /// Non-null only for [ProfileLookupStatus.found] and
  /// [ProfileLookupStatus.foundSettingsUnavailable].
  final UserProfile? profile;
}
