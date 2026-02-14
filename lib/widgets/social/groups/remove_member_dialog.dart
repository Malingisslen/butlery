// lib/widgets/social/groups/remove_member_dialog.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/widgets/social/groups/shared/group_dialog_components.dart';
import 'package:butlery/widgets/common/dialogs/base_dialog.dart';

/// Dialog for removing a member from a group
/// Refactored to extend BaseActionDialog, eliminating 30+ lines of duplicate
/// state management, error handling, and loading patterns.
class RemoveMemberDialog extends BaseActionDialog<bool> {
  final FriendCategory group;
  final UserProfile member;

  const RemoveMemberDialog({
    super.key,
    required this.group,
    required this.member,
  });

  @override
  Future<bool> performAction(BuildContext context) async {
    final friendsService = ServiceLocator.get<UnifiedFriendsService>();

    final success = await friendsService.categories.removeFriendFromCategory(
      member.uid,
      group.id,
    );

    if (!success) {
      throw Exception('Failed to remove member');
    }

    return true;
  }

  @override
  Widget buildContent(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Confirmation message
        RichText(
          text: TextSpan(
            style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
            children: [
              TextSpan(
                text: context.l10n.groupRemoveMemberConfirmPrefix,
              ),
              TextSpan(
                text: member.displayName,
                style: AppTextStyles.bodyBold.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              TextSpan(
                text: context.l10n.groupRemoveMemberFromGroup,
              ),
              TextSpan(
                text: '"${group.name}"',
                style: AppTextStyles.bodyBold.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const TextSpan(
                text: '?',
              ),
            ],
          ),
        ),

        const SizedBox(height: AppDimensions.spacingM),

        // Warning message
        WarningDisplayWidget(
          warningMessage: context.l10n.groupRemoveMemberWarning,
        ),
      ],
    );
  }

  @override
  Widget? get dialogIcon => const Icon(
        Icons.person_remove,
        color: AppColors.warning,
        size: AppDimensions.iconSizeXxl,
      );

  @override
  String dialogTitleText(BuildContext context) =>
      context.l10n.groupRemoveMember;

  @override
  String actionButtonLabel(BuildContext context) =>
      context.l10n.groupRemoveMember;

  @override
  String? loadingButtonLabel(BuildContext context) =>
      context.l10n.commonDeleting;

  @override
  Widget get actionButtonIcon => const Icon(Icons.person_remove);

  @override
  ButtonStyle get actionButtonStyle => FilledButton.styleFrom(
        backgroundColor: AppColors.warning,
        foregroundColor: AppColors.cardWhite,
      );
}
