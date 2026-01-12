// lib/views/social/friend_requests/friend_request_builders.dart

import 'package:flutter/material.dart';

// Theme
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

// ViewModels
import 'package:butlery/viewmodels/friends_viewmodel.dart';

// Widgets
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/state_widget.dart';

// Local
import 'package:butlery/views/social/friend_requests/friend_request_card.dart';

/// Builds the header and app bar for friend requests view
class FriendRequestsHeaderBuilder {
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
    final totalRequests =
        viewModel.incomingRequests.length + viewModel.sentRequests.length;

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
                    const SizedBox(width: AppDimensions.spacingSm),
                    Text('Acceptera valda (${selectedIncoming.length})'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'reject_all',
                child: Row(
                  children: [
                    const Icon(Icons.cancel, color: AppColors.error),
                    const SizedBox(width: AppDimensions.spacingSm),
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
        color: AppColors.error.withValues(alpha: AppDimensions.opacityVeryLight),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
        border: Border.all(
          color: AppColors.error.withValues(alpha: AppDimensions.opacityMediumLight),
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

/// Builds the incoming requests tab content
class IncomingRequestsTabBuilder {
  static Widget build(
    BuildContext context,
    FriendsViewModel viewModel,
    Set<String> selectedIncoming,
    Function(String, bool) onSelectionChanged,
    VoidCallback onClearSelection,
  ) {
    if (viewModel.isLoading && viewModel.incomingRequests.isEmpty) {
      return StateWidget.loading(message: 'Laddar förfrågningar...');
    }

    if (viewModel.incomingRequests.isEmpty) {
      return StateWidget.empty(
        title: 'Inga vänskapsförfrågningar',
        subtitle: 'När någon skickar dig en vänskapsförfrågan visas den här.',
        icon: Icons.inbox_outlined,
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await viewModel.refresh();
        onClearSelection();
      },
      child: Column(
        children: [
          // Selection header
          if (selectedIncoming.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppDimensions.spacingL),
              color: Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withValues(alpha: AppDimensions.opacityMediumLight),
              child: Row(
                children: [
                  Icon(
                    Icons.checklist,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: AppDimensions.spacingS),
                  Text(
                    '${selectedIncoming.length} förfrågningar valda',
                    style: AppTextStyles.titleSmall.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const Spacer(),
                  ActionButtons.secondaryButton(
                    context,
                    label: 'Rensa',
                    onPressed: onClearSelection,
                  ),
                ],
              ),
            ),

          // Requests list
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(AppDimensions.spacingL),
              itemCount: viewModel.incomingRequests.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppDimensions.spacingS),
              itemBuilder: (context, index) {
                final request = viewModel.incomingRequests[index];
                final isSelected = selectedIncoming.contains(request.id);

                return FriendRequestCard.buildIncomingCard(
                  context,
                  request,
                  viewModel,
                  isSelected,
                  (selected) => onSelectionChanged(request.id, selected),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Builds the sent requests tab content
class SentRequestsTabBuilder {
  static Widget build(
    BuildContext context,
    FriendsViewModel viewModel,
    Set<String> selectedSent,
    Function(String, bool) onSelectionChanged,
    VoidCallback onClearSelection,
  ) {
    if (viewModel.isLoading && viewModel.sentRequests.isEmpty) {
      return StateWidget.loading(message: 'Laddar skickade förfrågningar...');
    }

    if (viewModel.sentRequests.isEmpty) {
      return StateWidget.empty(
        title: 'Inga skickade förfrågningar',
        subtitle: 'Förfrågningar du skickar till andra visas här.',
        icon: Icons.outbox_outlined,
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await viewModel.refresh();
        onClearSelection();
      },
      child: Column(
        children: [
          // Selection header
          if (selectedSent.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppDimensions.spacingL),
              color: Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withValues(alpha: AppDimensions.opacityMediumLight),
              child: Row(
                children: [
                  Icon(
                    Icons.checklist,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: AppDimensions.spacingS),
                  Text(
                    '${selectedSent.length} förfrågningar valda',
                    style: AppTextStyles.titleSmall.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const Spacer(),
                  ActionButtons.secondaryButton(
                    context,
                    label: 'Rensa',
                    onPressed: onClearSelection,
                  ),
                ],
              ),
            ),

          // Requests list
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(AppDimensions.spacingL),
              itemCount: viewModel.sentRequests.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppDimensions.spacingS),
              itemBuilder: (context, index) {
                final request = viewModel.sentRequests[index];
                final isSelected = selectedSent.contains(request.id);

                return FriendRequestCard.buildSentCard(
                  context,
                  request,
                  viewModel,
                  isSelected,
                  (selected) => onSelectionChanged(request.id, selected),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
