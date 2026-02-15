// lib/views/unified_shopping/widgets/dialogs/shopping_list_operations.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/core/dialogs/dialog_factory.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/styled/styled_input.dart';
import 'package:butlery/core/utils/validation_utils.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// List management operations for shopping lists
class ShoppingListOperations {
  static Future<void> showCreateListDialog(
    BuildContext context,
    UnifiedShoppingViewModel viewModel,
    Function(String) onSuccess,
  ) async {
    final name = await DialogFactory.showTextInput(
      context,
      title: context.l10n.shoppingCreateNewList,
      hintText: context.l10n.shoppingCreateNewListHint,
      confirmText: context.l10n.commonCreate,
      required: true,
    );

    if (name != null && name.isNotEmpty) {
      await viewModel.createPersonalList(name);
      if (context.mounted) onSuccess(context.l10n.shoppingListCreated(name));
    }
  }

  static Future<void> showClearCompletedConfirmation(
    BuildContext context,
    UnifiedShoppingViewModel viewModel,
    Function(String) onSuccess,
  ) async {
    if (viewModel.boughtItems == 0) return;

    final confirmed = await DialogFactory.showConfirmation(
      context,
      title: context.l10n.shoppingClearPurchasedTitle,
      message:
          context.l10n.shoppingClearPurchasedMessage(viewModel.boughtItems),
      confirmText: context.l10n.shoppingClear,
      isDangerous: true,
    );

    if (confirmed == true) {
      await viewModel.clearBoughtItems();
      if (context.mounted) onSuccess(context.l10n.shoppingPurchasedCleared);
    }
  }

  static Future<void> showRenameListDialog(
    BuildContext context,
    UnifiedShoppingList list,
    UnifiedShoppingViewModel viewModel,
    Function(String) onSuccess,
    Function(String) onError,
  ) async {
    final textController = TextEditingController(text: list.name);
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.shoppingRenameList),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.l10n.shoppingCurrentName(list.name),
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppDimensions.spacingM),
              StyledInput(
                controller: textController,
                autofocus: true,
                label: context.l10n.shoppingNewName,
                hint: context.l10n.shoppingNewNameHint,
                validator: (value) {
                  final requiredCheck = ValidationUtils.validateRequired(value,
                      fieldName: context.l10n.commonName);
                  if (requiredCheck != null) return requiredCheck;
                  return ValidationUtils.validateLength(value,
                      minLength: 2,
                      maxLength: 50,
                      fieldName: context.l10n.commonName);
                },
                maxLength: 50,
              ),
            ],
          ),
        ),
        actions: [
          ActionButtons.secondaryButton(
            context,
            label: context.l10n.commonCancel,
            onPressed: () => Navigator.pop(context),
          ),
          ActionButtons.primaryButton(
            context,
            label: context.l10n.commonSave,
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final newName = textController.text.trim();
                Navigator.pop(context, newName);
              }
            },
          ),
        ],
      ),
    );

    if (result != null && result != list.name) {
      final success = await viewModel.renameList(list.id, result);
      if (context.mounted) {
        if (success) {
          onSuccess(context.l10n.shoppingListRenamed(result));
        } else {
          onError(context.l10n.shoppingCouldNotRenameList);
        }
      }
    }
  }

  static Future<void> showDeleteListConfirmationDialog(
    BuildContext context,
    UnifiedShoppingList list,
    UnifiedShoppingViewModel viewModel,
    Function(String) onSuccess,
    Function(String) onError,
  ) async {
    final confirmed = await DialogFactory.showConfirmation(
      context,
      title: context.l10n.shoppingDeleteList,
      message: list.items.isEmpty
          ? context.l10n.shoppingDeleteListConfirm(list.name)
          : context.l10n
              .shoppingDeleteListWithItemsConfirm(list.name, list.items.length),
      confirmText: context.l10n.commonDelete,
      cancelText: context.l10n.commonCancel,
      isDangerous: true,
    );

    if (confirmed == true) {
      final success = await viewModel.deleteList(list.id);
      if (context.mounted) {
        if (success) {
          onSuccess(context.l10n.shoppingListDeleted(list.name));
        } else {
          onError(context.l10n.shoppingCouldNotDeleteList);
        }
      }
    }
  }

  /// Shows friend picker dialog for converting a personal list to collaborative.
  /// Loads available friends, lets the user select members, then calls the
  /// backend conversion operation.
  static Future<void> showConvertToCollaborativeDialog(
    BuildContext context,
    UnifiedShoppingList list,
    Function(String) onSuccess,
    Function(String) onError,
  ) async {
    try {
      final friendsService = ServiceLocator.get<UnifiedFriendsService>();
      await friendsService.initialize();
      final availableFriends = friendsService.friends;

      if (availableFriends.isEmpty) {
        if (context.mounted) {
          onError(context.l10n.shoppingNoFriends);
        }
        return;
      }

      if (!context.mounted) return;

      final result = await showDialog<_ConvertToCollaborativeResult>(
        context: context,
        builder: (context) => _ConvertToCollaborativeDialog(
          friends: availableFriends,
        ),
      );

      if (result == null || result.selectedFriends.isEmpty) return;

      final shoppingService = ServiceLocator.get<UnifiedShoppingService>();
      final memberIds = result.selectedFriends.map((f) => f.uid).toList();
      final memberDisplayNames = {
        for (final f in result.selectedFriends) f.uid: f.displayName,
      };

      final newListId =
          await shoppingService.collaborative.convertPersonalToCollaborative(
        personalListId: list.id,
        memberIds: memberIds,
        memberDisplayNames: memberDisplayNames,
        description: result.description,
      );

      if (newListId != null && context.mounted) {
        onSuccess(context.l10n.shoppingConvertedToCollaborative);
      } else if (context.mounted) {
        onError(context.l10n.shoppingConvertError);
      }
    } catch (e) {
      AppLogger.error('Error converting to collaborative: $e');
      if (context.mounted) {
        onError(context.l10n.shoppingConvertError);
      }
    }
  }

  /// Shows confirmation dialog for converting a collaborative list to personal.
  /// Warns that collaborators will lose access.
  static Future<void> showConvertToPersonalDialog(
    BuildContext context,
    UnifiedShoppingList list,
    Function(String) onSuccess,
    Function(String) onError,
  ) async {
    final confirmed = await DialogFactory.showConfirmation(
      context,
      title: context.l10n.shoppingConvertToPersonalTitle,
      message: context.l10n.shoppingConvertToPersonalWarning,
      confirmText: context.l10n.shoppingConvertToPersonal,
      isDangerous: true,
    );

    if (confirmed != true) return;

    try {
      final shoppingService = ServiceLocator.get<UnifiedShoppingService>();
      final newListId = await shoppingService.collaborative
          .convertCollaborativeToPersonal(list.id);

      if (newListId != null && context.mounted) {
        onSuccess(context.l10n.shoppingConvertedToPersonal);
      } else if (context.mounted) {
        onError(context.l10n.shoppingConvertError);
      }
    } catch (e) {
      AppLogger.error('Error converting to personal: $e');
      if (context.mounted) {
        onError(context.l10n.shoppingConvertError);
      }
    }
  }
}

/// Result from the convert-to-collaborative dialog
class _ConvertToCollaborativeResult {
  final List<UserProfile> selectedFriends;
  final String? description;

  _ConvertToCollaborativeResult({
    required this.selectedFriends,
    this.description,
  });
}

/// Stateful dialog for selecting friends when converting to collaborative list
class _ConvertToCollaborativeDialog extends StatefulWidget {
  final List<UserProfile> friends;

  const _ConvertToCollaborativeDialog({required this.friends});

  @override
  State<_ConvertToCollaborativeDialog> createState() =>
      _ConvertToCollaborativeDialogState();
}

class _ConvertToCollaborativeDialogState
    extends State<_ConvertToCollaborativeDialog> {
  final Set<String> _selectedIds = {};
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.shoppingConvertToCollaborativeTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.shoppingConvertToCollaborativeDescription,
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingM),
            // Friend list with checkboxes
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.friends.length,
                itemBuilder: (context, index) {
                  final friend = widget.friends[index];
                  final isSelected = _selectedIds.contains(friend.uid);
                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: (checked) {
                      setState(() {
                        if (checked == true) {
                          _selectedIds.add(friend.uid);
                        } else {
                          _selectedIds.remove(friend.uid);
                        }
                      });
                    },
                    title: Text(
                      friend.displayName,
                      style: AppTextStyles.contentLabel,
                    ),
                    subtitle: friend.email.isNotEmpty
                        ? Text(
                            friend.email,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          )
                        : null,
                    secondary: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Text(
                        friend.displayName.isNotEmpty
                            ? friend.displayName[0].toUpperCase()
                            : '?',
                        style: AppTextStyles.contentLabel.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                    controlAffinity: ListTileControlAffinity.trailing,
                    activeColor: Theme.of(context).colorScheme.primary,
                    contentPadding: EdgeInsets.zero,
                  );
                },
              ),
            ),
            const SizedBox(height: AppDimensions.spacingM),
            // Optional description field
            StyledInput(
              controller: _descriptionController,
              label: context.l10n.shoppingDescriptionLabel,
              maxLength: 200,
            ),
          ],
        ),
      ),
      actions: [
        ActionButtons.secondaryButton(
          context,
          label: context.l10n.commonCancel,
          onPressed: () => Navigator.pop(context),
        ),
        ActionButtons.primaryButton(
          context,
          label: context.l10n.shoppingConvertToCollaborative,
          onPressed: _selectedIds.isEmpty
              ? null
              : () {
                  final selected = widget.friends
                      .where((f) => _selectedIds.contains(f.uid))
                      .toList();
                  final description =
                      _descriptionController.text.trim().isNotEmpty
                          ? _descriptionController.text.trim()
                          : null;
                  Navigator.pop(
                    context,
                    _ConvertToCollaborativeResult(
                      selectedFriends: selected,
                      description: description,
                    ),
                  );
                },
        ),
      ],
    );
  }
}
