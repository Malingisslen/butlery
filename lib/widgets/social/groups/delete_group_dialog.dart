// lib/widgets/social/groups/delete_group_dialog.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
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
      throw Exception('Kunde inte ta bort grupp. Försök igen.');
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
              const TextSpan(
                text: 'Är du säker på att du vill ta bort gruppen ',
              ),
              TextSpan(
                text: '"${group.name}"',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
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
        const WarningDisplayWidget(
          warningMessage: 'Detta kan inte ångras. Alla medlemmar kommer att tas bort från gruppen.',
        ),
      ],
    );
  }

  @override
  Widget? get dialogIcon => const Icon(
    Icons.warning_amber_rounded,
    color: AppColors.warning,
    size: AppDimensions.iconSizeXxl,
  );

  @override
  String get dialogTitle => 'Ta bort grupp';

  @override
  String get cancelButtonText => 'Avbryt';

  @override
  String get actionButtonText => 'Ta bort grupp';

  @override
  String get loadingButtonText => 'Tar bort...';

  @override
  Widget get actionButtonIcon => const Icon(Icons.delete_forever);

  @override
  ButtonStyle get actionButtonStyle => FilledButton.styleFrom(
    backgroundColor: AppColors.error,
    foregroundColor: Colors.white,
  );

  @override
  bool get isDestructiveAction => true;
}