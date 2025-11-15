// lib/widgets/social/groups/group_shared_content_section.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/services/group_shared_content_service.dart';
import 'package:butlery/viewmodels/shared_content/shared_menu_viewmodel.dart';
import 'package:butlery/views/veckomeny_view.dart';
import 'package:butlery/widgets/social/groups/shared_content_card.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
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
            content:
                Text('Visa ${item.title} (funktionalitet ej implementerad än)'),
            backgroundColor: AppColors.info,
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
            content: Text(
                'Importera ${item.title} (funktionalitet ej implementerad än)'),
            backgroundColor: AppColors.warning,
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
          const SnackBar(
            content: Text('Kunde inte hämta meny från servern'),
            backgroundColor: AppColors.error,
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
          content: Text('Fel vid öppning av meny: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showRecipeDetailsDialog(SharedContentItem item) {
    // Placeholder for recipe details
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Receptvisning: ${item.title} (kommer snart)'),
        backgroundColor: AppColors.info,
      ),
    );
  }

  void _showShoppingListDetailsDialog(SharedContentItem item) {
    // Placeholder for shopping list details
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Inköpslistevisning: ${item.title} (kommer snart)'),
        backgroundColor: AppColors.info,
      ),
    );
  }

  Future<void> _importMenu(SharedContentItem item) async {
    // Placeholder for menu import functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Importerar meny: ${item.title} (kommer snart)'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _importRecipe(SharedContentItem item) async {
    // Placeholder for recipe import functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Importerar recept: ${item.title} (kommer snart)'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _importShoppingList(SharedContentItem item) async {
    // Placeholder for shopping list import functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Importerar inköpslista: ${item.title} (kommer snart)'),
        backgroundColor: AppColors.success,
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
                          'Delat innehåll',
                          style: AppTextStyles.titleMedium.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (totalItems > 0) ...[
                          const SizedBox(width: AppDimensions.spacingS),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppDimensions.paddingS,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.primaryBlue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(
                                  AppDimensions.borderRadiusS),
                            ),
                            child: Text(
                              totalItems.toString(),
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.primaryBlue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppDimensions.spacingM),

                    // Tab bar
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.cardWhite,
                        borderRadius:
                            BorderRadius.circular(AppDimensions.borderRadiusM),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicatorColor: AppColors.primaryBlue,
                        labelColor: AppColors.primaryBlue,
                        unselectedLabelColor: AppColors.textSecondary,
                        tabs: [
                          Tab(
                            icon: const Icon(Icons.restaurant_menu, size: 20),
                            text: 'Recept (${recipes.length})',
                          ),
                          Tab(
                            icon: const Icon(Icons.calendar_today, size: 20),
                            text: 'Menyer (${menus.length})',
                          ),
                          Tab(
                            icon: const Icon(Icons.shopping_cart, size: 20),
                            text: 'Listor (${shoppingLists.length})',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingM),

                    // Tab content
                    SizedBox(
                      height: 400, // Fixed height for content area
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildTabContent(
                            recipes,
                            'Inga recept delade',
                            'Dela recept med gruppen för att inspirera varandra',
                            Icons.restaurant_menu_outlined,
                          ),
                          _buildTabContent(
                            menus,
                            'Inga menyer delade',
                            'Dela menyer med gruppen för att planera tillsammans',
                            Icons.calendar_today_outlined,
                          ),
                          _buildTabContent(
                            shoppingLists,
                            'Inga inköpslistor delade',
                            'Dela inköpslistor med gruppen för att samarbeta',
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
