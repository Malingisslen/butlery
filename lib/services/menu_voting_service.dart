/// Menu voting service for collaborative menu decision-making.

// lib/services/menu_voting_service.dart

import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/realtime/menu_slot_vote.dart';
import 'package:butlery/repositories/interfaces/menu_voting_repository.dart';
import 'package:butlery/services/permission_service.dart';

/// Manages menu slot voting — create votes, cast, resolve with winning recipe.
class MenuVotingService extends BaseService {
  @override
  String get serviceName => 'MenuVotingService';

  MenuVotingRepository get _repository =>
      ServiceLocator.get<MenuVotingRepository>();

  String get _currentUserId =>
      ServiceLocator.get<PermissionService>().currentUserId.orEmpty();

  /// Create a new vote for a menu slot.
  Future<MenuSlotVote?> createVote({
    required String menuId,
    required String category,
    required int slotIndex,
    required List<VoteOption> alternatives,
    Duration votingWindow = const Duration(hours: 24),
  }) async {
    return executeServiceOperation(
      () async {
        final userId = _currentUserId;
        final vote = MenuSlotVote.create(
          menuId: menuId,
          category: category,
          slotIndex: slotIndex,
          alternatives: alternatives,
          votingWindow: votingWindow,
          createdByUserId: userId,
        );
        return await _repository.createVote(vote);
      },
      operationName: 'createVote',
      requiresAuth: true,
    );
  }

  /// Cast a vote on a menu slot vote.
  Future<bool> castVote(String menuId, String voteId, String optionId) async {
    final result = await executeServiceOperation(
      () async {
        final userId = _currentUserId;
        final vote = await _repository.getVote(menuId, voteId);
        if (vote == null) throw Exception('Vote not found');
        if (!vote.isActive) throw Exception('Vote is no longer active');
        if (vote.hasVoted(userId)) throw Exception('Already voted');

        await _repository.castVote(menuId, voteId, userId, optionId);
        return true;
      },
      operationName: 'castVote',
      requiresAuth: true,
    );
    return result ?? false;
  }

  /// Resolve a vote — determine winner and update the menu.
  Future<bool> resolveVote(String menuId, String voteId) async {
    final result = await executeServiceOperation(
      () async {
        final vote = await _repository.getVote(menuId, voteId);
        if (vote == null) throw Exception('Vote not found');
        if (vote.isResolved) return true;

        final leading = vote.leadingOption;
        if (leading == null) throw Exception('No votes cast');

        await _repository.resolveVote(menuId, voteId, leading.id);
        return true;
      },
      operationName: 'resolveVote',
      requiresAuth: true,
    );
    return result ?? false;
  }

  /// Add an alternative recipe to an open vote.
  Future<bool> addAlternative(
      String menuId, String voteId, VoteOption option) async {
    final result = await executeServiceOperation(
      () async {
        final vote = await _repository.getVote(menuId, voteId);
        if (vote == null) throw Exception('Vote not found');
        if (!vote.isActive) throw Exception('Vote is no longer active');

        await _repository.addAlternative(menuId, voteId, option);
        return true;
      },
      operationName: 'addAlternative',
      requiresAuth: true,
    );
    return result ?? false;
  }

  /// Stream all votes for a menu.
  Stream<List<MenuSlotVote>> watchVotesForMenu(String menuId) =>
      _repository.watchVotesForMenu(menuId);

  /// Get only active (unresolved, not expired) votes for a menu.
  Future<List<MenuSlotVote>> getActiveVotesForMenu(String menuId) async {
    final result = await executeServiceOperation(
      () async {
        // Use a one-time listen to get current state
        final votes = await _repository.watchVotesForMenu(menuId).first;
        return votes.where((v) => v.isActive).toList();
      },
      operationName: 'getActiveVotesForMenu',
    );
    return result ?? [];
  }

  // Auth is validated by executeServiceOperation when requiresAuth: true
}
