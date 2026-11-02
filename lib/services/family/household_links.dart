// BUT-1508: what the household and allergen readers reach for. Every link may
// return null, because each of these is optional where it is read: the
// services are user-scoped and replaced at sign-in, and a reader that finds
// one missing takes its own "not wired" path. Read at each call, never kept.
library;

import 'package:butlery/repositories/interfaces/diner_profile_repository.dart';
import 'package:butlery/repositories/interfaces/household_allergen_share_repository.dart';
import 'package:butlery/repositories/interfaces/household_repository.dart';
import 'package:butlery/services/family/household_roster_service.dart';
import 'package:butlery/services/feature_flags/feature_flag_service.dart';
import 'package:butlery/services/household_service.dart';

class HouseholdLinks {
  const HouseholdLinks({
    required this.featureFlags,
    required this.households,
    required this.dinerProfiles,
    required this.roster,
    required this.householdService,
    required this.allergenShares,
    required this.currentUserId,
  });

  final FeatureFlagService? Function() featureFlags;
  final HouseholdRepository? Function() households;
  final DinerProfileRepository? Function() dinerProfiles;
  final HouseholdRosterService? Function() roster;
  final HouseholdService? Function() householdService;
  final HouseholdAllergenShareRepository? Function() allergenShares;

  /// The PERMISSION handle's user id, never `currentUserProfile`: the
  /// household repository refuses a caller that is not the named user.
  final String? Function() currentUserId;
}
