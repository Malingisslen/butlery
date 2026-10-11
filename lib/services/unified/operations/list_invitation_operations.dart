import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/social_request.dart';
import 'package:butlery/repositories/firebase/friends/list_invitation_repository.dart';
import 'package:butlery/services/analytics_service.dart';

enum ListInvitationOutcome {
  sent,
  accepted,
  alreadyMember,
  declined,
  revoked,

  /// The server refused: the invitation is spent, expired, void or not the
  /// caller's. One word on purpose, so nothing about the inviter leaks.
  notAvailable,

  offline,
  failed,
}

class ListInviteSendResult {
  const ListInviteSendResult(this.outcome, [this.result]);

  final ListInvitationOutcome outcome;

  /// Set when [outcome] is [ListInvitationOutcome.sent].
  final SendListInvitationsResult? result;
}

/// What an invite attempt means for the inviter's screen. A skip that only
/// repeats what is already true (member, invited, self) is not listed; a
/// refusal the inviter must not be able to tell apart (not a friend, blocked,
/// declined) and a call that never went through both land in [notInvited].
class ListInviteSummary {
  const ListInviteSummary({
    this.invited = const [],
    this.notInvited = const [],
    this.outcome = ListInvitationOutcome.sent,
  });

  final List<String> invited;
  final List<String> notInvited;

  /// [ListInvitationOutcome.sent] when the callable answered, otherwise why
  /// it did not (every requested id is then in [notInvited]).
  final ListInvitationOutcome outcome;

  bool get callFailed => outcome != ListInvitationOutcome.sent;
}

/// Invitations to a shared shopping list (BUT-2089), reached through
/// `UnifiedFriendsService.invitations.listInvitations`. Turns the repository's
/// exceptions into an outcome the view model can render.
class ListInvitationOperations {
  ListInvitationOperations({
    required ListInvitationRepository repository,
    required String? Function() getCurrentUserId,
    AnalyticsService? analytics,
  }) : _repository = repository,
       _getCurrentUserId = getCurrentUserId,
       _analytics = analytics ?? ServiceLocator.tryGet<AnalyticsService>();

  final ListInvitationRepository _repository;
  final String? Function() _getCurrentUserId;
  final AnalyticsService? _analytics;

  String? get currentUserId => _getCurrentUserId();

  Stream<List<SocialRequest>> get pendingReceived {
    final uid = _getCurrentUserId();
    if (uid == null) return const Stream.empty();
    return _repository.receivedListInvitationsStream(uid);
  }

  /// Pending invitations the signed-in user has sent for [listId].
  Stream<List<SocialRequest>> pendingSentForList(String listId) {
    final uid = _getCurrentUserId();
    if (uid == null || listId.isEmpty) return const Stream.empty();
    return _repository.sentListInvitationsStream(uid, listId);
  }

  /// Sends invitations and folds the answer into a [ListInviteSummary]; logs
  /// the analytics event when at least one went out.
  Future<ListInviteSummary> invite({
    required String listId,
    required List<String> userIds,
    required String permission,
  }) async {
    final sent = await sendListInvitations(
      listId: listId,
      userIds: userIds,
      permission: permission,
    );
    final result = sent.result;
    if (result == null) {
      return ListInviteSummary(
        notInvited: List.of(userIds),
        outcome: sent.outcome,
      );
    }
    if (result.sent.isNotEmpty) {
      unawaited(
        _analytics?.social.logListInvitationSent(
          count: result.sent.length,
        ),
      );
    }
    return ListInviteSummary(
      invited: result.sent.keys.toList(),
      notInvited: [
        for (final skip in result.skipped)
          if (skip.reason == ListInviteSkipReason.notFriends ||
              skip.reason == ListInviteSkipReason.unavailable)
            skip.userId,
      ],
    );
  }

  Future<ListInviteSendResult> sendListInvitations({
    required String listId,
    required List<String> userIds,
    required String permission,
  }) async {
    if (listId.isEmpty || userIds.isEmpty) {
      return const ListInviteSendResult(ListInvitationOutcome.failed);
    }
    try {
      final result = await _repository.sendListInvitationsViaFunction(
        listId: listId,
        userIds: userIds,
        permission: permission,
      );
      return ListInviteSendResult(ListInvitationOutcome.sent, result);
    } catch (e) {
      return ListInviteSendResult(_outcomeFor(e, 'send list invitations'));
    }
  }

  Future<ListInvitationOutcome> acceptListInvitation(
    String invitationId,
  ) async {
    try {
      final result = await _repository.acceptListInvitationViaFunction(
        invitationId,
      );
      return result.alreadyMember
          ? ListInvitationOutcome.alreadyMember
          : ListInvitationOutcome.accepted;
    } catch (e) {
      return _outcomeFor(e, 'accept list invitation');
    }
  }

  Future<ListInvitationOutcome> declineListInvitation(
    String invitationId,
  ) async {
    try {
      await _repository.declineListInvitation(invitationId);
      return ListInvitationOutcome.declined;
    } catch (e) {
      return _outcomeFor(e, 'decline list invitation');
    }
  }

  Future<ListInvitationOutcome> revokeListInvitation(
    String invitationId,
  ) async {
    try {
      await _repository.revokeListInvitation(invitationId);
      return ListInvitationOutcome.revoked;
    } catch (e) {
      return _outcomeFor(e, 'revoke list invitation');
    }
  }

  ListInvitationOutcome _outcomeFor(Object error, String what) {
    AppLogger.error('Failed to $what', error);
    if (error is FirebaseException) {
      if (error.code == 'failed-precondition') {
        return ListInvitationOutcome.notAvailable;
      }
      if (error.code == 'unavailable') return ListInvitationOutcome.offline;
    }
    // The row is gone: the sender took it back before the recipient acted.
    if (error is ResourceNotFoundException) {
      return ListInvitationOutcome.notAvailable;
    }
    return ListInvitationOutcome.failed;
  }
}
