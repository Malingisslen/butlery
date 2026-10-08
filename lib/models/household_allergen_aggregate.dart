import 'package:butlery/models/user_allergen_preferences.dart';

/// The household's aggregated allergen preferences PLUS how complete the
/// roster was when they were built (BUT-1663).
///
/// A degraded aggregate is value-identical to a healthy one, so any caller
/// that tells the user something about "the household" — the opt-out safety
/// dialog, the menu-pool telemetry — has to be able to tell them apart.
class HouseholdAllergenAggregate {
  /// Every member resolved; [preferences] describes the household exactly.
  const HouseholdAllergenAggregate.complete(this.preferences)
    : unresolvedMemberIds = const [],
      missingMemberIds = const [],
      isRosterComplete = true;

  /// Every member accounted for, but some ids point at profiles that are not
  /// there (deleted account, stale roster entry). The union is exact for the
  /// members who exist, so the roster counts as COMPLETE — an absent person
  /// cannot be protected, and treating them as unknown-forever would hold the
  /// household in a safety crouch it can never leave (BUT-1663).
  const HouseholdAllergenAggregate.completeWithMissing({
    required this.preferences,
    required this.missingMemberIds,
  }) : unresolvedMemberIds = const [],
       isRosterComplete = true;

  /// At least one member could not be read. [preferences] is the union of the
  /// members that DID resolve, widened with the common-allergen safety floor,
  /// so it is a superset of what is known — never a substitute for it.
  const HouseholdAllergenAggregate.degraded({
    required this.preferences,
    this.unresolvedMemberIds = const [],
    this.missingMemberIds = const [],
  }) : isRosterComplete = false;

  final UserAllergenPreferences preferences;

  /// Member ids whose profile read FAILED on this pass — transient, so the
  /// aggregate fails safe. Empty on the whole-aggregation-failed path, where
  /// no individual member is to blame.
  final List<String> unresolvedMemberIds;

  /// BUT-1663: member ids whose profile document does not exist. Distinct from
  /// [unresolvedMemberIds]: this is a roster-hygiene problem, not an unknown
  /// allergen, so it does NOT degrade filtering.
  final List<String> missingMemberIds;

  final bool isRosterComplete;
}
