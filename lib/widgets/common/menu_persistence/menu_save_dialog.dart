// lib/widgets/common/menu_persistence/menu_save_dialog.dart

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/widgets/common/dialogs/butlery_dialog.dart';
import 'package:butlery/widgets/common/dialogs/dialog_cancel_button.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/input/field_error_line.dart';
import 'package:butlery/widgets/common/input/labeled_field.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/validators/form_validators.dart';
import 'package:butlery/viewmodels/menu_viewmodel.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/field_text_style.dart';
import 'package:butlery/widgets/common/input/butlery_checkbox.dart';

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
    return ButleryDialog(
      title: context.l10n.menuSaveTitle,
      scrollable: false,
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
                const SizedBox(height: AppDimensions.space32),
                _buildNameField(),
                const SizedBox(height: AppDimensions.space32),
                _buildCommentField(),
                const SizedBox(height: AppDimensions.space32),
                _buildSocialSharingToggle(),
                if (_enableSocialSharing) ...[
                  const SizedBox(height: AppDimensions.space32),
                  _buildFriendSelection(),
                  const SizedBox(height: AppDimensions.space32),
                  _buildShareMessage(),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        DialogCancelButton(enabled: !_isLoading),
        ButleryDialogPrimary(
          label: context.l10n.commonSave,
          busy: _isLoading,
          onPressed: _saveMenu,
        ),
      ],
    );
  }

  Widget _buildMenuInfo() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.space12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.menuToSave,
            style: AppTextStyles.bodyLargeBold,
          ),
          const SizedBox(height: AppDimensions.space4),
          Text(
            context.l10n.menuRecipesInCategories(
              widget.viewModel.totalRecipeCount,
              widget.viewModel.menu.length,
            ),
            style: AppTextStyles.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildNameField() {
    return LabeledField(
      label: context.l10n.menuNameLabel,
      child: TextFormField(
        errorBuilder: FieldErrorLine.builder,
        style: fieldTextStyle(context, enabled: !_isLoading),
        controller: _nameController,
        decoration: InputDecoration(
          hintText: context.l10n.menuNameHint,
          prefixIcon: const ButleryIcon(ButleryIcons.utensils),
        ),
        validator: FormValidators.required(context.l10n.menuNameRequired),
        maxLength: 50,
        enabled: !_isLoading,
      ),
    );
  }

  Widget _buildCommentField() {
    return LabeledField(
      label: context.l10n.menuCommentLabel,
      child: TextFormField(
        style: fieldTextStyle(context, enabled: !_isLoading),
        controller: _commentController,
        decoration: InputDecoration(
          hintText: context.l10n.menuCommentHint,
          prefixIcon: const ButleryIcon(ButleryIcons.messageSquare),
        ),
        maxLines: 3,
        maxLength: 200,
        enabled: !_isLoading,
      ),
    );
  }

  Widget _buildSocialSharingToggle() {
    return ButleryListRow.toggle(
      label: context.l10n.menuShareWithFriends,
      subtitle: context.l10n.menuShareWithFriendsDescription,
      checked: _enableSocialSharing,
      enabled: !_isLoading,
      onChanged: (value) {
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
        const SizedBox(height: AppDimensions.space4),
        Container(
          height: 150,
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.outline),
            borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
          ),
          child:
              widget.availableFriends == null ||
                  widget.availableFriends!.isEmpty
              ? Center(
                  child: Builder(
                    builder: (context) => Text(
                      context.l10n.menuNoFriendsAvailable,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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

                    return ButleryCheckboxTile(
                      title: Text(friendName),
                      value: isSelected,
                      onChanged: _isLoading
                          ? null
                          : (bool selected) {
                              if (mounted) {
                                setState(() {
                                  if (selected) {
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
    return LabeledField(
      label: context.l10n.menuShareMessageLabel,
      child: TextFormField(
        style: fieldTextStyle(context, enabled: !_isLoading),
        controller: _shareMessageController,
        decoration: InputDecoration(
          hintText: context.l10n.menuShareMessageHint,
          prefixIcon: const ButleryIcon(ButleryIcons.messageSquare),
        ),
        maxLines: 2,
        maxLength: 100,
        enabled: !_isLoading,
      ),
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
          SnackBarUtils.showSuccess(context, message);
        } else {
          SnackBarUtils.showFailure(
            context,
            what: widget.viewModel.error ?? context.l10n.menuSaveFailed,
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
        SnackBarUtils.showFailure(
          context,
          what: context.l10n.errorSavingWithDetails(
            SnackBarUtils.userFriendlyMessage(context, e),
          ),
        );
      }
    }
  }
}
