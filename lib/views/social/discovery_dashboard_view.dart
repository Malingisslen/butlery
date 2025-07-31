// lib/views/social/discovery_dashboard_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:butlery/core/injection.dart';
import 'package:butlery/viewmodels/discovery_dashboard_viewmodel.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_colors.dart';

import 'package:butlery/widgets/common/state_widget.dart';

// Import focused components
import 'package:butlery/views/social/discovery_dashboard/discovery_app_bar.dart';
import 'package:butlery/views/social/discovery_dashboard/discovery_search_section.dart';
import 'package:butlery/views/social/discovery_dashboard/discovery_categories.dart';
import 'package:butlery/views/social/discovery_dashboard/trending_content_section.dart';
import 'package:butlery/views/social/discovery_dashboard/friend_activity_section.dart';
import 'package:butlery/views/social/discovery_dashboard/recommendations_section.dart';

/// Discovery Dashboard View - Unified content discovery for social platform
/// 
/// This view provides a comprehensive discovery experience featuring:
/// - Trending recipes, menus, and shopping lists
/// - Friend activity timeline
/// - Personalized recommendations
/// - Advanced search and filtering
/// - Content categories and discovery feeds
class DiscoveryDashboardView extends StatelessWidget {
  const DiscoveryDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<DiscoveryDashboardViewModel>(
      create: (context) => sl<DiscoveryDashboardViewModel>(),
      child: const _DiscoveryDashboardViewContent(),
    );
  }
}

class _DiscoveryDashboardViewContent extends StatefulWidget {
  const _DiscoveryDashboardViewContent();

  @override
  State<_DiscoveryDashboardViewContent> createState() =>
      _DiscoveryDashboardViewContentState();
}

class _DiscoveryDashboardViewContentState
    extends State<_DiscoveryDashboardViewContent>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true; // Keep state when switching tabs

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); // Discovery, Activity, Recommendations

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final viewModel = context.read<DiscoveryDashboardViewModel>();

      // Initialize the view model
      viewModel.initialize();

      // Sync tab controller with ViewModel
      _tabController.addListener(() {
        if (!_tabController.indexIsChanging) {
          viewModel.setActiveTab(_tabController.index);
        }
      });

      // Setup scroll controller for infinite loading
      _scrollController.addListener(() {
        if (_scrollController.position.pixels >= 
            _scrollController.position.maxScrollExtent - 200) {
          viewModel.loadMoreContent();
        }
      });
    });

    // Configure Swedish for timeago
    timeago.setLocaleMessages('sv', timeago.SvMessages());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Consumer<DiscoveryDashboardViewModel>(
        builder: (context, viewModel, _) {
          return CustomScrollView(
            controller: _scrollController,
            slivers: [
              DiscoveryAppBar.build(context, viewModel),
              DiscoverySearchSection.build(context, viewModel, _searchController),
              _buildTabBar(context, viewModel),
              _buildContent(context, viewModel),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTabBar(BuildContext context, DiscoveryDashboardViewModel viewModel) {
    return SliverToBoxAdapter(
      child: Container(
        color: AppColors.surface,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingL),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          ),
          child: TabBar(
            controller: _tabController,
            tabs: [
              _buildTab('Upptäck', Icons.explore, viewModel.trendingContentCount),
              _buildTab('Aktivitet', Icons.timeline, viewModel.friendActivityCount),
              _buildTab('För dig', Icons.recommend, viewModel.recommendationsCount),
            ],
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.onSurface.withValues(alpha: 0.6),
            labelStyle: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: AppTextStyles.bodyMedium,
            indicator: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDimensions.radiusS),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            overlayColor: MaterialStateProperty.all(
              AppColors.primary.withValues(alpha: 0.05),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTab(String label, IconData icon, int count) {
    return Tab(
      height: 56,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, size: 20),
              if (count > 0)
                Positioned(
                  right: -8,
                  top: -8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      count > 99 ? '99+' : count.toString(),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.onPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, DiscoveryDashboardViewModel viewModel) {
    if (viewModel.isInitialLoading) {
      return const SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: AppDimensions.iconSizeL,
                height: AppDimensions.iconSizeL,
                child: CircularProgressIndicator(),
              ),
              SizedBox(height: AppDimensions.spacingXl),
              Text(
                'Laddar upptäcktsinnehåll...',
                style: AppTextStyles.titleMedium,
              ),
            ],
          ),
        ),
      );
    }

    if (viewModel.hasError) {
      return SliverFillRemaining(
        child: StateWidget.error(
          message: viewModel.error!,
          onAction: viewModel.refresh,
        ),
      );
    }

    if (viewModel.searchQuery.isNotEmpty && !viewModel.hasSearchResults) {
      return SliverFillRemaining(
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
          _buildDiscoveryTab(context, viewModel),
          _buildActivityTab(context, viewModel),
          _buildRecommendationsTab(context, viewModel),
        ],
      ),
    );
  }

  Widget _buildDiscoveryTab(BuildContext context, DiscoveryDashboardViewModel viewModel) {
    if (viewModel.searchQuery.isNotEmpty) {
      // Show search results when searching
      return _buildSearchResults(context, viewModel);
    }

    return SingleChildScrollView(
      padding: AppDimensions.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DiscoveryCategories.build(context, viewModel),
          const SizedBox(height: AppDimensions.spacingL),
          TrendingContentSection.build(context, viewModel),
          const SizedBox(height: AppDimensions.spacingL),
          _buildPopularWithFriendsSection(context, viewModel),
          const SizedBox(height: AppDimensions.spacingL),
          _buildRecentlySharedSection(context, viewModel),
        ],
      ),
    );
  }

  Widget _buildActivityTab(BuildContext context, DiscoveryDashboardViewModel viewModel) {
    return SingleChildScrollView(
      padding: AppDimensions.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FriendActivitySection.build(context, viewModel),
        ],
      ),
    );
  }

  Widget _buildRecommendationsTab(BuildContext context, DiscoveryDashboardViewModel viewModel) {
    return SingleChildScrollView(
      padding: AppDimensions.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RecommendationsSection.build(context, viewModel),
        ],
      ),
    );
  }

  Widget _buildSearchResults(BuildContext context, DiscoveryDashboardViewModel viewModel) {
    final searchResults = viewModel.searchResults;
    
    if (searchResults.isEmpty) {
      return StateWidget.noSearchResults(
        message: 'Inga resultat för "${viewModel.searchQuery}"',
        actionLabel: 'Rensa sökning',
        onAction: () {
          _searchController.clear();
          viewModel.clearSearch();
        },
      );
    }

    return ListView.separated(
      padding: AppDimensions.screenPadding,
      itemCount: searchResults.length,
      separatorBuilder: (context, index) => const SizedBox(height: AppDimensions.spacingS),
      itemBuilder: (context, index) {
        final item = searchResults[index];
        return _buildSearchResultCard(context, item);
      },
    );
  }

  Widget _buildSearchResultCard(BuildContext context, Map<String, dynamic> item) {
    final type = item['type'] as String;
    final title = item['title'] as String;
    final description = item['description'] as String?;
    final imageUrl = item['imageUrl'] as String?;
    final ownerName = item['ownerName'] as String?;

    return Card(
      child: ListTile(
        leading: _buildSearchResultIcon(type),
        title: Text(
          title,
          style: AppTextStyles.titleSmall,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (description != null)
              Text(
                description,
                style: AppTextStyles.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            if (ownerName != null)
              Text(
                'Av $ownerName',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.onSurface.withValues(alpha: 0.6),
                ),
              ),
          ],
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: AppColors.onSurface.withValues(alpha: 0.4),
        ),
        onTap: () => _handleSearchResultTap(context, item),
      ),
    );
  }

  Widget _buildSearchResultIcon(String type) {
    IconData icon;
    Color color;
    
    switch (type) {
      case 'recipe':
        icon = Icons.restaurant;
        color = AppColors.success;
        break;
      case 'menu':
        icon = Icons.calendar_month;
        color = AppColors.info;
        break;
      case 'shopping_list':
        icon = Icons.shopping_cart;
        color = AppColors.warning;
        break;
      default:
        icon = Icons.help_outline;
        color = AppColors.onSurface;
    }

    return CircleAvatar(
      backgroundColor: color.withValues(alpha: 0.1),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _buildPopularWithFriendsSection(BuildContext context, DiscoveryDashboardViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.people,
              color: AppColors.primary,
              size: 20,
            ),
            const SizedBox(width: AppDimensions.spacingS),
            Text(
              'Populärt bland vänner',
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingM),
        Text(
          'Innehåll som dina vänner gillar och delar',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: AppDimensions.spacingM),
        // TODO: Implement popular with friends content
        Container(
          height: 120,
          decoration: BoxDecoration(
            color: AppColors.primaryContainer.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppDimensions.radiusM),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.2),
              style: BorderStyle.solid,
            ),
          ),
          child: const Center(
            child: Text('Populärt innehåll kommer snart!'),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentlySharedSection(BuildContext context, DiscoveryDashboardViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.access_time,
              color: AppColors.secondary,
              size: 20,
            ),
            const SizedBox(width: AppDimensions.spacingS),
            Text(
              'Nyligen delat',
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingM),
        Text(
          'Senast delade innehåll i ditt nätverk',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: AppDimensions.spacingM),
        // TODO: Implement recently shared content
        Container(
          height: 120,
          decoration: BoxDecoration(
            color: AppColors.secondaryContainer.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppDimensions.radiusM),
            border: Border.all(
              color: AppColors.secondary.withValues(alpha: 0.2),
              style: BorderStyle.solid,
            ),
          ),
          child: const Center(
            child: Text('Nyligen delat innehåll kommer snart!'),
          ),
        ),
      ],
    );
  }

  void _handleSearchResultTap(BuildContext context, Map<String, dynamic> item) {
    final type = item['type'] as String;
    final id = item['id'] as String;

    switch (type) {
      case 'recipe':
        Navigator.pushNamed(context, '/recipe-detail', arguments: {'recipeId': id});
        break;
      case 'menu':
        Navigator.pushNamed(context, '/menu-detail', arguments: {'menuId': id});
        break;
      case 'shopping_list':
        Navigator.pushNamed(context, '/shopping-list-detail', arguments: {'listId': id});
        break;
    }
  }
}