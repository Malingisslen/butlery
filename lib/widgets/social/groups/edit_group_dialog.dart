// lib/widgets/social/groups/edit_group_dialog.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/widgets/social/groups/shared/group_dialog_components.dart';

/// Dialog for editing an existing group
/// 
/// This dialog provides a focused interface for group editing with:
/// - Pre-populated form fields from existing group data
/// - Emoji/icon selection with current selection
/// - Group name and description modification
/// - Validation and error handling
/// - Service integration for group updates
class EditGroupDialog extends StatefulWidget {
  final FriendCategory group;

  const EditGroupDialog({super.key, required this.group});

  @override
  State<EditGroupDialog> createState() => _EditGroupDialogState();
}

class _EditGroupDialogState extends State<EditGroupDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  
  late String _selectedEmoji;
  bool _isUpdating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.group.name);
    _descriptionController = TextEditingController(
      text: widget.group.description ?? '',
    );
    _selectedEmoji = widget.group.emoji ?? '👥';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _updateGroup() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (mounted) setState(() {
      _isUpdating = true;
      _error = null;
    });

    try {
      final friendsService = ServiceLocator.get<UnifiedFriendsService>();
      
      final success = await friendsService.categories.updateCategory(
        categoryId: widget.group.id,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty 
          ? null 
          : _descriptionController.text.trim(),
        icon: _selectedEmoji,
      );

      if (success) {
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        if (mounted) setState(() {
          _error = 'Kunde inte uppdatera grupp. Försök igen.';
        });
      }
    } catch (e) {
      AppLogger.error('Error updating group', e);
      if (mounted) setState(() {
        _error = 'Ett fel uppstod: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        if (mounted) setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              DialogHeader(
                title: 'Redigera grupp',
                icon: Icons.edit,
                onClose: () => Navigator.of(context).pop(),
              ),
              
              // Content
              Padding(
                padding: const EdgeInsets.all(AppDimensions.spacingL),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Emoji selection
                    EmojiSelector(
                      selectedEmoji: _selectedEmoji,
                      onEmojiSelected: (emoji) {
                        if (mounted) setState(() {
                          _selectedEmoji = emoji;
                        });
                      },
                    ),
                    
                    const SizedBox(height: AppDimensions.spacingL),
                    
                    // Group name
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Gruppnamn *',
                        prefixIcon: Icon(Icons.group),
                      ),
                      validator: GroupValidationUtils.validateGroupName,
                      maxLength: 50,
                      textCapitalization: TextCapitalization.words,
                    ),
                    
                    const SizedBox(height: AppDimensions.spacingM),
                    
                    // Description (optional)
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Beskrivning (valfritt)',
                        hintText: 'Vad handlar den här gruppen om?',
                        prefixIcon: Icon(Icons.description),
                      ),
                      maxLines: 3,
                      maxLength: 200,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    
                    // Error display
                    if (_error != null) ...[
                      const SizedBox(height: AppDimensions.spacingM),
                      ErrorDisplayWidget(errorMessage: _error!),
                    ],
                  ],
                ),
              ),
              
              // Actions
              DialogFooter(
                primaryActionText: _isUpdating ? 'Sparar...' : 'Spara ändringar',
                secondaryActionText: 'Avbryt',
                onPrimaryAction: _isUpdating ? null : _updateGroup,
                onSecondaryAction: () => Navigator.of(context).pop(),
                isLoading: _isUpdating,
                primaryActionIcon: Icons.save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}