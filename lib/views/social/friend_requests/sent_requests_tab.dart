// lib/views/social/friend_requests/sent_requests_tab.dart

import 'package:flutter/material.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/views/social/friend_requests/friend_request_card.dart';

class SentRequestsTab {
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
                  .withValues(alpha: 0.3),
              child: Row(
                children: [
                  Icon(
                    Icons.checklist,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: AppDimensions.spacingS),
                  Text(
                    '${selectedSent.length} förfrågningar valda',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: onClearSelection,
                    child: const Text('Rensa'),
                  ),
                ],
              ),
            ),

          // Requests list
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(AppDimensions.spacingL),
              itemCount: viewModel.sentRequests.length,
              separatorBuilder: (context, index) => const SizedBox(height: AppDimensions.spacingS),
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
  @override
  void dispose() {
    // Cancel all timers
    // Cancel all stream subscriptions  
    // Dispose of resources
    disposeStreams(); // From StreamManagementMixin
    super.dispose();
  }
}