// lib/views/social/friend_requests/friend_request_actions.dart

import 'package:flutter/material.dart';

// Core
import 'package:butlery/core/base/base_action_handler.dart';

// Theme
import 'package:butlery/core/extensions/localization_extension.dart';

// ViewModels
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

/// Refactored FriendRequestActions using BaseActionHandler
/// This class provides standardized friend request operations with:
/// - Consistent batch operations with confirmation
/// - Proper error handling and user feedback
/// - Safe context handling for UI operations
/// - Standardized dialog patterns
class FriendRequestActions extends BaseActionHandler with ActionStateMixin {
  @override
  String get serviceName => 'FriendRequestActions';

  Future<void> acceptMultipleRequests(
    BuildContext context,
    FriendsViewModel viewModel,
    List<String> requestIds,
    void Function(List<String> landed)? onBatchSettled, {
    VoidCallback? onConfirmed,
  }) async {
    if (!validateContext(context) || requestIds.isEmpty) {
      showErrorMessage(context, context.l10n.socialNoRequestsSelected);
      return;
    }

    // Resolved before the await so the outcome message needs no BuildContext
    // once the batch returns.
    final l10n = context.l10n;

    final succeeded = await executeWithConfirmation<int>(
      context: context,
      action: () async {
        onConfirmed?.call();
        final landed = await viewModel.acceptFriendRequests(requestIds);
        // Unconditional: an empty result does not say whether the requests
        // failed or are gone, so the caller has to reconcile either way.
        onBatchSettled?.call(landed);
        return landed.length;
      },
      confirmationTitle: context.l10n.socialAcceptAllSelectedConfirm,
      confirmationMessage: context.l10n.socialAcceptAllSelectedMessage(
        requestIds.length,
      ),
      confirmActionText: context.l10n.socialAcceptAll,
      confirmationIcon: ButleryIcons.circleCheck,
      errorMessage: context.l10n.socialCouldNotAcceptAllRequests,
      metadata: {
        'request_count': requestIds.length,
        'action': 'accept_multiple',
      },
    );

    if (succeeded == null || !context.mounted) return;
    _reportBatchOutcome(
      context: context,
      succeeded: succeeded,
      total: requestIds.length,
      allMessage: l10n.socialRequestsAccepted(succeeded),
      partialMessage: l10n.socialRequestsAcceptedPartial(
        succeeded,
        requestIds.length,
      ),
      noneMessage: l10n.socialCouldNotAcceptAllRequests,
    );
  }

  /// Reject multiple friend requests with confirmation
  Future<void> rejectMultipleRequests(
    BuildContext context,
    FriendsViewModel viewModel,
    List<String> requestIds,
    void Function(List<String> landed)? onBatchSettled, {
    VoidCallback? onConfirmed,
  }) async {
    if (!validateContext(context) || requestIds.isEmpty) {
      showErrorMessage(context, context.l10n.socialNoRequestsSelected);
      return;
    }

    // Resolved before the await so the outcome message needs no BuildContext
    // once the batch returns.
    final l10n = context.l10n;

    final succeeded = await executeWithConfirmation<int>(
      context: context,
      action: () async {
        onConfirmed?.call();
        final landed = await viewModel.rejectFriendRequests(requestIds);
        onBatchSettled?.call(landed);
        return landed.length;
      },
      confirmationTitle: context.l10n.socialRejectAllSelectedConfirm,
      confirmationMessage: context.l10n.socialRejectAllSelectedMessage(
        requestIds.length,
      ),
      confirmActionText: context.l10n.socialRejectAll,
      confirmationIcon: ButleryIcons.userMinus,
      isDangerous: true,
      errorMessage: context.l10n.socialCouldNotRejectAllRequests,
      metadata: {
        'request_count': requestIds.length,
        'action': 'reject_multiple',
      },
    );

    if (succeeded == null || !context.mounted) return;
    _reportBatchOutcome(
      context: context,
      succeeded: succeeded,
      total: requestIds.length,
      allMessage: l10n.socialRequestsRejected(succeeded),
      partialMessage: l10n.socialRequestsRejectedPartial(
        succeeded,
        requestIds.length,
      ),
      noneMessage: l10n.socialCouldNotRejectAllRequests,
    );
  }

  /// Cancel multiple sent requests with confirmation
  Future<void> cancelMultipleSentRequests(
    BuildContext context,
    FriendsViewModel viewModel,
    List<String> requestIds,
    void Function(List<String> landed)? onBatchSettled, {
    VoidCallback? onConfirmed,
  }) async {
    if (!validateContext(context) || requestIds.isEmpty) {
      showErrorMessage(context, context.l10n.socialNoRequestsSelected);
      return;
    }

    // Resolved before the await so the outcome message needs no BuildContext
    // once the batch returns.
    final l10n = context.l10n;

    final succeeded = await executeWithConfirmation<int>(
      context: context,
      action: () async {
        onConfirmed?.call();
        final landed = await viewModel.cancelSentRequests(requestIds);
        onBatchSettled?.call(landed);
        return landed.length;
      },
      confirmationTitle: context.l10n.socialCancelSelectedRequestsConfirm,
      confirmationMessage: context.l10n.socialCancelSelectedRequestsMessage(
        requestIds.length,
      ),
      confirmActionText: context.l10n.socialCancelAll,
      confirmationIcon: ButleryIcons.x,
      isDangerous: true,
      errorMessage: context.l10n.socialCouldNotCancelAllRequests,
      metadata: {
        'request_count': requestIds.length,
        'action': 'cancel_multiple',
      },
    );

    if (succeeded == null || !context.mounted) return;
    _reportBatchOutcome(
      context: context,
      succeeded: succeeded,
      total: requestIds.length,
      allMessage: l10n.socialRequestsCancelled(succeeded),
      partialMessage: l10n.socialRequestsCancelledPartial(
        succeeded,
        requestIds.length,
      ),
      noneMessage: l10n.socialCouldNotCancelAllRequests,
    );
  }

  /// A count is needed rather than [executeWithConfirmation]'s `successMessage`,
  /// which [executeAction] shows without looking at the result — a batch where
  /// nothing landed would be reported as a success. That is why none of the
  /// three passes one.
  void _reportBatchOutcome({
    required BuildContext context,
    required int succeeded,
    required int total,
    required String allMessage,
    required String partialMessage,
    required String noneMessage,
  }) {
    if (succeeded == total) {
      showSuccessMessage(context, allMessage);
    } else if (succeeded > 0) {
      showWarningMessage(context, partialMessage);
    } else {
      showErrorMessage(context, noneMessage);
    }
  }

  void dispose() {
    clearError();
  }
}
