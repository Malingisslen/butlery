// lib/widgets/social/groups/group_dialog_implementations.dart

import 'package:flutter/material.dart';
import '../../../models/friend_category.dart';
import '../../../models/user_profile.dart';
import '../../../services/unified/unified_friends_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_dimensions.dart';
import '../../../theme/app_text_styles.dart';
import '../../../core/injection.dart';
import '../../../core/utils/logger.dart';

/// Dialog implementations for group management
///
/// This module contains fully functional dialog widget implementations
/// for creating, editing, and deleting groups with proper service integration.
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

  final List<String> _availableEmojis = [
    '👥', '🏠', '💼', '🎯', '⚽', '🎮', '📚', '🎵', '🍕', '☕',
    '💪', '🌟', '🔥', '💎', '🚀', '🎉', '💡', '🎨', '🌈', '⭐'
  ];

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
    
    setState(() {
      _isCreating = true;
      _error = null;
    });

    try {
      final friendsService = sl<UnifiedFriendsService>();
      
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
        setState(() {
          _error = 'Kunde inte skapa grupp. Försök igen.';
        });
      }
    } catch (e) {
      AppLogger.error('Error creating group', e);
      setState(() {
        _error = 'Ett fel uppstod: ${e.toString()}';
      });
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
              Container(
                padding: EdgeInsets.all(AppDimensions.spacingL),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.group_add,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    SizedBox(width: AppDimensions.spacingS),
                    Text(
                      'Skapa ny grupp',
                      style: AppTextStyles.headlineSmall.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              
              // Content
              Padding(
                padding: EdgeInsets.all(AppDimensions.spacingL),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Emoji selection
                    Text(
                      'Välj ikon',
                      style: AppTextStyles.titleMedium,
                    ),
                    SizedBox(height: AppDimensions.spacingS),
                    Container(
                      height: 60,
                      padding: EdgeInsets.all(AppDimensions.spacingS),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _availableEmojis.length,
                        itemBuilder: (context, index) {
                          final emoji = _availableEmojis[index];
                          final isSelected = emoji == _selectedEmoji;
                          
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedEmoji = emoji;
                              });
                            },
                            child: Container(
                              width: 44,
                              height: 44,
                              margin: EdgeInsets.only(
                                right: AppDimensions.spacingS,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primaryContainer
                                    : null,
                                borderRadius: BorderRadius.circular(8),
                                border: isSelected
                                    ? Border.all(
                                        color: Theme.of(context).colorScheme.primary,
                                        width: 2,
                                      )
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  emoji,
                                  style: const TextStyle(fontSize: 20),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    
                    SizedBox(height: AppDimensions.spacingL),
                    
                    // Group name
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Gruppnamn *',
                        hintText: 'T.ex. "Familjen", "Jobbet", "Bokklubben"',
                        prefixIcon: Icon(Icons.group),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Ange ett gruppnamn';
                        }
                        if (value.trim().length < 2) {
                          return 'Gruppnamnet måste vara minst 2 tecken';
                        }
                        if (value.trim().length > 50) {
                          return 'Gruppnamnet får vara max 50 tecken';
                        }
                        return null;
                      },
                      maxLength: 50,
                      textCapitalization: TextCapitalization.words,
                    ),
                    
                    SizedBox(height: AppDimensions.spacingM),
                    
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
                    
                    if (_selectedFriendIds.isNotEmpty) ...[
                      SizedBox(height: AppDimensions.spacingM),
                      Text(
                        'Förvalda medlemmar (${_selectedFriendIds.length})',
                        style: AppTextStyles.titleMedium,
                      ),
                      SizedBox(height: AppDimensions.spacingS),
                      Text(
                        'Dessa vänner kommer att få en inbjudan till gruppen.',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    
                    if (_error != null) ...[
                      SizedBox(height: AppDimensions.spacingM),
                      Container(
                        padding: EdgeInsets.all(AppDimensions.spacingM),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.error),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: AppColors.error,
                              size: 20,
                            ),
                            SizedBox(width: AppDimensions.spacingS),
                            Expanded(
                              child: Text(
                                _error!,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              // Actions
              Container(
                padding: EdgeInsets.all(AppDimensions.spacingL),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isCreating
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Avbryt'),
                    ),
                    SizedBox(width: AppDimensions.spacingM),
                    FilledButton.icon(
                      onPressed: _isCreating ? null : _createGroup,
                      icon: _isCreating
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            )
                          : const Icon(Icons.group_add),
                      label: Text(_isCreating ? 'Skapar...' : 'Skapa grupp'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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

  final List<String> _availableEmojis = [
    '👥', '🏠', '💼', '🎯', '⚽', '🎮', '📚', '🎵', '🍕', '☕',
    '💪', '🌟', '🔥', '💎', '🚀', '🎉', '💡', '🎨', '🌈', '⭐'
  ];

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
    
    setState(() {
      _isUpdating = true;
      _error = null;
    });

    try {
      final friendsService = sl<UnifiedFriendsService>();
      
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
        setState(() {
          _error = 'Kunde inte uppdatera grupp. Försök igen.';
        });
      }
    } catch (e) {
      AppLogger.error('Error updating group', e);
      setState(() {
        _error = 'Ett fel uppstod: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
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
              Container(
                padding: EdgeInsets.all(AppDimensions.spacingL),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.edit,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    SizedBox(width: AppDimensions.spacingS),
                    Text(
                      'Redigera grupp',
                      style: AppTextStyles.headlineSmall.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              
              // Content
              Padding(
                padding: EdgeInsets.all(AppDimensions.spacingL),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Emoji selection
                    Text(
                      'Välj ikon',
                      style: AppTextStyles.titleMedium,
                    ),
                    SizedBox(height: AppDimensions.spacingS),
                    Container(
                      height: 60,
                      padding: EdgeInsets.all(AppDimensions.spacingS),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _availableEmojis.length,
                        itemBuilder: (context, index) {
                          final emoji = _availableEmojis[index];
                          final isSelected = emoji == _selectedEmoji;
                          
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedEmoji = emoji;
                              });
                            },
                            child: Container(
                              width: 44,
                              height: 44,
                              margin: EdgeInsets.only(
                                right: AppDimensions.spacingS,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primaryContainer
                                    : null,
                                borderRadius: BorderRadius.circular(8),
                                border: isSelected
                                    ? Border.all(
                                        color: Theme.of(context).colorScheme.primary,
                                        width: 2,
                                      )
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  emoji,
                                  style: const TextStyle(fontSize: 20),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    
                    SizedBox(height: AppDimensions.spacingL),
                    
                    // Group name
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Gruppnamn *',
                        prefixIcon: Icon(Icons.group),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Ange ett gruppnamn';
                        }
                        if (value.trim().length < 2) {
                          return 'Gruppnamnet måste vara minst 2 tecken';
                        }
                        if (value.trim().length > 50) {
                          return 'Gruppnamnet får vara max 50 tecken';
                        }
                        return null;
                      },
                      maxLength: 50,
                      textCapitalization: TextCapitalization.words,
                    ),
                    
                    SizedBox(height: AppDimensions.spacingM),
                    
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
                    
                    if (_error != null) ...[
                      SizedBox(height: AppDimensions.spacingM),
                      Container(
                        padding: EdgeInsets.all(AppDimensions.spacingM),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.error),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: AppColors.error,
                              size: 20,
                            ),
                            SizedBox(width: AppDimensions.spacingS),
                            Expanded(
                              child: Text(
                                _error!,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              // Actions
              Container(
                padding: EdgeInsets.all(AppDimensions.spacingL),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isUpdating
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Avbryt'),
                    ),
                    SizedBox(width: AppDimensions.spacingM),
                    FilledButton.icon(
                      onPressed: _isUpdating ? null : _updateGroup,
                      icon: _isUpdating
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            )
                          : const Icon(Icons.save),
                      label: Text(_isUpdating ? 'Sparar...' : 'Spara ändringar'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
          Container(
            padding: EdgeInsets.all(AppDimensions.spacingM),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppColors.warning,
                  size: 20,
                ),
                SizedBox(width: AppDimensions.spacingS),
                Expanded(
                  child: Text(
                    'Detta kan inte ångras. Alla medlemmar kommer att tas bort från gruppen.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            SizedBox(height: AppDimensions.spacingM),
            Container(
              padding: EdgeInsets.all(AppDimensions.spacingM),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.error),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: AppColors.error,
                    size: 20,
                  ),
                  SizedBox(width: AppDimensions.spacingS),
                  Expanded(
                    child: Text(
                      _error!,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
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

class RemoveMemberDialog extends StatefulWidget {
  final FriendCategory group;
  final UserProfile member;

  const RemoveMemberDialog({super.key, required this.group, required this.member});

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
          Container(
            padding: EdgeInsets.all(AppDimensions.spacingM),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppColors.warning,
                  size: 20,
                ),
                SizedBox(width: AppDimensions.spacingS),
                Expanded(
                  child: Text(
                    'Medlemmen kommer att förlora åtkomst till gruppens innehåll.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            SizedBox(height: AppDimensions.spacingM),
            Container(
              padding: EdgeInsets.all(AppDimensions.spacingM),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.error),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: AppColors.error,
                    size: 20,
                  ),
                  SizedBox(width: AppDimensions.spacingS),
                  Expanded(
                    child: Text(
                      _error!,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
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