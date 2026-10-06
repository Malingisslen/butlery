import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/household.dart';
import 'package:butlery/repositories/interfaces/household_repository.dart';
import 'package:butlery/services/feature_flags/feature_flag_service.dart';
import 'package:butlery/services/permission_service.dart';

/// The household whose allergen shares this device reads (BUT-2267): whether
/// it could tell at all, whether sharing is on, and the household when there
/// is one.
class ActiveHousehold {
  const ActiveHousehold(this.household) : known = true, sharingOn = true;
  const ActiveHousehold.sharingOff()
    : household = null,
      known = true,
      sharingOn = false;
  const ActiveHousehold.unknown()
    : household = null,
      known = false,
      sharingOn = false;

  final Household? household;
  final bool known;
  final bool sharingOn;

  /// Off is KNOWLEDGE (an empty result, never a degraded one); a flag service
  /// or repository that is not there, or a read that failed, is IGNORANCE, and
  /// must not be spelled the same way.
  static Future<ActiveHousehold> resolve(String logTag) async {
    final flags = ServiceLocator.tryGet<FeatureFlagService>();
    if (flags == null) return const ActiveHousehold.unknown();
    if (!flags.isEnabled(FeatureFlags.enableHouseholdAllergenSharing)) {
      return const ActiveHousehold.sharingOff();
    }
    final householdRepository = ServiceLocator.tryGet<HouseholdRepository>();
    // The PERMISSION handle, not `currentUserProfile`: `getForUser` refuses a
    // caller that is not the named user, so this is an auth check, and the two
    // handles disagreeing during an auth transition would read as "no
    // household".
    final userId = ServiceLocator.tryGet<PermissionService>()?.currentUserId;
    if (householdRepository == null || userId == null) {
      return const ActiveHousehold.unknown();
    }
    try {
      return ActiveHousehold(
        await householdRepository.getActiveForUser(userId),
      );
    } catch (e) {
      AppLogger.warning('Could not read the active household: $e', logTag);
      return const ActiveHousehold.unknown();
    }
  }
}
