// lib/widgets/social/groups/remove_member_dialog.dart

import 'package:flutter/material.dart';
import '../../../models/friend_category.dart';
import '../../../models/user_profile.dart';
import '../../../services/unified/unified_friends_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_dimensions.dart';
import '../../../theme/app_text_styles.dart';
import '../../../core/injection.dart';
import '../../../core/utils/logger.dart';
import 'shared/group_dialog_components.dart';

/// Dialog for removing a member from a group
/// 
/// This dialog provides a focused interface for member removal with:
/// - Clear confirmation messaging with member and group names
/// - Warning about access loss
/// - Service integration for member removal
/// - Error handling
class RemoveMemberDialog extends StatefulWidget {
  final FriendCategory group;
  final UserProfile member;

  const RemoveMemberDialog({
    super.key, 
    required this.group, 
    required this.member,
  });

  @override
  State<RemoveMemberDialog> createState() => _RemoveMemberDialogState();
}

class _RemoveMemberDialogState extends State<RemoveMemberDialog> {
  bool _isRemoving = false;
  String? _error;

  Future<void> _removeMember() async {
    setState(() {
      _isRemoving = true;
      _error = null;
    });

    try {
      final friendsService = sl<UnifiedFriendsService>();
      
      final success = await friendsService.categories.removeFriendFromCategory(
        friendId: widget.member.uid,
        categoryId: widget.group.id,
      );

      if (success) {
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        setState(() {
          _error = 'Kunde inte ta bort medlem. Försök igen.';
        });
      }
    } catch (e) {
      AppLogger.error('Error removing member from group', e);
      setState(() {
        _error = 'Ett fel uppstod: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isRemoving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: Icon(
        Icons.person_remove,
        color: AppColors.warning,
        size: 48,
      ),
      title: const Text('Ta bort medlem'),
      content: Column(
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
                  text: widget.member.displayName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const TextSpan(
                  text: ' från gruppen ',
                ),
                TextSpan(
                  text: '"${widget.group.name}"',
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
          
          // Error display
          if (_error != null) ...[
            SizedBox(height: AppDimensions.spacingM),
            ErrorDisplayWidget(errorMessage: _error!),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isRemoving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Avbryt'),
        ),
        FilledButton.icon(
          onPressed: _isRemoving ? null : _removeMember,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.warning,
            foregroundColor: Colors.white,
          ),
          icon: _isRemoving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.person_remove),
          label: Text(_isRemoving ? 'Tar bort...' : 'Ta bort medlem'),
        ),
      ],
    );
  }
}