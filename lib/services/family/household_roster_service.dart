import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/household_roster_member.dart';
import 'package:butlery/models/user_profile.dart';
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
    final userIds = household.members.map((m) => m.userId).toList();
    final profiles = userIds.isEmpty
        ? <String, UserProfile>{}
        : {
            for (final p in await _userService.getUserProfiles(userIds))
              p.uid: p,
          };
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
