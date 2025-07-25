// lib/views/social/friend_requests/friend_request_actions_refactored.dart

import 'package:flutter/material.dart';
import '../../../core/base/base_action_handler.dart';
import '../../../theme/app_colors.dart';

/// Refactored FriendRequestActions using BaseActionHandler
/// 
/// This class provides standardized friend request operations with:
/// - Consistent batch operations with confirmation
/// - Proper error handling and user feedback
/// - Safe context handling for UI operations
/// - Standardized dialog patterns
class FriendRequestActions extends BaseActionHandler with ActionStateMixin {
  @override
  String get serviceName => 'FriendRequestActions';

  // ===== UI COMPONENTS =====

  /// Build floating action button for batch operations
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
        icon: const Icon(Icons.check_circle),
        label: Text('Acceptera ${selectedIncoming.length}'),
        backgroundColor: AppColors.success,
      );
    }
    return null;
  }

  // ===== INDIVIDUAL REQUEST OPERATIONS =====

  /// Accept a single friend request
  Future<void> acceptFriendRequest(
    BuildContext context,
    String requestId,
    String senderName,
    VoidCallback? onSuccess,
  ) async {
    if (!validateContext(context) || !validateRequired([requestId], 'accepting friend request')) {
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
      successMessage: 'Vänskapsförfrågan från $senderName accepterad',
      errorMessage: 'Kunde inte acceptera vänskapsförfrågan',
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
    if (!validateContext(context) || !validateRequired([requestId], 'rejecting friend request')) {
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
      confirmationTitle: 'Avböj vänskapsförfrågan?',
      confirmationMessage: 'Vill du avböja vänskapsförfrågan från $senderName?',
      confirmActionText: 'Avböj',
      confirmationIcon: Icons.person_remove,
      isDangerous: true,
      successMessage: 'Vänskapsförfrågan från $senderName avböjd',
      errorMessage: 'Kunde inte avböja vänskapsförfrågan',
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
    if (!validateContext(context) || !validateRequired([requestId], 'canceling sent request')) {
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
      confirmationTitle: 'Avbryt vänskapsförfrågan?',
      confirmationMessage: 'Vill du avbryta vänskapsförfrågan till $recipientName?',
      confirmActionText: 'Avbryt förfrågan',
      confirmationIcon: Icons.cancel,
      successMessage: 'Vänskapsförfrågan till $recipientName avbruten',
      errorMessage: 'Kunde inte avbryta vänskapsförfrågan',
      metadata: {
        'request_id': requestId,
        'recipient_name': recipientName,
        'action': 'cancel_sent',
      },
    );
  }

  // ===== BATCH OPERATIONS =====

  /// Accept multiple friend requests with confirmation
  Future<void> acceptMultipleRequests(
    BuildContext context,
    List<String> requestIds,
    VoidCallback? onSuccess,
  ) async {
    if (!validateContext(context) || requestIds.isEmpty) {
      showErrorMessage(context, 'Inga förfrågningar valda');
      return;
    }

    await executeWithConfirmation(
      context: context,
      action: () async {
        // Simulate batch accept
        showLoadingDialog(context, 'Accepterar ${requestIds.length} förfrågningar...');
        
        await Future.delayed(const Duration(milliseconds: 1000));
        onSuccess?.call();
        return true;
      },
      confirmationTitle: 'Acceptera alla valda?',
      confirmationMessage: 'Vill du acceptera ${requestIds.length} vänskapsförfrågningar?',
      confirmActionText: 'Acceptera alla',
      confirmationIcon: Icons.check_circle,
      successMessage: '${requestIds.length} vänskapsförfrågningar accepterade',
      errorMessage: 'Kunde inte acceptera alla förfrågningar',
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
      showErrorMessage(context, 'Inga förfrågningar valda');
      return;
    }

    await executeWithConfirmation(
      context: context,
      action: () async {
        // Simulate batch reject
        showLoadingDialog(context, 'Avböjer ${requestIds.length} förfrågningar...');
        
        await Future.delayed(const Duration(milliseconds: 1000));
        onSuccess?.call();
        return true;
      },
      confirmationTitle: 'Avböj alla valda?',
      confirmationMessage: 'Vill du avböja ${requestIds.length} vänskapsförfrågningar?',
      confirmActionText: 'Avböj alla',
      confirmationIcon: Icons.person_remove,
      isDangerous: true,
      successMessage: '${requestIds.length} vänskapsförfrågningar avböjda',
      errorMessage: 'Kunde inte avböja alla förfrågningar',
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
      showErrorMessage(context, 'Inga förfrågningar valda');
      return;
    }

    await executeWithConfirmation(
      context: context,
      action: () async {
        // Simulate batch cancel
        showLoadingDialog(context, 'Avbryter ${requestIds.length} förfrågningar...');
        
        await Future.delayed(const Duration(milliseconds: 1000));
        onSuccess?.call();
        return true;
      },
      confirmationTitle: 'Avbryt valda förfrågningar?',
      confirmationMessage: 'Vill du avbryta ${requestIds.length} skickade förfrågningar?',
      confirmActionText: 'Avbryt alla',
      confirmationIcon: Icons.cancel,
      isDangerous: true,
      successMessage: '${requestIds.length} förfrågningar avbrutna',
      errorMessage: 'Kunde inte avbryta alla förfrågningar',
      metadata: {
        'request_count': requestIds.length,
        'request_ids': requestIds,
        'action': 'cancel_multiple',
      },
    );
  }

  // ===== FRIEND MANAGEMENT OPERATIONS =====

  /// Send friend request to user
  Future<void> sendFriendRequest(
    BuildContext context,
    String userId,
    String userName,
    VoidCallback? onSuccess,
  ) async {
    if (!validateContext(context) || !validateRequired([userId], 'sending friend request')) {
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
      successMessage: 'Vänskapsförfrågan skickad till $userName',
      errorMessage: 'Kunde inte skicka vänskapsförfrågan',
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
    if (!validateContext(context) || !validateRequired([friendId], 'removing friend')) {
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
      confirmationTitle: 'Ta bort vän?',
      confirmationMessage: 'Vill du ta bort $friendName från dina vänner?',
      confirmActionText: 'Ta bort',
      confirmationIcon: Icons.person_remove,
      isDangerous: true,
      successMessage: '$friendName har tagits bort från dina vänner',
      errorMessage: 'Kunde inte ta bort vän',
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
    if (!validateContext(context) || !validateRequired([userId], 'blocking user')) {
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
      confirmationTitle: 'Blockera användare?',
      confirmationMessage: 
          'Vill du blockera $userName?\n\n'
          'Blockerade användare kan inte skicka vänskapsförfrågningar eller meddelanden till dig.',
      confirmActionText: 'Blockera',
      confirmationIcon: Icons.block,
      isDangerous: true,
      successMessage: '$userName har blockerats',
      errorMessage: 'Kunde inte blockera användare',
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
    if (!validateContext(context) || !validateRequired([userId], 'unblocking user')) {
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
      successMessage: '$userName har avblockerats',
      errorMessage: 'Kunde inte avblockera användare',
      metadata: {
        'user_id': userId,
        'user_name': userName,
        'action': 'unblock_user',
      },
    );
  }

  // ===== HELPER OPERATIONS =====

  /// Refresh friend requests list
  Future<void> refreshFriendRequests(BuildContext context) async {
    if (!validateContext(context)) return;

    await executeAction(
      context: context,
      action: () async {
        // Simulate refresh
        await Future.delayed(const Duration(milliseconds: 800));
        return true;
      },
      successMessage: 'Vänskapsförfrågningar uppdaterade',
      errorMessage: 'Kunde inte uppdatera förfrågningar',
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
      showErrorMessage(context, 'Ange en sökterm');
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
      errorMessage: 'Kunde inte söka efter användare',
      metadata: {
        'search_query': query,
        'action': 'search_users',
      },
    );
  }

  // ===== CLEANUP =====

  /// Dispose resources
  void dispose() {
    clearError();
  }
}