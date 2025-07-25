// lib/widgets/social/groups/remove_member_dialog.dart

import 'package:flutter/material.dart';
import '../../../models/friend_category.dart';
import '../../../models/user_profile.dart';
import '../../../services/unified/unified_friends_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_dimensions.dart';
import '../../../theme/app_text_styles.dart';
import '../../../core/injection.dart';
import 'shared/group_dialog_components.dart';
import '../../common/dialogs/base_dialog.dart';

/// Dialog for removing a member from a group
/// 
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
    final friendsService = sl<UnifiedFriendsService>();
    
    final success = await friendsService.categories.removeFriendFromCategory(
      friendId: member.uid,
      categoryId: group.id,
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
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(
                text: ' från gruppen ',
              ),
              TextSpan(
                text: '"${group.name}"',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(
                text: '?',
              ),
            ],
          ),
        ),
        
        SizedBox(height: AppDimensions.spacingM),
        
        // Warning message
        const WarningDisplayWidget(
          warningMessage: 'Medlemmen kommer att förlora åtkomst till gruppens innehåll.',
        ),
      ],
    );
  }

  @override
  Widget? get dialogIcon => Icon(
    Icons.person_remove,
    color: AppColors.warning,
    size: 48,
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