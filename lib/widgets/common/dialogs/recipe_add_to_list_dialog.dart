// lib/widgets/common/dialogs/recipe_add_to_list_dialog.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/shopping/recipe_pantry_check.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/butlery_control_focus.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';
import 'package:butlery/widgets/styled/styled_input.dart';

/// What the user picked: an existing list ([listId], [listName]) or a new
/// one ([newListName]).
class RecipeListChoice {
  const RecipeListChoice.existing({
    required String this.listId,
    required String this.listName,
  }) : newListName = null;

  const RecipeListChoice.create({required String this.newListName})
    : listId = null,
      listName = null;

  final String? listId;
  final String? listName;
  final String? newListName;
}

/// The one dialog behind "Lägg i inköpslistan" on a recipe: the ingredients
/// that will be added and the list they go to, chosen together (BUT-2308).
///
/// Lists come from the shopping service's own state. Re-reading every list
/// and all of its items on each open is what made the old list dialog sit on
/// "Hämtar dina inköpslistor" for seconds, so the service is only initialised
/// here when nothing has loaded it yet.
class RecipeAddToListDialog extends StatefulWidget {
  const RecipeAddToListDialog({
    super.key,
    required this.recipeTitle,
    required this.items,
    required this.shoppingService,
    this.pantryCheck,
  });

  final String recipeTitle;
  final List<UnifiedShoppingItem> items;
  final RecipePantryResult? pantryCheck;
  final UnifiedShoppingService shoppingService;

  @override
  State<RecipeAddToListDialog> createState() => _RecipeAddToListDialogState();
}

class _RecipeAddToListDialogState extends State<RecipeAddToListDialog> {
  final _newListNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  List<UnifiedShoppingList> _availableLists = [];
  bool _isLoading = false;
  bool _isCreatingNew = false;
  String? _selectedListId;
  bool _namePrefilled = false;

  @override
  void initState() {
    super.initState();
    if (widget.shoppingService.isInitialized) {
      _applyLists();
    } else {
      _isLoading = true;
      _initializeService();
    }
  }

  @override
  void dispose() {
    _newListNameController.dispose();
    super.dispose();
  }

  Future<void> _initializeService() async {
    try {
      await widget.shoppingService.initialize();
    } catch (e) {
      AppLogger.error('[RecipeAddToListDialog] Initialization failed', e);
    }
    if (!mounted) return;
    setState(_applyLists);
  }

  /// Preselects the list used last: the service persists the active list
  /// whenever an add targets it, so it is the most recently used one.
  void _applyLists() {
    final permissionService = ServiceLocator.get<PermissionService>();
    final editable = widget.shoppingService.lists
        .where((list) => permissionService.canEditShoppingList(list.id))
        .toList();
    _availableLists = editable;
    _isLoading = false;

    final activeId = widget.shoppingService.activeListId;
    if (activeId != null && editable.any((l) => l.id == activeId)) {
      _selectedListId = activeId;
    } else if (editable.isNotEmpty) {
      final byRecent = [...editable]
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      _selectedListId = byRecent.first.id;
    } else {
      _isCreatingNew = true;
    }
  }

  void _selectCreateNew() {
    setState(() {
      _isCreatingNew = true;
      _selectedListId = null;
    });
  }

  void _selectExisting(String listId) {
    setState(() {
      _isCreatingNew = false;
      _selectedListId = listId;
    });
  }

  bool get _canConfirm =>
      !_isLoading && (_isCreatingNew || _selectedListId != null);

  void _confirm() {
    if (_isCreatingNew) {
      if (_formKey.currentState?.validate() != true) return;
      Navigator.pop(
        context,
        RecipeListChoice.create(
          newListName: _newListNameController.text.trim(),
        ),
      );
      return;
    }
    final selected = _availableLists.firstWhere(
      (list) => list.id == _selectedListId,
    );
    Navigator.pop(
      context,
      RecipeListChoice.existing(listId: selected.id, listName: selected.name),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_isCreatingNew && !_namePrefilled) {
      _namePrefilled = true;
      _newListNameController.text = l10n.shoppingNewListNameTemplate(
        widget.recipeTitle,
      );
    }
    return AlertDialog(
      title: Text(
        l10n.shoppingAddToShoppingList,
        style: AppTextStyles.titleLarge,
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.shoppingIngredientsFromRecipe(
                  widget.items.length,
                  widget.recipeTitle,
                ),
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: AppDimensions.spacingM),
              ..._buildIngredientRows(context),
              ..._buildPantryNotes(context),
              const SizedBox(height: AppDimensions.spacingL),
              Text(
                l10n.shoppingAddToListHeading,
                style: AppTextStyles.titleMedium,
              ),
              const SizedBox(height: AppDimensions.space4),
              if (_isLoading)
                Center(
                  child: PlateLineMessage(message: l10n.loadingShoppingLists),
                )
              else
                ..._buildListChoices(context),
            ],
          ),
        ),
      ),
      actions: [
        ActionButtons.secondaryButton(
          context,
          label: l10n.commonCancel,
          onPressed: () => Navigator.pop(context),
        ),
        ActionButtons.primaryButton(
          context,
          label: l10n.commonAdd,
          onPressed: _canConfirm ? _confirm : null,
        ),
      ],
    );
  }

  List<Widget> _buildIngredientRows(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return [
      ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 220),
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: widget.items.length,
          itemBuilder: (context, index) {
            final item = widget.items[index];
            final note = item.note.orEmpty();
            return Padding(
              padding: AppDimensions.paddingVertical4,
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: onSurface),
                  ),
                  const SizedBox(width: AppDimensions.spacingL),
                  // The amount to buy, and the pantry's mark (Q4-03).
                  Expanded(
                    child: Text(
                      note.isEmpty
                          ? item.displayText
                          : '${item.displayText} · $note',
                      style: AppTextStyles.bodyMedium,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ];
  }

  List<Widget> _buildPantryNotes(BuildContext context) {
    final check = widget.pantryCheck;
    if (check == null) return const [];
    return [
      if (check.coveredAtHome.isNotEmpty) ...[
        const SizedBox(height: AppDimensions.spacingL),
        Text(
          context.l10n.shoppingMergePantryCovered(
            check.coveredAtHome.join(', '),
          ),
          key: const ValueKey('recipePantryCovered'),
          style: AppTextStyles.bodyMedium,
        ),
      ],
      if (check.lessened.isNotEmpty) ...[
        const SizedBox(height: AppDimensions.spacingSm),
        Text(
          context.l10n.recipePantryLessened(check.lessened.join(', ')),
          key: const ValueKey('recipePantryLessened'),
          style: AppTextStyles.bodyMedium,
        ),
      ],
    ];
  }

  // Rows are chosen by list id; the focus ring and 48 dp come from
  // ButleryControlFocus like the other radio rows (P4-U10, P4-U16).
  static const _createNewValue = '\u0000new';

  List<Widget> _buildListChoices(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return [
      RadioGroup<String>(
        groupValue: _isCreatingNew ? _createNewValue : _selectedListId,
        onChanged: (value) {
          if (value == null) return;
          if (value == _createNewValue) {
            _selectCreateNew();
          } else {
            _selectExisting(value);
          }
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final list in _availableLists)
              ButleryControlFocus(
                child: RadioListTile<String>(
                  key: ValueKey('recipeListChoice_${list.id}'),
                  value: list.id,
                  title: Text(list.name),
                  subtitle: Text(
                    '${list.totalItems} ${l10n.dialogItems} • ${list.type == ListType.collaborative ? l10n.dialogShared : l10n.dialogPrivate}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ButleryControlFocus(
              child: RadioListTile<String>(
                key: const ValueKey('recipeListChoice_new'),
                value: _createNewValue,
                title: Text(l10n.shoppingCreateList),
                subtitle: _isCreatingNew
                    ? Form(
                        key: _formKey,
                        child: Padding(
                          padding: const EdgeInsets.only(
                            top: AppDimensions.space4,
                          ),
                          child: StyledInput(
                            controller: _newListNameController,
                            label: l10n.shoppingListName,
                            hint: l10n.dialogShoppingListNameHint,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return l10n.dialogEnterListName;
                              }
                              if (value.trim().length < 2) {
                                return l10n.dialogNameMinTwoChars;
                              }
                              return null;
                            },
                          ),
                        ),
                      )
                    : Text(l10n.dialogCreateNewListForIngredients),
              ),
            ),
          ],
        ),
      ),
    ];
  }
}
