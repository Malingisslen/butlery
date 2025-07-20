// lib/views/social/friend_requests/friend_request_actions.dart

import 'package:flutter/material.dart';
import '../../../viewmodels/friends_viewmodel.dart';
import '../../../theme/app_colors.dart';

class FriendRequestActions {
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

  static Future<void> showBatchAcceptDialog(
    BuildContext context,
    int count,
    VoidCallback onConfirm,
  ) async {
    final shouldAccept = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Acceptera alla valda?'),
        content: Text('Vill du acceptera $count vänskapsförfrågningar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Avbryt'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('Acceptera alla'),
          ),
        ],
      ),
    );

    if (shouldAccept == true) {
      onConfirm();
    }
  }

  static Future<void> showBatchRejectDialog(
    BuildContext context,
    int count,
    VoidCallback onConfirm,
  ) async {
    final shouldReject = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Avböj alla valda?'),
        content: Text('Vill du avböja $count vänskapsförfrågningar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Avbryt'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Avböj alla'),
          ),
        ],
      ),
    );

    if (shouldReject == true) {
      onConfirm();
    }
  }

  static Future<void> showCancelSentDialog(
    BuildContext context,
    int count,
    VoidCallback onConfirm,
  ) async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Avbryt valda förfrågningar?'),
        content: Text('Vill du avbryta $count skickade förfrågningar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Nej'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Avbryt alla'),
          ),
        ],
      ),
    );

    if (shouldCancel == true) {
      onConfirm();
    }
  }

  static Future<void> performBatchAccept(
    BuildContext context,
    FriendsViewModel viewModel,
    Set<String> selectedIncoming,
    VoidCallback onComplete,
  ) async {
    int successCount = 0;

    for (final requestId in selectedIncoming) {
      final success = await viewModel.acceptFriendRequest(requestId);
      if (success) successCount++;
    }

    onComplete();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$successCount vänskapsförfrågningar accepterade! 🎉'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  static Future<void> performBatchReject(
    BuildContext context,
    FriendsViewModel viewModel,
    Set<String> selectedIncoming,
    VoidCallback onComplete,
  ) async {
    int successCount = 0;

    for (final requestId in selectedIncoming) {
      final success = await viewModel.rejectFriendRequest(requestId);
      if (success) successCount++;
    }

    onComplete();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$successCount vänskapsförfrågningar avböjda'),
          backgroundColor: AppColors.warning,
        ),
      );
    }
  }

  static Future<void> performBatchCancel(
    BuildContext context,
    FriendsViewModel viewModel,
    Set<String> selectedSent,
    VoidCallback onComplete,
  ) async {
    int successCount = 0;

    for (final requestId in selectedSent) {
      final success = await viewModel.cancelSentRequest(requestId);
      if (success) successCount++;
    }

    onComplete();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$successCount förfrågningar avbrutna'),
          backgroundColor: AppColors.warning,
        ),
      );
    }
  }
}