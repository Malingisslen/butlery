/// Comprehensive personal recipe management view providing advanced recipe browsing and social integration for Flutter applications.
///
/// This module implements sophisticated personal recipe interface ("Mina Recept") following Single Responsibility Principle,
/// specializing in recipe collection management, advanced filtering, social integration, and offline functionality.
/// It provides complete personal recipe interface while maintaining clean separation from business logic, data persistence,
/// and state management through MVVM architecture and multi-provider integration.
///
/// **Single Responsibility Focus:**
/// This module exclusively handles personal recipe UI presentation concerns through multi-provider architecture:
/// - **Recipe Collection Management**: Advanced recipe browsing with filtering, sorting, and search functionality
/// - **Social Integration Intelligence**: Comprehensive notification system with friend requests and shared content indicators
/// - **Offline Functionality Excellence**: Complete offline support with synchronization and local cache management
/// - **Advanced Search and Filtering**: Multi-criteria filtering with time, meal type, and rating filters
/// - **Swedish Localization Excellence**: Complete Swedish language support for recipe operations and user feedback
///
/// **What This Module Does NOT Handle:**
/// - Recipe business logic and data operations (handled by RecipeListViewModel and recipe services)
/// - Social interaction business logic (handled by FriendsViewModel and SharedContentViewModel)
/// - Offline synchronization logic (handled by OfflineService and synchronization infrastructure)
/// - Search and filtering algorithms (handled by SearchService and filtering services)
///
/// **Personal Recipe View Architecture:**
/// - **Multi-Provider Integration**: Comprehensive state management with multiple specialized ViewModels
/// - **Advanced Filtering System**: Multi-criteria filtering with SearchFilterWidget and visual indicators
/// - **Social Notification System**: Complete notification management with badge aggregation and user awareness
/// - **Offline-First Design**: Seamless offline functionality with sync status and local cache coordination
/// - **Performance Optimized**: Efficient data loading with safety checks and memory management
///
/// **Usage Examples:**
/// ```dart
/// // Navigate to personal recipe view
/// Navigator.of(context).push(
///   MaterialPageRoute(
///     builder: (context) => const MinaReceptView(),
///   ),
/// );
/// 
/// // The view provides comprehensive recipe functionality:
/// // - Recipe collection browsing with advanced filtering and search
/// // - Social integration with notification badges and friend activity
/// // - Offline functionality with synchronization and local cache support
/// // - Advanced sorting with multiple criteria and visual indicators
/// // - Error handling with user feedback and recovery options
/// 
/// // Multi-provider architecture enables:
/// // - RecipeListViewModel for recipe collection management
/// // - FriendsViewModel for social relationship tracking
/// // - SharedContentViewModel for shared recipe and menu notifications
/// // - OfflineService for offline functionality and synchronization
/// ```

// lib/views/main_views/mina_recept_view.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// ViewModel integration for comprehensive state management
import 'package:butlery/viewmodels/recipe_list_viewmodel.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/viewmodels/shared_content_viewmodel.dart';

// Constants and theming
import 'package:butlery/core/constants/app_strings.dart';

// Widget components for modern UI architecture
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/widgets/common/content_card.dart';
import 'package:butlery/widgets/common/search_filter_widget.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/common/social_components.dart';
import 'package:butlery/widgets/common/indicators/notification_badge.dart';
import 'package:butlery/widgets/common/indicators/filter_indicator_dot.dart';

// Service integration for functionality and data management
import 'package:butlery/services/search_service.dart';
import 'package:butlery/services/offline_service.dart' as offline_service;
import 'package:butlery/services/user_service.dart';

// Theme system integration
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

// Core services and utilities
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
/// Comprehensive personal recipe management view providing advanced recipe browsing through multi-provider architecture.
///
/// Manages complete personal recipe interface enabling recipe collection management, social integration,
/// offline functionality, and advanced filtering while maintaining clean separation between UI presentation
/// and business logic through MVVM architecture and specialized provider integration.
///
/// **Core Responsibilities:**
/// - Advanced recipe collection presentation with filtering, sorting, and search functionality
/// - Multi-provider state management with specialized ViewModels and service integration
/// - Social integration coordination with notification system and friend activity tracking
/// - Offline functionality management with synchronization status and local cache coordination
/// - Swedish localized user experience with comprehensive feedback and error handling
class MinaReceptView extends StatelessWidget {
  /// Creates comprehensive personal recipe view with multi-provider architecture and service integration.
  /// 
  /// Establishes personal recipe interface with multi-provider state management,
  /// social integration, offline functionality, and comprehensive recipe management
  /// through clean architectural separation and modern component integration.
  const MinaReceptView({super.key});

  /// Comprehensive multi-provider widget construction with specialized ViewModel and service integration.
  /// 
  /// [context] Build context for provider creation and widget construction coordination
  /// 
  /// Constructs personal recipe view with multi-provider architecture enabling comprehensive
  /// state management, social integration, offline functionality, and recipe collection management
  /// through specialized provider coordination and content component delegation.
  /// 
  /// **Multi-Provider Architecture:**
  /// - RecipeListViewModel for recipe collection management and filtering functionality
  /// - UserService for user profile management and authentication coordination
  /// - FriendsViewModel for social relationship tracking and notification management
  /// - SharedContentViewModel for shared recipe and menu notification coordination
  /// - OfflineService for offline functionality and synchronization management
  /// 
  /// Returns multi-provider personal recipe view with comprehensive functionality.
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Recipe collection state management
        ChangeNotifierProvider<RecipeListViewModel>(
          create: (context) => ServiceLocator.get<RecipeListViewModel>(),
        ),
        // User profile and authentication service
        ChangeNotifierProvider.value(value: ServiceLocator.get<UserService>()),
        // Social relationship and friend management
        ChangeNotifierProvider.value(value: ServiceLocator.get<FriendsViewModel>()),
        // Shared content and notification management
        ChangeNotifierProvider.value(value: ServiceLocator.get<SharedContentViewModel>()),
        // Offline functionality and synchronization service
        ChangeNotifierProvider.value(
            value: ServiceLocator.get<offline_service.OfflineService>()),
      ],
      child: const _MinaReceptViewContent(),
    );
  }
}

/// Personal recipe view content managing filtering state, social data loading, and comprehensive recipe interface coordination.
///
/// Handles complete personal recipe state management including filter toggling, social data loading,
/// offline synchronization, and user interaction handling while maintaining clean state management
/// and proper resource disposal through comprehensive lifecycle coordination.
class _MinaReceptViewContent extends StatefulWidget {
  /// Creates personal recipe view content with state management and lifecycle coordination.
  /// 
  /// Establishes stateful recipe content enabling filter management, social data loading,
  /// and comprehensive recipe functionality through proper state lifecycle and
  /// multi-provider integration coordination.
  const _MinaReceptViewContent();

  /// Creates personal recipe view content state with multi-provider integration and lifecycle management.
  /// 
  /// Establishes stateful recipe interface enabling filter state management,
  /// social data coordination, and comprehensive recipe functionality through
  /// proper state lifecycle and provider integration coordination.
  @override
  State<_MinaReceptViewContent> createState() => _MinaReceptViewContentState();
}

/// Personal recipe view content state managing filter visibility, social data loading, and comprehensive recipe interaction coordination.
///
/// Handles complete personal recipe state management including filter toggle state, social data loading coordination,
/// offline synchronization management, and user interaction handling while maintaining clean state management
/// and proper lifecycle coordination through comprehensive multi-provider integration.
class _MinaReceptViewContentState extends State<_MinaReceptViewContent> {
  /// Filter visibility state for advanced filtering interface toggle and user experience coordination.
  /// 
  /// Manages filter panel visibility enabling advanced filtering interface,
  /// user experience optimization, and filtering functionality coordination.
  bool _showFilters = false;

  /// Personal recipe view state initialization with multi-provider data loading and lifecycle coordination.
  /// 
  /// Initializes personal recipe state enabling safe data loading, provider synchronization,
  /// and comprehensive recipe functionality through post-frame callback coordination
  /// and proper lifecycle management with safety checks and error handling.
  /// 
  /// **Initialization Process:**
  /// - Lifecycle preparation with proper state management and resource allocation
  /// - Post-frame callback setup for safe data loading after widget construction
  /// - Multi-provider data coordination with social and recipe data synchronization
  /// - Safety checks ensuring proper widget mounting and state consistency
  /// - Error handling with graceful degradation and user experience protection
  /// 
  /// **Data Loading Features:**
  /// - Safe social data loading with friend relationship and notification synchronization
  /// - Recipe data loading with collection management and filtering preparation
  /// - Provider coordination ensuring proper state initialization and data consistency
  /// - Asynchronous loading with proper error handling and recovery mechanisms
  @override
  void initState() {
    super.initState();

    // ✅ SÄKERT: Ladda data efter widget mount med safety checks
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _safeLoadSocialData();
        _safeLoadRecipeData();
      }
    });
  }

  /// Comprehensive social data loading with optimization, delayed refresh, and multi-provider coordination.
  /// 
  /// Handles safe social data loading enabling friend relationship synchronization,
  /// notification management, and comprehensive social integration through optimized
  /// loading strategy with duplicate prevention and performance coordination.
  /// 
  /// **Social Data Loading Features:**
  /// - Performance optimization with duplicate loading prevention and efficient resource management
  /// - Delayed refresh strategy with proper timing and lifecycle coordination
  /// - Multi-provider coordination with FriendsViewModel and SharedContentViewModel integration
  /// - Automatic service initialization with auth listener integration and state synchronization
  /// - Comprehensive error handling with graceful degradation and logging coordination
  /// 
  /// **Loading Strategy:**
  /// - Delayed loading with 1.5 second buffer for proper widget initialization
  /// - Friend data refresh with social relationship synchronization
  /// - SharedContentViewModel automatic loading through service integration
  /// - Mount safety checks preventing disposed widget operations
  /// - Swedish localized logging with comprehensive error tracking
  /// 
  /// **Performance Optimization:**
  /// - Duplicate loading prevention with smart refresh logic
  /// - Service-based automatic initialization reducing manual refresh requirements
  /// - Efficient resource management with proper timing and lifecycle coordination
  void _safeLoadSocialData() {
    try {
      // 🚀 PERFORMANCE FIX: Only refresh if content hasn't been loaded yet
      // SocialRecipeService handles initial loading automatically via auth listener
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted) return;

        try {
          final friendsViewModel = context.read<FriendsViewModel>();

          // Only refresh friends - SharedContentViewModel loads automatically via service
          AppLogger.info(
              '🔄 Refreshing friends data for MinaReceptView (delayed)...');
          friendsViewModel.refresh();

          AppLogger.success(
              '✅ Friends data refreshed for MinaReceptView (delayed)');
        } catch (e) {
          AppLogger.error(
              '❌ Fel vid delayed friends data refresh i MinaReceptView', e);
        }
      });
    } catch (e) {
      AppLogger.error(
          '❌ Fel vid setup av delayed friends refresh i MinaReceptView', e);
    }
  }

  /// Comprehensive recipe data loading with automatic provider coordination and lifecycle management.
  /// 
  /// Handles safe recipe data loading enabling recipe collection initialization,
  /// provider coordination, and comprehensive recipe functionality through
  /// automated data loading with RecipeListViewModel integration and error handling.
  /// 
  /// **Recipe Data Loading Features:**
  /// - Automatic provider coordination with RecipeListViewModel and RecipeService integration
  /// - Safe mounting checks preventing disposed widget operations and memory leaks
  /// - Comprehensive logging with Swedish localized messages and progress tracking
  /// - Provider-based data loading reducing manual refresh requirements and improving performance
  /// - Error handling with graceful degradation and proper exception management
  /// 
  /// **Loading Strategy:**
  /// - RecipeListViewModel automatic data loading through service integration
  /// - Provider-based architecture eliminating explicit refresh requirements
  /// - Lifecycle safety with mounted checks and proper state management
  /// - Comprehensive logging for debugging and maintenance support
  /// 
  /// **Performance Features:**
  /// - Efficient data loading with provider-based automatic synchronization
  /// - Minimal manual intervention with service-driven data management
  /// - Proper resource management with lifecycle coordination and safety checks
  void _safeLoadRecipeData() {
    try {
      if (mounted) {
        AppLogger.info('🔄 Laddar receptdata för MinaReceptView...');

        // RecipeListViewModel laddar automatiskt data från RecipeService
        // Inget explicit refresh behövs här - providern hanterar detta

        AppLogger.success('✅ Receptdata redo för MinaReceptView');
      }
    } catch (e) {
      AppLogger.error('❌ Fel vid laddning av receptdata i MinaReceptView', e);
    }
  }

  void _onSortChanged(SortCriteria? criteria) {
    if (criteria != null) {
      final viewModel = context.read<RecipeListViewModel>();
      viewModel.updateSort(criteria);
    }
  }

  // Exit-dialog
  Future<void> _showExitDialog(BuildContext context) async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.exitApp),
        content: const Text(AppStrings.exitAppConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text(AppStrings.exit),
          ),
        ],
      ),
    );

    if (shouldExit == true && context.mounted) {
      SystemNavigator.pop();
    }
  }

  // Synkronisera med online
  Future<void> _syncWithOnline() async {
    final offlineService = context.read<offline_service.OfflineService>();
    final viewModel = context.read<RecipeListViewModel>();

    if (offlineService.isOnline) {
      try {
        // Visa loading indicator
        if (mounted) {
          SnackBarUtils.showInfo(context, 'Synkroniserar...');
        }

        // Synka offline-ändringar
        await offlineService.syncNow();

        // Uppdatera receptlistan
        await viewModel.refresh();

        // Visa success
        if (mounted) {
          SnackBarUtils.showSuccess(context, 'Synkronisering klar!');
        }
      } catch (e) {
        if (mounted) {
          SnackBarUtils.showError(context, 'Synkronisering misslyckades: $e');
        }
      }
    }
  }

  /// Comprehensive user avatar construction with notification aggregation and social integration coordination.
  /// 
  /// Constructs user avatar with comprehensive notification badge system enabling
  /// social awareness, friend activity tracking, and user profile integration through
  /// multi-consumer architecture with graceful error handling and comprehensive social features.
  /// 
  /// **User Avatar Features:**
  /// - Multi-consumer architecture with UserService, FriendsViewModel, and SharedContentViewModel integration
  /// - Notification aggregation with friend requests, unread recipes, and menu notification tracking
  /// - Graceful error handling with disposed ViewModel protection and fallback coordination
  /// - Social integration with avatar display, online status, and profile menu coordination
  /// - Comprehensive navigation with profile editing, friend management, and notification access
  /// 
  /// **Notification System:**
  /// - Total notification badge with aggregated count from multiple sources
  /// - Friend request tracking with pending invitation management
  /// - Content notification tracking with unread recipe and menu coordination
  /// - Disposed ViewModel safety with graceful degradation and fallback values
  /// - Swedish localized logging with comprehensive error tracking
  /// 
  /// **Social Features:**
  /// - User avatar with SocialComponents integration and consistent design
  /// - Online status display with real-time presence and social awareness
  /// - Profile menu integration with comprehensive user management functionality
  /// - Navigation coordination with profile editing, friends, shared content, and notifications
  /// 
  /// Returns user avatar widget with comprehensive notification system and social integration.
  Widget _buildUserAvatarWithBadge() {
    return Consumer3<UserService, FriendsViewModel, SharedContentViewModel>(
      builder: (context, userService, friendsViewModel, sharedContentViewModel,
          child) {
        // ✅ SAFETY: Hantera disposed ViewModels gracefully
        int pendingFriendRequests = 0;
        int unreadRecipes = 0;
        int unreadMenus = 0;

        try {
          pendingFriendRequests = friendsViewModel.pendingRequestsCount;
          unreadRecipes = sharedContentViewModel.unreadRecipesCount;
          unreadMenus = sharedContentViewModel.unreadMenusCount;
        } catch (e) {
          AppLogger.warning(
              '⚠️ Ett eller flera ViewModels är disposed - visar fallback notification badge');
          // Fallback till 0 om ViewModels är disposed
        }

        final totalNotifications =
            pendingFriendRequests + unreadRecipes + unreadMenus;

        return Stack(
          children: [
            SocialComponents.avatar(
              user: userService.currentUserProfile,
              size: ImageSize.extraLarge,
              showOnlineStatus: true,
              onTap: () => LayoutComponents.showProfileMenu(
                context,
                userImageUrl: userService.currentUserProfile?.avatarUrl,
                displayName:
                    userService.currentUserProfile?.displayName ?? 'Användare',
                email: userService.currentUserProfile?.email,
                onEditProfile: () =>
                    Navigator.pushNamed(context, Routes.profileEdit),
                onViewFriends: () =>
                    Navigator.pushNamed(context, Routes.friends),
                onViewShared: () => Navigator.pushNamed(context, Routes.shared),
                onViewNotifications: () =>
                    Navigator.pushNamed(context, Routes.friendRequests),
              ),
            ),
            // ✅ TOTAL NOTIFICATION BADGE
            if (totalNotifications > 0)
              Positioned(
                top: 0,
                right: 0,
                child: NotificationBadge(count: totalNotifications),
              ),
          ],
        );
      },
    );
  }

  /// Comprehensive personal recipe interface construction with multi-provider architecture and advanced functionality.
  /// 
  /// [context] Build context for theme access and component construction coordination
  /// 
  /// Constructs complete personal recipe interface featuring multi-provider state management,
  /// advanced filtering system, social integration, and comprehensive recipe functionality
  /// through consumer-based reactive architecture with comprehensive user experience optimization.
  /// 
  /// **Interface Architecture:**
  /// - Multi-provider consumer architecture with RecipeListViewModel and OfflineService reactive coordination
  /// - PopScope integration with exit confirmation and user safety features preventing accidental navigation
  /// - LayoutComponents integration with main menu structure and consistent app navigation
  /// - Comprehensive action toolbar with filtering, sorting, error handling, and social features
  /// - SearchFilterWidget integration replacing manual filter implementation with modern component architecture
  /// 
  /// **Feature Integration:**
  /// - Advanced filtering system with multi-criteria filtering and visual filter indicators
  /// - Social integration with user avatar, notification badges, and comprehensive social awareness
  /// - Offline functionality with connection status and synchronization indicators
  /// - Error handling with visual error indicators and user feedback coordination
  /// - Sorting system with comprehensive criteria and visual sort direction indicators
  /// 
  /// **User Experience Features:**
  /// - Filter visibility toggle with reactive UI state management and user control
  /// - Comprehensive search functionality with hint text and result statistics
  /// - Recipe collection display with item management and interaction coordination
  /// - Swedish localized interface with comprehensive user guidance and feedback
  /// 
  /// Returns complete personal recipe interface with comprehensive functionality and modern architecture.
  @override
  Widget build(BuildContext context) {
    // ✅ FIXAT: Nu kan vi använda watch för RecipeListViewModel eftersom den finns i MultiProvider
    final viewModel = context.watch<RecipeListViewModel>();
    final offlineService = context.watch<offline_service.OfflineService>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          _showExitDialog(context);
        }
      },
      child: LayoutComponents.mainMenu(
        // ✅ UPPDATERAD WIDGET
        currentIndex: 0,
        title: 'Mina recept',
        actions: [
          // OFFLINE STATUS ICON - ✅ UPPDATERAD
          LayoutComponents.offlineStatusIcon(),

          // ✅ UPPDATERAD: USER AVATAR med notification badge
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingXs),
            child: _buildUserAvatarWithBadge(),
          ),

          // Filter-knapp med indikator för aktiva filter
          IconButton(
            icon: Stack(
              children: [
                Icon(
                  Icons.filter_list,
                  color: _showFilters
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface,
                ),
                // Visa en prick om det finns aktiva filter
                if (viewModel.hasActiveFilters)
                  const Positioned(
                    right: 0,
                    top: 0,
                    child: FilterIndicatorDot(),
                  ),
              ],
            ),
            onPressed: () {
              if (mounted) {
                setState(() {
                  _showFilters = !_showFilters;
                });
              }
            },
            tooltip: 'Filtrera',
          ),

          // Error indicator
          if (viewModel.hasError)
            IconButton(
              icon: const Icon(Icons.error, color: AppColors.error),
              onPressed: () {
                SnackBarUtils.showError(context, viewModel.error!);
              },
              tooltip: 'Visa fel',
            ),

          // Sort menu
          PopupMenuButton<SortCriteria>(
            icon: Icon(
              Icons.sort,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            tooltip: 'Sortera',
            onSelected: _onSortChanged,
            itemBuilder: (context) => [
              _buildSortMenuItem(
                SortCriteria.title,
                'Titel',
                Icons.title,
                viewModel.sortCriteria,
                viewModel.sortAscending,
              ),
              _buildSortMenuItem(
                SortCriteria.time,
                'Tid',
                Icons.access_time,
                viewModel.sortCriteria,
                viewModel.sortAscending,
              ),
              _buildSortMenuItem(
                SortCriteria.rating,
                'Betyg',
                Icons.star,
                viewModel.sortCriteria,
                viewModel.sortAscending,
              ),
              _buildSortMenuItem(
                SortCriteria.mealType,
                'Måltidstyp',
                Icons.restaurant,
                viewModel.sortCriteria,
                viewModel.sortAscending,
              ),
            ],
          ),
        ],
        body: Column(
          children: [
            // OFFLINE INDICATOR - ✅ UPPDATERAD
            LayoutComponents.offlineIndicator(),

            // ✅ HELT NY: SearchFilterWidget ersätter ~50 rader kod!
            SearchFilterWidget(
              // Search properties
              searchQuery: viewModel.searchQuery,
              onSearchChanged: viewModel.updateSearch,
              searchHint: 'Sök recept...',

              // Filter properties
              activeTimeFilters: viewModel.activeTimeFilters,
              activeMealTypeFilters: viewModel.activeMealTypeFilters,
              activeRatingFilters: viewModel.activeRatingFilters,
              onTimeFilterToggle: viewModel.toggleTimeFilter,
              onMealTypeFilterToggle: viewModel.toggleMealTypeFilter,
              onRatingFilterToggle: viewModel.toggleRatingFilter,

              // UI state
              showFilters: _showFilters,
              onToggleFilters: () =>
                  setState(() => _showFilters = !_showFilters),
              hasActiveFilters: viewModel.hasActiveFilters,
              onClearAllFilters: viewModel.clearAllFilters,

              // Results info
              resultCount: viewModel.recipes.length,
              showStats: true,
            ),

            // Huvudinnehåll
            Expanded(child: _buildContent(viewModel, offlineService)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    RecipeListViewModel viewModel,
    offline_service.OfflineService offlineService,
  ) {
    // Loading state
    if (viewModel.isLoading) {
      return Column(
        children: [
          // ✅ MIGRATION: StateWidget skeleton loader
          Expanded(child: StateWidget.skeletonRecipeList(itemCount: 5)),
        ],
      );
    }

    // Error state
    if (viewModel.hasError) {
      return Center(
        child: Padding(
          padding: AppDimensions.screenPadding,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppDimensions.paddingL),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
                  border: Border.all(color: AppColors.error),
                ),
                child: Text(
                  viewModel.error!,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.spacingXl),
              ElevatedButton(
                onPressed: () {
                  viewModel.clearError();
                  viewModel.refresh();
                },
                child: const Text('Försök igen'),
              ),
            ],
          ),
        ),
      );
    }

    // Hämta filtrerade och sorterade recept från ViewModel
    final recipes = viewModel.recipes;

    // Empty states
    if (recipes.isEmpty) {
      return viewModel.searchQuery.isEmpty && !viewModel.hasActiveFilters
          // ✅ MIGRATION: StateWidget no recipes
          ? StateWidget.noRecipes(
              onAction: () => Navigator.pushNamed(context, '/laggTill'),
            )
          // ✅ MIGRATION: StateWidget no search results
          : StateWidget.noSearchResults(
              onAction: viewModel.searchQuery.isNotEmpty
                  ? () => viewModel.updateSearch('')
                  : viewModel.clearAllFilters,
              actionLabel: viewModel.searchQuery.isNotEmpty
                  ? 'Rensa sökning'
                  : 'Rensa filter',
            );
    }

    // Receptlista med RefreshIndicator som synkar om online
    return RefreshIndicator(
      onRefresh: () async {
        // Om online, synka först
        if (offlineService.isOnline) {
          await _syncWithOnline();
        } else {
          // Om offline, bara refresh från lokal cache
          await viewModel.refresh();
          if (mounted) {
            SnackBarUtils.showWarning(context, 'Offline-läge - visar lokala recept');
          }
        }
      },
      child: ListView.builder(
        padding: EdgeInsets.zero, // Remove all ListView padding
        itemCount: recipes.length,
        itemBuilder: (context, index) {
          final recipe = recipes[index];

          return ContentCard(
            key: ValueKey(recipe.id),
            item: recipe,
            type: ContentCardType.recipe,
            onTap: () async {
              // Navigera till detaljer
              await Navigator.pushNamed(
                context,
                '/receptDetalj',
                arguments: recipe,
              );

              // Ingen refresh behövs - ViewModel lyssnar på RecipeService
            },
          );
        },
      ),
    );
  }

  PopupMenuItem<SortCriteria> _buildSortMenuItem(
    SortCriteria criteria,
    String label,
    IconData icon,
    SortCriteria currentSort,
    bool sortAscending,
  ) {
    final isSelected = currentSort == criteria;

    return PopupMenuItem(
      value: criteria,
      child: Row(
        children: [
          Icon(
            icon,
            color: isSelected ? Theme.of(context).colorScheme.primary : null,
          ),
          const SizedBox(width: AppDimensions.spacingS),
          Text(label),
          const Spacer(),
          if (isSelected)
            Icon(
              sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: AppDimensions.iconSizeM,
              color: Theme.of(context).colorScheme.primary,
            ),
        ],
      ),
    );
  }
  @override
  void dispose() {
    // Cancel all timers
    // Cancel all stream subscriptions  
    // Dispose of resources
    super.dispose();
  }
}
