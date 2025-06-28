import 'package:flutter/material.dart';
import '../models/shopping_item.dart';

class ShoppingItemTile extends StatelessWidget {
  final ShoppingItem item;
  final String formattedText;
  final VoidCallback onToggle;
  final VoidCallback onDismissed;
  final bool showCategory;

  const ShoppingItemTile({
    super.key,
    required this.item,
    required this.formattedText,
    required this.onToggle,
    required this.onDismissed,
    this.showCategory = true,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(formattedText),
      subtitle: showCategory ? Text(item.category) : null,
      leading: Checkbox(
        value: item.bought,
        onChanged: (_) => onToggle(),
      ),
    );
  }
}
