// lib/views/unified_shopping/widgets/shopping_dialogs.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';
import 'package:butlery/viewmodels/universal_share_dialog_viewmodel.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/core/dialogs/dialog_factory.dart';
import 'package:butlery/widgets/common/universal_share_dialog.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';

/// Dialog-related functionality for shopping view
class ShoppingDialogs {
  static Future<void> showAddItemDialog(
    BuildContext context,
    UnifiedShoppingViewModel viewModel,
    Function(String) onSuccess,
    Function(String) onError,
  ) async {
    final result = await showDialog<UnifiedShoppingItem>(
      context: context,
      builder: (context) => _AddItemDialog(viewModel: viewModel),
    );

    if (result != null) {
      try {
        final success = await viewModel.addItemToActiveList(
          name: result.name,
          amount: result.amount,
          unit: result.unit,
          category: result.category,
          note: result.note,
          estimatedPrice: result.estimatedPrice,
          priority: result.priority,
        );

        if (success) {
          onSuccess('${result.name} tillagd!');
        } else {
          onError('Kunde inte lägga till ${result.name}');
        }
      } catch (e) {
        onError('Fel vid tillägg: $e');
      }
    }
  }

  static Future<void> showEditItemDialog(
    BuildContext context,
    UnifiedShoppingItem item,
    UnifiedShoppingViewModel viewModel,
    Function(String) onSuccess,
    Function(String) onError,
  ) async {
    final result = await showDialog<UnifiedShoppingItem>(
      context: context,
      builder: (context) => _EditItemDialog(item: item, viewModel: viewModel),
    );

    if (result != null) {
      try {
        final success = await viewModel.updateItem(
          itemId: item.id,
          name: result.name,
          quantity: result.amount,
          unit: result.unit,
          category: result.category,
          notes: result.note,
          estimatedPrice: result.estimatedPrice,
          priority: result.priority,
        );

        if (success) {
          onSuccess('${result.name} uppdaterad!');
        } else {
          onError('Kunde inte uppdatera ${result.name}');
        }
      } catch (e) {
        onError('Fel vid uppdatering: $e');
      }
    }
  }

  static Future<void> showShareDialog(
    BuildContext context,
    UnifiedShoppingViewModel viewModel,
  ) async {
    if (viewModel.activeList == null) return;

    try {
      final friendsService = ServiceLocator.get<UnifiedFriendsService>();
      await friendsService.initialize();
      final availableFriends = friendsService.friends;

      if (availableFriends.isEmpty) {
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Inga vänner'),
              content: const Text('Du har inga vänner att dela med än. Lägg till vänner först.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return;
      }

      final shareViewModel = ServiceLocator.get<UniversalShareDialogViewModel>();
      if (context.mounted) {
        await showDialog(
          context: context,
          builder: (context) => UniversalShareDialog.shoppingList(
            shoppingList: viewModel.activeList!,
            viewModel: shareViewModel,
            availableFriends: availableFriends,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Error showing share dialog: $e');
    }
  }

  static Future<void> showSyncStatus(
    BuildContext context,
    UnifiedShoppingViewModel viewModel,
  ) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.sync, color: AppColors.textMedium, size: AppDimensions.iconSizeM),
            SizedBox(width: AppDimensions.spacingS),
            Text(
              'Synkroniseringsstatus',
              style: AppTextStyles.titleMedium,
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusRow(
              context,
              'Status',
              viewModel.isOnline ? 'Online' : 'Offline',
              viewModel.isOnline ? AppColors.success : AppColors.error,
            ),
            const SizedBox(height: AppDimensions.spacingM),
            if (viewModel.activeList != null)
              _buildStatusRow(
                context,
                'Lista',
                viewModel.activeList!.name,
                Theme.of(context).colorScheme.onSurface,
              ),
            const SizedBox(height: AppDimensions.spacingM),
            _buildStatusRow(
              context,
              'Artiklar',
              '${viewModel.totalItems} totalt',
              Theme.of(context).colorScheme.onSurface,
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: AppColors.cardWhite,
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingL,
                vertical: AppDimensions.paddingM,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
              ),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  static Widget _buildStatusRow(
    BuildContext context,
    String label,
    String value,
    Color valueColor,
  ) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: AppTextStyles.labelLarge,
        ),
        Text(
          value,
          style: AppTextStyles.bodyLarge.copyWith(color: valueColor),
        ),
      ],
    );
  }

  static Future<void> showCreateListDialog(
    BuildContext context,
    UnifiedShoppingViewModel viewModel,
    Function(String) onSuccess,
  ) async {
    final name = await DialogFactory.showTextInput(
      context,
      title: 'Skapa ny lista',
      hintText: 'T.ex. Veckohandling',
      confirmText: 'Skapa',
      required: true,
    );

    if (name != null && name.isNotEmpty) {
      await viewModel.createPersonalList(name);
      onSuccess('Lista "$name" skapad!');
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
      title: 'Töm inhandlade varor',
      message: 'Vill du ta bort alla ${viewModel.boughtItems} inhandlade varor från listan?',
      confirmText: 'Töm',
      isDangerous: true,
    );

    if (confirmed == true) {
      await viewModel.clearBoughtItems();
      onSuccess('Inhandlade varor rensade!');
    }
  }
}

class _AddItemDialog extends StatefulWidget {
  final UnifiedShoppingViewModel viewModel;

  const _AddItemDialog({required this.viewModel});

  @override
  State<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<_AddItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController(text: '1');
  final _unitController = TextEditingController();
  final _categoryController = TextEditingController();
  final _noteController = TextEditingController();
  final _priceController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _unitController.dispose();
    _categoryController.dispose();
    _noteController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Lägg till vara'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Varunamn',
                hintText: 'T.ex. Mjölk',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Varunamn krävs';
                }
                return null;
              },
            ),
            const SizedBox(height: AppDimensions.spacingM),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _amountController,
                    decoration: const InputDecoration(
                      labelText: 'Mängd',
                      hintText: '1',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingSm),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _unitController,
                    decoration: const InputDecoration(
                      labelText: 'Enhet',
                      hintText: 'st, liter, kg',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingM),
            TextFormField(
              controller: _categoryController,
              decoration: const InputDecoration(
                labelText: 'Kategori',
                hintText: 'T.ex. Mejeri',
              ),
            ),
            const SizedBox(height: AppDimensions.spacingM),
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Anteckning (valfritt)',
                hintText: 'T.ex. Laktosfri',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Avbryt'),
        ),
        FilledButton(
          onPressed: _onSave,
          child: const Text('Lägg till'),
        ),
      ],
    );
  }

  void _onSave() {
    if (_formKey.currentState!.validate()) {
      final item = UnifiedShoppingItem.basic(
        name: _nameController.text.trim(),
        amount: double.tryParse(_amountController.text) ?? 1.0,
        unit: _unitController.text.trim(),
        category: _categoryController.text.trim().isEmpty
            ? 'Övrigt'
            : _categoryController.text.trim(),
      );

      Navigator.pop(context, item);
    }
  }
}

class _EditItemDialog extends StatefulWidget {
  final UnifiedShoppingItem item;
  final UnifiedShoppingViewModel viewModel;

  const _EditItemDialog({required this.item, required this.viewModel});

  @override
  State<_EditItemDialog> createState() => _EditItemDialogState();
}

class _EditItemDialogState extends State<_EditItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late final TextEditingController _unitController;
  late final TextEditingController _categoryController;
  late final TextEditingController _noteController;
  late final TextEditingController _priceController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item.name);
    _amountController = TextEditingController(text: widget.item.amount.toString());
    _unitController = TextEditingController(text: widget.item.unit);
    _categoryController = TextEditingController(text: widget.item.category);
    _noteController = TextEditingController(text: widget.item.note ?? '');
    _priceController = TextEditingController(text: widget.item.estimatedPrice?.toString() ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _unitController.dispose();
    _categoryController.dispose();
    _noteController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Redigera vara'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Varunamn',
                hintText: 'T.ex. Mjölk',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Varunamn krävs';
                }
                return null;
              },
            ),
            const SizedBox(height: AppDimensions.spacingM),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _amountController,
                    decoration: const InputDecoration(
                      labelText: 'Mängd',
                      hintText: '1',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingSm),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _unitController,
                    decoration: const InputDecoration(
                      labelText: 'Enhet',
                      hintText: 'st, liter, kg',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingM),
            TextFormField(
              controller: _categoryController,
              decoration: const InputDecoration(
                labelText: 'Kategori',
                hintText: 'T.ex. Mejeri',
              ),
            ),
            const SizedBox(height: AppDimensions.spacingM),
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Anteckning (valfritt)',
                hintText: 'T.ex. Laktosfri',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Avbryt'),
        ),
        FilledButton(
          onPressed: _onSave,
          child: const Text('Spara'),
        ),
      ],
    );
  }

  void _onSave() {
    if (_formKey.currentState!.validate()) {
      final item = widget.item.copyWith(
        name: _nameController.text.trim(),
        amount: double.tryParse(_amountController.text) ?? widget.item.amount,
        unit: _unitController.text.trim(),
        category: _categoryController.text.trim().isEmpty
            ? 'Övrigt'
            : _categoryController.text.trim(),
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        estimatedPrice: _priceController.text.trim().isEmpty
            ? null
            : double.tryParse(_priceController.text),
        priority: widget.item.priority,
      );

      Navigator.pop(context, item);
    }
  }
}