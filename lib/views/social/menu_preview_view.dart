// lib/views/social/menu_preview_view.dart
// ✅ FÖRHANDSVISNING av delade menyer med alla recept

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../widgets/common/social_components.dart';
import '../../models/shared_menu.dart';
import '../../models/recipe.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/content_card.dart';
import '../../viewmodels/shared_content_viewmodel.dart';

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
      child: Container(
        margin: AppTheme.screenPadding,
        padding: AppTheme.cardPadding,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: AppTheme.mediumRadius,
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
                SizedBox(width: AppTheme.spacingSm),
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
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingSm,
                    vertical: AppTheme.spacingXs,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: AppTheme.chipRadius,
                  ),
                  child: Text(
                    'DELAD MENY',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),

            SizedBox(height: AppTheme.spacingMd),

            // Meny titel och beskrivning
            Text(
              sharedMenu.menuTitle,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
            ),

            SizedBox(height: AppTheme.spacingSm),

            // Meny statistik
            Row(
              children: [
                Icon(
                  Icons.restaurant_menu,
                  size: AppTheme.iconSizeInfo,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                SizedBox(width: AppTheme.spacingXs),
                Text(
                  '${sharedMenu.totalRecipeCount} recept',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                ),
                SizedBox(width: AppTheme.spacingMd),
                Icon(
                  Icons.category,
                  size: AppTheme.iconSizeInfo,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                SizedBox(width: AppTheme.spacingXs),
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
              SizedBox(height: AppTheme.spacingMd),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(AppTheme.spacingSm),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: AppTheme.smallRadius,
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
                    SizedBox(height: AppTheme.spacingXs),
                    Text(
                      '"${sharedMenu.shareMessage}"',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMenuContent(BuildContext context) {
    // Gruppera recept per kategori från menuSnapshot
    final menuContent = sharedMenu.menuSnapshot;

    if (menuContent.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
          padding: AppTheme.screenPadding,
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.restaurant_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                SizedBox(height: AppTheme.spacingMd),
                Text(
                  'Inga recept i menyn',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
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

          return Container(
            margin: EdgeInsets.fromLTRB(
              AppTheme.spacingSm,
              AppTheme.spacingSm,
              AppTheme.spacingSm,
              index == categories.length - 1 ? AppTheme.spacingLg : 0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Kategori header
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingSm,
                    vertical: AppTheme.spacingXs,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: AppTheme.smallRadius,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getCategoryIcon(category),
                        size: AppTheme.iconSizeInfo,
                        color:
                            Theme.of(context).colorScheme.onSecondaryContainer,
                      ),
                      SizedBox(width: AppTheme.spacingSm),
                      Text(
                        category,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSecondaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                      const Spacer(),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingXs,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${recipes.length}',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                color:
                                    Theme.of(context).colorScheme.onSecondary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: AppTheme.spacingSm),

                // Recept i kategorin
                ...recipes.map((recipe) => Container(
                      margin: EdgeInsets.only(bottom: AppTheme.spacingXs),
                      child: ContentCard.compactRecipe(
                        recipe: recipe,
                        onTap: () => _navigateToRecipeDetail(context, recipe),
                      ),
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
      child: Container(
        padding: AppTheme.screenPadding,
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

                SizedBox(height: AppTheme.spacingSm),

                // Dismiss knapp
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _dismissMenu(context, viewModel),
                    icon: const Icon(Icons.visibility_off),
                    label: const Text('Dölj från min lista'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),

                SizedBox(height: AppTheme.spacingMd),

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
          backgroundColor: AppTheme.successColor,
          duration: AppTheme.wait3s,
        ),
      );

      // Navigera tillbaka efter lyckad import
      Navigator.pop(context);
    } else if (context.mounted && viewModel.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(viewModel.error!),
          backgroundColor: AppTheme.errorColor,
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
            backgroundColor: AppTheme.successColor,
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
            backgroundColor: AppTheme.errorColor,
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
        backgroundColor: AppTheme.accentColor,
      ),
    );
  }
}
