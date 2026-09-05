// lib/views/social/friend_requests/friend_request_actions.dart

import 'package:flutter/material.dart';

// Core
import 'package:butlery/core/base/base_action_handler.dart';

// Theme
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// Refactored FriendRequestActions using BaseActionHandler
/// This class provides standardized friend request operations with:
/// - Consistent batch operations with confirmation
/// - Proper error handling and user feedback
/// - Safe context handling for UI operations
/// - Standardized dialog patterns
/// The three bulk methods below are STUBS: they run a delay, call `onSuccess`
/// and report success without writing anything. `FriendRequestsView` calls all
/// three, so the app confirms batch accept/reject/cancel that never happened.
/// A live defect with no ticket of its own yet. BUT-1951 removed the nine
/// unreferenced stubs that sat beside them and left these three alone.
class FriendRequestActions extends BaseActionHandler with ActionStateMixin {
  @override
  String get serviceName => 'FriendRequestActions';

  Widget? buildFloatingActionButton(
    BuildContext context,
    TabController tabController,
    Set<String> selectedIncoming,
    VoidCallback onBatchAccept,
  ) {
    if (!validateContext(context)) return null;

    if (tabController.index == 0 && selectedIncoming.isNotEmpty) {
      return FloatingActionButton.extended(
        onPressed: () => acceptMultipleRequests(
          context,
          selectedIncoming.toList(),
          onBatchAccept,
        ),
        tooltip: context.l10n.socialAcceptSelected,
        icon: const Icon(Icons.check_circle),
        label: Text(context.l10n.socialAcceptCount(selectedIncoming.length)),
        backgroundColor: context.butleryColors.success,
      );
    }
    return null;
  }

  Future<void> acceptMultipleRequests(
    BuildContext context,
    List<String> requestIds,
    VoidCallback? onSuccess,
  ) async {
    if (!validateContext(context) || requestIds.isEmpty) {
      showErrorMessage(context, context.l10n.socialNoRequestsSelected);
      return;
    }

    await executeWithConfirmation(
      context: context,
      action: () async {
        // Simulate batch accept
        showLoadingDialog(
          context,
          context.l10n.socialAcceptingRequests(requestIds.length),
        );

        await Future.delayed(const Duration(milliseconds: 1000));
        onSuccess?.call();
        return true;
      },
      confirmationTitle: context.l10n.socialAcceptAllSelectedConfirm,
      confirmationMessage: context.l10n.socialAcceptAllSelectedMessage(
        requestIds.length,
      ),
      confirmActionText: context.l10n.socialAcceptAll,
      confirmationIcon: Icons.check_circle,
      successMessage: context.l10n.socialRequestsAccepted(requestIds.length),
      errorMessage: context.l10n.socialCouldNotAcceptAllRequests,
      metadata: {
        'request_count': requestIds.length,
        'request_ids': requestIds,
        'action': 'accept_multiple',
      },
    );
  }

  /// Reject multiple friend requests with confirmation
  Future<void> rejectMultipleRequests(
    BuildContext context,
    List<String> requestIds,
    VoidCallback? onSuccess,
  ) async {
    if (!validateContext(context) || requestIds.isEmpty) {
      showErrorMessage(context, context.l10n.socialNoRequestsSelected);
      return;
    }

    await executeWithConfirmation(
      context: context,
      action: () async {
        // Simulate batch reject
        showLoadingDialog(
          context,
          context.l10n.socialRejectingRequests(requestIds.length),
        );

        await Future.delayed(const Duration(milliseconds: 1000));
        onSuccess?.call();
        return true;
      },
      confirmationTitle: context.l10n.socialRejectAllSelectedConfirm,
      confirmationMessage: context.l10n.socialRejectAllSelectedMessage(
        requestIds.length,
      ),
      confirmActionText: context.l10n.socialRejectAll,
      confirmationIcon: Icons.person_remove,
      isDangerous: true,
      successMessage: context.l10n.socialRequestsRejected(requestIds.length),
      errorMessage: context.l10n.socialCouldNotRejectAllRequests,
      metadata: {
        'request_count': requestIds.length,
        'request_ids': requestIds,
        'action': 'reject_multiple',
      },
    );
  }

  /// Cancel multiple sent requests with confirmation
  Future<void> cancelMultipleSentRequests(
    BuildContext context,
    List<String> requestIds,
    VoidCallback? onSuccess,
  ) async {
    if (!validateContext(context) || requestIds.isEmpty) {
      showErrorMessage(context, context.l10n.socialNoRequestsSelected);
      return;
    }

    await executeWithConfirmation(
      context: context,
      action: () async {
        // Simulate batch cancel
        showLoadingDialog(
          context,
          context.l10n.socialCancellingRequests(requestIds.length),
        );

        await Future.delayed(const Duration(milliseconds: 1000));
        onSuccess?.call();
        return true;
      },
      confirmationTitle: context.l10n.socialCancelSelectedRequestsConfirm,
      confirmationMessage: context.l10n.socialCancelSelectedRequestsMessage(
        requestIds.length,
      ),
      confirmActionText: context.l10n.socialCancelAll,
      confirmationIcon: Icons.cancel,
      isDangerous: true,
      successMessage: context.l10n.socialRequestsCancelled(requestIds.length),
      errorMessage: context.l10n.socialCouldNotCancelAllRequests,
      metadata: {
        'request_count': requestIds.length,
        'request_ids': requestIds,
        'action': 'cancel_multiple',
      },
    );
  }

  void dispose() {
    clearError();
  }
}
