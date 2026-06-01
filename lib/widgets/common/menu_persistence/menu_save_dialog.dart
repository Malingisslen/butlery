// lib/widgets/common/menu_persistence/menu_save_dialog.dart

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/indicators/loading_indicator.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/validators/form_validators.dart';
import 'package:butlery/viewmodels/menu_viewmodel.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// Dialog for saving a menu with name, comment and social sharing
/// This dialog allows users to save their generated menus with custom names,
/// optional comments, and social sharing options.
class SaveMenuDialog extends StatefulWidget {
  final MenuViewModel viewModel;
  final List<dynamic>? availableFriends;

  const SaveMenuDialog({
    super.key,
    required this.viewModel,
    this.availableFriends,
  });

  @override
  State<SaveMenuDialog> createState() => _SaveMenuDialogState();
}

class _SaveMenuDialogState extends State<SaveMenuDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _commentController = TextEditingController();
  bool _isLoading = false;
  bool _enableSocialSharing = false;
  final List<String> _selectedFriendIds = [];
  final _shareMessageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Default share message set in build() to use l10n
  }

  @override
  void dispose() {
    _nameController.dispose();
    _commentController.dispose();
    _shareMessageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_shareMessageController.text.isEmpty) {
      _shareMessageController.text = context.l10n.menuShareDefaultMessage;
    }
    return AlertDialog(
      title: Text(context.l10n.menuSaveTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMenuInfo(),
                const SizedBox(height: AppDimensions.spacingXl),
                _buildNameField(),
                const SizedBox(height: AppDimensions.spacingXl),
                _buildCommentField(),
                const SizedBox(height: AppDimensions.spacingXl),
                _buildSocialSharingToggle(),
                if (_enableSocialSharing) ...[
                  const SizedBox(height: AppDimensions.spacingXl),
                  _buildFriendSelection(),
                  const SizedBox(height: AppDimensions.spacingXl),
                  _buildShareMessage(),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: Text(context.l10n.commonCancel),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _saveMenu,
          child: _isLoading
              ? LoadingIndicator(
                  size: 20,
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.onPrimary,
                )
              : Text(context.l10n.commonSave),
        ),
      ],
    );
  }

  Widget _buildMenuInfo() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingL),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .primaryContainer
            .withValues(alpha: AppDimensions.opacityMediumLight),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.menuToSave,
            style: AppTextStyles.bodyLargeBold,
          ),
          const SizedBox(height: AppDimensions.spacingXs),
          Text(
            context.l10n.menuRecipesInCategories(
                widget.viewModel.totalRecipeCount,
                widget.viewModel.menu.length),
            style: AppTextStyles.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      decoration: InputDecoration(
        labelText: context.l10n.menuNameLabel,
        hintText: context.l10n.menuNameHint,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.restaurant_menu),
      ),
      validator: FormValidators.required(context.l10n.menuNameRequired),
      maxLength: 50,
      enabled: !_isLoading,
    );
  }

  Widget _buildCommentField() {
    return TextFormField(
      controller: _commentController,
      decoration: InputDecoration(
        labelText: context.l10n.menuCommentLabel,
        hintText: context.l10n.menuCommentHint,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.comment),
      ),
      maxLines: 3,
      maxLength: 200,
      enabled: !_isLoading,
    );
  }

  Widget _buildSocialSharingToggle() {
    return SwitchListTile(
      title: Text(context.l10n.menuShareWithFriends),
      subtitle: Text(context.l10n.menuShareWithFriendsDescription),
      value: _enableSocialSharing,
      onChanged: _isLoading
          ? null
          : (value) {
              if (mounted) {
                setState(() {
                  _enableSocialSharing = value;
                  if (!value) {
                    _selectedFriendIds.clear();
                  }
                });
              }
            },
    );
  }

  Widget _buildFriendSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.menuSelectFriendsToShare,
          style: AppTextStyles.bodyLargeBold,
        ),
        const SizedBox(height: AppDimensions.spacingXs),
        Container(
          height: 150,
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.outline),
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
          ),
          child: widget.availableFriends == null ||
                  widget.availableFriends!.isEmpty
              ? Center(
                  child: Builder(
                    builder: (context) => Text(
                      context.l10n.menuNoFriendsAvailable,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: widget.availableFriends!.length,
                  itemBuilder: (context, index) {
                    final friend = widget.availableFriends![index];
                    final friendId = friend.uid;
                    final friendName = friend.displayName;
                    final isSelected = _selectedFriendIds.contains(friendId);

                    return CheckboxListTile(
                      title: Text(friendName),
                      value: isSelected,
                      onChanged: _isLoading
                          ? null
                          : (bool? selected) {
                              if (mounted) {
                                setState(() {
                                  if (selected == true) {
                                    _selectedFriendIds.add(friendId);
                                  } else {
                                    _selectedFriendIds.remove(friendId);
                                  }
                                });
                              }
                            },
                      dense: true,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildShareMessage() {
    return TextFormField(
      controller: _shareMessageController,
      decoration: InputDecoration(
        labelText: context.l10n.menuShareMessageLabel,
        hintText: context.l10n.menuShareMessageHint,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.message),
      ),
      maxLines: 2,
      maxLength: 100,
      enabled: !_isLoading,
    );
  }

  Future<void> _saveMenu() async {
    if (!_formKey.currentState!.validate()) return;

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      // FIXED: Use actual ViewModel save logic
      final success = await widget.viewModel.saveMenuWithNameAndComment(
        _nameController.text,
        _commentController.text,
        shareWithFriends: _enableSocialSharing,
        selectedFriendIds: _selectedFriendIds,
        shareMessage: _shareMessageController.text,
      );

      if (mounted) {
        Navigator.pop(context);
        if (success) {
          final message = context.l10n.menuSavedSuccess(_nameController.text);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: context.butleryColors.success,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(widget.viewModel.error ?? context.l10n.menuSaveFailed),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.errorSavingWithDetails(e.toString())),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}
