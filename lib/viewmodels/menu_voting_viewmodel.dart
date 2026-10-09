/// ViewModel for menu slot voting — manages vote state for a collaborative menu.

// lib/viewmodels/menu_voting_viewmodel.dart

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/realtime/menu_slot_vote.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/menu_voting_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';

/// Writes a winning dish into the menu slot, as a swap would.
typedef ApplyDish =
    Future<void> Function(String category, int slotIndex, Recipe dish);

/// The votes on one live menu. The live session hands it the menu's roster
/// ([setParticipants]) and the menu write a winner needs ([applyDish]).
class MenuVotingViewModel extends BaseViewModel {
  final String menuId;
  final MenuVotingService _votingService;
  final ApplyDish? applyDish;

  /// A settled vote stays on the slot this long, so people see the outcome.
  static const Duration showDecidedFor = Duration(hours: 24);

  List<MenuBallot> _documents = const [];
  Set<String> _participantIds = const {};
  List<MenuSlotVote> _votes = const [];
  StreamSubscription<List<MenuBallot>>? _subscription;

  MenuVotingViewModel({
    required this.menuId,
    this.applyDish,
    MenuVotingService? votingService,
  }) : _votingService =
           votingService ?? ServiceLocator.get<MenuVotingService>();

  String get currentUserId =>
      ServiceLocator.get<PermissionService>().currentUserId.orEmpty();

  List<MenuSlotVote> get allVotes => List.unmodifiable(_votes);

  List<MenuSlotVote> get activeVotes =>
      _votes.where((v) => v.isActive).toList();

  /// The vote a slot shows: the newest one that is open, waiting on its
  /// starter, or settled with a winner within [showDecidedFor].
  MenuSlotVote? voteForSlot(String category, int slotIndex) {
    MenuSlotVote? best;
    for (final v in _votes) {
      if (v.category != category || v.slotIndex != slotIndex) continue;
      if (!_isShown(v)) continue;
      if (best == null || v.createdAt.isAfter(best.createdAt)) best = v;
    }
    return best;
  }

  bool _isShown(MenuSlotVote v) => switch (v.state) {
    SlotVoteState.released => false,
    SlotVoteState.decided => clock.now().isBefore(
      v.resolution!.at.add(showDecidedFor),
    ),
    _ => !v.isStale,
  };

  /// A new vote can start unless one is still running or waiting on its
  /// starter.
  bool canStartVote(String category, int slotIndex) {
    final v = voteForSlot(category, slotIndex);
    return v == null || v.state == SlotVoteState.decided;
  }

  bool hasProposed(MenuSlotVote vote) {
    for (final d in _documents) {
      if (d.userId == currentUserId) return d.proposals.containsKey(vote.id);
    }
    return false;
  }

  void setParticipants(Set<String> participantIds) {
    if (_sameSet(participantIds, _participantIds)) return;
    _participantIds = Set.unmodifiable(participantIds);
    _derive();
  }

  void subscribe() {
    _subscription?.cancel();
    _subscription = _votingService.watchBallots(menuId).listen(
      (documents) {
        if (isDisposed) return;
        _documents = documents;
        _derive();
      },
      // The votes keep their last state; the menu reports its own errors.
      onError: (Object e) =>
          AppLogger.error('[MenuVotingViewModel] ballots stream failed', e),
    );
  }

  void _derive() {
    _votes = MenuSlotVote.deriveAll(_documents, _participantIds);
    if (!isDisposed) notifyListeners();
  }

  Future<bool> startVote({
    required String category,
    required int slotIndex,
    required Recipe current,
    required Recipe proposal,
  }) {
    if (!canStartVote(category, slotIndex)) return Future.value(false);
    return _votingService.startVote(
      menuId: menuId,
      category: category,
      slotIndex: slotIndex,
      current: current,
      proposal: proposal,
    );
  }

  Future<bool> propose(MenuSlotVote vote, Recipe recipe) =>
      _votingService.propose(menuId, vote, recipe);

  Future<bool> castVote(MenuSlotVote vote, String optionId) =>
      _votingService.castVote(menuId, vote, optionId);

  /// The starter puts [optionId] on the slot. The dish is written first and
  /// the vote marked settled after, so a failed menu write leaves the vote
  /// open to try again rather than settled with nothing on the slot.
  Future<bool> settle(MenuSlotVote vote, String optionId) async {
    final option = vote.optionById(optionId);
    final apply = applyDish;
    if (option == null || apply == null || !vote.isStarter(currentUserId)) {
      return false;
    }
    try {
      await apply(vote.category, vote.slotIndex, option.toRecipe());
    } catch (e) {
      AppLogger.error('[MenuVotingViewModel] writing the winner failed', e);
      setError(AppLocale.current.menuVoteApplyFailed);
      return false;
    }
    return _votingService.recordWinner(menuId, vote, optionId);
  }

  Future<bool> release(MenuSlotVote vote) =>
      _votingService.release(menuId, vote);

  Future<bool> reopen(MenuSlotVote vote) => _votingService.reopen(menuId, vote);

  static bool _sameSet(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
