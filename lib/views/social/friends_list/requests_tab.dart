// lib/views/social/friends_list/requests_tab.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
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

/// Discovery/requests tab content.
/// const constructor so Flutter skips rebuilding when parent Consumer fires.
class RequestsTab extends StatelessWidget {
  const RequestsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _DiscoverySection(),
          const SizedBox(height: AppDimensions.spacingXl),
          // Request sections — rebuild only when request lists change
          Selector<FriendsViewModel,
              ({List<FriendRequest> incoming, List<FriendRequest> sent})>(
            selector: (_, vm) =>
                (incoming: vm.incomingRequests, sent: vm.sentRequests),
            shouldRebuild: (prev, next) =>
                prev.incoming.length != next.incoming.length ||
                prev.sent.length != next.sent.length,
            builder: (context, requests, _) {
              final vm = context.read<FriendsViewModel>();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (requests.incoming.isNotEmpty) ...[
                    _buildIncomingRequestsSection(
                        context, vm, requests.incoming),
                    const SizedBox(height: AppDimensions.spacingXl),
                  ],
                  if (requests.sent.isNotEmpty) ...[
                    _buildSentRequestsSection(context, vm, requests.sent),
                  ],
                  if (requests.incoming.isEmpty && requests.sent.isEmpty) ...[
                    StateWidget.empty(
                      title: context.l10n.socialNoFriendRequests,
                      subtitle: context.l10n.socialNoFriendRequestsDescription,
                      icon: Icons.search,
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  static Widget _buildIncomingRequestsSection(
    BuildContext context,
    FriendsViewModel viewModel,
    List<FriendRequest> requests,
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
                '${requests.length}',
                style: AppTextStyles.labelSmall.copyWith(
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingM),
        ...requests.map((request) => Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.spacingS),
              child: FriendRequestCard.build(context, request, viewModel),
            )),
      ],
    );
  }

  static Widget _buildSentRequestsSection(
    BuildContext context,
    FriendsViewModel viewModel,
    List<FriendRequest> requests,
  ) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.outbox,
              size: AppDimensions.iconSizeM,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(width: AppDimensions.spacingS),
            Text(
              context.l10n.socialSentRequests,
              style: AppTextStyles.titleMedium.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: AppDimensions.spacingS),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingS,
                vertical: AppDimensions.paddingS,
              ),
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant,
                borderRadius:
                    BorderRadius.circular(AppDimensions.borderRadiusS),
              ),
              child: Text(
                '${requests.length}',
                style: AppTextStyles.labelSmall.copyWith(
                  color: cs.surfaceContainerHighest,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingM),
        ...requests.map((request) => Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.spacingS),
              child: _buildSentRequestCard(context, request, viewModel),
            )),
      ],
    );
  }

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
      await SharePlus.instance.share(ShareParams(text: url, subject: subject));
    } catch (e) {
      if (!context.mounted) return;
      SnackBarUtils.showError(context, context.l10n.errorGeneric);
    }
  }

  static Future<void> copyInvitationLink(
    BuildContext context,
    FriendsViewModel viewModel,
  ) async {
    final userId = viewModel.currentUserId;
    if (userId == null) return;
    try {
      final invitationId = const Uuid().v4();
      final url = DeepLinkService.generateFriendInvitationLink(
        invitationId: invitationId,
        fromUserId: userId,
      );
      await Clipboard.setData(ClipboardData(text: url));
      if (!context.mounted) return;
      SnackBarUtils.showSuccess(context, context.l10n.commonLinkCopied);
    } catch (e) {
      if (!context.mounted) return;
      SnackBarUtils.showError(context, context.l10n.errorGeneric);
    }
  }
}

/// Static discovery section — const constructor so Flutter's Element
/// system skips rebuilding it entirely.
class _DiscoverySection extends StatelessWidget {
  const _DiscoverySection();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: AppDimensions.opacityVeryLight),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
        border: Border.all(
          color: cs.primary.withValues(alpha: AppDimensions.opacityMediumLight),
          width: AppDimensions.borderWidthThin,
        ),
      ),
      child: Column(
        children: [
          Icon(Icons.search, size: AppDimensions.iconSizeXl, color: cs.primary),
          const SizedBox(height: AppDimensions.spacingM),
          Text(
            context.l10n.socialFindNewFriends,
            style: AppTextStyles.headlineSmall.copyWith(color: cs.primary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.spacingS),
          Text(
            context.l10n.socialFindNewFriendsDescription,
            style:
                AppTextStyles.bodyMedium.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.spacingM),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Override theme's minimumSize(width: infinity) — buttons in
              // a Row can't both be full-width, causes layout crash.
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, AppDimensions.minTouchTarget),
                ),
                onPressed: () {
                  final vm = context.read<FriendsViewModel>();
                  RequestsTab.shareInvitationLink(context, vm);
                },
                icon: const Icon(Icons.share, size: AppDimensions.iconSizeM),
                label: Text(context.l10n.socialInviteFriends),
              ),
              const SizedBox(width: AppDimensions.spacingSm),
              IconButton.filled(
                onPressed: () {
                  final vm = context.read<FriendsViewModel>();
                  RequestsTab.copyInvitationLink(context, vm);
                },
                icon: const Icon(Icons.copy, size: AppDimensions.iconSizeM),
                tooltip: context.l10n.commonCopyLink,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
