/// Shared content view displaying what friends have shared with the user.

// lib/views/social/shared_with_me_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/viewmodels/shared_content/shared_content_coordinator_viewmodel.dart';
import 'package:butlery/core/utils/logger.dart';

import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';
import 'package:butlery/widgets/common/layout/butlery_page.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/constants/routes.dart';

// Import focused components
import 'package:butlery/views/social/shared_with_me/shared_content_search_bar.dart';
import 'package:butlery/views/social/shared_with_me/shared_content_tabs.dart';
import 'package:butlery/views/social/shared_with_me/shared_content_lists.dart';

/// Shared content view: tabs over recipes, menus and shopping lists.
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

class _SharedWithMeViewContentState extends State<_SharedWithMeViewContent> {
  final _searchController = TextEditingController();
  SharedContentFilter _filter = SharedContentFilter.recipes;

  @override
  void initState() {
    AppLogger.info('_SharedWithMeViewContent.initState() called');
    super.initState();

    // Trigger initial data load after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SharedContentCoordinatorViewModel>().initialize();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<SharedContentCoordinatorViewModel>();
    return ButleryPage.undersida(
      title: context.l10n.profileSharedWithMe,
      backTo: context.l10n.moreTitle,
      body: Column(
        children: [
          LayoutComponents.offlineIndicator(),
          if (viewModel.hasAnyContent) ...[
            SharedContentSearchBar.build(
              context,
              viewModel,
              _searchController,
            ),
            Padding(
              padding: ButleryPageBody.margin(context),
              child: SharedContentTabs(
                viewModel: viewModel,
                selected: _filter,
                onSelected: (filter) => setState(() => _filter = filter),
              ),
            ),
          ],
          Expanded(child: _buildContent(context, viewModel)),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    SharedContentCoordinatorViewModel viewModel,
  ) {
    if (viewModel.isGloballyLoading) {
      return Center(
        child: PlateLineMessage(message: context.l10n.sharedLoadingContent),
      );
    }

    if (viewModel.hasGlobalError) {
      return StateWidget.error(
        message: viewModel.globalError!,
        onAction: viewModel.refreshAllContent,
      );
    }

    if (!viewModel.hasAnyContent) {
      return StateWidget.empty(
        title: context.l10n.sharedNoContentYet,
        subtitle: context.l10n.sharedEmptyStateExplanation,
        icon: ButleryIcons.share2,
        actionLabel: context.l10n.socialFindFriends,
        onAction: () => Navigator.pushNamed(context, Routes.friends),
      );
    }

    final rows = SharedContentLists.rowsFor(viewModel, _filter);
    if (rows.isEmpty) {
      if (viewModel.searchViewModel.hasSearchQuery) {
        return StateWidget.noSearchResults(
          actionLabel: context.l10n.commonClearSearch,
          onAction: () {
            _searchController.clear();
            viewModel.clearAllSearch();
          },
        );
      }
      return _buildEmptyForFilter(context);
    }

    return SharedContentLists.build(context, viewModel, _filter, rows);
  }

  Widget _buildEmptyForFilter(BuildContext context) {
    final l10n = context.l10n;
    return switch (_filter) {
      SharedContentFilter.recipes => StateWidget.empty(
        title: l10n.sharedNoRecipes,
        subtitle: l10n.sharedNoRecipesDescription,
        icon: ButleryIcons.utensils,
        actionLabel: context.l10n.socialFindFriends,
        onAction: () => Navigator.pushNamed(context, Routes.friends),
      ),
      SharedContentFilter.menus => StateWidget.empty(
        title: l10n.sharedNoMenus,
        subtitle: l10n.sharedNoMenusDescription,
        icon: ButleryIcons.calendar,
        actionLabel: context.l10n.socialFindFriends,
        onAction: () => Navigator.pushNamed(context, Routes.friends),
      ),
      SharedContentFilter.shoppingLists => StateWidget.empty(
        title: l10n.sharedNoShoppingLists,
        subtitle: l10n.sharedNoShoppingListsDescription,
        icon: ButleryIcons.shoppingCart,
        actionLabel: context.l10n.socialFindFriends,
        onAction: () => Navigator.pushNamed(context, Routes.friends),
      ),
    };
  }
}
