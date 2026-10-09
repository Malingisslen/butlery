/// Menu voting service for collaborative menu decision-making.

// lib/services/menu_voting_service.dart

import 'package:clock/clock.dart';
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/realtime/menu_slot_vote.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/interfaces/menu_voting_repository.dart';
import 'package:butlery/services/permission_service.dart';

/// Starts, joins and settles votes on a live menu's slots. Every write goes to
/// the signed-in user's own ballot document; whether the vote is still open
/// and who started it is checked here, because the rules cannot see the
/// starter's document from anyone else's write (BUT-2118).
class MenuVotingService extends BaseService {
  @override
  String get serviceName => 'MenuVotingService';

  static const Duration votingWindow = Duration(hours: 24);

  MenuVotingRepository get _repository =>
      ServiceLocator.get<MenuVotingRepository>();

  String get _currentUserId =>
      ServiceLocator.get<PermissionService>().currentUserId.orEmpty();

  Stream<List<MenuBallot>> watchBallots(String menuId) =>
      _repository.watchBallots(menuId);

  /// A vote between the dish on the slot now and [proposal].
  Future<bool> startVote({
    required String menuId,
    required String category,
    required int slotIndex,
    required Recipe current,
    required Recipe proposal,
  }) => _write(menuId, 'startVote', (ballot) {
    final key = MenuBallot.slotKey(category, slotIndex);
    final previous = ballot.started[key];
    if (previous != null && clock.now().isBefore(previous.deadline)) {
      final settled = ballot.resolved.containsKey(previous.id);
      if (!settled) return null;
    }
    final vote = StartedVote.create(
      options: [
        VoteOption.fromRecipe(current),
        VoteOption.fromRecipe(proposal),
      ],
      window: votingWindow,
    );
    // A vote that is replaced takes its settlement record with it.
    final resolved = {...ballot.resolved}..remove(previous?.id);
    return ballot.copyWith(
      started: {...ballot.started, key: vote},
      resolved: resolved,
    );
  });

  /// Adds [recipe] to [vote], one proposal per person and vote. The option
  /// carries how many had already voted, which the card shows.
  Future<bool> propose(String menuId, MenuSlotVote vote, Recipe recipe) =>
      _write(menuId, 'propose', (ballot) {
        if (!vote.isActive || ballot.proposals.containsKey(vote.id)) {
          return null;
        }
        return ballot.copyWith(
          proposals: {
            ...ballot.proposals,
            vote.id: VoteOption.fromRecipe(
              recipe,
              votersBefore: vote.totalVotes,
            ),
          },
        );
      });

  /// Casts the user's ballot, or moves it while the vote is open
  /// (produktregler 4.8).
  Future<bool> castVote(String menuId, MenuSlotVote vote, String optionId) =>
      _write(menuId, 'castVote', (ballot) {
        if (!vote.isActive ||
            vote.optionById(optionId) == null ||
            ballot.ballots[vote.id] == optionId) {
          return null;
        }
        return ballot.copyWith(ballots: {...ballot.ballots, vote.id: optionId});
      });

  /// Records [optionId] as the winner. Only the starter settles a vote, and
  /// the caller writes the dish into the menu first.
  Future<bool> recordWinner(
    String menuId,
    MenuSlotVote vote,
    String optionId,
  ) => _settle(
    menuId,
    vote,
    VoteResolution(
      outcome: VoteOutcome.winner,
      optionId: optionId,
      at: clock.now(),
    ),
  );

  /// Gives up the vote; the dish on the slot stays as it is.
  Future<bool> release(String menuId, MenuSlotVote vote) => _settle(
    menuId,
    vote,
    VoteResolution(outcome: VoteOutcome.released, at: clock.now()),
  );

  /// Opens the vote for another day from now.
  Future<bool> reopen(String menuId, MenuSlotVote vote) =>
      _write(menuId, 'reopen', (ballot) {
        final started = ballot.started[vote.slotKey];
        if (started == null ||
            started.id != vote.id ||
            ballot.resolved.containsKey(vote.id)) {
          return null;
        }
        return ballot.copyWith(
          started: {
            ...ballot.started,
            vote.slotKey: started.withDeadline(clock.now().add(votingWindow)),
          },
        );
      });

  Future<bool> _settle(
    String menuId,
    MenuSlotVote vote,
    VoteResolution resolution,
  ) => _write(menuId, 'settle', (ballot) {
    final started = ballot.started[vote.slotKey];
    if (started == null ||
        started.id != vote.id ||
        ballot.resolved.containsKey(vote.id)) {
      return null;
    }
    return ballot.copyWith(resolved: {...ballot.resolved, vote.id: resolution});
  });

  /// Applies [change] to the user's own document. A null from [change] means
  /// the step does not apply (the same choice again, vote closed, not the
  /// starter), and the call reports false without writing.
  Future<bool> _write(
    String menuId,
    String operationName,
    MenuBallot? Function(MenuBallot current) change,
  ) async {
    final result = await executeServiceOperation(
      () async {
        if (_currentUserId.isEmpty) return false;
        var applied = false;
        await _repository.updateOwnBallot(menuId, (current) {
          final next = change(current);
          applied = next != null;
          return next ?? current;
        });
        return applied;
      },
      operationName: operationName,
      requiresAuth: true,
    );
    return result ?? false;
  }
}
