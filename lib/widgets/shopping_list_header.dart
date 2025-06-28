import 'package:flutter/material.dart';

class ShoppingListHeader extends StatelessWidget {
  final VoidCallback onListTap;

  const ShoppingListHeader({
    super.key,
    required this.onListTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      child: ElevatedButton(
        onPressed: onListTap,
        child: Text('Select List'),
      ),
    );
  }
}
