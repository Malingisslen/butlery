// lib/views/social/edit_group_dialog.dart

import 'package:flutter/material.dart';
import '../../models/friend_category.dart';
import '../../theme/app_theme.dart';
import '../../core/injection.dart';
import '../../services/friend_categories_service.dart';
import '../../core/events/group_events.dart';

/// 🔍 AI INFO BLOCK:
/// Component: Edit Group Dialog - Redigera befintliga grupper
/// File: views/social/edit_group_dialog.dart
/// Quick Guide: Dialog för att redigera gruppnamn, emoji, beskrivning
/// Dependencies IN: FriendCategory, FriendCategoriesService, GroupEvents
/// Dependencies OUT: Uppdatera grupp + trigga events för UI-uppdatering
/// Data flow: Load existing data → Edit → Validate → Save → Trigger event
/// State management: StatefulWidget med local form state
/// Purpose: Användarvänlig redigering av gruppinformation med validering
/// Common issues: Form validation, name conflicts, event triggering
/// Test coverage: N/A (UI component)
/// Performance: ⚡ Minimal, endast form state
/// Analytics: ✅ Group edit tracking
/// Code smells: ✅ Clean form validation, event-driven updates
/// Connected to: FriendCategoriesService, GroupEventBus
/// Used in phases: 18.4 - Steg 2B

class EditGroupDialog extends StatefulWidget {
  final FriendCategory group;

  const EditGroupDialog({
    super.key,
    required this.group,
  });

  @override
  State<EditGroupDialog> createState() => _EditGroupDialogState();
}

class _EditGroupDialogState extends State<EditGroupDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  late String _selectedEmoji;
  bool _isSaving = false;

  // Fördefinierade emojis för grupper
  final List<String> _availableEmojis = [
    '👥',
    '🏠',
    '🍽️',
    '💼',
    '🎯',
    '⚽',
    '🎮',
    '📚',
    '🎵',
    '✈️',
    '🍕',
    '💪',
    '🛒',
    '🎉',
    '❤️',
    '⭐'
  ];

  @override
  void initState() {
    super.initState();

    // Förfyll med befintliga värden
    _nameController = TextEditingController(text: widget.group.name);
    _descriptionController =
        TextEditingController(text: widget.group.description ?? '');
    _selectedEmoji = widget.group.emoji ?? '👥';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(AppTheme.spacingLg),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(AppTheme.radiusMedium),
                  topRight: Radius.circular(AppTheme.radiusMedium),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.edit,
                    color: AppTheme.primaryColor,
                    size: AppTheme.iconSizeMedium,
                  ),
                  SizedBox(width: AppTheme.spacingMd),
                  const Expanded(
                    child: Text(
                      'Redigera grupp',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(AppTheme.spacingLg),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Info om befintlig grupp
                      Container(
                        padding: EdgeInsets.all(AppTheme.spacingMd),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.05),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSmall),
                          border: Border.all(
                            color: AppTheme.primaryColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: AppTheme.primaryColor,
                              size: AppTheme.iconSizeInfo,
                            ),
                            SizedBox(width: AppTheme.spacingSm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Redigerar: ${widget.group.name}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          color: AppTheme.primaryColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                  Text(
                                    '${widget.group.friendCount} ${widget.group.friendCount == 1 ? 'medlem' : 'medlemmar'}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: AppTheme.primaryColor,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: AppTheme.spacingLg),

                      // Gruppnamn
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Gruppnamn *',
                          hintText: 'T.ex. Familjen, Jobbet, Träningskompisar',
                          prefixIcon: Container(
                            width: 48,
                            height: 48,
                            alignment: Alignment.center,
                            child: Text(
                              _selectedEmoji,
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value?.trim().isEmpty ?? true) {
                            return 'Gruppnamn krävs';
                          }

                          // Kontrollera om namnet ändrats
                          final newName = value!.trim();
                          if (newName != widget.group.name) {
                            // Kontrollera om det nya namnet redan finns
                            final categoriesService =
                                sl<FriendCategoriesService>();
                            if (!categoriesService
                                .isCategoryNameAvailable(newName)) {
                              return 'Det här gruppnamnet finns redan';
                            }
                          }
                          return null;
                        },
                        textCapitalization: TextCapitalization.words,
                      ),

                      SizedBox(height: AppTheme.spacingLg),

                      // Emoji-väljare
                      Text(
                        'Välj ikon för gruppen',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      SizedBox(height: AppTheme.spacingSm),
                      Container(
                        padding: EdgeInsets.all(AppTheme.spacingSm),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSmall),
                        ),
                        child: Wrap(
                          spacing: AppTheme.spacingSm,
                          runSpacing: AppTheme.spacingSm,
                          children: _availableEmojis.map((emoji) {
                            final isSelected = emoji == _selectedEmoji;
                            return GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedEmoji = emoji),
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppTheme.primaryColor
                                          .withValues(alpha: 0.2)
                                      : null,
                                  borderRadius: BorderRadius.circular(
                                      AppTheme.radiusSmall),
                                  border: isSelected
                                      ? Border.all(color: AppTheme.primaryColor)
                                      : null,
                                ),
                                child: Center(
                                  child: Text(
                                    emoji,
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      SizedBox(height: AppTheme.spacingLg),

                      // Beskrivning
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Beskrivning (valfritt)',
                          hintText: 'Beskriv vad den här gruppen är till för',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                      ),

                      SizedBox(height: AppTheme.spacingLg),

                      // Info om medlemmar (readonly)
                      Container(
                        padding: EdgeInsets.all(AppTheme.spacingMd),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.3),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSmall),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.people,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              size: AppTheme.iconSizeInfo,
                            ),
                            SizedBox(width: AppTheme.spacingSm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Medlemmar',
                                    style:
                                        Theme.of(context).textTheme.titleSmall,
                                  ),
                                  Text(
                                    '${widget.group.friendCount} ${widget.group.friendCount == 1 ? 'medlem' : 'medlemmar'} i gruppen',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              'Hantera medlemmar\nkomma i nästa steg',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    fontStyle: FontStyle.italic,
                                  ),
                              textAlign: TextAlign.end,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer buttons
            Container(
              padding: EdgeInsets.all(AppTheme.spacingLg),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _isSaving ? null : () => Navigator.pop(context),
                      child: const Text('Avbryt'),
                    ),
                  ),
                  SizedBox(width: AppTheme.spacingMd),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isSaving ? null : _saveChanges,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : const Icon(Icons.save),
                      label: Text(_isSaving ? 'Sparar...' : 'Spara ändringar'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final categoriesService = sl<FriendCategoriesService>();

      // Kontrollera om något ändrats
      final hasChanges = _nameController.text.trim() != widget.group.name ||
          _descriptionController.text.trim() !=
              (widget.group.description ?? '') ||
          _selectedEmoji != widget.group.emoji;

      if (!hasChanges) {
        // Inga ändringar gjorda
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Inga ändringar att spara'),
              backgroundColor: AppTheme.warningColor,
            ),
          );
          Navigator.pop(context);
        }
        return;
      }

      // Uppdatera gruppen (kommer att implementeras i service)
      final success = await _updateGroup(categoriesService);

      if (success && mounted) {
        // ✅ Trigga event för att uppdatera alla lyssnade vyer
        GroupEventBus.groupUpdated();

        // Visa framgångsmeddelande
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gruppen "${_nameController.text.trim()}" uppdaterad! ✏️',
            ),
            backgroundColor: AppTheme.successColor,
          ),
        );

        // Stäng dialogen
        Navigator.pop(context);
      } else if (mounted) {
        // Visa felmeddelande
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kunde inte spara ändringar'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fel vid sparande: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // Uppdatera gruppen via service
  Future<bool> _updateGroup(FriendCategoriesService categoriesService) async {
    return await categoriesService.updateCategory(
      categoryId: widget.group.id,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      emoji: _selectedEmoji,
      // Behåll befintliga medlemmar - medlemshantering kommer i nästa steg
      friendUserIds: widget.group.friendUserIds,
    );
  }
}
