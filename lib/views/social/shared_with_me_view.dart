// lib/views/social/shared_with_me_view.dart
// ✅ FIXAD: Proper Provider setup without conflicts

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../core/injection.dart';
import '../../viewmodels/shared_content_viewmodel.dart';
import '../../models/shared_recipe.dart';
import '../../models/shared_menu.dart';
import '../../theme/app_theme.dart';
import '../../widgets/user/user_display_widgets.dart';
import '../../widgets/common/state_widget.dart';
import 'menu_preview_view.dart'; // ✅ NY IMPORT

/// ✅ FIXAD SharedWithMeView med korrekt Provider-arkitektur
class SharedWithMeView extends StatelessWidget {
  const SharedWithMeView({super.key});

  @override
  Widget build(BuildContext context) {
    // ✅ FIX: Skapa Provider här utan konflikter
    return ChangeNotifierProvider<SharedContentViewModel>(
      create: (context) => sl<SharedContentViewModel>(),
      child: const _SharedWithMeViewContent(),
    );
  }
}

class _SharedWithMeViewContent extends StatefulWidget {
  const _SharedWithMeViewContent();

  @override
  State<_SharedWithMeViewContent> createState() =>
      _SharedWithMeViewContentState();
}

class _SharedWithMeViewContentState extends State<_SharedWithMeViewContent>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // ✅ FIX: Säker Provider access utan context.read() i initState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final viewModel = context.read<SharedContentViewModel>();

      // Sync tab controller med ViewModel
      _tabController.addListener(() {
        if (!_tabController.indexIsChanging) {
          viewModel.setTabIndex(_tabController.index);
        }
      });
    });

    // Konfigurera svenska för timeago
    timeago.setLocaleMessages('sv', timeago.SvMessages());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Consumer<SharedContentViewModel>(
        builder: (context, viewModel, _) {
          return CustomScrollView(
            slivers: [
              _buildAppBar(context, viewModel),
              _buildSearchBar(context, viewModel),
              _buildTabBar(context, viewModel),
              _buildContent(context, viewModel),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, SharedContentViewModel viewModel) {
    return SliverAppBar(
      title: const Text('Delat innehåll'),
      floating: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back),
      ),
      actions: [
        // Notification badge med unread count
        if (viewModel.totalUnreadCount > 0)
          Container(
            margin: EdgeInsets.only(right: AppTheme.spacingSm),
            child: Stack(
              children: [
                IconButton(
                  onPressed: () => viewModel.refresh(),
                  icon: const Icon(Icons.refresh),
                ),
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    child: Text(
                      '${viewModel.totalUnreadCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          IconButton(
            onPressed: () => viewModel.refresh(),
            icon: const Icon(Icons.refresh),
          ),
      ],
    );
  }

  Widget _buildSearchBar(
      BuildContext context, SharedContentViewModel viewModel) {
    if (!viewModel.hasSharedContent) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: AppTheme.screenPadding,
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Sök i dina delade recept och menyer...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: viewModel.searchQuery.isNotEmpty
                ? IconButton(
                    onPressed: () {
                      _searchController.clear();
                      viewModel.clearSearch();
                    },
                    icon: const Icon(Icons.clear),
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: AppTheme.mediumRadius,
            ),
          ),
          onChanged: viewModel.updateSearchQuery,
        ),
      ),
    );
  }

  Widget _buildTabBar(BuildContext context, SharedContentViewModel viewModel) {
    if (!viewModel.hasSharedContent) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Container(
        margin: AppTheme.screenPadding,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: AppTheme.mediumRadius,
        ),
        child: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.restaurant, size: 20),
                  SizedBox(width: AppTheme.spacingXs),
                  Text('Recept (${viewModel.totalSharedRecipes})'),
                  if (viewModel.unreadRecipesCount > 0) ...[
                    SizedBox(width: AppTheme.spacingXs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${viewModel.unreadRecipesCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_month, size: 20),
                  SizedBox(width: AppTheme.spacingXs),
                  Text('Menyer (${viewModel.totalSharedMenus})'),
                  if (viewModel.unreadMenusCount > 0) ...[
                    SizedBox(width: AppTheme.spacingXs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${viewModel.unreadMenusCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          indicator: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: AppTheme.mediumRadius,
          ),
          labelColor: Theme.of(context).colorScheme.onPrimary,
          unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
          dividerColor: Colors.transparent,
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, SharedContentViewModel viewModel) {
    if (viewModel.isLoading) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppTheme.mediumLoadingIndicator(),
              AppTheme.mediumGap,
              Text(
                'Laddar delat innehåll...',
                style: AppTheme.subtitleStyle,
              ),
            ],
          ),
        ),
      );
    }

    if (viewModel.hasError) {
      return SliverFillRemaining(
        // ✅ MIGRATION: Error state
        child: StateWidget.error(
          message: viewModel.error!,
          onAction: viewModel.loadSharedContent,
        ),
      );
    }

    if (!viewModel.hasSharedContent) {
      return SliverFillRemaining(
        // ✅ MIGRATION: No shared content state
        child: StateWidget.empty(
          title: 'Inga delade recept än',
          subtitle:
              'När vänner delar recept eller menyer med dig kommer de att visas här.',
          icon: Icons.share_outlined,
          actionLabel: 'Lägg till vänner',
          onAction: () => Navigator.pushNamed(context, '/friends'),
        ),
      );
    }

    if (!viewModel.hasFilteredContent && viewModel.searchQuery.isNotEmpty) {
      return SliverFillRemaining(
        // ✅ MIGRATION: No search results state
        child: StateWidget.noSearchResults(
          actionLabel: 'Rensa sökning',
          onAction: () {
            _searchController.clear();
            viewModel.clearSearch();
          },
        ),
      );
    }

    return SliverFillRemaining(
      child: TabBarView(
        controller: _tabController,
        children: [
          _buildRecipesList(context, viewModel),
          _buildMenusList(context, viewModel),
        ],
      ),
    );
  }

  Widget _buildRecipesList(
      BuildContext context, SharedContentViewModel viewModel) {
    final recipes = viewModel.filteredSharedRecipes;

    if (recipes.isEmpty) {
      // ✅ MIGRATION: No recipes state
      return StateWidget.empty(
        title: 'Inga recept',
        subtitle: 'Inga recept har delats med dig än.',
        icon: Icons.restaurant_outlined,
        actionLabel: 'Hitta vänner',
        onAction: () => Navigator.pushNamed(context, '/friends'),
      );
    }

    return RefreshIndicator(
      onRefresh: viewModel.refresh,
      child: ListView.separated(
        padding: AppTheme.screenPadding,
        itemCount: recipes.length,
        separatorBuilder: (context, index) =>
            SizedBox(height: AppTheme.spacingSm),
        itemBuilder: (context, index) {
          final sharedRecipe = recipes[index];
          return _buildRecipeCard(context, viewModel, sharedRecipe);
        },
      ),
    );
  }

  Widget _buildMenusList(
      BuildContext context, SharedContentViewModel viewModel) {
    final menus = viewModel.filteredSharedMenus;

    if (menus.isEmpty) {
      // ✅ MIGRATION: No menus state
      return StateWidget.empty(
        title: 'Inga menyer',
        subtitle: 'Inga menyer har delats med dig än.',
        icon: Icons.calendar_month_outlined,
        actionLabel: 'Hitta vänner',
        onAction: () => Navigator.pushNamed(context, '/friends'),
      );
    }

    return RefreshIndicator(
      onRefresh: viewModel.refresh,
      child: ListView.separated(
        padding: AppTheme.screenPadding,
        itemCount: menus.length,
        separatorBuilder: (context, index) =>
            SizedBox(height: AppTheme.spacingSm),
        itemBuilder: (context, index) {
          final sharedMenu = menus[index];
          return _buildMenuCard(context, viewModel, sharedMenu);
        },
      ),
    );
  }

  Widget _buildRecipeCard(
    BuildContext context,
    SharedContentViewModel viewModel,
    SharedRecipe sharedRecipe,
  ) {
    final recipe = sharedRecipe.recipeSnapshot;
    final isRead = viewModel.isRecipeRead(sharedRecipe);
    final isImported = viewModel.isRecipeImported(sharedRecipe);

    return Card(
      elevation: isRead ? 1 : 3,
      child: InkWell(
        borderRadius: AppTheme.mediumRadius,
        onTap: () {
          if (!isRead) {
            viewModel.markRecipeAsRead(sharedRecipe);
          }
          Navigator.pushNamed(
            context,
            '/receptDetalj',
            arguments: recipe,
          );
        },
        child: Container(
          padding: AppTheme.cardPadding,
          decoration: BoxDecoration(
            borderRadius: AppTheme.mediumRadius,
            border: !isRead
                ? Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  )
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header med delningsinfo
              Row(
                children: [
                  UserDisplayWidgets.avatar(
                    size: ImageSize.small,
                    displayName: sharedRecipe.sharedByDisplayName,
                  ),
                  SizedBox(width: AppTheme.spacingSm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delat av ${sharedRecipe.sharedByDisplayName}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                fontWeight: isRead
                                    ? FontWeight.normal
                                    : FontWeight.w600,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                        Text(
                          timeago.format(sharedRecipe.sharedAt, locale: 'sv'),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  // Dismiss knapp
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .errorContainer
                          .withValues(alpha: 0.1),
                      borderRadius: AppTheme.smallRadius,
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withValues(alpha: 0.2),
                      ),
                    ),
                    child: IconButton(
                      onPressed: () =>
                          _dismissRecipe(context, viewModel, sharedRecipe),
                      icon: Icon(
                        Icons.close,
                        size: AppTheme.iconSizeInfo,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      tooltip: 'Dölj från min lista',
                      padding: EdgeInsets.all(AppTheme.spacingXs),
                      constraints: BoxConstraints(
                        minWidth: AppTheme.iconSizeAction + AppTheme.spacingSm,
                        minHeight: AppTheme.iconSizeAction + AppTheme.spacingSm,
                      ),
                    ),
                  ),
                  if (!isRead)
                    Container(
                      width: 8,
                      height: 8,
                      margin: EdgeInsets.only(left: AppTheme.spacingXs),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              SizedBox(height: AppTheme.spacingSm),

              // Recept content
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (recipe.hasImages)
                    ClipRRect(
                      borderRadius: AppTheme.smallRadius,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: AppTheme.smallRadius,
                          image: recipe.primaryImageUrl != null
                              ? DecorationImage(
                                  image: NetworkImage(recipe.primaryImageUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                          color: recipe.primaryImageUrl == null
                              ? Theme.of(context).colorScheme.surfaceContainer
                              : null,
                        ),
                        child: recipe.primaryImageUrl == null
                            ? Icon(
                                Icons.restaurant,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                size: AppTheme.iconSizeInfo,
                              )
                            : null,
                      ),
                    ),
                  SizedBox(width: AppTheme.spacingSm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          recipe.title,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: isRead
                                        ? FontWeight.normal
                                        : FontWeight.w600,
                                  ),
                        ),
                        if (recipe.description.isNotEmpty) ...[
                          SizedBox(height: AppTheme.spacingXs),
                          Text(
                            recipe.description,
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        SizedBox(height: AppTheme.spacingXs),
                        Row(
                          children: [
                            Icon(
                              Icons.restaurant,
                              size: 16,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                            SizedBox(width: AppTheme.spacingXs),
                            Text(
                              '${recipe.portions ?? '?'} portioner',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            SizedBox(width: AppTheme.spacingSm),
                            Icon(
                              Icons.access_time,
                              size: 16,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                            SizedBox(width: AppTheme.spacingXs),
                            Text(
                              recipe.cookTimeText,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Message från delaren
              if (sharedRecipe.shareMessage?.isNotEmpty == true) ...[
                SizedBox(height: AppTheme.spacingSm),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(AppTheme.spacingSm),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    borderRadius: AppTheme.smallRadius,
                  ),
                  child: Text(
                    '"${sharedRecipe.shareMessage}"',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                  ),
                ),
              ],

              SizedBox(height: AppTheme.spacingSm),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        if (!isRead) {
                          viewModel.markRecipeAsRead(sharedRecipe);
                        }
                        Navigator.pushNamed(
                          context,
                          '/receptDetalj',
                          arguments: recipe,
                        );
                      },
                      icon: const Icon(Icons.visibility, size: 18),
                      label: const Text('Visa'),
                    ),
                  ),
                  SizedBox(width: AppTheme.spacingSm),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: isImported || viewModel.isImporting
                          ? null
                          : () =>
                              _importRecipe(context, viewModel, sharedRecipe),
                      icon: isImported
                          ? const Icon(Icons.check, size: 18)
                          : viewModel.isImporting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.download, size: 18),
                      label: Text(
                        isImported ? 'Importerat' : 'Importera',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context,
    SharedContentViewModel viewModel,
    SharedMenu sharedMenu,
  ) {
    final isRead = viewModel.isMenuRead(sharedMenu);
    final isImported = viewModel.isMenuImported(sharedMenu);

    return Card(
      elevation: isRead ? 1 : 3,
      child: InkWell(
        borderRadius: AppTheme.mediumRadius,
        onTap: () {
          if (!isRead) {
            viewModel.markMenuAsRead(sharedMenu);
          }
          // ✅ NAVIGERA till MenuPreviewView
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChangeNotifierProvider.value(
                value: viewModel,
                child: MenuPreviewView(sharedMenu: sharedMenu),
              ),
            ),
          );
        },
        child: Container(
          padding: AppTheme.cardPadding,
          decoration: BoxDecoration(
            borderRadius: AppTheme.mediumRadius,
            border: !isRead
                ? Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  )
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header med delningsinfo
              Row(
                children: [
                  UserDisplayWidgets.avatar(
                    size: ImageSize.small,
                    displayName: sharedMenu.sharedByDisplayName,
                  ),
                  SizedBox(width: AppTheme.spacingSm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delat av ${sharedMenu.sharedByDisplayName}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                fontWeight: isRead
                                    ? FontWeight.normal
                                    : FontWeight.w600,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                        Text(
                          timeago.format(sharedMenu.sharedAt, locale: 'sv'),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  // Dismiss knapp
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .errorContainer
                          .withValues(alpha: 0.1),
                      borderRadius: AppTheme.smallRadius,
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withValues(alpha: 0.2),
                      ),
                    ),
                    child: IconButton(
                      onPressed: () =>
                          _dismissMenu(context, viewModel, sharedMenu),
                      icon: Icon(
                        Icons.close,
                        size: AppTheme.iconSizeInfo,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      tooltip: 'Dölj från min lista',
                      padding: EdgeInsets.all(AppTheme.spacingXs),
                      constraints: BoxConstraints(
                        minWidth: AppTheme.iconSizeAction + AppTheme.spacingSm,
                        minHeight: AppTheme.iconSizeAction + AppTheme.spacingSm,
                      ),
                    ),
                  ),
                  if (!isRead)
                    Container(
                      width: 8,
                      height: 8,
                      margin: EdgeInsets.only(left: AppTheme.spacingXs),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              SizedBox(height: AppTheme.spacingSm),

              // Meny content
              Row(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: AppTheme.smallRadius,
                    ),
                    child: Icon(
                      Icons.calendar_month,
                      size: 40,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  SizedBox(width: AppTheme.spacingSm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sharedMenu.menuTitle,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: isRead
                                        ? FontWeight.normal
                                        : FontWeight.w600,
                                  ),
                        ),
                        SizedBox(height: AppTheme.spacingXs),
                        Text(
                          sharedMenu.menuSummary,
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: AppTheme.spacingXs),
                        Row(
                          children: [
                            Icon(
                              Icons.restaurant_menu,
                              size: 16,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                            SizedBox(width: AppTheme.spacingXs),
                            Text(
                              '${sharedMenu.totalRecipeCount} recept',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            SizedBox(width: AppTheme.spacingSm),
                            Icon(
                              Icons.category,
                              size: 16,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                            SizedBox(width: AppTheme.spacingXs),
                            Text(
                              '${sharedMenu.categories.length} kategorier',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Message från delaren
              if (sharedMenu.shareMessage?.isNotEmpty == true) ...[
                SizedBox(height: AppTheme.spacingSm),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(AppTheme.spacingSm),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    borderRadius: AppTheme.smallRadius,
                  ),
                  child: Text(
                    '"${sharedMenu.shareMessage}"',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                  ),
                ),
              ],

              SizedBox(height: AppTheme.spacingSm),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        if (!isRead) {
                          viewModel.markMenuAsRead(sharedMenu);
                        }
                        // ✅ NAVIGERA till MenuPreviewView
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChangeNotifierProvider.value(
                              value: viewModel,
                              child: MenuPreviewView(sharedMenu: sharedMenu),
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.visibility, size: 18),
                      label: const Text('Visa'),
                    ),
                  ),
                  SizedBox(width: AppTheme.spacingSm),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: isImported || viewModel.isImporting
                          ? null
                          : () => _importMenu(context, viewModel, sharedMenu),
                      icon: isImported
                          ? const Icon(Icons.check, size: 18)
                          : viewModel.isImporting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.download, size: 18),
                      label: Text(
                        isImported ? 'Importerat' : 'Importera',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _importRecipe(
    BuildContext context,
    SharedContentViewModel viewModel,
    SharedRecipe sharedRecipe,
  ) async {
    final success = await viewModel.importSharedRecipe(sharedRecipe);

    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '✅ Recept "${sharedRecipe.recipeSnapshot.title}" importerat!'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } else if (context.mounted && viewModel.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(viewModel.error!),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _importMenu(
    BuildContext context,
    SharedContentViewModel viewModel,
    SharedMenu sharedMenu,
  ) async {
    final success = await viewModel.importSharedMenu(sharedMenu);

    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Meny "${sharedMenu.menuTitle}" importerad!'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } else if (context.mounted && viewModel.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(viewModel.error!),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _dismissRecipe(
    BuildContext context,
    SharedContentViewModel viewModel,
    SharedRecipe sharedRecipe,
  ) async {
    // Visa bekräftelsedialog
    final shouldDismiss = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dölj recept'),
        content: Text(
          'Vill du dölja "${sharedRecipe.recipeSnapshot.title}" från din lista?\n\n'
          'Du kan fortfarande komma åt receptet genom att söka eller be '
          '${sharedRecipe.sharedByDisplayName} att dela det igen.',
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
      final success = await viewModel.dismissSharedRecipe(sharedRecipe);

      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '✅ "${sharedRecipe.recipeSnapshot.title}" dolt från din lista'),
            backgroundColor: AppTheme.successColor,
            action: SnackBarAction(
              label: 'Ångra',
              onPressed: () => viewModel.undismissSharedRecipe(sharedRecipe),
            ),
          ),
        );
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

  Future<void> _dismissMenu(
    BuildContext context,
    SharedContentViewModel viewModel,
    SharedMenu sharedMenu,
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
}
