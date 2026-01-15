// lib/views/social/discovery_dashboard_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:butlery/viewmodels/discovery_dashboard_viewmodel.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_colors.dart';

import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/common/state/loading_states.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/widgets/common/animations/animated_list_item.dart';
import 'package:butlery/views/social/discovery_dashboard/discovery_section_header.dart';

// Import focused components
import 'package:butlery/views/social/discovery_dashboard/discovery_app_bar.dart';
import 'package:butlery/views/social/discovery_dashboard/discovery_search_section.dart';
import 'package:butlery/views/social/discovery_dashboard/discovery_categories.dart';
import 'package:butlery/views/social/discovery_dashboard/trending_content_section.dart';
import 'package:butlery/views/social/discovery_dashboard/friend_activity_section.dart';
import 'package:butlery/views/social/discovery_dashboard/recommendations_section.dart';
import 'package:butlery/views/social/discovery_dashboard/responsive_dashboard_wrapper.dart';
import 'package:butlery/views/social/discovery_dashboard/popular_with_friends_section.dart';
import 'package:butlery/views/social/discovery_dashboard/recently_shared_section.dart';

/// Discovery Dashboard View - Unified content discovery with trending content, friend activity, and personalized recommendations.
class DiscoveryDashboardView extends StatelessWidget {
  const DiscoveryDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<DiscoveryDashboardViewModel>(
      create: (context) => DiscoveryDashboardViewModel(),
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
    _tabController = TabController(
        length: 3, vsync: this); // Discovery, Activity, Recommendations

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final viewModel = context.read<DiscoveryDashboardViewModel>();

      viewModel.initialize();

      _tabController.addListener(() {
        if (!_tabController.indexIsChanging) {
          viewModel.setActiveTab(_tabController.index);
        }
      });

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
              DiscoverySearchSection.build(
                  context, viewModel, _searchController),
              _buildTabBar(context, viewModel),
              _buildContent(context, viewModel),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTabBar(
      BuildContext context, DiscoveryDashboardViewModel viewModel) {
    return SliverToBoxAdapter(
      child: ColoredBox(
        color: AppColors.surface,
        // ✅ RESPONSIVE: Center and constrain tab bar on large screens
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: LayoutComponents.valueFor(
                context: context,
                mobile: double.infinity,
                tablet: 900,
                desktop: 1200,
              ),
            ),
            child: Container(
              margin: AppDimensions.responsiveHorizontalPadding(context),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant.withValues(alpha: AppDimensions.opacityMediumLight),
                borderRadius:
                    BorderRadius.circular(AppDimensions.borderRadiusM),
              ),
              child: TabBar(
                controller: _tabController,
                tabs: [
                  _buildTab(
                      'Upptäck', Icons.explore, viewModel.trendingContentCount),
                  _buildTab('Aktivitet', Icons.timeline,
                      viewModel.friendActivityCount),
                  _buildTab('För dig', Icons.recommend,
                      viewModel.recommendationsCount),
                ],
                labelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor:
                    Theme.of(context).colorScheme.onSurfaceVariant,
                labelStyle: AppTextStyles.bodyBold,
                unselectedLabelStyle: AppTextStyles.bodyMedium,
                indicator: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: AppDimensions.opacityVeryLight),
                  borderRadius:
                      BorderRadius.circular(AppDimensions.borderRadiusS),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: AppColors.transparent,
                overlayColor: WidgetStateProperty.all(
                  AppColors.primary.withValues(alpha: AppDimensions.opacityExtraVeryLight),
                ),
              ),
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
              Icon(icon, size: AppDimensions.iconSizeM),
              if (count > 0)
                Positioned(
                  right: -8,
                  top: -8,
                  child: Container(
                    padding: AppDimensions.paddingAll2,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(count > 99 ? '99+' : count.toString(),
                        style: AppTextStyles.labelLarge.copyWith(
                            color: AppColors.onPrimary),
                        textAlign: TextAlign.center),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingXs),
          Text(label, style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, DiscoveryDashboardViewModel viewModel) {
    if (viewModel.isInitialLoading) {
      return SliverFillRemaining(
        child: LoadingStates.buildLoadingState(
          context,
          variant: LoadingVariant.spinner,
          message: 'Laddar upptäcktsinnehåll...',
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

  Widget _buildDiscoveryTab(
      BuildContext context, DiscoveryDashboardViewModel viewModel) {
    if (viewModel.searchQuery.isNotEmpty) {
      return _buildSearchResults(context, viewModel);
    }

    return ResponsiveDashboardWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DiscoveryCategories.build(context, viewModel),
          const DiscoverySectionDivider(),
          TrendingContentSection.build(context, viewModel),
          const DiscoverySectionDivider(),
          PopularWithFriendsSection.build(context, viewModel),
          const DiscoverySectionDivider(),
          RecentlySharedSection.build(context, viewModel),
        ],
      ),
    );
  }

  Widget _buildActivityTab(
      BuildContext context, DiscoveryDashboardViewModel viewModel) {
    return ResponsiveDashboardWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FriendActivitySection.build(context, viewModel),
        ],
      ),
    );
  }

  Widget _buildRecommendationsTab(
      BuildContext context, DiscoveryDashboardViewModel viewModel) {
    return ResponsiveDashboardWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RecommendationsSection.build(context, viewModel),
        ],
      ),
    );
  }

  Widget _buildSearchResults(
      BuildContext context, DiscoveryDashboardViewModel viewModel) {
    final searchResults = viewModel.searchResults;

    if (searchResults.isEmpty) {
      return StateWidget.noSearchResults(
        actionLabel: 'Rensa sökning',
        onAction: () {
          _searchController.clear();
          viewModel.clearSearch();
        },
      );
    }

    return ResponsiveDashboardWrapper(
      scrollable: false,
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: searchResults.length,
        separatorBuilder: (context, index) =>
            const SizedBox(height: AppDimensions.spacingS),
        itemBuilder: (context, index) {
          final item = searchResults[index];
          return AnimatedListItem(
            index: index,
            child: _buildSearchResultCard(context, item),
          );
        },
      ),
    );
  }

  Widget _buildSearchResultCard(
      BuildContext context, Map<String, dynamic> item) {
    final type = item['type'] as String, title = item['title'] as String;
    final description = item['description'] as String?,
        ownerName = item['ownerName'] as String?;

    return Card(
      child: ListTile(
        leading: _buildSearchResultIcon(type),
        title: Text(title, style: AppTextStyles.titleSmall),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (description != null)
              Text(description,
                  style: AppTextStyles.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            if (ownerName != null)
              Text('Av $ownerName',
                  style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.onSurface.withValues(alpha: AppDimensions.opacityMediumDark))),
          ],
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: AppDimensions.iconSizeS,
          color: AppColors.onSurface.withValues(alpha: AppDimensions.opacityMedium),
        ),
        onTap: () => _handleSearchResultTap(context, item),
      ),
    );
  }

  Widget _buildSearchResultIcon(String type) {
    final iconData = switch (type) {
      'recipe' => (Icons.restaurant, AppColors.success),
      'menu' => (Icons.calendar_month, AppColors.info),
      'shopping_list' => (Icons.shopping_cart, AppColors.warning),
      _ => (Icons.help_outline, AppColors.onSurface),
    };
    return CircleAvatar(
      backgroundColor: iconData.$2.withValues(alpha: AppDimensions.opacityVeryLight),
      child:
          Icon(iconData.$1, color: iconData.$2, size: AppDimensions.iconSizeM),
    );
  }

  void _handleSearchResultTap(BuildContext context, Map<String, dynamic> item) {
    final type = item['type'] as String, id = item['id'] as String;

    switch (type) {
      case 'recipe':
        Navigator.pushNamed(context, '/recipe-detail',
            arguments: {'recipeId': id});
        break;
      case 'menu':
        Navigator.pushNamed(context, '/menu-detail', arguments: {'menuId': id});
        break;
      case 'shopping_list':
        Navigator.pushNamed(context, '/shopping-list-detail',
            arguments: {'listId': id});
        break;
    }
  }
}
