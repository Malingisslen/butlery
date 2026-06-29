import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/family_rating.dart';
import 'package:butlery/models/household_roster_member.dart';
import 'package:butlery/repositories/interfaces/household_repository.dart';
import 'package:butlery/services/family/family_rating_service.dart';
import 'package:butlery/services/family/household_roster_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';

/// One resolved per-diner row for the detail-page breakdown — a stored verdict
/// joined to the roster member it belongs to, plus the "inmatat av {name}"
/// attribution when an account holder's verdict was entered by someone else.
class DinerRatingDisplay {
  final HouseholdRosterMember member;
  final int stars;
  final DateTime lastUpdated;
  final bool isProxy;

  /// Display name of whoever entered a proxy verdict; null for self/profile.
  final String? enteredByName;

  const DinerRatingDisplay({
    required this.member,
    required this.stars,
    required this.lastUpdated,
    required this.isProxy,
    this.enteredByName,
  });
}

/// Drives the recipe-detail family-rating breakdown: the household average plus
/// one row per member who has rated. Read-only — re-rating happens on the entry
/// screen (the rows deep-link into it). Community/personal comparison values
/// come from the recipe object in the view, not this VM.
class FamilyRatingBreakdownViewModel extends BaseViewModel {
  final String recipeId;

  final HouseholdRepository _householdRepository;
  final HouseholdRosterService _rosterService;
  final FamilyRatingService _familyRatingService;
  final PermissionService _permissionService;

  FamilyRatingBreakdownViewModel({
    required this.recipeId,
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

  FamilyRatingSummary _summary = const FamilyRatingSummary(
    recipeId: '',
    familyAverage: 0,
    familyRatingCount: 0,
  );
  List<DinerRatingDisplay> _rows = const [];

  bool get hasFamilyRatings => _summary.hasRatings;
  String get familyAverageDisplay => _summary.displayAverage;
  int get familyCount => _summary.familyRatingCount;
  List<DinerRatingDisplay> get rows => _rows;

  Future<void> load() async {
    await executeAsyncVoid(() async {
      final uid = _permissionService.currentUserId;
      if (uid == null) {
        throw StateError('Ingen inloggad användare');
      }
      final household = await _householdRepository.ensureForUser(uid);

      final ratings = await _familyRatingService.getMemberRatings(
        householdId: household.id,
        recipeId: recipeId,
      );
      _summary = FamilyRatingSummary.fromRatings(recipeId, ratings);

      // No verdicts → the section renders nothing, so skip the roster read
      // entirely (the common case for any not-yet-rated recipe). Cost: 2 reads
      // instead of 3 on every collapsed recipe-detail open.
      if (!_summary.hasRatings) {
        _rows = const [];
        return;
      }

      final roster = await _rosterService.getRoster(household.id);
      final byId = {for (final m in roster) m.memberId: m};

      final byRecipient = {
        for (final r in ratings)
          if (r.hasValidStars) r.memberId: r,
      };

      // Roster order, only members who have a verdict.
      _rows = [
        for (final member in roster)
          if (byRecipient[member.memberId] case final r?)
            DinerRatingDisplay(
              member: member,
              stars: r.stars,
              lastUpdated: r.lastUpdatedAt,
              isProxy: r.isProxyEntry,
              enteredByName: r.isProxyEntry
                  ? byId[r.enteredByUid]?.displayName
                  : null,
            ),
      ];
    }, errorPrefix: 'Kunde inte ladda betygen');
  }
}
