// lib/views/social/delete_group_dialog.dart

import 'package:flutter/material.dart';
import '../../models/friend_category.dart';
import '../../theme/app_theme.dart';
import '../../core/injection.dart';
import '../../services/friend_categories_service.dart';
import '../../core/events/group_events.dart';

/// 🔍 AI INFO BLOCK:
/// Component: Delete Group Dialog - Säker bekräftelse för borttagning
/// File: views/social/delete_group_dialog.dart
/// Quick Guide: Bekräftelsedialog för att ta bort grupper med säkerhetskontroller
/// Dependencies IN: FriendCategory, FriendCategoriesService, GroupEvents
/// Dependencies OUT: Ta bort grupp + trigga events för UI-uppdatering
/// Data flow: Show warning → Confirm deletion → Delete → Trigger event → Navigate back
/// State management: StatefulWidget med loading state
/// Purpose: Säker borttagning med tydlig bekräftelse och information
/// Common issues: Accidental deletion prevention, clear user communication
/// Test coverage: N/A (UI component)
/// Performance: ⚡ Minimal, endast confirmation state
/// Analytics: ✅ Group deletion tracking
/// Code smells: ✅ Clear UX patterns, safety-first design
/// Connected to: FriendCategoriesService, GroupEventBus
/// Used in phases: 18.4 - Steg 2C

class DeleteGroupDialog extends StatefulWidget {
  final FriendCategory group;

  const DeleteGroupDialog({
    super.key,
    required this.group,
  });

  @override
  State<DeleteGroupDialog> createState() => _DeleteGroupDialogState();
}

class _DeleteGroupDialogState extends State<DeleteGroupDialog> {
  bool _isDeleting = false;
  bool _confirmationChecked = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: Icon(
        Icons.warning_amber_rounded,
        size: 48,
        color: AppTheme.errorColor,
      ),
      title: const Text(
        'Ta bort grupp?',
        style: TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gruppinformation
            Container(
              padding: EdgeInsets.all(AppTheme.spacingMd),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                border: Border.all(
                  color: AppTheme.errorColor.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    ),
                    child: Center(
                      child: Text(
                        widget.group.emoji ?? '👥',
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                  ),
                  SizedBox(width: AppTheme.spacingMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.group.name,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        Text(
                          widget.group.summary,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: AppTheme.spacingLg),

            // Varningstext
            RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.bodyMedium,
                children: [
                  const TextSpan(
                    text: 'Du är på väg att ta bort gruppen ',
                  ),
                  TextSpan(
                    text: '"${widget.group.name}"',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const TextSpan(
                    text: '. Denna åtgärd kan inte ångras.',
                  ),
                ],
              ),
            ),

            SizedBox(height: AppTheme.spacingMd),

            // Information om vad som händer
            Container(
              padding: EdgeInsets.all(AppTheme.spacingMd),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vad som händer:',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  SizedBox(height: AppTheme.spacingXs),
                  _buildInfoItem('🗑️', 'Gruppen tas bort permanent'),
                  _buildInfoItem('👥',
                      'Medlemmarna påverkas inte (de är fortfarande dina vänner)'),
                  _buildInfoItem('📋',
                      'Eventuella delade inköpslistor med gruppen påverkas'),
                ],
              ),
            ),

            SizedBox(height: AppTheme.spacingLg),

            // Bekräftelse checkbox
            CheckboxListTile(
              value: _confirmationChecked,
              onChanged: _isDeleting
                  ? null
                  : (value) {
                      setState(() {
                        _confirmationChecked = value ?? false;
                      });
                    },
              title: Text(
                'Jag förstår att denna åtgärd inte kan ångras',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              activeColor: AppTheme.errorColor,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      actions: [
        // Avbryt knapp
        TextButton(
          onPressed: _isDeleting ? null : () => Navigator.pop(context, false),
          child: const Text('Avbryt'),
        ),

        // Ta bort knapp
        FilledButton.icon(
          onPressed:
              (_isDeleting || !_confirmationChecked) ? null : _deleteGroup,
          icon: _isDeleting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : const Icon(Icons.delete_forever),
          label: Text(_isDeleting ? 'Tar bort...' : 'Ta bort grupp'),
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.errorColor,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoItem(String emoji, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppTheme.spacingXs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          SizedBox(width: AppTheme.spacingXs),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteGroup() async {
    setState(() {
      _isDeleting = true;
    });

    try {
      final categoriesService = sl<FriendCategoriesService>();

      final success = await categoriesService.deleteCategory(widget.group.id);

      if (success && mounted) {
        // ✅ Trigga event för att uppdatera alla lyssnade vyer
        GroupEventBus.groupDeleted();

        // Visa framgångsmeddelande
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gruppen "${widget.group.name}" har tagits bort',
            ),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Stäng dialogen med bekräftelse
        Navigator.pop(context, true);
      } else if (mounted) {
        // Visa felmeddelande
        final errorMessage =
            categoriesService.error ?? 'Kunde inte ta bort gruppen';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fel vid borttagning: $e'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }
}
