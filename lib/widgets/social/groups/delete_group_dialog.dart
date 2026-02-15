// lib/widgets/social/groups/delete_group_dialog.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/widgets/social/groups/shared/group_dialog_components.dart';
import 'package:butlery/widgets/common/dialogs/base_dialog.dart';

/// Dialog for deleting a group
/// Refactored to extend BaseActionDialog, eliminating 25+ lines of duplicate
/// state management, error handling, and loading patterns.
class DeleteGroupDialog extends BaseActionDialog<bool> {
  final FriendCategory group;

  const DeleteGroupDialog({super.key, required this.group});

  @override
  Future<bool> performAction(BuildContext context) async {
    final friendsService = ServiceLocator.get<UnifiedFriendsService>();

    final success = await friendsService.categories.deleteCategory(
      group.id,
    );

    if (!success) {
      throw Exception('Failed to delete group');
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
                text: context.l10n.groupDeleteConfirmPrefix,
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
          warningMessage: context.l10n.groupDeleteWarning,
        ),
      ],
    );
  }

  @override
  Widget? get dialogIcon => Builder(
        builder: (context) => Icon(
          Icons.warning_amber_rounded,
          color: context.butleryColors.warning,
          size: AppDimensions.iconSizeXxl,
        ),
      );

  @override
  String dialogTitleText(BuildContext context) => context.l10n.groupDeleteGroup;

  @override
  String actionButtonLabel(BuildContext context) =>
      context.l10n.groupDeleteGroup;

  @override
  String? loadingButtonLabel(BuildContext context) =>
      context.l10n.commonDeleting;

  @override
  Widget get actionButtonIcon => const Icon(Icons.delete_forever);

  @override
  ButtonStyle? actionButtonStyleFor(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FilledButton.styleFrom(
      backgroundColor: cs.error,
      foregroundColor: cs.onError,
    );
  }

  @override
  bool get isDestructiveAction => true;
}
