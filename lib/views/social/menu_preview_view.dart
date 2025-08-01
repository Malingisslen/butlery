// lib/views/social/menu_preview_view.dart
// ✅ FÖRHANDSVISNING av delade menyer med alla recept

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:butlery/widgets/common/social_components.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/component_themes.dart';
import 'package:butlery/widgets/common/content_card.dart';
import 'package:butlery/viewmodels/shared_content_viewmodel.dart';
import 'package:butlery/widgets/common/indicators/status_badge.dart';
import 'package:butlery/widgets/common/layout/category_header.dart';

/// ✅ MenuPreviewView - Visa delad meny med alla recept
class MenuPreviewView extends StatelessWidget {
  final SharedMenu sharedMenu;

  const MenuPreviewView({
    super.key,
    required this.sharedMenu,
  });

  @override
  Widget build(BuildContext context) {
    // Konfigurera svenska för timeago
    timeago.setLocaleMessages('sv', timeago.SvMessages());

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          _buildMenuHeader(context),
          _buildMenuContent(context),
          _buildActionButtons(context),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      title: Text(sharedMenu.menuTitle),
      floating: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back),
      ),
      actions: [
        IconButton(
          onPressed: () => _shareMenu(context),
          icon: const Icon(Icons.share),
          tooltip: 'Dela meny',
        ),
      ],
    );
  }

  Widget _buildMenuHeader(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppDimensions.paddingL),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Delningsinformation
              Row(
                children: [
                  SocialComponents.avatar(
                    displayName: sharedMenu.sharedByDisplayName,
                    size: ImageSize.small,
                  ),
                  const SizedBox(width: AppDimensions.spacingS),
                  Expanded(
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Delat av ${sharedMenu.sharedByDisplayName}',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                      Text(
                        timeago.format(sharedMenu.sharedAt, locale: 'sv'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                            ),
                      ),
                    ],
                  ),
                ),
                const StatusBadge.primary(text: 'DELAD MENY'),
              ],
            ),

            const SizedBox(height: AppDimensions.spacingL),

            // Meny titel och beskrivning
            Text(
              sharedMenu.menuTitle,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
            ),

            const SizedBox(height: AppDimensions.spacingS),

            // Meny statistik
            Row(
              children: [
                Icon(
                  Icons.restaurant_menu,
                  size: AppDimensions.iconSizeM,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: AppDimensions.spacingXs),
                Text(
                  '${sharedMenu.totalRecipeCount} recept',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                ),
                const SizedBox(width: AppDimensions.spacingL),
                Icon(
                  Icons.category,
                  size: AppDimensions.iconSizeM,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: AppDimensions.spacingXs),
                Text(
                  '${sharedMenu.categories.length} kategorier',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                ),
              ],
            ),

            // Delningsmeddelande
            if (sharedMenu.shareMessage?.isNotEmpty == true) ...[
              const SizedBox(height: AppDimensions.spacingL),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppDimensions.paddingL),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Meddelande:',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: AppDimensions.spacingXs),
                    Text(
                      '"${sharedMenu.shareMessage}"',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                    ),
                  ],
                ),
              ),
            ], // Close if statement spread array
            ], // Close children array of main Column
          ), // Close main Column
        ), // Close Container
      ),
    );
  }

  Widget _buildMenuContent(BuildContext context) {
    // Gruppera recept per kategori från menuSnapshot
    final menuContent = sharedMenu.menuSnapshot;

    if (menuContent.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingL),
          child: StateWidget.empty(
            title: 'Inga recept i menyn',
            icon: Icons.restaurant_outlined,
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final categories = menuContent.keys.toList();
          final category = categories[index];
          final recipes = menuContent[category] ?? [];

          return Padding(
            padding: EdgeInsets.fromLTRB(
              AppDimensions.spacingS,
              AppDimensions.spacingS,
              AppDimensions.spacingS,
              index == categories.length - 1 ? AppDimensions.spacingL : 0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Kategori header
                CategoryHeader(
                  title: category,
                  icon: _getCategoryIcon(category),
                  count: recipes.length,
                ),

                const SizedBox(height: AppDimensions.spacingS),

                // Recept i kategorin
                ...recipes.map((recipe) => Column(
                      children: [
                        ContentCard.compactRecipe(
                          recipe: recipe,
                          onTap: () => _navigateToRecipeDetail(context, recipe),
                        ),
                        const SizedBox(height: AppDimensions.spacingXs),
                      ],
                    )),
              ],
            ),
          );
        },
        childCount: menuContent.keys.length,
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: AppDimensions.screenPadding,
        child: Consumer<SharedContentViewModel>(
          builder: (context, viewModel, _) {
            final isImported = viewModel.isMenuImported(sharedMenu);

            return Column(
              children: [
                // Import knapp
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: isImported || viewModel.isImporting
                        ? null
                        : () => _importMenu(context, viewModel),
                    icon: isImported
                        ? const Icon(Icons.check)
                        : viewModel.isImporting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.download),
                    label: Text(
                      isImported
                          ? 'Meny importerad'
                          : viewModel.isImporting
                              ? 'Importerar...'
                              : 'Importera hela menyn',
                    ),
                  ),
                ),

                const SizedBox(height: AppDimensions.spacingS),

                // Dismiss knapp
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _dismissMenu(context, viewModel),
                    icon: const Icon(Icons.visibility_off),
                    label: const Text('Dölj från min lista'),
                    style: ComponentThemes.outlinedButtonStyle,
                  ),
                ),

                const SizedBox(height: AppDimensions.spacingL),

                // Info text
                Text(
                  'När du importerar menyn läggs alla ${sharedMenu.totalRecipeCount} recept till i din samling.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    final categoryLower = category.toLowerCase();

    if (categoryLower.contains('frukost')) {
      return Icons.free_breakfast;
    }
    if (categoryLower.contains('lunch')) {
      return Icons.lunch_dining;
    }
    if (categoryLower.contains('middag')) {
      return Icons.dinner_dining;
    }
    if (categoryLower.contains('mellanmål') ||
        categoryLower.contains('snack')) {
      return Icons.cookie;
    }
    if (categoryLower.contains('dessert')) {
      return Icons.cake;
    }
    if (categoryLower.contains('drink') || categoryLower.contains('dryck')) {
      return Icons.local_cafe;
    }

    return Icons.restaurant_menu;
  }

  void _navigateToRecipeDetail(BuildContext context, Recipe recipe) {
    Navigator.pushNamed(
      context,
      '/receptDetalj',
      arguments: recipe,
    );
  }

  Future<void> _importMenu(
    BuildContext context,
    SharedContentViewModel viewModel,
  ) async {
    final success = await viewModel.importSharedMenu(sharedMenu);

    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Meny "${sharedMenu.menuTitle}" importerad!'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 3),
        ),
      );

      // Navigera tillbaka efter lyckad import
      Navigator.pop(context);
    } else if (context.mounted && viewModel.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(viewModel.error!),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _dismissMenu(
    BuildContext context,
    SharedContentViewModel viewModel,
  ) async {
    // Visa bekräftelsedialog
    final shouldDismiss = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dölj meny'),
        content: Text(
          'Vill du dölja "${sharedMenu.menuTitle}" från din lista?\n\n'
          'Du kan fortfarande komma åt menyn genom att be '
          '${sharedMenu.sharedByDisplayName} att dela den igen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Avbryt'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Dölj'),
          ),
        ],
      ),
    );

    if (shouldDismiss == true) {
      final success = await viewModel.dismissSharedMenu(sharedMenu);

      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ "${sharedMenu.menuTitle}" dold från din lista'),
            backgroundColor: AppColors.success,
            action: SnackBarAction(
              label: 'Ångra',
              onPressed: () => viewModel.undismissSharedMenu(sharedMenu),
            ),
          ),
        );

        // Navigera tillbaka efter dismiss
        Navigator.pop(context);
      } else if (context.mounted && viewModel.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(viewModel.error!),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _shareMenu(BuildContext context) {
    // Implementera delning av meny-information
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Delning av "${sharedMenu.menuTitle}" kommer snart!'),
        backgroundColor: AppColors.accent,
      ),
    );
  }

  @override
  void dispose() {
    // Cancel all timers
    // Cancel all stream subscriptions  
    // Dispose of resources
    disposeStreams(); // From StreamManagementMixin
    super.dispose();
  }
}
