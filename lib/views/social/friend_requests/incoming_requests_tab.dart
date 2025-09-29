// lib/views/social/friend_requests/incoming_requests_tab.dart

import 'package:flutter/material.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/views/social/friend_requests/friend_request_card.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';

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
              separatorBuilder: (context, index) => const SizedBox(height: AppDimensions.spacingS),
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