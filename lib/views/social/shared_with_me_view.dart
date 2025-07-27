// lib/views/social/shared_with_me_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:butlery/core/injection.dart';
import 'package:butlery/viewmodels/shared_content_viewmodel.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';

import 'package:butlery/widgets/common/state_widget.dart';

// Import focused components
import 'package:butlery/views/social/shared_with_me/shared_content_app_bar.dart';
import 'package:butlery/views/social/shared_with_me/shared_content_search_bar.dart';
import 'package:butlery/views/social/shared_with_me/shared_content_tab_bar.dart';
import 'package:butlery/views/social/shared_with_me/shared_content_lists.dart';

class SharedWithMeView extends StatelessWidget {
  const SharedWithMeView({super.key});

  @override
  Widget build(BuildContext context) {
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
              SharedContentAppBar.build(context, viewModel),
              SharedContentSearchBar.build(context, viewModel, _searchController),
              SharedContentTabBar.build(context, viewModel, _tabController),
              _buildContent(context, viewModel),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, SharedContentViewModel viewModel) {
    if (viewModel.isLoading) {
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
                'Laddar delat innehåll...',
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
          onAction: viewModel.loadSharedContent,
        ),
      );
    }

    if (!viewModel.hasSharedContent) {
      return SliverFillRemaining(
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
          SharedContentLists.buildRecipesList(context, viewModel, _searchController),
          SharedContentLists.buildMenusList(context, viewModel, _searchController),
        ],
      ),
    );
  }
}