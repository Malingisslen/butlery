/// Comprehensive friends and groups management view providing social relationship coordination for Flutter applications.
/// This module implements sophisticated social relationship management following Single Responsibility Principle,
/// specializing in friend management, group coordination, request handling, and comprehensive social interaction.
/// It provides complete social management interface while maintaining clean separation from business logic,
/// data persistence, and state management through FriendsViewModel integration and modern component architecture.
/// **Single Responsibility Focus:**
/// This module exclusively handles social relationship UI presentation concerns through comprehensive social architecture:
/// - **Friend Management Excellence**: Advanced friend display with search functionality and relationship status tracking
/// - **Group Coordination Intelligence**: Sophisticated group management with creation, search, and membership coordination
/// - **Request Handling System**: Comprehensive request management with incoming and outgoing request coordination
/// - **Search and Filter Coordination**: Advanced search functionality with friend and group discovery capabilities
/// - **Swedish Localization Excellence**: Complete Swedish language support for social operations and user feedback
/// **What This Module Does NOT Handle:**
/// - Friend relationship business logic and data operations (handled by FriendsViewModel and social services)
/// - Group creation and management logic (handled by UnifiedFriendsService and group infrastructure)
/// - Search algorithms and friend discovery (handled by search services and discovery infrastructure)
/// - Request processing and notification logic (handled by request services and notification systems)
/// **Friends List View Architecture:**
/// - **Multi-Tab Interface**: Advanced tab system with friends, groups, and requests coordination
/// - **Adaptive Search Integration**: Comprehensive search functionality with context-aware results and filtering
/// - **Real-Time Request Management**: Sophisticated request handling with badge notifications and status updates
/// - **Group Creation Workflow**: Complete group creation with member selection and invitation coordination
/// - **Social Action System**: Advanced social actions with friend removal, group management, and interaction controls
/// **Usage Examples:**
/// ```dart
/// // Navigate to friends list with specific tab
/// Navigator.of(context).push(
///   MaterialPageRoute(
///     builder: (context) => FriendsListView(),
///     settings: RouteSettings(
///       arguments: {'tabIndex': 1}, // Open groups tab
///     ),
///   ),
/// );
/// // The view provides comprehensive social management functionality:
/// // - Multi-tab interface with friends, groups, and requests coordination
/// // - Advanced search with friend and group discovery capabilities
/// // - Real-time request management with badge notifications and status updates
/// // - Group creation workflow with member selection and invitation coordination
/// // - Social actions including friend removal, group management, and interactions
/// // Integration with specialized components:
/// // - FriendsTab, GroupsTab, RequestsTab for tab-specific functionality
/// // - SearchTab and GroupSearchTab for search result display
/// // - SocialComponents for group creation and social action dialogs
/// // - SearchFilterWidget for unified search interface
/// ```

// lib/views/social/friends_list_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/widgets/common/social_components.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/widgets/common/search_filter_widget.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/widgets/common/indicators/circular_icon_badge.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';

// Import focused components
import 'package:butlery/views/social/friends_list/friends_tab.dart';
import 'package:butlery/views/social/friends_list/requests_tab.dart';
import 'package:butlery/views/social/friends_list/search_tab.dart';
import 'package:butlery/views/social/friends_list/groups_tab.dart';
import 'package:butlery/views/social/friends_list/group_search_tab.dart';

/// Comprehensive friends and groups management view providing social relationship coordination through advanced social architecture.
/// Manages complete social relationship interface enabling friend management, group coordination, request handling,
/// and comprehensive social interaction while maintaining clean separation between UI presentation
/// and business logic through FriendsViewModel integration and specialized component architecture.
/// **Core Responsibilities:**
/// - Advanced friend management with display, search, relationship status tracking, and social action coordination
/// - Group coordination with creation, search, membership management, and comprehensive group functionality
/// - Request handling with incoming and outgoing request management, badge notifications, and status coordination
/// - Search and filter coordination with friend discovery, group search, and comprehensive result management
/// - Swedish localized social experience with comprehensive user feedback and interactive guidance
class FriendsListView extends StatelessWidget {
  /// Creates comprehensive friends and groups management view with social coordination.
  /// Establishes social relationship interface with friend management, group coordination,
  /// and comprehensive social functionality through multi-provider integration
  /// and advanced social architecture with proper dependency injection.
  const FriendsListView({super.key});

  /// Comprehensive social management interface construction with multi-provider integration and dependency coordination.
  /// [context] Build context for theme access and component construction coordination
  /// Constructs complete social management interface featuring friend management, group coordination,
  /// and comprehensive social functionality through FriendsViewModel and UnifiedFriendsService integration
  /// with multi-provider architecture and specialized content coordination.
  /// **Interface Architecture:**
  /// - FriendsViewModel integration with friend management and request coordination
  /// - UnifiedFriendsService integration with group management and social operations
  /// - Multi-provider setup with service locator dependency injection
  /// - Content delegation with specialized component architecture
  /// Returns complete social management interface with comprehensive functionality and multi-provider coordination.
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: ServiceLocator.get<FriendsViewModel>()),
        ChangeNotifierProvider.value(value: ServiceLocator.get<UnifiedFriendsService>()),
      ],
      child: const _FriendsListViewContent(),
    );
  }
}

class _FriendsListViewContent extends StatefulWidget {
  const _FriendsListViewContent();

  @override
  State<_FriendsListViewContent> createState() =>
      _FriendsListViewContentState();
}

class _FriendsListViewContentState extends State<_FriendsListViewContent>
    with TickerProviderStateMixin {
  late TabController _tabController;
  int _currentTabIndex = 0;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        if (mounted) {
          setState(() {
            _currentTabIndex = _tabController.index;
          });
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null && args['tabIndex'] != null) {
        final tabIndex = args['tabIndex'] as int;
        if (tabIndex >= 0 && tabIndex < 3) {
          _tabController.animateTo(tabIndex);
          if (mounted) {
            setState(() {
              _currentTabIndex = tabIndex;
            });
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (mounted) {
      setState(() {
        _searchQuery = query;
      });
    }
    final viewModel = context.read<FriendsViewModel>();
    viewModel.updateSearch(query);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<FriendsViewModel, UnifiedFriendsService>(
      builder: (context, viewModel, friendsService, child) {
        // 🎯 UX ENHANCEMENT: Sync local search query with ViewModel
        // When ViewModel clears search (after friend request), clear UI search field
        if (viewModel.searchQuery.isEmpty && _searchQuery.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _searchQuery = '';
              });
            }
          });
        }

        return LayoutComponents.mainMenu(
          currentIndex: null,
          title: 'Vänner & Grupper',
          body: SafeArea(
            // ✅ RESPONSIVE: Center and constrain content on large screens
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: LayoutComponents.valueFor(
                    context: context,
                    mobile: double.infinity,
                    tablet: 700,
                    desktop: 800,
                  ),
                ),
                child: Column(
                  children: [
                    // TabBar with proper styling
                    ColoredBox(
                color: Theme.of(context).colorScheme.surface,
                child: TabBar(
                  controller: _tabController,
                  isScrollable: false, // Center the tabs
                  tabAlignment: TabAlignment.fill, // Fill available space
                  labelColor: Theme.of(context).colorScheme.primary,
                  unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
                  indicatorColor: Theme.of(context).colorScheme.primary,
                  indicatorWeight: AppDimensions.borderWidthThick,
                  tabs: [
                    const Tab(
                      icon: Icon(Icons.people),
                      text: 'Vänner',
                    ),
                    Tab(
                      icon: Badge(
                        isLabelVisible: friendsService.invitations.pendingReceivedInvitations.isNotEmpty,
                        label: Text('${friendsService.invitations.pendingReceivedInvitations.length}'),
                        child: const Icon(Icons.groups),
                      ),
                      text: 'Grupper',
                    ),
                    Tab(
                      icon: Badge(
                        isLabelVisible: viewModel.incomingRequests.isNotEmpty,
                        label: Text('${viewModel.incomingRequests.length}'),
                        child: const Icon(Icons.search),
                      ),
                      text: 'Hitta Vänner',
                    ),
                  ],
                ),
              ),
              // Error display
              if (viewModel.hasError) ...[
                const SizedBox(height: AppDimensions.spacingL),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingL),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppDimensions.paddingL),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.error),
                        const SizedBox(width: AppDimensions.spacingS),
                        Expanded(
                          child: Text(
                            viewModel.error!,
                            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
                          ),
                        ),
                        ActionButtons.secondaryButton(
                          context,
                          label: 'Stäng',
                          onPressed: viewModel.clearError,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingL),
              ],

              // Search functionality for groups and friend discovery tabs
              if (_currentTabIndex == 1)
                SearchFilterWidget.searchOnly(
                  searchQuery: _searchQuery,
                  onSearchChanged: _onSearchChanged,
                  searchHint: 'Sök efter grupper...',
                  autofocus: false,
                  padding: const EdgeInsets.all(AppDimensions.spacingL),
                  showStats: true,
                  resultCount: viewModel.searchResults.length,
                ),
              if (_currentTabIndex == 2)
                SearchFilterWidget.searchOnly(
                  searchQuery: _searchQuery,
                  onSearchChanged: _onSearchChanged,
                  searchHint: 'Sök efter nya vänner...',
                  autofocus: false,
                  padding: const EdgeInsets.all(AppDimensions.spacingL),
                  showStats: true,
                  resultCount: viewModel.searchResults.length,
                ),

              // Tab content
              Expanded(
                child: IndexedStack(
                  index: _currentTabIndex,
                  children: [
                    _buildFriendsTab(viewModel), // Vänner
                    _buildGroupsTab(friendsService), // Grupper (with search)
                    _buildDiscoveryTab(viewModel), // Hitta Vänner
                  ],
                ),
              ),
            ],
                ),
              ),
            ),
          ),
          floatingActionButton: _currentTabIndex == 1
              ? FloatingActionButton(
                  onPressed: () => _showCreateGroupDialog(viewModel),
                  child: const Stack(
                    children: [
                      Center(
                        child: Icon(
                          Icons.groups, 
                          size: AppDimensions.iconSizeL,
                        ),
                      ),
                      Positioned(
                        top: AppDimensions.spacingXs,
                        right: AppDimensions.spacingXs,
                        child: CircularIconBadge.add(),
                      ),
                    ],
                  ),
                )
              : null,
        );
      },
    );
  }

  Widget _buildFriendsTab(FriendsViewModel viewModel) {
    // Clean friends tab - existing friends only, no search
    return FriendsTab.build(context, viewModel);
  }

  Widget _buildDiscoveryTab(FriendsViewModel viewModel) {
    // Friend discovery hub with search and requests
    return _searchQuery.isEmpty 
        ? RequestsTab.build(context, viewModel)
        : SearchTab.build(context, viewModel, _searchQuery, isGroupsSearch: false);
  }

  Widget _buildGroupsTab(UnifiedFriendsService friendsService) {
    // Groups tab with search functionality
    return _searchQuery.isEmpty 
        ? GroupsTab.build(context, friendsService)
        : GroupSearchTab.build(context, friendsService, _searchQuery);
  }


  // ✅ UPPDATERAD: Använd SocialComponents.showCreateGroupDialog
  Future<void> _showCreateGroupDialog(FriendsViewModel viewModel) async {
    try {
      final result = await SocialComponents.showCreateGroupDialog(
        context: context,
      );

      // ✅ FIX: Dialog returns bool? - true on success, false/null on cancel
      // The transformation happens in social_group_components.dart: .then((result) => result != null)
      if (result == true && mounted) {
        SnackBarUtils.showSuccess(context, 'Gruppen skapades! 🎉');
        // ✅ FIX: Switch to groups tab (index 1) after successful creation
        if (mounted) {
          setState(() {
            _currentTabIndex = 1;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(context, 'Kunde inte skapa grupp: $e');
      }
    }
  }

}
