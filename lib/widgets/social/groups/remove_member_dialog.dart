// lib/widgets/social/groups/remove_member_dialog.dart

import 'package:flutter/material.dart';
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
      throw Exception('Kunde inte ta bort medlem. Försök igen.');
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
                text: 'Är du säker på att du vill ta bort ',
              ),
              TextSpan(
                text: member.displayName,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const TextSpan(
                text: ' från gruppen ',
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
          warningMessage: 'Medlemmen kommer att förlora åtkomst till gruppens innehåll.',
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
  String get dialogTitle => 'Ta bort medlem';

  @override
  String get actionButtonText => 'Ta bort medlem';

  @override
  String get loadingButtonText => 'Tar bort...';

  @override
  Widget get actionButtonIcon => const Icon(Icons.person_remove);

  @override
  ButtonStyle get actionButtonStyle => FilledButton.styleFrom(
    backgroundColor: AppColors.warning,
    foregroundColor: Colors.white,
  );
}