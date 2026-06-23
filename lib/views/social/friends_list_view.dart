/// Friends and groups management view with multi-tab interface.

// lib/views/social/friends_list_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/widgets/common/social_components.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/widgets/common/search_filter_widget.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/widgets/common/indicators/circular_icon_badge.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/services/feature_flags/feature_flag_service.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/constants/routes.dart';

// Import focused components
import 'package:butlery/views/social/friends_list/friends_tab.dart';
import 'package:butlery/views/social/friends_list/requests_tab.dart';
import 'package:butlery/views/social/friends_list/search_tab.dart';
import 'package:butlery/views/social/friends_list/groups_tab.dart';
import 'package:butlery/views/social/friends_list/group_search_tab.dart';
import 'package:butlery/views/social/friends_list/feed_tab.dart';
import 'package:butlery/viewmodels/social/activity_feed_viewmodel.dart';

/// Friends and groups management view with tabs for friends, groups, and discovery.
class FriendsListView extends StatefulWidget {
  const FriendsListView({super.key});

  @override
  State<FriendsListView> createState() => _FriendsListViewState();
}

class _FriendsListViewState extends State<FriendsListView> {
  late final FriendsViewModel _vm;
  late final ActivityFeedViewModel _feedVm;

  @override
  void initState() {
    super.initState();
    _vm = ServiceLocator.get<FriendsViewModel>();
    _feedVm = ServiceLocator.get<ActivityFeedViewModel>();
    _feedVm.loadFeed();
    _fireSocialOnboardingIfFirstEntry();
  }

  /// BUT-1046: once-per-install funnel-entry signal. Fire-and-forget so the
  /// analytics path never blocks the friends view from rendering. The
  /// tracker no-ops on repeated entries via SharedPreferences dedupe.
  void _fireSocialOnboardingIfFirstEntry() {
    final userId = ServiceLocator.get<PermissionService>().currentUserId;
    if (userId == null) return;
    ServiceLocator.get<AnalyticsService>().social
        .logSocialOnboardingStartedIfFirstEntry(
          userId: userId,
          entryPoint: 'friends_tab',
        );
  }

  @override
  void dispose() {
    _vm.dispose();
    _feedVm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<FriendsViewModel>.value(value: _vm),
        ChangeNotifierProvider<ActivityFeedViewModel>.value(value: _feedVm),
        Provider.value(value: ServiceLocator.get<UnifiedFriendsService>()),
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
  late final bool _socialEnabled;
  int _currentTabIndex = 0;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _socialEnabled = ServiceLocator.get<FeatureFlagService>().isEnabled(
      FeatureFlags.enableSocialFeatures,
    );
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        if (mounted) {
          setState(() {
            _currentTabIndex = _tabController.index;
            // Clear search synchronously on tab switch to avoid stale query flash
            _searchQuery = '';
          });
          context.read<FriendsViewModel>().updateSearch('');
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null && args['tabIndex'] != null) {
        final tabIndex = args['tabIndex'] as int;
        if (tabIndex >= 0 && tabIndex < 4) {
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
    if (!_socialEnabled) {
      return LayoutComponents.mainMenu(
        currentIndex: null,
        title: context.l10n.socialFriendsAndGroups,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingXl),
            child: Text(
              'Sociala funktioner är tillfälligt inaktiverade.',
              style: AppTextStyles.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Consumer<FriendsViewModel>(
      builder: (context, viewModel, child) {
        final friendsService = context.read<UnifiedFriendsService>();
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
          title: context.l10n.socialFriendsAndGroups,
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
                    LayoutComponents.offlineIndicator(),
                    // TabBar with proper styling and badge counts
                    ColoredBox(
                      color: Theme.of(context).colorScheme.surface,
                      child: TabBar(
                        controller: _tabController,
                        isScrollable: false,
                        tabAlignment: TabAlignment.fill,
                        labelColor: Theme.of(context).colorScheme.primary,
                        unselectedLabelColor: Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant,
                        indicatorColor: Theme.of(context).colorScheme.primary,
                        indicatorWeight: AppDimensions.borderWidthThick,
                        tabs: [
                          Tab(
                            icon: const Icon(Icons.dynamic_feed),
                            text: context.l10n.socialFeed,
                          ),
                          Tab(
                            icon: const Icon(Icons.people),
                            text: context.l10n.socialFriends,
                          ),
                          Tab(
                            icon: Badge(
                              isLabelVisible: friendsService
                                  .invitations
                                  .pendingReceivedInvitations
                                  .isNotEmpty,
                              label: Text(
                                '${friendsService.invitations.pendingReceivedInvitations.length}',
                              ),
                              child: const Icon(Icons.groups),
                            ),
                            text: context.l10n.socialGroups,
                          ),
                          Tab(
                            icon: Badge(
                              isLabelVisible:
                                  viewModel.incomingRequests.isNotEmpty,
                              label: Text(
                                '${viewModel.incomingRequests.length}',
                              ),
                              child: const Icon(Icons.search),
                            ),
                            text: context.l10n.socialFindFriends,
                          ),
                        ],
                      ),
                    ),
                    // Error display
                    if (viewModel.hasError) ...[
                      const SizedBox(height: AppDimensions.spacingL),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.paddingL,
                        ),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppDimensions.paddingL),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.error
                                .withValues(
                                  alpha: AppDimensions.opacityVeryLight,
                                ),
                            borderRadius: BorderRadius.circular(
                              AppDimensions.borderRadiusM,
                            ),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.error
                                  .withValues(
                                    alpha: AppDimensions.opacityMediumLight,
                                  ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Theme.of(context).colorScheme.error,
                              ),
                              const SizedBox(width: AppDimensions.spacingS),
                              Expanded(
                                child: Text(
                                  viewModel.error!,
                                  style: AppTextStyles.bodyMediumError,
                                ),
                              ),
                              ActionButtons.secondaryButton(
                                context,
                                label: context.l10n.commonClose,
                                onPressed: viewModel.clearError,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacingL),
                    ],

                    // Search functionality for groups and friend discovery tabs
                    if (_currentTabIndex == 2)
                      SearchFilterWidget.searchOnly(
                        searchQuery: _searchQuery,
                        onSearchChanged: _onSearchChanged,
                        searchHint: context.l10n.socialSearchGroups,
                        autofocus: false,
                        padding: const EdgeInsets.all(AppDimensions.spacingL),
                        showStats: true,
                        resultCount: viewModel.searchResults.length,
                      ),
                    if (_currentTabIndex == 3)
                      SearchFilterWidget.searchOnly(
                        searchQuery: _searchQuery,
                        onSearchChanged: _onSearchChanged,
                        searchHint: context.l10n.socialSearchNewFriends,
                        autofocus: false,
                        padding: const EdgeInsets.all(AppDimensions.spacingL),
                        showStats: true,
                        resultCount: viewModel.searchResults.length,
                      ),

                    // Tab content — only build the active tab
                    Expanded(
                      child: switch (_currentTabIndex) {
                        0 => FeedTab.build(
                          context,
                          context.watch<ActivityFeedViewModel>(),
                          hasFriends: viewModel.friendsCount > 0,
                          onAddFriendsCta: () => _tabController.animateTo(1),
                        ),
                        1 => _buildFriendsTab(viewModel),
                        2 => _buildGroupsTab(friendsService, viewModel),
                        3 => _buildDiscoveryTab(viewModel),
                        _ => const SizedBox.shrink(),
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          floatingActionButton: _buildFloatingActionButton(viewModel),
        );
      },
    );
  }

  /// BUT-1357: primary-action FAB resolves per selected tab.
  /// - Friends tab (1): "Add friend" — reuses the EXISTING add-friend entry
  ///   point (the Find Friends tab at index 3, same target as the friends-tab
  ///   empty-state `onFindByUsername` CTA). No new flow is introduced.
  /// - Groups tab (2): create-group FAB, unchanged.
  /// Feed (0) and Find Friends (3) tabs have no FAB — Find Friends already
  /// carries its own primary action (the search field).
  /// FAB squareness comes from the global FloatingActionButtonThemeData
  /// (BUT-964 square design language); no per-widget shape override needed.
  Widget? _buildFloatingActionButton(FriendsViewModel viewModel) {
    switch (_currentTabIndex) {
      case 1:
        return Semantics(
          label: context.l10n.a11yAddFriend,
          button: true,
          child: FloatingActionButton(
            onPressed: () => _tabController.animateTo(3),
            tooltip: context.l10n.socialAddFriend,
            child: const Icon(
              Icons.person_add_alt_1,
              size: AppDimensions.iconSizeL,
            ),
          ),
        );
      case 2:
        return Semantics(
          label: context.l10n.groupCreateGroup,
          button: true,
          child: FloatingActionButton(
            onPressed: () => _showCreateGroupDialog(viewModel),
            tooltip: context.l10n.groupCreateGroup,
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
          ),
        );
      default:
        return null;
    }
  }

  Widget _buildFriendsTab(FriendsViewModel viewModel) {
    // Clean friends tab - existing friends only, no search.
    // BUT-975: the empty-state "find by username" CTA jumps to the Find
    // Friends tab (index 3).
    return FriendsTab.build(
      context,
      viewModel,
      onFindByUsername: () => _tabController.animateTo(3),
    );
  }

  Widget _buildDiscoveryTab(FriendsViewModel viewModel) {
    // Friend discovery hub with search and requests
    return _searchQuery.isEmpty
        ? const RequestsTab()
        : SearchTab.build(
            context,
            viewModel,
            _searchQuery,
            isGroupsSearch: false,
          );
  }

  Widget _buildGroupsTab(
    UnifiedFriendsService friendsService,
    FriendsViewModel viewModel,
  ) {
    // Groups tab with search functionality
    return _searchQuery.isEmpty
        ? GroupsTab.build(
            context,
            friendsService,
            onCreateGroup: () => _showCreateGroupDialog(viewModel),
          )
        : GroupSearchTab.build(context, friendsService, _searchQuery);
  }

  Future<void> _showCreateGroupDialog(FriendsViewModel viewModel) async {
    try {
      final createdGroup = await SocialGroupComponents.showCreateGroupDialog(
        context: context,
      );

      if (createdGroup != null && mounted) {
        SnackBarUtils.showSuccess(context, context.l10n.groupCreatedSuccess);
        if (mounted) {
          Navigator.pushNamed(
            context,
            Routes.groupDetail,
            arguments: createdGroup.id,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(
          context,
          context.l10n.groupCouldNotCreate('$e'),
        );
      }
    }
  }
}
