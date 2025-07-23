// lib/views/social/friend_requests/incoming_requests_tab.dart

import 'package:flutter/material.dart';
import '../../../viewmodels/friends_viewmodel.dart';
import '../../../widgets/common/state_widget.dart';
import '../../../theme/app_dimensions.dart';
import 'friend_request_card.dart';

class IncomingRequestsTab {
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
        subtitle: 'När någon skickar dig en vänskapsförfrågning visas den här.',
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
              padding: EdgeInsets.all(AppDimensions.spacingL),
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
                  SizedBox(width: AppDimensions.spacingS),
                  Text(
                    '${selectedIncoming.length} förfrågningar valda',
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
              padding: EdgeInsets.all(AppDimensions.spacingL),
              itemCount: viewModel.incomingRequests.length,
              separatorBuilder: (context, index) => SizedBox(height: AppDimensions.spacingS),
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