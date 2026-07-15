import 'package:butlery/models/diner_profile.dart';
import 'package:butlery/models/family_rating.dart' show HouseholdMemberType;
import 'package:butlery/models/user_allergen_preferences.dart';

/// A unified household member for family rating, attendance, and menu
/// personalization.
///
/// A roster member is either a real app user (a household account holder) or a
/// non-account [DinerProfile] (a child or guest tracked only inside the
/// household). [memberId] is the stable key both representations share with
/// [FamilyRating.memberId] and with attendance lists — it is the account `userId`
/// for users and the `DinerProfile.id` for profiles, disambiguated by [type].
///
/// This is a read-model assembled by `HouseholdRosterService`; it is never
/// persisted on its own.
class HouseholdRosterMember {
  /// Account `userId` (when [type] is [HouseholdMemberType.user]) or
  /// `DinerProfile.id` (when [type] is [HouseholdMemberType.profile]).
  final String memberId;

  final HouseholdMemberType type;

  final String displayName;

  /// Known only for diner profiles; `null` for account holders (we don't track
  /// an adult user's age band).
  final DinerAgeBand? ageBand;

  /// True only for diner profiles whose [DinerProfile.isMinor] is set. Account
  /// holders are self-managing (ADR-0001 floors accounts at 15) and never
  /// require guardian consent, so they are reported as non-minors here.
  final bool isMinor;

  final String? avatarColor;

  /// Allergen preferences for present-aware menu filtering. Resolved from the
  /// user profile for accounts and from the diner profile for non-account
  /// members; may be `null` when none are recorded.
  final UserAllergenPreferences? allergenPreferences;

  /// Ingredients this member dislikes — a soft preference (not a safety
  /// constraint). Resolved from the diner profile for non-account members;
  /// empty when none are recorded. Menu generation does not yet consume it.
  final Set<String> dislikedIngredients;

  const HouseholdRosterMember({
    required this.memberId,
    required this.type,
    required this.displayName,
    required this.isMinor,
    this.ageBand,
    this.avatarColor,
    this.allergenPreferences,
    this.dislikedIngredients = const {},
  });

  bool get isUser => type == HouseholdMemberType.user;
  bool get isProfile => type == HouseholdMemberType.profile;

  factory HouseholdRosterMember.fromUser({
    required String userId,
    required String displayName,
    UserAllergenPreferences? allergenPreferences,
    Set<String> dislikedIngredients = const {},
    String? avatarColor,
  }) => HouseholdRosterMember(
    memberId: userId,
    type: HouseholdMemberType.user,
    displayName: displayName,
    isMinor: false,
    allergenPreferences: allergenPreferences,
    dislikedIngredients: dislikedIngredients,
    avatarColor: avatarColor,
  );

  factory HouseholdRosterMember.fromDinerProfile(DinerProfile profile) =>
      HouseholdRosterMember(
        memberId: profile.id,
        type: HouseholdMemberType.profile,
        displayName: profile.name,
        isMinor: profile.isMinor,
        ageBand: profile.ageBand,
        avatarColor: profile.avatarColor,
        allergenPreferences: profile.allergenPreferences,
        dislikedIngredients: profile.dislikedIngredients,
      );
}
