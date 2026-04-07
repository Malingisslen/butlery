// lib/views/social/friends_list/requests_tab.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
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
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.spacingL),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _DiscoverySection(),
          Selector<FriendsViewModel, bool>(
            selector: (_, vm) =>
                vm.incomingRequests.isEmpty && vm.sentRequests.isEmpty,
            builder: (context, noRequests, _) {
              if (!noRequests) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: AppDimensions.spacingXl),
                child: StateWidget.empty(
                  title: context.l10n.socialNoFriendRequests,
                  subtitle: context.l10n.socialNoFriendRequestsDescription,
                  icon: Icons.search,
                ),
              );
            },
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
          color:
              cs.primary.withValues(alpha: AppDimensions.opacityMediumLight),
          width: AppDimensions.borderWidthThin,
        ),
      ),
      child: Column(
        children: [
          Icon(Icons.search,
              size: AppDimensions.iconSizeXl, color: cs.primary),
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
              FilledButton.icon(
                onPressed: () {
                  final vm = context.read<FriendsViewModel>();
                  RequestsTab.shareInvitationLink(context, vm);
                },
                icon:
                    const Icon(Icons.share, size: AppDimensions.iconSizeM),
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
