// lib/views/social/friend_requests/friend_request_card.dart

import 'package:butlery/widgets/common/buttons/butlery_text_button.dart';
import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/buttons/hero_button.dart';

// Models
import 'package:butlery/models/friend_request.dart';

// Theme
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_mode_colors.dart';

// ViewModels
import 'package:butlery/viewmodels/friends_viewmodel.dart';

// Widgets
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/press_fill.dart';
import 'package:butlery/widgets/common/avatar_circle.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/widgets/common/input/butlery_checkbox.dart';

/// Builds the rows of the friend requests list, incoming and sent. Rows sit in
/// a ButleryListSection, so they carry no card of their own.
class FriendRequestCard {
  /// [selecting] is the "Välj" mode: the row gets a checkbox and a tap toggles
  /// it, and the answer buttons step aside.
  static Widget buildIncomingCard(
    BuildContext context,
    FriendRequest request,
    FriendsViewModel viewModel,
    bool isSelected,
    Function(bool) onSelectionChanged, {
    bool selecting = false,
  }) {
    final userProfile = viewModel.getUserProfile(request.fromUserId);
    final displayName =
        userProfile?.displayName ?? context.l10n.friendRequestTitle;
    final cs = Theme.of(context).colorScheme;
    final hasMessage = request.message?.isNotEmpty == true;

    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.space12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (selecting) ...[
                ButleryCheckbox(
                  value: isSelected,
                  onChanged: onSelectionChanged,
                ),
                const SizedBox(width: AppDimensions.space4),
              ],
              ExcludeSemantics(
                child: AvatarCircle(
                  imageUrl: userProfile?.avatarUrl,
                  displayName: displayName,
                ),
              ),
              const SizedBox(width: AppDimensions.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: AppTextStyles.bodyBold.copyWith(
                        color: cs.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      context.l10n.socialWantsToBeFriend,
                      style: AppTextStyles.captionBase.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppDimensions.space8),
              Text(
                request.timeAgoText,
                style: AppTextStyles.captionBase.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (hasMessage) ...[
            const SizedBox(height: AppDimensions.space8),
            Text(
              '"${request.message!}"',
              style: AppTextStyles.bodyMedium.copyWith(
                fontStyle: FontStyle.italic,
                color: cs.onSurfaceVariant,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (!selecting) ...[
            const SizedBox(height: AppDimensions.space12),
            // Acceptera first, then the decline action, in the order drawn
            // in Skarmar v12 del 3 #forfragningar, which labels the decline
            // action "Avböj" (del 3:406, :420).
            Row(
              children: [
                // PQ-18 = A (produktbeslut 2026-09-23, revised after the
                // prototype): every incoming row keeps a saffron "Acceptera",
                // as drawn. This is a deliberate exception to one saffron
                // action per view (Komponentark v1:843-844; Grafisk manual
                // v6:219), for friend requests only.
                Expanded(
                  child: HeroButton(
                    key: ValueKey('friendRequest.accept.${request.id}'),
                    label: context.l10n.commonAccept,
                    semanticLabel: context.l10n.a11yAcceptFriendRequestFrom(
                      displayName,
                    ),
                    busy: viewModel.isAccepting(request.id),
                    busyLabel: context.l10n.socialAccepting,
                    onPressed: viewModel.isLoading
                        ? null
                        : () => _acceptRequest(context, request, viewModel),
                    expand: true,
                  ),
                ),
                const SizedBox(width: AppDimensions.space12),
                Expanded(
                  child: ActionButtons.outlinedButton(
                    context,
                    label: context.l10n.socialDecline,
                    semanticLabel: context.l10n.a11yDeclineFriendRequestFrom(
                      displayName,
                    ),
                    onPressed: viewModel.isLoading
                        ? null
                        : () => _rejectRequest(context, request, viewModel),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );

    if (!selecting) return content;
    return Semantics(
      label: context.l10n.a11yFriendRequestIncoming,
      button: true,
      selected: isSelected,
      child: PressFill(
        surface: PressSurface.base,
        child: InkWell(
          onTap: () => onSelectionChanged(!isSelected),
          child: content,
        ),
      ),
    );
  }

  static Widget buildSentCard(
    BuildContext context,
    FriendRequest request,
    FriendsViewModel viewModel,
    bool isSelected,
    Function(bool) onSelectionChanged, {
    bool selecting = false,
  }) {
    final userProfile = viewModel.getUserProfile(request.toUserId);
    final displayName =
        userProfile?.displayName ?? context.l10n.friendRequestTitle;
    final cs = Theme.of(context).colorScheme;

    final (statusColor, statusText) = switch (request.status) {
      FriendRequestStatus.pending => (
        cs.onSurfaceVariant,
        context.l10n.socialPendingResponse,
      ),
      FriendRequestStatus.accepted => (
        context.modeColors.success,
        context.l10n.socialAccepted,
      ),
      FriendRequestStatus.rejected => (cs.error, context.l10n.socialDeclined),
      FriendRequestStatus.expired => (
        cs.onSurfaceVariant,
        context.l10n.socialExpired,
      ),
      _ => (cs.onSurfaceVariant, context.l10n.socialUnknownStatus),
    };
    final selectable = selecting && request.isPending;

    final content = ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: AppDimensions.minTouchTarget,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.space12),
        child: Row(
          children: [
            if (selectable) ...[
              ButleryCheckbox(
                value: isSelected,
                onChanged: onSelectionChanged,
              ),
              const SizedBox(width: AppDimensions.space4),
            ],
            ExcludeSemantics(
              child: AvatarCircle(
                imageUrl: userProfile?.avatarUrl,
                displayName: displayName,
              ),
            ),
            const SizedBox(width: AppDimensions.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: AppTextStyles.bodyBold.copyWith(color: cs.onSurface),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (request.message?.isNotEmpty == true)
                    Text(
                      request.message!,
                      style: AppTextStyles.captionBase.copyWith(
                        fontStyle: FontStyle.italic,
                        color: cs.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  Text(
                    '$statusText · ${request.timeAgoText}',
                    style: AppTextStyles.captionBase.copyWith(
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ),
            // Cancel for pending requests, not while choosing.
            if (request.isPending && !selecting)
              ButleryTextButton(
                label: context.l10n.commonCancel,
                semanticLabel: context.l10n.socialCancelRequest,
                tone: ButleryTextButtonTone.warning,
                onPressed: () =>
                    _cancelSentRequest(context, request, viewModel),
              ),
          ],
        ),
      ),
    );

    if (!selectable) return content;
    return Semantics(
      label: context.l10n.a11yFriendRequestSent,
      button: true,
      selected: isSelected,
      child: PressFill(
        surface: PressSurface.base,
        child: InkWell(
          onTap: () => onSelectionChanged(!isSelected),
          child: content,
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
      SnackBarUtils.showSuccess(
        context,
        context.l10n.socialFriendRequestAccepted,
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
      SnackBarUtils.showWarning(
        context,
        context.l10n.socialFriendRequestDeclined,
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
      SnackBarUtils.showWarning(context, context.l10n.socialRequestCancelled);
    }
  }
}
