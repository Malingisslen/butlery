import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/household_roster_member.dart';
import 'package:butlery/models/profile_lookup.dart';
import 'package:butlery/repositories/interfaces/diner_profile_repository.dart';
import 'package:butlery/repositories/interfaces/household_repository.dart';
import 'package:butlery/services/user_service.dart';

/// Resolves a household's full roster — account holders plus non-account diner
/// profiles — into one unified [HouseholdRosterMember] list.
///
/// This is the single source of "who is in this household" for family rating,
/// who's-eating attendance, and present-aware menu personalization. Reads are
/// membership-gated by the underlying repositories; a non-member caller (or an
/// unknown household) yields an empty roster rather than an error.
class HouseholdRosterService extends BaseService {
  @override
  String get serviceName => 'HouseholdRosterService';

  HouseholdRepository get _householdRepository =>
      ServiceLocator.get<HouseholdRepository>();
  DinerProfileRepository get _dinerProfileRepository =>
      ServiceLocator.get<DinerProfileRepository>();
  UserService get _userService => ServiceLocator.get<UserService>();

  /// Resolve every member of [householdId] — accounts first (in stored member
  /// order), then diner profiles. Returns an empty list if the household is
  /// missing or the caller is not a member.
  Future<List<HouseholdRosterMember>> getRoster(String householdId) async {
    final result = await executeServiceOperation(
      () => _resolveRoster(householdId),
      operationName: 'getRoster',
    );
    return result ?? const <HouseholdRosterMember>[];
  }

  Future<List<HouseholdRosterMember>> _resolveRoster(
    String householdId,
  ) async {
    final household = await _householdRepository.read(householdId);
    if (household == null) return const <HouseholdRosterMember>[];

    final members = <HouseholdRosterMember>[];

    // Account holders. Batch the profile fetch so a five-person household is one
    // read, not five; fall back to the bare userId for a display name if a
    // profile can't be resolved (deleted account, transient miss).
    //
    // A failed read (BUT-2027's `unavailableIds`) is logged rather than
    // silently absorbed into the same fallback as a confirmed-absent
    // profile: this roster feeds present-diner allergen filtering
    // (`MenuGenerator._presentAllergenPrefs`), and that union already treats
    // a null `allergenPreferences` as "no allergens declared" with no floor
    // for "could not check" — a residual named here rather than fixed, since
    // closing it is a BUT-1663-style safety redesign of that union, not a
    // migration of this method's return type.
    final userIds = household.members.map((m) => m.userId).toList();
    final batch = userIds.isEmpty
        ? const ProfileBatchLookup(
            profiles: [],
            missingIds: {},
            unavailableIds: {},
          )
        : await _userService.getUserProfiles(userIds);
    if (batch.unavailableIds.isNotEmpty) {
      AppLogger.warning(
        'HouseholdRosterService: could not read '
        '${batch.unavailableIds.length}/${userIds.length} member profile(s) '
        'for household $householdId',
      );
    }
    final profiles = {for (final p in batch.profiles) p.uid: p};
    for (final member in household.members) {
      final profile = profiles[member.userId];
      members.add(
        HouseholdRosterMember.fromUser(
          userId: member.userId,
          displayName: profile?.displayName ?? member.userId,
          allergenPreferences: profile?.allergenPreferences,
        ),
      );
    }

    // Non-account diners.
    final diners = await _dinerProfileRepository.getByHousehold(householdId);
    for (final diner in diners) {
      members.add(HouseholdRosterMember.fromDinerProfile(diner));
    }

    return members;
  }
}
