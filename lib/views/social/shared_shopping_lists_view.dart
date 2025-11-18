import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/widgets/common/layout_components.dart';

/// View for displaying shared shopping lists.
///
/// This view shows all shopping lists that are shared with the current user,
/// allowing them to collaborate on shopping with friends and family.
class SharedShoppingListsView extends StatelessWidget {
  const SharedShoppingListsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delade inköpslistor'),
      ),
      body: SafeArea(
        // ✅ RESPONSIVE: Center and constrain content on large screens
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: LayoutComponents.valueFor(
                context: context,
                mobile: double.infinity,
                tablet: 700,
                desktop: 800,
              ),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.shopping_cart_outlined,
                  size: 64,
                  color: AppColors.textMedium,
                ),
                SizedBox(height: 16),
                Text(
                  'Delade inköpslistor',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Kommer snart...',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
