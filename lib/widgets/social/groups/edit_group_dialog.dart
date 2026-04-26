// lib/widgets/social/groups/edit_group_dialog.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/validation_utils.dart';
import 'package:butlery/core/validators/form_validators.dart';
import 'package:butlery/widgets/social/groups/shared/group_dialog_components.dart';

/// Dialog for editing an existing group
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

    if (mounted) {
      setState(() {
        _isUpdating = true;
        _error = null;
      });
    }

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
          // Return updated category to match expected FriendCategory? return type
          final updatedCategory =
              friendsService.getCategoryById(widget.group.id);
          Navigator.of(context).pop(updatedCategory);
        }
      } else {
        if (mounted) {
          setState(() {
            _error = context.l10n.errorCouldNotUpdate(
                context.l10n.socialGroupName.toLowerCase());
          });
        }
      }
    } catch (e) {
      AppLogger.error('Error updating group', e);
      if (mounted) {
        setState(() {
          _error = context.l10n.errorWithContext(
              context.l10n.statusUpdating.toLowerCase(), e.toString());
        });
      }
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
        constraints:
            const BoxConstraints(maxWidth: AppDimensions.dialogMaxWidthMedium),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              DialogHeader(
                title: context.l10n.socialEditGroup,
                icon: Icons.edit,
                onClose: () => Navigator.of(context).pop(),
              ),

              // Content — scrollable to prevent overflow when error is shown
              Flexible(
                child: SingleChildScrollView(
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

                      // Group name
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: '${context.l10n.socialGroupName} *',
                          prefixIcon: const Icon(Icons.group),
                        ),
                        // BUT-517: chain content-filter onto group-name rules.
                        validator: FormValidators.combine([
                          (v) => ValidationUtils.validateGroupName(v),
                          FormValidators.contentFilter(
                              context.l10n.socialGroupName),
                        ]),
                        maxLength: 50,
                        textCapitalization: TextCapitalization.words,
                      ),

                      const SizedBox(height: AppDimensions.spacingM),

                      // Description (optional)
                      TextFormField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          labelText: context.l10n.groupDescriptionLabel,
                          hintText: context.l10n.groupDescriptionHint,
                          prefixIcon: const Icon(Icons.description),
                        ),
                        // BUT-517
                        validator: FormValidators.contentFilter(
                            context.l10n.groupDescriptionLabel),
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
              ),

              // Actions
              DialogFooter(
                primaryActionText: _isUpdating
                    ? context.l10n.statusSaving
                    : context.l10n.commonSaveChanges,
                secondaryActionText: context.l10n.commonCancel,
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
