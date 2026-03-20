// lib/views/social/friends_list/requests_tab.dart

import 'package:flutter/material.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/models/friend_request.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/views/social/friends_list/friends_list_cards.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/services/deep_link_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

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
            _buildDiscoverySection(context, viewModel),

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
                title: context.l10n.socialNoFriendRequests,
                subtitle: context.l10n.socialNoFriendRequestsDescription,
                icon: Icons.search,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Build discovery encouragement section
  static Widget _buildDiscoverySection(
    BuildContext context,
    FriendsViewModel viewModel,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .primary
            .withValues(alpha: AppDimensions.opacityVeryLight),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .primary
              .withValues(alpha: AppDimensions.opacityMediumLight),
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
            context.l10n.socialFindNewFriends,
            style: AppTextStyles.headlineSmall.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.spacingS),
          Text(
            context.l10n.socialFindNewFriendsDescription,
            style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.spacingM),
          FilledButton.icon(
            onPressed: () => shareInvitationLink(context, viewModel),
            icon: const Icon(Icons.share, size: AppDimensions.iconSizeM),
            label: Text(context.l10n.socialInviteFriends),
          ),
        ],
      ),
    );
  }

  /// Generates an invitation link and opens the native share sheet.
  static Future<void> shareInvitationLink(
    BuildContext context,
    FriendsViewModel viewModel,
  ) async {
    final userId = viewModel.currentUserId;
    if (userId == null) return;

    final subject = context.l10n.socialInviteSubject;
    try {
      final invitationId = const Uuid().v4();
      final url = DeepLinkService.generateFriendInvitationLink(
        invitationId: invitationId,
        fromUserId: userId,
      );
      await SharePlus.instance.share(ShareParams(
        text: url,
        subject: subject,
      ));
    } catch (e) {
      if (!context.mounted) return;
      SnackBarUtils.showError(context, context.l10n.errorGeneric);
    }
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
              context.l10n.socialIncomingRequests,
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
            Icon(
              Icons.outbox,
              size: AppDimensions.iconSizeM,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppDimensions.spacingS),
            Text(
              context.l10n.socialSentRequests,
              style: AppTextStyles.titleMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: AppDimensions.spacingS),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingS,
                vertical: AppDimensions.paddingS,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                borderRadius:
                    BorderRadius.circular(AppDimensions.borderRadiusS),
              ),
              child: Text(
                '${viewModel.sentRequests.length}',
                style: AppTextStyles.labelSmall.copyWith(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        border: Border.all(
          color: cs.outline,
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
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person,
                size: AppDimensions.iconSizeL,
                color: cs.onSurfaceVariant,
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
                  context.l10n.socialWaitingForResponse,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: cs.onSurfaceVariant,
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
                side: BorderSide(color: cs.onSurfaceVariant),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.paddingS,
                  vertical: AppDimensions.paddingS,
                ),
              ),
              child: Text(
                context.l10n.commonCancel,
                style: AppTextStyles.labelSmall.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
