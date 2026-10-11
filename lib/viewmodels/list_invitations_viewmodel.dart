import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/mixins/state_notifier_mixin.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/social_request.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/unified/operations/list_invitation_operations.dart';

/// The invitee's side of shared shopping list invitations (BUT-2089): the
/// pending ones, and answering one. Rendering the outcome (snackbar text,
/// whether the card goes) is the view's; this decides only what stays listed.
class ListInvitationsViewModel extends ChangeNotifier
    with ErrorHandlingMixin, StateNotifierMixin {
  ListInvitationsViewModel({
    required ListInvitationOperations operations,
    AnalyticsService? analytics,
  }) : _operations = operations,
       _analytics = analytics ?? ServiceLocator.tryGet<AnalyticsService>() {
    _subscription = _operations.pendingReceived.listen(
      _onInvitations,
      onError: (Object e) {
        // The section is optional chrome on the shopping tab: a failed read
        // leaves it empty rather than breaking the tab.
        AppLogger.error('List invitations stream failed', e);
        _received = const [];
        setError(extractUserMessage(e));
      },
    );
  }

  final ListInvitationOperations _operations;
  final AnalyticsService? _analytics;
  StreamSubscription<List<SocialRequest>>? _subscription;

  List<SocialRequest> _received = const [];
  final Set<String> _responding = {};

  // Rows the server still lists as pending but the invitee has dealt with
  // here: refused as void, or the sender blocked. Kept so the next snapshot
  // cannot bring the card back.
  final Set<String> _dismissed = {};

  List<SocialRequest> get invitations => List.unmodifiable(
    _received.where((r) => !_dismissed.contains(r.id) && !r.isExpired),
  );

  bool isResponding(String invitationId) => _responding.contains(invitationId);

  void _onInvitations(List<SocialRequest> rows) {
    if (isDisposed) return;
    _received = rows;
    clearError();
    notifyListeners();
  }

  Future<ListInvitationOutcome> accept(String invitationId) async {
    final outcome = await _respond(
      invitationId,
      _operations.acceptListInvitation,
    );
    if (outcome == ListInvitationOutcome.accepted) {
      unawaited(_analytics?.social.logListInvitationAccepted());
    }
    return outcome;
  }

  Future<ListInvitationOutcome> decline(String invitationId) async {
    final outcome = await _respond(
      invitationId,
      _operations.declineListInvitation,
    );
    if (outcome == ListInvitationOutcome.declined) {
      unawaited(_analytics?.social.logListInvitationDeclined());
    }
    return outcome;
  }

  /// Hides every invitation from [userId] after the invitee blocked them.
  void dismissFrom(String userId) {
    _dismissed.addAll(
      _received.where((r) => r.fromUserId == userId).map((r) => r.id),
    );
    if (!isDisposed) notifyListeners();
  }

  Future<ListInvitationOutcome> _respond(
    String invitationId,
    Future<ListInvitationOutcome> Function(String) call,
  ) async {
    if (_responding.contains(invitationId)) return ListInvitationOutcome.failed;
    _responding.add(invitationId);
    if (!isDisposed) notifyListeners();
    try {
      final outcome = await call(invitationId);
      // Offline and failed leave the card for another try; every other
      // outcome means the invitation is settled or void.
      if (outcome != ListInvitationOutcome.offline &&
          outcome != ListInvitationOutcome.failed) {
        _dismissed.add(invitationId);
      }
      return outcome;
    } finally {
      _responding.remove(invitationId);
      if (!isDisposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
