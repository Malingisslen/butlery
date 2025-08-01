/// Comprehensive shared content view providing organized display of friend-shared recipes and menus for Flutter applications.
///
/// This module implements sophisticated shared content interface following Single Responsibility Principle,
/// specializing in shared content display, search functionality, categorization, and comprehensive content interaction.
/// It provides complete shared content interface while maintaining clean separation from business logic,
/// data persistence, and state management through SharedContentViewModel integration and modern component architecture.
///
/// **Single Responsibility Focus:**
/// This module exclusively handles shared content UI presentation concerns through comprehensive content architecture:
/// - **Content Organization Excellence**: Advanced content display with tabbed categorization and comprehensive organization
/// - **Search and Filter Intelligence**: Sophisticated search functionality with real-time filtering and content discovery
/// - **Social Content Coordination**: Comprehensive shared content management with friend attribution and interaction tracking
/// - **State Management Integration**: Advanced state handling with loading, error, and empty states coordination
/// - **Swedish Localization Excellence**: Complete Swedish language support with timeago localization and user feedback
///
/// **What This Module Does NOT Handle:**
/// - Shared content business logic and data operations (handled by SharedContentViewModel and content services)
/// - Content sharing implementation and social distribution (handled by sharing services and social infrastructure)
/// - Friend relationship management (handled by friend services and social relationship systems)
/// - Content persistence and synchronization (handled by content services and data management systems)
///
/// **Shared Content View Architecture:**
/// - **Tabbed Content Organization**: Advanced categorization with recipes and menus separation and comprehensive organization
/// - **Real-Time Search Integration**: Sophisticated search functionality with instant filtering and content discovery
/// - **Focused Component System**: Comprehensive component coordination with app bar, search, tabs, and content lists
/// - **Swedish Localization System**: Complete localization with timeago Swedish messages and cultural adaptation
/// - **Adaptive State Management**: Advanced state handling with loading, error, empty, and no-results states
///
/// **Usage Examples:**
/// ```dart
/// // Navigate to shared content view
/// Navigator.of(context).push(
///   MaterialPageRoute(
///     builder: (context) => SharedWithMeView(),
///   ),
/// );
/// 
/// // The view provides comprehensive shared content functionality:
/// // - Organized content display with tabbed categorization for recipes and menus
/// // - Advanced search functionality with real-time filtering and content discovery
/// // - Social content management with friend attribution and interaction tracking
/// // - Complete state management with loading, error, empty, and no-results handling
/// // - Swedish localization with timeago formatting and cultural adaptation
/// 
/// // Integration with focused components:
/// // - SharedContentAppBar for navigation and title display
/// // - SharedContentSearchBar for search functionality and filtering
/// // - SharedContentTabBar for content categorization and tab coordination
/// // - SharedContentLists for content display and interaction management
/// ```

// lib/views/social/shared_with_me_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/viewmodels/shared_content_viewmodel.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';

import 'package:butlery/widgets/common/state_widget.dart';

// Import focused components
import 'package:butlery/views/social/shared_with_me/shared_content_app_bar.dart';
import 'package:butlery/views/social/shared_with_me/shared_content_search_bar.dart';
import 'package:butlery/views/social/shared_with_me/shared_content_tab_bar.dart';
import 'package:butlery/views/social/shared_with_me/shared_content_lists.dart';

/// Comprehensive shared content view providing organized display of friend-shared recipes and menus through advanced content architecture.
///
/// Manages complete shared content interface enabling content display, search functionality, categorization,
/// and comprehensive content interaction while maintaining clean separation between UI presentation
/// and business logic through SharedContentViewModel integration and specialized component architecture.
///
/// **Core Responsibilities:**
/// - Advanced content organization with tabbed categorization, comprehensive display, and structured content management
/// - Search and filter coordination with real-time filtering, content discovery, and comprehensive search functionality
/// - Social content management with friend attribution, interaction tracking, and comprehensive social integration
/// - State management integration with loading, error, empty, and no-results state coordination and user feedback
/// - Swedish localized content experience with timeago formatting, cultural adaptation, and comprehensive localization
class SharedWithMeView extends StatelessWidget {
  /// Creates comprehensive shared content view with organized display and search coordination.
  /// 
  /// Establishes shared content interface with content organization, search functionality,
  /// and comprehensive content interaction through SharedContentViewModel integration
  /// and advanced content architecture with focused component coordination.
  const SharedWithMeView({super.key});

  /// Comprehensive shared content interface construction with ViewModel integration and component coordination.
  /// 
  /// [context] Build context for theme access and component construction coordination
  /// 
  /// Constructs complete shared content interface featuring content organization, search functionality,
  /// and comprehensive content interaction through SharedContentViewModel integration
  /// with service locator dependency injection and specialized content coordination.
  /// 
  /// **Interface Architecture:**
  /// - SharedContentViewModel integration with service locator and dependency injection
  /// - Content organization with tabbed categorization and comprehensive display
  /// - Search functionality with real-time filtering and content discovery
  /// - Content delegation with specialized focused component architecture
  /// 
  /// Returns complete shared content interface with comprehensive functionality and content organization.
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SharedContentViewModel>(
      create: (context) => ServiceLocator.get<SharedContentViewModel>(),
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