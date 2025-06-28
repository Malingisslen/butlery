import 'package:flutter/material.dart';
import '../viewmodels/shopping_list_viewmodel.dart';

class ShoppingListSelector extends StatelessWidget {
  final ShoppingListViewModel viewModel;

  const ShoppingListSelector({
    super.key,
    required this.viewModel,
  });

  @override
  Widget build(BuildContext context) {
    return Text('List Selector');
  }
}
