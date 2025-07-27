// lib/views/social/friend_requests/friend_request_actions.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/base/base_action_handler.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/theme/app_colors.dart';

class FriendRequestActions extends BaseActionHandler with ActionStateMixin {
  @override
  String get serviceName => 'FriendRequestActions';

  /// Build floating action button for batch operations
  static Widget? buildFloatingActionButton(
    BuildContext context,
    TabController tabController,
    Set<String> selectedIncoming,
    VoidCallback onBatchAccept,
  ) {
    if (tabController.index == 0 && selectedIncoming.isNotEmpty) {
      return FloatingActionButton.extended(
        onPressed: onBatchAccept,
        icon: const Icon(Icons.check_circle),
        label: Text('Acceptera ${selectedIncoming.length}'),
        backgroundColor: AppColors.success,
      );
    }
    return null;
  }

  Future<void> showBatchAcceptDialog(
    BuildContext context,
    int count,
    VoidCallback onConfirm,
  ) async {
    await executeWithConfirmation(
      context: context,
      action: () async {
        onConfirm();
        return true;
      },
      confirmationTitle: 'Acceptera alla valda?',
      confirmationMessage: 'Vill du acceptera $count vänskapsförfrågningar?',
      confirmActionText: 'Acceptera alla',
      confirmationIcon: Icons.check_circle,
      metadata: {
        'request_count': count,
        'action': 'batch_accept_dialog',
      },
    );
  }

  Future<void> showBatchRejectDialog(
    BuildContext context,
    int count,
    VoidCallback onConfirm,
  ) async {
    await executeWithConfirmation(
      context: context,
      action: () async {
        onConfirm();
        return true;
      },
      confirmationTitle: 'Avböj alla valda?',
      confirmationMessage: 'Vill du avböja $count vänskapsförfrågningar?',
      confirmActionText: 'Avböj alla',
      confirmationIcon: Icons.person_remove,
      isDangerous: true,
      metadata: {
        'request_count': count,
        'action': 'batch_reject_dialog',
      },
    );
  }

  Future<void> showCancelSentDialog(
    BuildContext context,
    int count,
    VoidCallback onConfirm,
  ) async {
    await executeWithConfirmation(
      context: context,
      action: () async {
        onConfirm();
        return true;
      },
      confirmationTitle: 'Avbryt valda förfrågningar?',
      confirmationMessage: 'Vill du avbryta $count skickade förfrågningar?',
      confirmActionText: 'Avbryt alla',
      confirmationIcon: Icons.cancel,
      isDangerous: true,
      metadata: {
        'request_count': count,
        'action': 'cancel_sent_dialog',
      },
    );
  }

  Future<void> performBatchAccept(
    BuildContext context,
    FriendsViewModel viewModel,
    Set<String> selectedIncoming,
    VoidCallback onComplete,
  ) async {
    if (!validateContext(context)) return;

    await executeWithLoadingState(
      context: context,
      action: () async {
        int successCount = 0;

        for (final requestId in selectedIncoming) {
          final success = await viewModel.acceptFriendRequest(requestId);
          if (success) successCount++;
        }

        onComplete();
        return successCount;
      },
      successMessage: '${selectedIncoming.length} vänskapsförfrågningar accepterade! 🎉',
      errorMessage: 'Kunde inte acceptera alla förfrågningar',
      metadata: {
        'request_count': selectedIncoming.length,
        'request_ids': selectedIncoming.toList(),
        'action': 'batch_accept',
      },
    );
  }

  Future<void> performBatchReject(
    BuildContext context,
    FriendsViewModel viewModel,
    Set<String> selectedIncoming,
    VoidCallback onComplete,
  ) async {
    if (!validateContext(context)) return;

    await executeWithLoadingState(
      context: context,
      action: () async {
        int successCount = 0;

        for (final requestId in selectedIncoming) {
          final success = await viewModel.rejectFriendRequest(requestId);
          if (success) successCount++;
        }

        onComplete();
        return successCount;
      },
      successMessage: '${selectedIncoming.length} vänskapsförfrågningar avböjda',
      errorMessage: 'Kunde inte avböja alla förfrågningar',
      metadata: {
        'request_count': selectedIncoming.length,
        'request_ids': selectedIncoming.toList(),
        'action': 'batch_reject',
      },
    );
  }

  Future<void> performBatchCancel(
    BuildContext context,
    FriendsViewModel viewModel,
    Set<String> selectedSent,
    VoidCallback onComplete,
  ) async {
    if (!validateContext(context)) return;

    await executeWithLoadingState(
      context: context,
      action: () async {
        int successCount = 0;

        for (final requestId in selectedSent) {
          final success = await viewModel.cancelSentRequest(requestId);
          if (success) successCount++;
        }

        onComplete();
        return successCount;
      },
      successMessage: '${selectedSent.length} förfrågningar avbrutna',
      errorMessage: 'Kunde inte avbryta alla förfrågningar',
      metadata: {
        'request_count': selectedSent.length,
        'request_ids': selectedSent.toList(),
        'action': 'batch_cancel',
      },
    );
  }

  /// Dispose resources
  void dispose() {
    clearError();
  }
}