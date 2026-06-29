import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/household_roster_member.dart';
import 'package:butlery/repositories/interfaces/household_repository.dart';
import 'package:butlery/services/family/family_rating_service.dart';
import 'package:butlery/services/family/household_roster_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';

/// Drives the "vad tyckte ni?" family rating-entry screen — one star row per
/// present diner ("hand the phone around"). Pre-fills each row with that
/// member's last verdict on the recipe (latest-verdict-wins = an edit), and on
/// save upserts via [FamilyRatingService] (which mirrors a genuine adult
/// self-rating to their personal/social rating; proxy entries never do).
///
/// [presentMemberIds] are the diners who ate (from the who's-eating pick). When
/// null — the manual "Betygsätt som familj" entry point — every roster member
/// is shown.
class FamilyRatingEntryViewModel extends BaseViewModel {
  final String recipeId;
  final List<String>? presentMemberIds;

  final HouseholdRepository _householdRepository;
  final HouseholdRosterService _rosterService;
  final FamilyRatingService _familyRatingService;
  final PermissionService _permissionService;

  FamilyRatingEntryViewModel({
    required this.recipeId,
    this.presentMemberIds,
    HouseholdRepository? householdRepository,
    HouseholdRosterService? rosterService,
    FamilyRatingService? familyRatingService,
    PermissionService? permissionService,
  }) : _householdRepository =
           householdRepository ?? ServiceLocator.get<HouseholdRepository>(),
       _rosterService =
           rosterService ?? ServiceLocator.get<HouseholdRosterService>(),
       _familyRatingService =
           familyRatingService ?? ServiceLocator.get<FamilyRatingService>(),
       _permissionService =
           permissionService ?? ServiceLocator.get<PermissionService>();

  String? _householdId;
  String? _currentUid;
  List<HouseholdRosterMember> _present = const [];
  final Map<String, int> _stars = <String, int>{};

  List<HouseholdRosterMember> get present => _present;

  /// The current member's previously-stored verdict, or 0 when unrated.
  int starsFor(String memberId) => _stars[memberId] ?? 0;

  /// Whether [memberId] is the logged-in account holder (their row is a real
  /// self-rating; everyone else's is entered on their behalf).
  bool isHolder(String memberId) => memberId == _currentUid;

  /// True when at least one row carries a 1–5 verdict (gates the save button).
  bool get hasAnyRating => _stars.values.any((s) => s >= 1 && s <= 5);

  Future<void> load() async {
    await executeAsyncVoid(() async {
      final uid = _permissionService.currentUserId;
      if (uid == null) {
        throw StateError('Ingen inloggad användare');
      }
      _currentUid = uid;
      final household = await _householdRepository.ensureForUser(uid);
      _householdId = household.id;

      final roster = await _rosterService.getRoster(household.id);
      if (presentMemberIds == null) {
        _present = roster;
      } else {
        final present = presentMemberIds!.toSet();
        _present = roster.where((m) => present.contains(m.memberId)).toList();
      }

      // Pre-fill from existing verdicts so re-rating is an edit, not a reset.
      final existing = await _familyRatingService.getMemberRatings(
        householdId: household.id,
        recipeId: recipeId,
      );
      _stars.clear();
      for (final r in existing) {
        if (r.hasValidStars) _stars[r.memberId] = r.stars;
      }
    }, errorPrefix: 'Kunde inte ladda betygssättningen');
  }

  void setStars(String memberId, int stars) {
    _stars[memberId] = stars;
    notifyListeners();
  }

  /// Persist every present diner's 1–5 verdict (empty rows are skipped — a
  /// no-write, not a zero). Returns true when the batch of writes succeeded.
  Future<bool> save() async {
    return executeAsyncVoid(() async {
      final householdId = _householdId;
      final uid = _currentUid;
      if (householdId == null || uid == null) {
        throw StateError('Ingen aktiv hushållssession');
      }

      for (final member in _present) {
        final stars = _stars[member.memberId] ?? 0;
        if (stars < 1 || stars > 5) continue;
        await _familyRatingService.rateAsFamily(
          recipeId: recipeId,
          householdId: householdId,
          memberId: member.memberId,
          memberType: member.type,
          stars: stars,
          enteredByUid: uid,
        );
      }
    }, errorPrefix: 'Kunde inte spara betyget');
  }
}
