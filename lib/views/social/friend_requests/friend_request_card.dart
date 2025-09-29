// lib/views/social/friend_requests/friend_request_card.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/friend_request.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/widgets/common/social_components.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/styled/styled_widgets.dart';

class FriendRequestCard {
  static Widget buildIncomingCard(
    BuildContext context,
    FriendRequest request,
    FriendsViewModel viewModel,
    bool isSelected,
    Function(bool) onSelectionChanged,
  ) {
    final userProfile = viewModel.getUserProfile(request.fromUserId);
    final displayName = userProfile?.displayName ??
        viewModel.getDisplayNameForUser(request.fromUserId);
    final avatarUrl = userProfile?.avatarUrl;
    final isOnline = userProfile?.isOnline ?? false;

    return Card(
      color: isSelected
          ? Theme.of(context)
              .colorScheme
              .primaryContainer
              .withValues(alpha: 0.3)
          : null,
      child: InkWell(
        onTap: () => onSelectionChanged(!isSelected),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadius12),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacingL),
          child: Column(
            children: [
              Row(
                children: [
                  // Selection checkbox
                  Checkbox(
                    value: isSelected,
                    onChanged: (value) => onSelectionChanged(value ?? false),
                  ),
                  const SizedBox(width: AppDimensions.spacingS),

                  // User avatar with online indicator
                  Stack(
                    children: [
                      SocialComponents.avatar(
                        size: ImageSize.small,
                        imageUrl: avatarUrl,
                        displayName: displayName,
                      ),
                      if (isOnline)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Theme.of(context).colorScheme.surface,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: AppDimensions.spacingL),

                  // Request info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: AppTextStyles.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'vill bli vän',
                          style: AppTextStyles.bodyMedium.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        if (request.message?.isNotEmpty == true) ...[
                          const SizedBox(height: AppDimensions.spacingXs),
                          Container(
                            padding: const EdgeInsets.all(AppDimensions.spacingS),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(AppDimensions.borderRadius8),
                            ),
                            child: Text(
                              '"${request.message!}"',
                              style: AppTextStyles.bodySmall.copyWith(
                                    fontStyle: FontStyle.italic,
                                  ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        const SizedBox(height: AppDimensions.spacingXs),
                        Text(
                          request.timeAgoText,
                          style: AppTextStyles.bodySmall.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Actions (not shown during bulk selection)
              if (!isSelected) ...[
                const SizedBox(height: AppDimensions.spacingL),
                Row(
                  children: [
                    Expanded(
                      child: ActionButtons.outlinedButton(
                        context,
                        label: 'Avböj',
                        icon: Icons.close,
                        onPressed: viewModel.isLoading
                            ? null
                            : () => _rejectRequest(context, request, viewModel),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spacingL),
                    Expanded(
                      child: StyledButton.primary(
                        text: 'Acceptera',
                        icon: const Icon(Icons.check),
                        onPressed: viewModel.isLoading
                            ? null
                            : () => _acceptRequest(context, request, viewModel),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static Widget buildSentCard(
    BuildContext context,
    FriendRequest request,
    FriendsViewModel viewModel,
    bool isSelected,
    Function(bool) onSelectionChanged,
  ) {
    final userProfile = viewModel.getUserProfile(request.toUserId);
    final displayName = userProfile?.displayName ??
        viewModel.getDisplayNameForUser(request.toUserId);
    final avatarUrl = userProfile?.avatarUrl;
    final isOnline = userProfile?.isOnline ?? false;

    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (request.status) {
      case FriendRequestStatus.pending:
        statusColor = AppColors.warning;
        statusIcon = Icons.schedule;
        statusText = 'Väntande svar';
        break;
      case FriendRequestStatus.accepted:
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle;
        statusText = 'Accepterad';
        break;
      case FriendRequestStatus.rejected:
        statusColor = AppColors.error;
        statusIcon = Icons.cancel;
        statusText = 'Avböjd';
        break;
      case FriendRequestStatus.expired:
        statusColor = AppColors.neutralMedium;
        statusIcon = Icons.timer_off;
        statusText = 'Utgången';
        break;
      default:
        statusColor = AppColors.neutralMedium;
        statusIcon = Icons.help;
        statusText = 'Okänd status';
    }

    return Card(
      color: isSelected
          ? Theme.of(context)
              .colorScheme
              .primaryContainer
              .withValues(alpha: 0.3)
          : null,
      child: InkWell(
        onTap: () => onSelectionChanged(!isSelected),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadius12),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacingL),
          child: Row(
            children: [
              // Selection checkbox (only for pending requests)
              if (request.isPending)
                Checkbox(
                  value: isSelected,
                  onChanged: (value) => onSelectionChanged(value ?? false),
                )
              else
                const SizedBox(width: AppDimensions.spacingXxxl), // Placeholder for alignment

              const SizedBox(width: AppDimensions.spacingS),

              // User avatar with online indicator
              Stack(
                children: [
                  SocialComponents.avatar(
                    size: ImageSize.small,
                    imageUrl: avatarUrl,
                    displayName: displayName,
                  ),
                  if (isOnline)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.surface,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: AppDimensions.spacingL),

              // Request info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: AppTextStyles.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (request.message?.isNotEmpty == true)
                      Text(
                        request.message!,
                        style: AppTextStyles.bodySmall.copyWith(
                              fontStyle: FontStyle.italic,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: AppDimensions.spacingXs),
                    Row(
                      children: [
                        Icon(statusIcon, size: AppDimensions.iconSizeS, color: statusColor),
                        const SizedBox(width: AppDimensions.spacingXs),
                        Text(
                          statusText,
                          style: AppTextStyles.bodySmall.copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                        const Spacer(),
                        Text(
                          request.timeAgoText,
                          style: AppTextStyles.bodySmall.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Cancel button for pending requests (not during selection)
              if (request.isPending && !isSelected)
                IconButton(
                  onPressed: () => _cancelSentRequest(context, request, viewModel),
                  icon: const Icon(Icons.cancel, color: AppColors.error),
                  tooltip: 'Avbryt förfrågan',
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper methods for actions
  static Future<void> _acceptRequest(
    BuildContext context,
    FriendRequest request,
    FriendsViewModel viewModel,
  ) async {
    final success = await viewModel.acceptFriendRequest(request.id);

    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vänskapsförfrågan accepterad! 🎉'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  static Future<void> _rejectRequest(
    BuildContext context,
    FriendRequest request,
    FriendsViewModel viewModel,
  ) async {
    final success = await viewModel.rejectFriendRequest(request.id);

    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vänskapsförfrågan avböjd'),
          backgroundColor: AppColors.warning,
        ),
      );
    }
  }

  static Future<void> _cancelSentRequest(
    BuildContext context,
    FriendRequest request,
    FriendsViewModel viewModel,
  ) async {
    final success = await viewModel.cancelSentRequest(request.id);

    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Förfrågan avbruten'),
          backgroundColor: AppColors.warning,
        ),
      );
    }
  }
}