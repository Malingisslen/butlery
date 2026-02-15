// lib/widgets/social/groups/group_shared_content_section.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/services/group_shared_content_service.dart';
import 'package:butlery/viewmodels/shared_content/shared_menu_viewmodel.dart';
import 'package:butlery/views/veckomeny_view.dart';
import 'package:butlery/widgets/social/groups/shared_content_card.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';

/// Section widget displaying shared content (recipes, menus, shopping lists) for a group
class GroupSharedContentSection extends StatefulWidget {
  final FriendCategory group;

  const GroupSharedContentSection({
    super.key,
    required this.group,
  });

  @override
  State<GroupSharedContentSection> createState() =>
      _GroupSharedContentSectionState();
}

class _GroupSharedContentSectionState extends State<GroupSharedContentSection>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late GroupSharedContentService _contentService;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _contentService = ServiceLocator.get<GroupSharedContentService>();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  int _getTotalItems(
    List<SharedContentItem> recipes,
    List<SharedContentItem> menus,
    List<SharedContentItem> shoppingLists,
  ) {
    return recipes.length + menus.length + shoppingLists.length;
  }

  Widget _buildTabContent(
    List<SharedContentItem> items,
    String emptyTitle,
    String emptySubtitle,
    IconData emptyIcon,
  ) {
    if (items.isEmpty) {
      return StateWidget.empty(
        title: emptyTitle,
        subtitle: emptySubtitle,
        icon: emptyIcon,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return SharedContentCard(
          item: item,
          onView: () => _handleViewItem(item),
          onImport: () => _handleImportItem(item),
        );
      },
    );
  }

  void _handleViewItem(SharedContentItem item) {
    // Show detailed view dialog based on item type
    switch (item.type) {
      case 'menu':
        _showMenuDetailsDialog(item);
        break;
      case 'recipe':
        _showRecipeDetailsDialog(item);
        break;
      case 'shopping_list':
        _showShoppingListDetailsDialog(item);
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.groupViewNotImplemented(item.title)),
            backgroundColor: context.butleryColors.info,
          ),
        );
    }
  }

  void _handleImportItem(SharedContentItem item) {
    // Import functionality based on item type
    switch (item.type) {
      case 'menu':
        _importMenu(item);
        break;
      case 'recipe':
        _importRecipe(item);
        break;
      case 'shopping_list':
        _importShoppingList(item);
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.groupImportNotImplemented(item.title)),
            backgroundColor: context.butleryColors.warning,
          ),
        );
    }
  }

  Future<void> _showMenuDetailsDialog(SharedContentItem item) async {
    // Fetch the full SharedMenu object to enable collaborative editing
    // Week 2 Task 1 Completion: Use ViewModel method instead of direct repository access
    try {
      final sharedMenuViewModel = ServiceLocator.get<SharedMenuViewModel>();
      final sharedMenu = await sharedMenuViewModel.getSharedMenuById(item.id);

      if (sharedMenu == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.groupCouldNotFetchMenu),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return;
      }

      // Navigate to VeckomenyView with the shared menu for collaborative editing
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => VeckomenyView(sharedMenu: sharedMenu),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.groupErrorOpeningMenu(e.toString())),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _showRecipeDetailsDialog(SharedContentItem item) {
    // Placeholder for recipe details
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.groupRecipeViewComingSoon(item.title)),
        backgroundColor: context.butleryColors.info,
      ),
    );
  }

  void _showShoppingListDetailsDialog(SharedContentItem item) {
    // Placeholder for shopping list details
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.groupShoppingListViewComingSoon(item.title)),
        backgroundColor: context.butleryColors.info,
      ),
    );
  }

  Future<void> _importMenu(SharedContentItem item) async {
    // Placeholder for menu import functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.groupImportingMenuComingSoon(item.title)),
        backgroundColor: context.butleryColors.success,
      ),
    );
  }

  Future<void> _importRecipe(SharedContentItem item) async {
    // Placeholder for recipe import functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.groupImportingRecipeComingSoon(item.title)),
        backgroundColor: context.butleryColors.success,
      ),
    );
  }

  Future<void> _importShoppingList(SharedContentItem item) async {
    // Placeholder for shopping list import functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(context.l10n.groupImportingShoppingListComingSoon(item.title)),
        backgroundColor: context.butleryColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SharedContentItem>>(
      stream: _contentService.streamSharedRecipes(widget.group),
      builder: (context, recipesSnapshot) {
        return StreamBuilder<List<SharedContentItem>>(
          stream: _contentService.streamSharedMenus(widget.group),
          builder: (context, menusSnapshot) {
            return StreamBuilder<List<SharedContentItem>>(
              stream: _contentService.streamSharedShoppingLists(widget.group),
              builder: (context, shoppingListsSnapshot) {
                // Get data from snapshots or empty lists
                final recipes = recipesSnapshot.data ?? [];
                final menus = menusSnapshot.data ?? [];
                final shoppingLists = shoppingListsSnapshot.data ?? [];
                final totalItems =
                    _getTotalItems(recipes, menus, shoppingLists);

                // Show loading if any stream is still loading
                final isLoading = !recipesSnapshot.hasData ||
                    !menusSnapshot.hasData ||
                    !shoppingListsSnapshot.hasData;

                if (isLoading) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppDimensions.paddingXl),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section header
                    Row(
                      children: [
                        Text(
                          context.l10n.groupSharedContent,
                          style: AppTextStyles.titleBold,
                        ),
                        if (totalItems > 0) ...[
                          const SizedBox(width: AppDimensions.spacingS),
                          Builder(builder: (context) {
                            final cs = Theme.of(context).colorScheme;
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppDimensions.paddingS,
                                vertical: AppDimensions.spacingXs,
                              ),
                              decoration: BoxDecoration(
                                color: cs.primary.withValues(
                                    alpha: AppDimensions.opacityVeryLight),
                                borderRadius: BorderRadius.circular(
                                    AppDimensions.borderRadiusS),
                              ),
                              child: Text(
                                totalItems.toString(),
                                style: AppTextStyles.labelLarge.copyWith(
                                  color: cs.primary,
                                ),
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppDimensions.spacingM),

                    // Tab bar
                    Builder(builder: (context) {
                      final cs = Theme.of(context).colorScheme;
                      return DecoratedBox(
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(
                              AppDimensions.borderRadiusM),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          indicatorColor: cs.primary,
                          labelColor: cs.primary,
                          unselectedLabelColor: cs.onSurfaceVariant,
                          tabs: [
                            Tab(
                              icon: const Icon(Icons.restaurant_menu,
                                  size: AppDimensions.iconSizeM),
                              text:
                                  '${context.l10n.groupContentTypeRecipe} (${recipes.length})',
                            ),
                            Tab(
                              icon: const Icon(Icons.calendar_today,
                                  size: AppDimensions.iconSizeM),
                              text:
                                  '${context.l10n.groupTabMenus} (${menus.length})',
                            ),
                            Tab(
                              icon: const Icon(Icons.shopping_cart,
                                  size: AppDimensions.iconSizeM),
                              text:
                                  '${context.l10n.groupTabLists} (${shoppingLists.length})',
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: AppDimensions.spacingM),

                    // Tab content
                    SizedBox(
                      height: 400, // Fixed height for content area
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildTabContent(
                            recipes,
                            context.l10n.groupNoRecipesShared,
                            context.l10n.groupNoRecipesSharedSubtitle,
                            Icons.restaurant_menu_outlined,
                          ),
                          _buildTabContent(
                            menus,
                            context.l10n.groupNoMenusShared,
                            context.l10n.groupNoMenusSharedSubtitle,
                            Icons.calendar_today_outlined,
                          ),
                          _buildTabContent(
                            shoppingLists,
                            context.l10n.groupNoShoppingListsShared,
                            context.l10n.groupNoShoppingListsSharedSubtitle,
                            Icons.shopping_cart_outlined,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}
