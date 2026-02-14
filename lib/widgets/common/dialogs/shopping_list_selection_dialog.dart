// lib/widgets/common/dialogs/shopping_list_selection_dialog.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/widgets/styled/styled_widgets.dart';

/// Shopping List Selection Dialog
/// Allows users to select an existing shopping list or create a new one
/// for adding recipe ingredients. Provides a clean Swedish interface with
/// proper validation and user feedback.
class ShoppingListSelectionDialog extends StatefulWidget {
  final String title;
  final String subtitle;
  final UnifiedShoppingService shoppingService;

  const ShoppingListSelectionDialog({
    super.key,
    required this.title,
    required this.subtitle,
    required this.shoppingService,
  });

  @override
  State<ShoppingListSelectionDialog> createState() =>
      _ShoppingListSelectionDialogState();
}

class _ShoppingListSelectionDialogState
    extends State<ShoppingListSelectionDialog> {
  final _newListNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isCreatingNew = false;
  List<UnifiedShoppingList> _availableLists = [];
  bool _isLoading = true;
  String? _selectedListId;

  @override
  void initState() {
    super.initState();
    _loadShoppingLists();
  }

  @override
  void dispose() {
    _newListNameController.dispose();
    super.dispose();
  }

  Future<void> _loadShoppingLists() async {
    try {
      await widget.shoppingService.loadLists();

      // ULTRATHINK FIX: Filter lists to only show those the user can edit
      final permissionService = ServiceLocator.get<PermissionService>();
      final editableLists = widget.shoppingService.lists.where((list) {
        return permissionService.canEditShoppingList(list.id);
      }).toList();

      setState(() {
        _availableLists = editableLists;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _handleCreateNew() {
    setState(() {
      _isCreatingNew = true;
      _selectedListId = null;
    });
  }

  void _handleSelectExisting(String listId) {
    setState(() {
      _isCreatingNew = false;
      _selectedListId = listId;
    });
  }

  void _handleConfirm() {
    if (_isCreatingNew) {
      if (_formKey.currentState?.validate() != true) return;

      Navigator.pop(context, {
        'action': 'create_new',
        'name': _newListNameController.text.trim(),
      });
    } else if (_selectedListId != null) {
      final selectedList = _availableLists.firstWhere(
        (list) => list.id == _selectedListId,
      );

      Navigator.pop(context, {
        'action': 'select_existing',
        'listId': _selectedListId,
        'listName': selectedList.name,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.title,
        style: AppTextStyles.titleLarge,
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.subtitle,
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingL),
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(),
              )
            else ...[
              // Create new list option
              Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: Icon(
                    _isCreatingNew
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: _isCreatingNew
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  title: Text(context.l10n.shoppingCreateList),
                  subtitle: _isCreatingNew
                      ? Form(
                          key: _formKey,
                          child: Padding(
                            padding: const EdgeInsets.only(
                                top: AppDimensions.spacingS),
                            child: StyledInput(
                              controller: _newListNameController,
                              label: context.l10n.shoppingListName,
                              hint: context.l10n.dialogShoppingListNameHint,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return context.l10n.dialogEnterListName;
                                }
                                if (value.trim().length < 2) {
                                  return context.l10n.dialogNameMinTwoChars;
                                }
                                return null;
                              },
                            ),
                          ),
                        )
                      : Text(context.l10n.dialogCreateNewListForIngredients),
                  onTap: _handleCreateNew,
                ),
              ),

              const SizedBox(height: AppDimensions.spacingM),

              // Existing lists
              if (_availableLists.isNotEmpty) ...[
                Text(
                  context.l10n.dialogOrSelectExistingList,
                  style: AppTextStyles.titleMedium,
                ),
                const SizedBox(height: AppDimensions.spacingS),
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _availableLists.length,
                    itemBuilder: (context, index) {
                      final list = _availableLists[index];
                      return Card(
                        margin: const EdgeInsets.only(
                            bottom: AppDimensions.spacingS),
                        child: ListTile(
                          leading: Icon(
                            _selectedListId == list.id
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: _selectedListId == list.id
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                          title: Text(list.name),
                          subtitle: Text(
                            '${list.totalItems} ${context.l10n.dialogItems} • ${list.type == ListType.collaborative ? context.l10n.dialogShared : context.l10n.dialogPrivate}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          onTap: () => _handleSelectExisting(list.id),
                        ),
                      );
                    },
                  ),
                ),
              ] else if (!_isCreatingNew) ...[
                Container(
                  padding: const EdgeInsets.all(AppDimensions.paddingL),
                  decoration: BoxDecoration(
                    color: AppColors.cardWhite,
                    borderRadius:
                        BorderRadius.circular(AppDimensions.borderRadiusM),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: AppDimensions.spacingM),
                      Expanded(
                        child: Text(
                          context.l10n.dialogNoEditableShoppingLists,
                          style: AppTextStyles.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        StyledButton.secondary(
          text: context.l10n.commonCancel,
          onPressed: () => Navigator.pop(context),
        ),
        StyledButton.primary(
          text: _isCreatingNew
              ? context.l10n.dialogCreateList
              : context.l10n.commonAdd,
          onPressed:
              _isCreatingNew || _selectedListId != null ? _handleConfirm : null,
        ),
      ],
    );
  }
}
