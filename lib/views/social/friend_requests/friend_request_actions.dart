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

  Future<void> acceptFriendRequest(
    BuildContext context,
    String requestId,
    String senderName,
    VoidCallback? onSuccess,
  ) async {
    if (!validateContext(context) ||
        !validateRequired([requestId], 'accepting friend request')) {
      return;
    }

    await executeAction(
      context: context,
      action: () async {
        // Simulate accepting friend request
        await Future.delayed(const Duration(milliseconds: 500));
        onSuccess?.call();
        return true;
      },
      successMessage: context.l10n.socialFriendRequestAcceptedFrom(senderName),
      errorMessage: context.l10n.socialCouldNotAcceptFriendRequest,
      metadata: {
        'request_id': requestId,
        'sender_name': senderName,
        'action': 'accept_single',
      },
    );
  }

  /// Reject a single friend request
  Future<void> rejectFriendRequest(
    BuildContext context,
    String requestId,
    String senderName,
    VoidCallback? onSuccess,
  ) async {
    if (!validateContext(context) ||
        !validateRequired([requestId], 'rejecting friend request')) {
      return;
    }

    await executeWithConfirmation(
      context: context,
      action: () async {
        // Simulate rejecting friend request
        await Future.delayed(const Duration(milliseconds: 500));
        onSuccess?.call();
        return true;
      },
      confirmationTitle: context.l10n.socialRejectFriendRequestConfirm,
      confirmationMessage: context.l10n.socialRejectFriendRequestMessage(
        senderName,
      ),
      confirmActionText: context.l10n.socialReject,
      confirmationIcon: Icons.person_remove,
      isDangerous: true,
      successMessage: context.l10n.socialFriendRequestRejected(senderName),
      errorMessage: context.l10n.socialCouldNotRejectFriendRequest,
      metadata: {
        'request_id': requestId,
        'sender_name': senderName,
        'action': 'reject_single',
      },
    );
  }

  /// Cancel a sent friend request
  Future<void> cancelSentRequest(
    BuildContext context,
    String requestId,
    String recipientName,
    VoidCallback? onSuccess,
  ) async {
    if (!validateContext(context) ||
        !validateRequired([requestId], 'canceling sent request')) {
      return;
    }

    await executeWithConfirmation(
      context: context,
      action: () async {
        // Simulate canceling sent request
        await Future.delayed(const Duration(milliseconds: 500));
        onSuccess?.call();
        return true;
      },
      confirmationTitle: context.l10n.socialCancelFriendRequestConfirm,
      confirmationMessage: context.l10n.socialCancelFriendRequestMessage(
        recipientName,
      ),
      confirmActionText: context.l10n.socialCancelRequest,
      confirmationIcon: Icons.cancel,
      successMessage: context.l10n.socialFriendRequestCancelled(recipientName),
      errorMessage: context.l10n.socialCouldNotCancelFriendRequest,
      metadata: {
        'request_id': requestId,
        'recipient_name': recipientName,
        'action': 'cancel_sent',
      },
    );
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

  Future<void> sendFriendRequest(
    BuildContext context,
    String userId,
    String userName,
    VoidCallback? onSuccess,
  ) async {
    if (!validateContext(context) ||
        !validateRequired([userId], 'sending friend request')) {
      return;
    }

    await executeAction(
      context: context,
      action: () async {
        // Simulate sending friend request
        await Future.delayed(const Duration(milliseconds: 500));
        onSuccess?.call();
        return true;
      },
      successMessage: context.l10n.socialFriendRequestSent(userName),
      errorMessage: context.l10n.socialCouldNotSendFriendRequest,
      metadata: {
        'user_id': userId,
        'user_name': userName,
        'action': 'send_friend_request',
      },
    );
  }

  /// Remove friend with confirmation
  Future<void> removeFriend(
    BuildContext context,
    String friendId,
    String friendName,
    VoidCallback? onSuccess,
  ) async {
    if (!validateContext(context) ||
        !validateRequired([friendId], 'removing friend')) {
      return;
    }

    await executeWithConfirmation(
      context: context,
      action: () async {
        // Simulate removing friend
        await Future.delayed(const Duration(milliseconds: 500));
        onSuccess?.call();
        return true;
      },
      confirmationTitle: context.l10n.socialRemoveFriendConfirm,
      confirmationMessage: context.l10n.socialRemoveFriendMessage(friendName),
      confirmActionText: context.l10n.commonRemove,
      confirmationIcon: Icons.person_remove,
      isDangerous: true,
      successMessage: context.l10n.socialFriendRemoved(friendName),
      errorMessage: context.l10n.socialCouldNotRemoveFriend,
      metadata: {
        'friend_id': friendId,
        'friend_name': friendName,
        'action': 'remove_friend',
      },
    );
  }

  /// Block user with confirmation
  Future<void> blockUser(
    BuildContext context,
    String userId,
    String userName,
    VoidCallback? onSuccess,
  ) async {
    if (!validateContext(context) ||
        !validateRequired([userId], 'blocking user')) {
      return;
    }

    await executeWithConfirmation(
      context: context,
      action: () async {
        // Simulate blocking user
        await Future.delayed(const Duration(milliseconds: 500));
        onSuccess?.call();
        return true;
      },
      confirmationTitle: context.l10n.socialBlockUserConfirm,
      confirmationMessage: context.l10n.socialBlockUserMessage(userName),
      confirmActionText: context.l10n.socialBlock,
      confirmationIcon: Icons.block,
      isDangerous: true,
      successMessage: context.l10n.socialUserBlocked(userName),
      errorMessage: context.l10n.socialCouldNotBlockUser,
      metadata: {
        'user_id': userId,
        'user_name': userName,
        'action': 'block_user',
      },
    );
  }

  /// Unblock user
  Future<void> unblockUser(
    BuildContext context,
    String userId,
    String userName,
    VoidCallback? onSuccess,
  ) async {
    if (!validateContext(context) ||
        !validateRequired([userId], 'unblocking user')) {
      return;
    }

    await executeAction(
      context: context,
      action: () async {
        // Simulate unblocking user
        await Future.delayed(const Duration(milliseconds: 500));
        onSuccess?.call();
        return true;
      },
      successMessage: context.l10n.socialUserUnblocked(userName),
      errorMessage: context.l10n.socialCouldNotUnblockUser,
      metadata: {
        'user_id': userId,
        'user_name': userName,
        'action': 'unblock_user',
      },
    );
  }

  Future<void> refreshFriendRequests(BuildContext context) async {
    if (!validateContext(context)) return;

    await executeAction(
      context: context,
      action: () async {
        // Simulate refresh
        await Future.delayed(const Duration(milliseconds: 800));
        return true;
      },
      successMessage: context.l10n.socialFriendRequestsUpdated,
      errorMessage: context.l10n.socialCouldNotUpdateRequests,
      metadata: {
        'action': 'refresh_friend_requests',
      },
    );
  }

  /// Search for users to send friend requests
  Future<void> searchUsers(
    BuildContext context,
    String query,
    Function(List<dynamic>) onResults,
  ) async {
    if (!validateContext(context) || query.trim().isEmpty) {
      showErrorMessage(context, context.l10n.socialEnterSearchTerm);
      return;
    }

    await executeAction(
      context: context,
      action: () async {
        // Simulate user search
        await Future.delayed(const Duration(milliseconds: 600));

        // Mock search results
        final results = [
          {'id': '1', 'name': 'Test User 1'},
          {'id': '2', 'name': 'Test User 2'},
        ];

        onResults(results);
        return true;
      },
      errorMessage: context.l10n.socialCouldNotSearchUsers,
      metadata: {
        'search_query': query,
        'action': 'search_users',
      },
    );
  }

  void dispose() {
    clearError();
  }
}
