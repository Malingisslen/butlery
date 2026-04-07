/// ViewModel for menu slot voting — manages vote state for a collaborative menu.

// lib/viewmodels/menu_voting_viewmodel.dart

import 'dart:async';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/realtime/menu_slot_vote.dart';
import 'package:butlery/services/menu_voting_service.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';

class MenuVotingViewModel extends BaseViewModel {
  final String menuId;
  final MenuVotingService _votingService;

  List<MenuSlotVote> _votes = [];
  StreamSubscription<List<MenuSlotVote>>? _votesSubscription;

  MenuVotingViewModel({required this.menuId})
      : _votingService = ServiceLocator.get<MenuVotingService>();

  List<MenuSlotVote> get activeVotes =>
      _votes.where((v) => v.isActive).toList();

  List<MenuSlotVote> get resolvedVotes =>
      _votes.where((v) => v.isResolved).toList();

  List<MenuSlotVote> get allVotes => List.unmodifiable(_votes);

  /// Get the active vote for a specific menu slot (if any).
  MenuSlotVote? getVoteForSlot(String category, int slotIndex) {
    try {
      return _votes.firstWhere(
        (v) => v.category == category && v.slotIndex == slotIndex && v.isActive,
      );
    } on StateError {
      return null;
    }
  }

  /// Subscribe to vote updates for this menu.
  void subscribe() {
    _votesSubscription?.cancel();
    _votesSubscription =
        _votingService.watchVotesForMenu(menuId).listen((votes) {
      if (isDisposed) return;
      _votes = votes;
      notifyListeners();
    });
  }

  /// Create a new vote for a menu slot.
  Future<bool> createVote({
    required String category,
    required int slotIndex,
    required List<VoteOption> alternatives,
    Duration votingWindow = const Duration(hours: 24),
  }) async {
    final result = await _votingService.createVote(
      menuId: menuId,
      category: category,
      slotIndex: slotIndex,
      alternatives: alternatives,
      votingWindow: votingWindow,
    );
    return result != null;
  }

  /// Cast a vote on an active vote.
  Future<bool> castVote(String voteId, String optionId) async {
    return await _votingService.castVote(menuId, voteId, optionId);
  }

  /// Resolve a vote (determine winner).
  Future<bool> resolveVote(String voteId) async {
    return await _votingService.resolveVote(menuId, voteId);
  }

  /// Add an alternative recipe to an open vote.
  Future<bool> addAlternative(String voteId, VoteOption option) async {
    return await _votingService.addAlternative(menuId, voteId, option);
  }

  @override
  void dispose() {
    _votesSubscription?.cancel();
    super.dispose();
  }
}
