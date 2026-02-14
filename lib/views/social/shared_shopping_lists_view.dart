import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// View for displaying shared shopping lists.
/// This view shows all shopping lists that are shared with the current user,
/// allowing them to collaborate on shopping with friends and family.
class SharedShoppingListsView extends StatelessWidget {
  const SharedShoppingListsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.shoppingSharedLists),
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.shopping_cart_outlined,
                  size: 64,
                  color: AppColors.textMedium,
                ),
                const SizedBox(height: AppDimensions.spacingMd),
                Text(
                  context.l10n.shoppingSharedLists,
                  style: AppTextStyles.sectionHeader,
                ),
                const SizedBox(height: AppDimensions.spacingSm),
                Text(
                  context.l10n.commonComingSoon,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
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
