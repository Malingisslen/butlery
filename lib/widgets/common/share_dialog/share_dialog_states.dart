// lib/widgets/common/share_dialog/share_dialog_states.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/views/social/friends_list/invitation_link_share.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/universal_share_dialog.dart';

class ShareDialogStates {
  static Widget buildNoFriendsState(
    BuildContext context,
    ShareContentType contentType,
  ) {
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ButleryIcon(
            ButleryIcons.users,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppDimensions.spacingLg),
          Text(
            context.l10n.shareNoFriendsToShareWith,
            style: AppTextStyles.titleMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.spacingM),
          Text(
            context.l10n.shareAddFriendsToShare,
            style: AppTextStyles.bodySmall.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.spacingLg),
          ActionButtons.primaryButton(
            context,
            label: context.l10n.shareAddFriends,
            icon: ButleryIcons.userPlus,
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, Routes.friends);
            },
          ),
          const SizedBox(height: AppDimensions.spacingM),
          ActionButtons.outlinedButton(
            context,
            label: context.l10n.socialInviteFriends,
            icon: ButleryIcons.share2,
            onPressed: () {
              final userId =
                  ServiceLocator.get<PermissionService>().currentUserId;
              if (userId == null) return;
              InvitationLinkShare.shareInvitationLinkForUser(context, userId);
            },
          ),
        ],
      ),
    );
  }

  static Widget buildLoadingState(
    BuildContext context,
    String message,
  ) {
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        // The plate line with what is happening (produktregler.md:163).
        children: [PlateLineMessage(message: message)],
      ),
    );
  }

  static Widget buildSuccessState(
    BuildContext context,
    String message,
    VoidCallback? onClose,
  ) {
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ButleryIcon(
            ButleryIcons.circleCheck,
            size: 64,
            color: context.modeColors.success,
          ),
          const SizedBox(height: AppDimensions.spacingLg),
          Text(
            context.l10n.shareSucceeded,
            style: AppTextStyles.titleMedium.copyWith(
              color: context.modeColors.success,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.spacingM),
          Text(
            message,
            style: AppTextStyles.bodySmall.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          if (onClose != null) ...[
            const SizedBox(height: AppDimensions.spacingLg),
            ActionButtons.primaryButton(
              context,
              label: context.l10n.commonClose,
              onPressed: onClose,
            ),
          ],
        ],
      ),
    );
  }
}
