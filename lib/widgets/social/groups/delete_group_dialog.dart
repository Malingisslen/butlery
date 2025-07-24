// lib/widgets/social/groups/delete_group_dialog.dart

import 'package:flutter/material.dart';
import '../../../models/friend_category.dart';
import '../../../services/unified/unified_friends_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_dimensions.dart';
import '../../../theme/app_text_styles.dart';
import '../../../core/injection.dart';
import '../../../core/utils/logger.dart';
import 'shared/group_dialog_components.dart';

/// Dialog for deleting a group
/// 
/// This dialog provides a focused interface for group deletion with:
/// - Clear confirmation messaging
/// - Warning about permanent action
/// - Group name display for verification
/// - Service integration for group deletion
/// - Error handling
class DeleteGroupDialog extends StatefulWidget {
  final FriendCategory group;

  const DeleteGroupDialog({super.key, required this.group});

  @override
  State<DeleteGroupDialog> createState() => _DeleteGroupDialogState();
}

class _DeleteGroupDialogState extends State<DeleteGroupDialog> {
  bool _isDeleting = false;
  String? _error;

  Future<void> _deleteGroup() async {
    setState(() {
      _isDeleting = true;
      _error = null;
    });

    try {
      final friendsService = sl<UnifiedFriendsService>();
      
      final success = await friendsService.categories.deleteCategory(
        widget.group.id,
      );

      if (success) {
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        setState(() {
          _error = 'Kunde inte ta bort grupp. Försök igen.';
        });
      }
    } catch (e) {
      AppLogger.error('Error deleting group', e);
      setState(() {
        _error = 'Ett fel uppstod: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: Icon(
        Icons.warning_amber_rounded,
        color: AppColors.warning,
        size: 48,
      ),
      title: const Text('Ta bort grupp'),
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
                  text: 'Är du säker på att du vill ta bort gruppen ',
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
            warningMessage: 'Detta kan inte ångras. Alla medlemmar kommer att tas bort från gruppen.',
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
          onPressed: _isDeleting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Avbryt'),
        ),
        FilledButton.icon(
          onPressed: _isDeleting ? null : _deleteGroup,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
          ),
          icon: _isDeleting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.delete_forever),
          label: Text(_isDeleting ? 'Tar bort...' : 'Ta bort grupp'),
        ),
      ],
    );
  }
}