/// Shared content view displaying friend-shared recipes and menus.

// lib/views/social/shared_with_me_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/viewmodels/shared_content/shared_content_coordinator_viewmodel.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/utils/logger.dart';

import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/common/indicators/loading_indicator.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

// Import focused components
import 'package:butlery/views/social/shared_with_me/shared_content_app_bar.dart';
import 'package:butlery/views/social/shared_with_me/shared_content_search_bar.dart';
import 'package:butlery/views/social/shared_with_me/shared_content_tab_bar.dart';
import 'package:butlery/views/social/shared_with_me/shared_content_lists.dart';

/// Shared content view with tabbed display for recipes, menus, and shopping lists.
class SharedWithMeView extends StatefulWidget {
  const SharedWithMeView({super.key});

  @override
  State<SharedWithMeView> createState() => _SharedWithMeViewState();
}

class _SharedWithMeViewState extends State<SharedWithMeView> {
  late final SharedContentCoordinatorViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = ServiceLocator.get<SharedContentCoordinatorViewModel>();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SharedContentCoordinatorViewModel>.value(
      value: _viewModel,
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
    AppLogger.info('_SharedWithMeViewContent.initState() called');
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Configure Swedish for timeago
    timeago.setLocaleMessages('sv', timeago.SvMessages());

    // Trigger initial data load after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SharedContentCoordinatorViewModel>().initialize();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutComponents.mainMenu(
      body: Consumer<SharedContentCoordinatorViewModel>(
        builder: (context, viewModel, _) {
          return SafeArea(
            // Responsive: center and constrain content on large screens
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
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: LayoutComponents.offlineIndicator(),
                    ),
                    SharedContentAppBar.build(context, viewModel),
                    SharedContentSearchBar.build(
                        context, viewModel, _searchController),
                    SharedContentTabBar.build(
                        context, viewModel, _tabController),
                    _buildContent(context, viewModel),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, SharedContentCoordinatorViewModel viewModel) {
    if (viewModel.isGloballyLoading) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const LoadingIndicator(size: AppDimensions.iconSizeL),
              const SizedBox(height: AppDimensions.spacingXl),
              Text(
                context.l10n.sharedLoadingContent,
                style: AppTextStyles.titleMedium,
              ),
            ],
          ),
        ),
      );
    }

    if (viewModel.hasGlobalError) {
      return SliverFillRemaining(
        child: StateWidget.error(
          message: viewModel.globalError!,
          onAction: viewModel.refreshAllContent,
        ),
      );
    }

    if (!viewModel.hasAnyContent) {
      return SliverFillRemaining(
        child: StateWidget.empty(
          title: context.l10n.sharedNoContentYet,
          subtitle: context.l10n.sharedEmptyStateExplanation,
          icon: Icons.share_outlined,
          actionLabel: context.l10n.sharedShareFirstRecipe,
          onAction: () => Navigator.pushNamed(context, Routes.home),
        ),
      );
    }

    // Check if search is active and no results - check each specialized viewmodel
    final hasSearchQuery = viewModel.searchViewModel.hasSearchQuery;
    final hasFilteredContent = viewModel.recipeViewModel.hasFilteredContent ||
        viewModel.menuViewModel.hasFilteredContent ||
        viewModel.shoppingViewModel.hasFilteredContent;

    if (!hasFilteredContent && hasSearchQuery) {
      return SliverFillRemaining(
        child: StateWidget.noSearchResults(
          actionLabel: context.l10n.commonClearSearch,
          onAction: () {
            _searchController.clear();
            viewModel.clearAllSearch();
          },
        ),
      );
    }

    return SliverFillRemaining(
      child: TabBarView(
        controller: _tabController,
        children: [
          SharedContentLists.buildRecipesList(
              context, viewModel, _searchController),
          SharedContentLists.buildMenusList(
              context, viewModel, _searchController),
          SharedContentLists.buildSharedShoppingListsList(
              context, viewModel, _searchController),
        ],
      ),
    );
  }
}
