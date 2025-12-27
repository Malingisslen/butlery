// lib/views/social/friends_list/requests_tab.dart

import 'package:flutter/material.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/models/friend_request.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/views/social/friends_list/friends_list_cards.dart';

/// RequestsTab - Friend discovery hub component
/// Primary social discovery tab with search encouragement and request management.
/// Serves as the central hub for finding new friends and managing friend requests.
class RequestsTab {
  static Widget build(
    BuildContext context,
    FriendsViewModel viewModel,
  ) {
    if (viewModel.isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await viewModel.refresh();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppDimensions.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Discovery encouragement section
            _buildDiscoverySection(context),

            const SizedBox(height: AppDimensions.spacingXl),

            // Incoming requests section
            if (viewModel.incomingRequests.isNotEmpty) ...[
              _buildIncomingRequestsSection(context, viewModel),
              const SizedBox(height: AppDimensions.spacingXl),
            ],

            // Sent requests section
            if (viewModel.sentRequests.isNotEmpty) ...[
              _buildSentRequestsSection(context, viewModel),
            ],

            // Empty state when no requests
            if (viewModel.incomingRequests.isEmpty &&
                viewModel.sentRequests.isEmpty) ...[
              const SizedBox(height: AppDimensions.spacingXl),
              StateWidget.empty(
                title: 'Inga vänskapsförfrågningar',
                subtitle:
                    'Börja söka efter vänner ovan för att utvidga ditt nätverk!',
                icon: Icons.search,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Build discovery encouragement section
  static Widget _buildDiscoverySection(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
          width: AppDimensions.borderWidthThin,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.search,
            size: AppDimensions.iconSizeXl,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: AppDimensions.spacingM),
          Text(
            'Hitta nya vänner',
            style: AppTextStyles.headlineSmall.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.spacingS),
          Text(
            'Använd sökfältet ovan för att hitta personer du vill bli vän med. Sök på namn eller användarnamn.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textMedium,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Build incoming requests section
  static Widget _buildIncomingRequestsSection(
    BuildContext context,
    FriendsViewModel viewModel,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.inbox,
              size: AppDimensions.iconSizeM,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: AppDimensions.spacingS),
            Text(
              'Inkommande förfrågningar',
              style: AppTextStyles.titleMedium,
            ),
            const SizedBox(width: AppDimensions.spacingS),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingS,
                vertical: AppDimensions.paddingS,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius:
                    BorderRadius.circular(AppDimensions.borderRadiusS),
              ),
              child: Text(
                '${viewModel.incomingRequests.length}',
                style: AppTextStyles.labelSmall.copyWith(
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingM),
        ...viewModel.incomingRequests.map((request) => Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.spacingS),
              child: FriendRequestCard.build(context, request, viewModel),
            )),
      ],
    );
  }

  /// Build sent requests section
  static Widget _buildSentRequestsSection(
    BuildContext context,
    FriendsViewModel viewModel,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.outbox,
              size: AppDimensions.iconSizeM,
              color: AppColors.textMedium,
            ),
            const SizedBox(width: AppDimensions.spacingS),
            Text(
              'Skickade förfrågningar',
              style: AppTextStyles.titleMedium.copyWith(
                color: AppColors.textMedium,
              ),
            ),
            const SizedBox(width: AppDimensions.spacingS),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingS,
                vertical: AppDimensions.paddingS,
              ),
              decoration: BoxDecoration(
                color: AppColors.textMedium,
                borderRadius:
                    BorderRadius.circular(AppDimensions.borderRadiusS),
              ),
              child: Text(
                '${viewModel.sentRequests.length}',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.cardWhite,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingM),
        ...viewModel.sentRequests.map((request) => Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.spacingS),
              child: _buildSentRequestCard(context, request, viewModel),
            )),
      ],
    );
  }

  /// Build card for sent friend requests
  static Widget _buildSentRequestCard(
    BuildContext context,
    FriendRequest request,
    FriendsViewModel viewModel,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        border: Border.all(
          color: AppColors.textLight,
          width: AppDimensions.borderWidthThin,
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDimensions.borderRadius25),
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.backgroundTint,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person,
                size: AppDimensions.iconSizeL,
                color: AppColors.textMedium,
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  viewModel.getDisplayNameForUser(request.toUserId),
                  style: AppTextStyles.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppDimensions.spacingXs),
                Text(
                  'Väntar på svar...',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textMedium,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 80,
            child: OutlinedButton(
              onPressed: () async {
                await viewModel.cancelSentRequest(request.id);
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.textMedium),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.paddingS,
                  vertical: AppDimensions.paddingS,
                ),
              ),
              child: Text(
                'Avbryt',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textMedium,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
