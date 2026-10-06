import 'package:clock/clock.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/household_allergen_share.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/repositories/interfaces/household_allergen_share_repository.dart';
import 'package:butlery/repositories/interfaces/household_repository.dart';

/// The member's own allergen shares, carrying preferences they are about to
/// save (DPIA R4, BUT-2267). The settings save writes these in the same batch
/// as the settings, so a household never filters on a list its owner has
/// already changed.
///
/// Not gated on `enable_household_allergen_sharing`: a share that exists was
/// consented to, and if the flag is switched off and on again it must not come
/// back stale.
class OwnAllergenShareMirror {
  const OwnAllergenShareMirror({
    HouseholdRepository? householdRepository,
    HouseholdAllergenShareRepository? shareRepository,
  }) : _householdRepository = householdRepository,
       _shareRepository = shareRepository;

  final HouseholdRepository? _householdRepository;
  final HouseholdAllergenShareRepository? _shareRepository;

  /// Every share [userId] holds, in each household they are in, with
  /// [preferences] in place of the old list and the stored consent record
  /// unchanged. Empty when they share nothing.
  ///
  /// Throws when a share's existence cannot be read: saving the settings
  /// without it is exactly the lag this exists to prevent, so the save must
  /// fail rather than go ahead. A row of their own that is corrupt is skipped,
  /// because the household's read skips it too, so it filters nothing.
  Future<List<HouseholdAllergenShare>> sharesFor(
    String userId,
    UserAllergenPreferences preferences,
  ) async {
    final households =
        _householdRepository ?? ServiceLocator.tryGet<HouseholdRepository>();
    final shares =
        _shareRepository ??
        ServiceLocator.tryGet<HouseholdAllergenShareRepository>();
    if (households == null || shares == null) return const [];

    final now = clock.now();
    final mirrored = <HouseholdAllergenShare>[];
    for (final household in await households.getForUser(userId)) {
      final HouseholdAllergenShare? own;
      try {
        own = await shares.getOwn(household.id);
      } on FormatException catch (e) {
        AppLogger.warning('Not mirroring a corrupt allergen share: $e');
        continue;
      }
      if (own == null) continue;
      mirrored.add(
        own.copyWith(
          trackedAllergens: preferences.trackedAllergens,
          trackedDietary: preferences.trackedDietary,
          includeUnknownInMenu: preferences.includeUnknownInMenu,
          updatedAt: now,
        ),
      );
    }
    return mirrored;
  }
}
