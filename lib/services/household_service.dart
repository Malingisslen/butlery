/// Household service for aggregating allergen preferences across household members.

// lib/services/household_service.dart

import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/user_service.dart';

/// Aggregates allergen preferences across household members for menu planning.
class HouseholdService extends BaseService {
  @override
  String get serviceName => 'HouseholdService';

  UnifiedFriendsService get _friendsService =>
      ServiceLocator.get<UnifiedFriendsService>();
  UserService get _userService => ServiceLocator.get<UserService>();

  /// Find the household group (first category marked as household).
  FriendCategory? getHousehold() {
    try {
      return _friendsService.categories.categoriesList.firstWhere(
        (c) => c.isHousehold,
      );
    } on StateError {
      return null;
    }
  }

  /// Whether the current user has a household group.
  bool get hasHousehold => getHousehold() != null;

  /// All member IDs in the household (including owner).
  List<String> getHouseholdMemberIds() {
    final household = getHousehold();
    if (household == null) {
      final userId = ServiceLocator.get<UserService>().currentUserProfile?.uid;
      return userId != null ? [userId] : [];
    }
    return household.allMemberIds;
  }

  /// Aggregate allergen preferences across all household members.
  /// - trackedAllergens: UNION (any member's allergy is respected)
  /// - trackedDietary: UNION (any member's restriction is respected)
  /// - includeUnknownInMenu: most conservative (false if ANY member has false)
  Future<UserAllergenPreferences> getAggregatedAllergenPreferences() async {
    final result = await executeServiceOperation(
      () => _aggregatePreferences(),
      operationName: 'getAggregatedAllergenPreferences',
    );
    return result ?? UserAllergenPreferences.defaults;
  }

  Future<UserAllergenPreferences> _aggregatePreferences() async {
    final memberIds = getHouseholdMemberIds();
    if (memberIds.length <= 1) {
      // Single user or no household — return current user's prefs
      return _userService.currentUserProfile?.allergenPreferences ??
          UserAllergenPreferences.defaults;
    }

    final profiles = <UserProfile>[];
    for (final memberId in memberIds) {
      final profile = await _userService.getUserProfile(memberId);
      if (profile != null) profiles.add(profile);
    }

    if (profiles.isEmpty) {
      return UserAllergenPreferences.defaults;
    }

    // Union allergens: if ANY member tracks an allergen, include it
    final unionAllergens = <String>{};
    // Union dietary: if ANY member has a restriction, include it
    final unionDietary = <String>{};
    // Most conservative: false if ANY member has false
    var includeUnknown = true;

    for (final profile in profiles) {
      final prefs = profile.allergenPreferences;
      if (prefs != null) {
        unionAllergens.addAll(prefs.trackedAllergens);
        unionDietary.addAll(prefs.trackedDietary);
        if (!prefs.includeUnknownInMenu) includeUnknown = false;
      }
    }

    return UserAllergenPreferences(
      trackedAllergens: unionAllergens,
      trackedDietary: unionDietary,
      includeUnknownInMenu: includeUnknown,
      showOnCards: true,
      showOnDetail: true,
      showCoverage: true,
    );
  }
}
