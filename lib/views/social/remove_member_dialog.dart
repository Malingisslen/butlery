// lib/views/social/remove_member_dialog.dart

import 'package:flutter/material.dart';
import '../../models/friend_category.dart';
import '../../models/user_profile.dart';
import '../../services/friend_categories_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/user_avatar.dart';
import '../../theme/app_theme.dart';
import '../../core/injection.dart';
import '../../core/utils/logger.dart';
import '../../core/events/group_events.dart';

/// 🔍 AI INFO BLOCK:
/// Component: Remove Member Dialog - Smart dialog för medlemsborttagning
/// File: views/social/remove_member_dialog.dart
/// Quick Guide: Dialog med behörighetskontroll för att ta bort medlemmar
/// Dependencies IN: FriendCategoriesService, AuthService, member data
/// Dependencies OUT: Member removal actions, group updates
/// Data flow: Check permissions → Show confirmation → Remove member → Update group
/// State management: Local state med loading och error handling
/// Purpose: Säker medlemsborttagning med behörighetskontroll
/// Common issues: Permission validation, admin checks, self-removal
/// Test coverage: 0% (ny komponent)
/// Performance: ⚡ Minimal state, efficient permission checks
/// Analytics: 📊 Member removal tracking
/// Code smells: ✅ Clean permission logic, clear user feedback
/// Connected to: FriendCategoriesService, GroupDetailView, event bus
/// Used in phases: 18.5 - Avancerad medlemshantering

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

  // Permission checking
  bool get _isCurrentUser => _currentUserId == widget.member.uid;
  bool get _isCurrentUserAdmin => _currentUserId == widget.group.createdBy;
  bool get _canRemoveMember => _isCurrentUser || _isCurrentUserAdmin;

  String? get _currentUserId => sl<AuthService>().currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            _isCurrentUser ? Icons.exit_to_app : Icons.person_remove,
            color: AppTheme.warningColor,
            size: AppTheme.iconSizeAction,
          ),
          AppTheme.smallHorizontalGap,
          Expanded(
            child: Text(
              _isCurrentUser ? 'Lämna grupp' : 'Ta bort medlem',
              style: AppTheme.sectionTitleStyle,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Member info
          _buildMemberInfo(),

          AppTheme.mediumGap,

          // Warning message
          _buildWarningMessage(),

          if (_error != null) ...[
            AppTheme.mediumGap,
            AppTheme.errorContainer(context, _error!),
          ],
        ],
      ),
      actions: [
        // Cancel button
        TextButton(
          onPressed: _isRemoving ? null : () => Navigator.pop(context, false),
          child: const Text('Avbryt'),
        ),

        // Remove button
        FilledButton(
          onPressed:
              _canRemoveMember && !_isRemoving ? _handleRemoveMember : null,
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.errorColor,
            foregroundColor: Colors.white,
          ),
          child: _isRemoving
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppTheme.smallLoadingIndicator(color: Colors.white),
                    AppTheme.smallHorizontalGap,
                    Text(_isCurrentUser ? 'Lämnar...' : 'Tar bort...'),
                  ],
                )
              : Text(_isCurrentUser ? 'Lämna grupp' : 'Ta bort medlem'),
        ),
      ],
    );
  }

  Widget _buildMemberInfo() {
    return Container(
      padding: AppTheme.cardPadding,
      decoration: AppTheme.cardDecoration,
      child: Row(
        children: [
          UserAvatar.medium(
            imageUrl: widget.member.avatarUrl,
            displayName: widget.member.displayName,
          ),
          AppTheme.mediumHorizontalGap,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.member.displayName,
                  style: AppTheme.cardTitleStyle,
                ),
                if (widget.member.bio?.isNotEmpty == true) ...[
                  AppTheme.tinyGap,
                  Text(
                    widget.member.bio!,
                    style: AppTheme.subtitleStyle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (widget.member.uid == widget.group.createdBy) ...[
                  AppTheme.tinyGap,
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingSm,
                      vertical: AppTheme.spacingXs,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: AppTheme.chipRadius,
                    ),
                    child: Text(
                      'Admin',
                      style: AppTheme.chipLabelStyle.copyWith(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningMessage() {
    String message;
    IconData icon;
    Color color;

    if (!_canRemoveMember) {
      message =
          'Du har inte behörighet att ta bort denna medlem. Bara admins kan ta bort andra medlemmar.';
      icon = Icons.lock;
      color = AppTheme.warningColor;
    } else if (_isCurrentUser) {
      message =
          'Är du säker på att du vill lämna gruppen "${widget.group.name}"? Du kommer inte längre att ha tillgång till gruppens innehåll.';
      icon = Icons.info_outline;
      color = AppTheme.warningColor;
    } else {
      message =
          'Är du säker på att du vill ta bort ${widget.member.displayName} från gruppen? Medlemmen kommer att meddelas om borttagningen.';
      icon = Icons.warning_outlined;
      color = AppTheme.errorColor;
    }

    return Container(
      padding: AppTheme.cardPadding,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppTheme.mediumRadius,
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: AppTheme.iconSizeAction),
          AppTheme.smallHorizontalGap,
          Expanded(
            child: Text(
              message,
              style: AppTheme.bodyStyle.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRemoveMember() async {
    if (!_canRemoveMember) {
      _setError('Du har inte behörighet att utföra denna åtgärd');
      return;
    }

    try {
      setState(() {
        _isRemoving = true;
        _error = null;
      });

      final categoriesService = sl<FriendCategoriesService>();

      AppLogger.info(
        '🔄 ${_isCurrentUser ? "Lämnar" : "Tar bort medlem från"} grupp: ${widget.group.name}',
      );

      // Remove member from group
      final success = await categoriesService.removeFriendFromCategory(
        widget.group.id,
        widget.member.uid,
      );

      if (success) {
        AppLogger.success(
          '✅ ${_isCurrentUser ? "Lämnade" : "Tog bort medlem från"} grupp framgångsrikt',
        );

        // Trigger group update event
        GroupEventBus.memberRemoved();

        // Close dialog with success
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        _setError(
          categoriesService.error ??
              'Kunde inte ${_isCurrentUser ? "lämna" : "ta bort medlem från"} gruppen',
        );
      }
    } catch (e) {
      AppLogger.error('❌ Fel vid medlemsborttagning', e);
      _setError('Ett oväntat fel uppstod: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isRemoving = false;
        });
      }
    }
  }

  void _setError(String message) {
    if (mounted) {
      setState(() {
        _error = message;
      });
    }
  }
}
