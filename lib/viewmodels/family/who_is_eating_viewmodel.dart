import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/household_roster_member.dart';
import 'package:butlery/repositories/interfaces/cook_event_repository.dart';
import 'package:butlery/repositories/interfaces/household_repository.dart';
import 'package:butlery/services/family/household_roster_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';

/// Drives the "vem åt?" (who's eating) picker shown when a recipe is marked as
/// cooked. Loads the household roster and pre-selects attendees using the
/// "remember last time" rule: the members of the caller's most recent cook
/// event that recorded attendance, intersected with the current roster; on
/// first use (no prior attendance) everyone is selected.
///
/// The picker is a lightweight attendance pick — it never writes; the caller
/// passes [selectedMemberIds] to `markAsCooked`.
class WhoIsEatingViewModel extends BaseViewModel {
  final HouseholdRepository _householdRepository;
  final HouseholdRosterService _rosterService;
  final CookEventRepository _cookEventRepository;
  final PermissionService _permissionService;

  WhoIsEatingViewModel({
    HouseholdRepository? householdRepository,
    HouseholdRosterService? rosterService,
    CookEventRepository? cookEventRepository,
    PermissionService? permissionService,
  }) : _householdRepository =
           householdRepository ?? ServiceLocator.get<HouseholdRepository>(),
       _rosterService =
           rosterService ?? ServiceLocator.get<HouseholdRosterService>(),
       _cookEventRepository =
           cookEventRepository ?? ServiceLocator.get<CookEventRepository>(),
       _permissionService =
           permissionService ?? ServiceLocator.get<PermissionService>();

  List<HouseholdRosterMember> _roster = const [];
  final Set<String> _selected = <String>{};

  List<HouseholdRosterMember> get roster => _roster;
  bool isSelected(String memberId) => _selected.contains(memberId);
  int get selectedCount => _selected.length;
  List<String> get selectedMemberIds => _selected.toList();

  /// Load the roster and seed the selection from the "remember last time" rule.
  Future<void> load() async {
    await executeAsyncVoid(() async {
      final uid = _permissionService.currentUserId;
      if (uid == null) {
        throw StateError('Ingen inloggad användare');
      }
      final household = await _householdRepository.ensureForUser(uid);
      _roster = await _rosterService.getRoster(household.id);
      final rosterIds = _roster.map((m) => m.memberId).toSet();

      // Intersect last-time's attendees with today's roster so a since-removed
      // member never reappears as "eating"; fall back to everyone when there's
      // no prior attendance or none of the prior set is still present.
      final last = await _cookEventRepository.recentAttendeeMemberIds(uid);
      final seed = last.where(rosterIds.contains).toSet();
      _selected
        ..clear()
        ..addAll(seed.isEmpty ? rosterIds : seed);
    }, errorPrefix: 'Kunde inte ladda hushållet');
  }

  void toggle(String memberId) {
    if (!_selected.remove(memberId)) {
      _selected.add(memberId);
    }
    notifyListeners();
  }
}
