// lib/views/social/friend_requests/friend_request_builders.dart

import 'package:flutter/material.dart';

// Theme
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';

// ViewModels
import 'package:butlery/viewmodels/friends_viewmodel.dart';

// Widgets
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/state_widget.dart';

// Local
import 'package:butlery/views/social/friend_requests/friend_request_card.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

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
      title: Text(context.l10n.socialNotificationsCount(totalRequests)),
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
            text: context.l10n.socialIncoming,
          ),
          Tab(
            icon: Badge(
              isLabelVisible: viewModel.sentRequests.isNotEmpty,
              label: Text('${viewModel.sentRequests.length}'),
              child: const Icon(Icons.outbox),
            ),
            text: context.l10n.socialSent,
          ),
        ],
      ),
      actions: [
        // Batch actions for current tab
        if (tabController.index == 0 && selectedIncoming.isNotEmpty)
          PopupMenuButton<String>(
            icon: Icon(
              Icons.checklist,
              color: Theme.of(context).colorScheme.primary,
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
                    Icon(
                      Icons.check_circle,
                      color: context.butleryColors.success,
                    ),
                    const SizedBox(width: AppDimensions.spacingSm),
                    Text(
                      context.l10n.socialAcceptCount(selectedIncoming.length),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'reject_all',
                child: Row(
                  children: [
                    Icon(
                      Icons.cancel,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: AppDimensions.spacingSm),
                    Text(
                      context.l10n.socialDeclineCount(selectedIncoming.length),
                    ),
                  ],
                ),
              ),
            ],
          ),
        if (tabController.index == 1 && selectedSent.isNotEmpty)
          IconButton(
            icon: Icon(
              Icons.cancel,
              color: Theme.of(context).colorScheme.error,
            ),
            onPressed: onCancelSelected,
            tooltip: context.l10n.socialCancelCount(selectedSent.length),
          ),
      ],
    );
  }

  static Widget buildErrorDisplay(
    BuildContext context,
    FriendsViewModel viewModel,
  ) {
    if (!viewModel.hasError) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.spacingL),
      margin: const EdgeInsets.all(AppDimensions.spacingL),
      decoration: BoxDecoration(
        color: cs.error.withValues(alpha: AppDimensions.opacityVeryLight),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
        border: Border.all(
          color: cs.error.withValues(alpha: AppDimensions.opacityMediumLight),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: cs.error),
          const SizedBox(width: AppDimensions.spacingS),
          Expanded(
            child: Text(
              viewModel.error!,
              style: TextStyle(color: cs.error),
            ),
          ),
          TextButton(
            onPressed: viewModel.clearError,
            child: Text(context.l10n.commonClose),
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
      return StateWidget.loading(message: context.l10n.socialLoadingRequests);
    }

    if (viewModel.incomingRequests.isEmpty) {
      return StateWidget.empty(
        title: context.l10n.socialNoFriendRequests,
        subtitle: context.l10n.socialNoFriendRequestsDescription,
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
              color: Theme.of(context).colorScheme.primaryContainer.withValues(
                alpha: AppDimensions.opacityMediumLight,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.checklist,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: AppDimensions.spacingS),
                  Text(
                    context.l10n.socialRequestsSelected(
                      selectedIncoming.length,
                    ),
                    style: AppTextStyles.titleSmall.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const Spacer(),
                  ActionButtons.secondaryButton(
                    context,
                    label: context.l10n.commonClear,
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

                return KeyedSubtree(
                  key: ValueKey(request.id),
                  child: FriendRequestCard.buildIncomingCard(
                    context,
                    request,
                    viewModel,
                    isSelected,
                    (selected) => onSelectionChanged(request.id, selected),
                  ),
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
      return StateWidget.loading(
        message: context.l10n.socialLoadingSentRequests,
      );
    }

    if (viewModel.sentRequests.isEmpty) {
      return StateWidget.empty(
        title: context.l10n.socialNoSentRequests,
        subtitle: context.l10n.socialNoSentRequestsDescription,
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
              color: Theme.of(context).colorScheme.primaryContainer.withValues(
                alpha: AppDimensions.opacityMediumLight,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.checklist,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: AppDimensions.spacingS),
                  Text(
                    context.l10n.socialRequestsSelected(selectedSent.length),
                    style: AppTextStyles.titleSmall.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const Spacer(),
                  ActionButtons.secondaryButton(
                    context,
                    label: context.l10n.commonClear,
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

                return KeyedSubtree(
                  key: ValueKey(request.id),
                  child: FriendRequestCard.buildSentCard(
                    context,
                    request,
                    viewModel,
                    isSelected,
                    (selected) => onSelectionChanged(request.id, selected),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
