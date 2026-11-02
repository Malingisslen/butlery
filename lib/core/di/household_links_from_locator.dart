import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/repositories/interfaces/diner_profile_repository.dart';
import 'package:butlery/repositories/interfaces/household_allergen_share_repository.dart';
import 'package:butlery/repositories/interfaces/household_repository.dart';
import 'package:butlery/services/family/household_links.dart';
import 'package:butlery/services/family/household_roster_service.dart';
import 'package:butlery/services/feature_flags/feature_flag_service.dart';
import 'package:butlery/services/household_service.dart';
import 'package:butlery/services/permission_service.dart';

/// [HouseholdLinks] over whatever is registered when each link is called, for
/// the DI modules and for the view models that build a household reader.
HouseholdLinks householdLinksFromLocator() => HouseholdLinks(
  featureFlags: ServiceLocator.tryGet<FeatureFlagService>,
  households: ServiceLocator.tryGet<HouseholdRepository>,
  dinerProfiles: ServiceLocator.tryGet<DinerProfileRepository>,
  roster: ServiceLocator.tryGet<HouseholdRosterService>,
  householdService: ServiceLocator.tryGet<HouseholdService>,
  allergenShares: ServiceLocator.tryGet<HouseholdAllergenShareRepository>,
  currentUserId: () =>
      ServiceLocator.tryGet<PermissionService>()?.currentUserId,
);
