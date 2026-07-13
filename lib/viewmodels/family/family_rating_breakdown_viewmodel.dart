import 'dart:async';

import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
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

  static const _emptySummary = FamilyRatingSummary(
    recipeId: '',
    familyAverage: 0,
    familyRatingCount: 0,
  );

  FamilyRatingSummary _summary = _emptySummary;
  List<DinerRatingDisplay> _rows = const [];

  StreamSubscription<List<FamilyRating>>? _subscription;
  Completer<void>? _firstEmission;
  String? _householdId;
  List<HouseholdRosterMember> _roster = const [];

  // Monotonic tag per emission handler. Because each handler awaits a roster
  // read, a slow earlier emission could otherwise apply after a newer one and
  // show stale state; a handler only applies if it is still the latest.
  int _generation = 0;

  bool get hasFamilyRatings => _summary.hasRatings;
  String get familyAverageDisplay => _summary.displayAverage;
  int get familyCount => _summary.familyRatingCount;
  List<DinerRatingDisplay> get rows => _rows;

  /// Subscribe to live family ratings for this recipe (BUT-1461) so the
  /// breakdown updates when another member rates on their own device. Loading
  /// clears once the first emission resolves; the subscription is cancelled in
  /// [dispose].
  Future<void> startListening() async {
    await executeAsyncVoid(() async {
      final uid = _permissionService.currentUserId;
      if (uid == null) {
        throw StateError('Ingen inloggad användare');
      }
      final household = await _householdRepository.ensureForUser(uid);
      _householdId = household.id;
      // The view may have been torn down during the await above; don't open a
      // subscription dispose() has already run past (it would leak a live
      // Firestore listener forever).
      if (isDisposed) return;

      await _subscription?.cancel();
      final firstEmission = Completer<void>();
      _firstEmission = firstEmission;
      _subscription = _familyRatingService
          .watchMemberRatings(householdId: household.id, recipeId: recipeId)
          .listen(
            (ratings) => unawaited(_onRatings(ratings)),
            onError: _onEmissionError,
          );
      // Await the first snapshot so loading clears only once the breakdown has
      // resolved (data, empty, or a swallowed read failure). dispose() also
      // completes this, so a fast open/close can't leave it suspended.
      await firstEmission.future;
    }, errorPrefix: 'Kunde inte ladda betygen');
  }

  /// Handle one live emission. The roster is (re)read only when there are
  /// verdicts to attribute — skipped for a not-yet-rated recipe (the common
  /// case), and refreshed per rating-bearing emission so a member added since
  /// the view opened gets a row (and the count stays right).
  Future<void> _onRatings(List<FamilyRating> ratings) async {
    if (isDisposed) return;
    final gen = ++_generation;
    List<HouseholdRosterMember> roster;
    try {
      final hasVerdicts = ratings.any((r) => r.hasValidStars);
      roster = hasVerdicts
          ? await _rosterService.getRoster(_householdId!)
          : const <HouseholdRosterMember>[];
    } catch (e) {
      _onEmissionError(e);
      return;
    }
    // Superseded by a newer emission (or disposed) while awaiting the roster —
    // drop this stale result so it can't overwrite fresher state.
    if (isDisposed || gen != _generation) {
      _completeFirstEmission();
      return;
    }
    _roster = roster;
    _applyRatings(ratings);
    notifyListeners();
    _completeFirstEmission();
  }

  /// A read failure hides the section ONLY if nothing has rendered yet (the
  /// first emission), matching the pre-live behaviour where a failed read simply
  /// rendered nothing. Once the breakdown is showing data, a transient blip
  /// keeps the last-known rows rather than erasing a visible section. Firestore
  /// terminates the stream on error; re-opening the view re-subscribes.
  void _onEmissionError(Object e) {
    // Supersede any in-flight _onRatings so a roster read that resolves AFTER
    // this error can't re-apply the pre-error snapshot on a now-dead stream.
    _generation++;
    AppLogger.error('Family rating breakdown stream failed', e);
    final isFirst = !(_firstEmission?.isCompleted ?? true);
    if (isFirst && !isDisposed) {
      _summary = _emptySummary;
      _rows = const [];
      notifyListeners();
    }
    _completeFirstEmission();
  }

  void _completeFirstEmission() {
    final completer = _firstEmission;
    if (completer != null && !completer.isCompleted) completer.complete();
  }

  /// Rebuild the per-diner rows (roster order, only members who rated). The
  /// summary comes from the FULL rating set so the detail count/average matches
  /// the recipe-card pill, which denormalises the same set.
  void _applyRatings(List<FamilyRating> ratings) {
    _summary = FamilyRatingSummary.fromRatings(recipeId, ratings);
    if (!_summary.hasRatings) {
      _rows = const [];
      return;
    }

    final byId = {for (final m in _roster) m.memberId: m};
    final byRecipient = {
      for (final r in ratings)
        if (r.hasValidStars) r.memberId: r,
    };

    _rows = [
      for (final member in _roster)
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
  }

  @override
  void dispose() {
    _subscription?.cancel();
    // Release a startListening() still awaiting the first emission (a dispose
    // between subscribe and the first snapshot would otherwise suspend forever).
    _completeFirstEmission();
    super.dispose();
  }
}
