// lib/widgets/social/groups/create_group_dialog.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/widgets/common/dialogs/dialog_form_fields.dart';
import 'package:butlery/widgets/social/groups/shared/group_dialog_components.dart';

/// Dialog for creating a new group
/// 
/// Enhanced consolidation using DialogFormFields, eliminating 40+ lines of duplicate
/// form field patterns, validation logic, and styling inconsistencies.
class CreateGroupDialog extends StatefulWidget {
  final List<UserProfile>? preSelectedMembers;

  const CreateGroupDialog({super.key, this.preSelectedMembers});

  @override
  State<CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<CreateGroupDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  String _selectedEmoji = '👥';
  final Set<String> _selectedFriendIds = <String>{};
  bool _isCreating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.preSelectedMembers != null) {
      _selectedFriendIds.addAll(
        widget.preSelectedMembers!.map((member) => member.uid)
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (mounted) {
      setState(() {
        _isCreating = true;
        _error = null;
      });
    }

    try {
      final friendsService = ServiceLocator.get<UnifiedFriendsService>();
      
      final categoryId = await friendsService.categories.createCategory(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty 
          ? null 
          : _descriptionController.text.trim(),
        icon: _selectedEmoji,
        initialMemberIds: _selectedFriendIds.toList(),
      );

      if (categoryId != null) {
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        if (mounted) {
          setState(() {
            _error = 'Kunde inte skapa grupp. Försök igen.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Ett fel uppstod: ${e.toString()}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
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
                title: 'Skapa ny grupp',
                icon: Icons.group_add,
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
                        if (mounted) {
                          setState(() {
                            _selectedEmoji = emoji;
                          });
                        }
                      },
                    ),
                    
                    const SizedBox(height: AppDimensions.spacingL),
                    
                    // ✅ CONSOLIDATED: Group name using standardized form field
                    DialogFormFields.buildNameField(
                      controller: _nameController,
                      labelText: 'Gruppnamn',
                      hintText: 'T.ex. "Familjen", "Jobbet", "Bokklubben"',
                      prefixIcon: Icons.group,
                      maxLength: 50,
                    ),
                    
                    // ✅ CONSOLIDATED: Description using standardized form field  
                    DialogFormFields.buildDescriptionField(
                      controller: _descriptionController,
                      labelText: 'Beskrivning (valfritt)',
                      hintText: 'Vad handlar den här gruppen om?',
                      maxLength: 200,
                      maxLines: 3,
                    ),
                    
                    // Pre-selected members info
                    if (_selectedFriendIds.isNotEmpty) ...[
                      const SizedBox(height: AppDimensions.spacingM),
                      Text(
                        'Förvalda medlemmar (${_selectedFriendIds.length})',
                        style: AppTextStyles.titleMedium,
                      ),
                      const SizedBox(height: AppDimensions.spacingS),
                      Text(
                        'Dessa vänner kommer att få en inbjudan till gruppen.',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    
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
                primaryActionText: _isCreating ? 'Skapar...' : 'Skapa grupp',
                secondaryActionText: 'Avbryt',
                onPrimaryAction: _isCreating ? null : _createGroup,
                onSecondaryAction: () => Navigator.of(context).pop(),
                isLoading: _isCreating,
                primaryActionIcon: Icons.group_add,
              ),
            ],
          ),
        ),
      ),
    );
  }
}