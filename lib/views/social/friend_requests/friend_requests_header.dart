// lib/views/social/friend_requests/friend_requests_header.dart

import 'package:flutter/material.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';

class FriendRequestsHeader {
  static PreferredSizeWidget buildAppBar(
    BuildContext context,
    FriendsViewModel viewModel,
    TabController tabController,
    Function() onClearSelection,
    Set<String> selectedIncoming,
    Set<String> selectedSent,
    VoidCallback onBatchAccept,
    VoidCallback onBatchReject,
    VoidCallback onCancelSelected,
  ) {
    final totalRequests = viewModel.incomingRequests.length + viewModel.sentRequests.length;
    
    return AppBar(
      title: Text('Notiser ($totalRequests)'),
      bottom: TabBar(
        controller: tabController,
        onTap: (_) => onClearSelection(),
        tabs: [
          Tab(
            icon: Badge(
              isLabelVisible: viewModel.incomingRequests.isNotEmpty,
              label: Text('${viewModel.incomingRequests.length}'),
              child: const Icon(Icons.inbox),
            ),
            text: 'Inkommande',
          ),
          Tab(
            icon: Badge(
              isLabelVisible: viewModel.sentRequests.isNotEmpty,
              label: Text('${viewModel.sentRequests.length}'),
              child: const Icon(Icons.outbox),
            ),
            text: 'Skickade',
          ),
        ],
      ),
      actions: [
        // Batch actions for current tab
        if (tabController.index == 0 && selectedIncoming.isNotEmpty)
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.checklist,
              color: AppColors.primaryBlue,
            ),
            onSelected: (value) {
              if (value == 'accept_all') {
                onBatchAccept();
              } else if (value == 'reject_all') {
                onBatchReject();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'accept_all',
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.success),
                    const SizedBox(width: 8),
                    Text('Acceptera valda (${selectedIncoming.length})'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'reject_all',
                child: Row(
                  children: [
                    const Icon(Icons.cancel, color: AppColors.error),
                    const SizedBox(width: 8),
                    Text('Avböj valda (${selectedIncoming.length})'),
                  ],
                ),
              ),
            ],
          ),
        if (tabController.index == 1 && selectedSent.isNotEmpty)
          IconButton(
            icon: const Icon(
              Icons.cancel,
              color: AppColors.error,
            ),
            onPressed: onCancelSelected,
            tooltip: 'Avbryt valda (${selectedSent.length})',
          ),
      ],
    );
  }

  static Widget buildErrorDisplay(
    BuildContext context,
    FriendsViewModel viewModel,
  ) {
    if (!viewModel.hasError) return const SizedBox.shrink();
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.spacingL),
      margin: const EdgeInsets.all(AppDimensions.spacingL),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error),
          const SizedBox(width: AppDimensions.spacingS),
          Expanded(
            child: Text(
              viewModel.error!,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
          TextButton(
            onPressed: viewModel.clearError,
            child: const Text('Stäng'),
          ),
        ],
      ),
    );
  }
}