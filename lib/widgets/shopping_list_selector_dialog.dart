// lib/widgets/shopping_list_selector_dialog.dart

import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../viewmodels/shopping_list_viewmodel.dart';
import '../theme/app_theme.dart';
import '../core/injection.dart';

/// Dialog för att välja vilken lista som ska få items från menyn
class ShoppingListSelectorDialog extends StatefulWidget {
  final Map<String, List<Recipe>> menu;

  const ShoppingListSelectorDialog({
    super.key,
    required this.menu,
  });

  @override
  State<ShoppingListSelectorDialog> createState() =>
      _ShoppingListSelectorDialogState();
}

class _ShoppingListSelectorDialogState
    extends State<ShoppingListSelectorDialog> {
  final _viewModel = sl<ShoppingListViewModel>();
  final _nameController = TextEditingController();
  bool _createNewList = false;
  String? _selectedListId;

  @override
  void initState() {
    super.initState();
    // Sätt aktiv lista som default
    _selectedListId = _viewModel.activeList?.id;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Välj inköpslista'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_createNewList) ...[
              // Radio buttons för befintliga listor
              ..._viewModel.lists.map((list) => RadioListTile<String>(
                    title: Text(list.name),
                    subtitle: Text(list.summary),
                    value: list.id,
                    groupValue: _selectedListId,
                    onChanged: (value) {
                      setState(() {
                        _selectedListId = value;
                      });
                    },
                  )),
              const Divider(),
              // Alternativ för ny lista
              RadioListTile<String>(
                title: const Text('Skapa ny lista'),
                value: 'new',
                groupValue: _selectedListId,
                onChanged: (value) {
                  setState(() {
                    _selectedListId = value;
                    _createNewList = true;
                  });
                },
              ),
            ] else ...[
              // Input för ny lista
              TextField(
                controller: _nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Namn på ny lista',
                  hintText: 'T.ex. Veckans inköp',
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              AppTheme.smallGap,
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _createNewList = false;
                    _selectedListId = _viewModel.activeList?.id;
                  });
                },
                icon: const Icon(Icons.arrow_back),
                label: const Text('Tillbaka'),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Avbryt'),
        ),
        FilledButton(
          onPressed: _selectedListId != null || _createNewList
              ? () => _generateToList(context)
              : null,
          child: const Text('Lägg till'),
        ),
      ],
    );
  }

  Future<void> _generateToList(BuildContext context) async {
    if (_createNewList) {
      // Skapa ny lista med items från menyn
      final listId = await _viewModel.createListFromMenu(
        _nameController.text.trim(),
        widget.menu,
      );

      if (listId != null && context.mounted) {
        Navigator.pop(context);
        Navigator.pushReplacementNamed(
          context,
          '/inkopslista',
          arguments: {'listId': listId},
        );
      }
    } else if (_selectedListId != null) {
      // Lägg till i befintlig lista
      await _viewModel.selectList(_selectedListId!);
      await _viewModel.generateFromMenu(widget.menu);

      if (context.mounted) {
        Navigator.pop(context);
        Navigator.pushReplacementNamed(context, '/inkopslista');
      }
    }
  }
}
