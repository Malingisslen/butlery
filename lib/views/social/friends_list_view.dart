/// Friends and groups management view with multi-tab interface.

// lib/views/social/friends_list_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/widgets/common/social_components.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/services/feature_flags/feature_flag_service.dart';

// Import focused components
import 'package:butlery/views/social/friends_list/friends_tab.dart';
import 'package:butlery/views/social/friends_list/requests_tab.dart';
import 'package:butlery/views/social/friends_list/search_tab.dart';
import 'package:butlery/views/social/friends_list/groups_tab.dart';
import 'package:butlery/views/social/friends_list/group_search_tab.dart';

/// Friends and groups management view with tabs for friends, groups, and discovery.
class FriendsListView extends StatefulWidget {
  const FriendsListView({super.key});

  @override
  State<FriendsListView> createState() => _FriendsListViewState();
}

class _FriendsListViewState extends State<FriendsListView> {
  late final FriendsViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = ServiceLocator.get<FriendsViewModel>();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<FriendsViewModel>.value(value: _vm),
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
    _socialEnabled = ServiceLocator.get<FeatureFlagService>()
        .isEnabled(FeatureFlags.enableSocialFeatures);
    _tabController = TabController(length: 3, vsync: this);
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

  // ignore: unused_element
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
                    // TabBar with proper styling
                    ColoredBox(
                      color: Theme.of(context).colorScheme.surface,
                      child: TabBar(
                        controller: _tabController,
                        isScrollable: false, // Center the tabs
                        tabAlignment: TabAlignment.fill, // Fill available space
                        labelColor: Theme.of(context).colorScheme.primary,
                        unselectedLabelColor:
                            Theme.of(context).colorScheme.onSurfaceVariant,
                        indicatorColor: Theme.of(context).colorScheme.primary,
                        indicatorWeight: AppDimensions.borderWidthThick,
                        tabs: [
                          Tab(
                            icon: const Icon(Icons.people),
                            text: context.l10n.socialFriends,
                          ),
                          Tab(
                            icon: const Icon(Icons.groups),
                            text: context.l10n.socialGroups,
                          ),
                          Tab(
                            icon: const Icon(Icons.search),
                            text: context.l10n.socialFindFriends,
                          ),
                        ],
                      ),
                    ),
                    // Tab content — only build the active tab
                    Expanded(
                      child: switch (_currentTabIndex) {
                        0 => _buildFriendsTab(viewModel),
                        1 => _buildGroupsTab(friendsService, viewModel),
                        2 => _buildDiscoveryTab(viewModel),
                        _ => const SizedBox.shrink(),
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          floatingActionButton: _currentTabIndex == 1
              ? FloatingActionButton(
                  onPressed: () {},
                  child: const Icon(Icons.add),
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
        : SearchTab.build(context, viewModel, _searchQuery,
            isGroupsSearch: false);
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
      final result = await SocialGroupComponents.showCreateGroupDialog(
        context: context,
      );

      // ✅ FIX: Dialog returns bool? - true on success, false/null on cancel
      // The transformation happens in social_group_components.dart: .then((result) => result != null)
      if (result == true && mounted) {
        SnackBarUtils.showSuccess(context, context.l10n.groupCreatedSuccess);
        // ✅ FIX: Switch to groups tab (index 1) after successful creation
        if (mounted) {
          setState(() {
            _currentTabIndex = 1;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(
            context, context.l10n.groupCouldNotCreate('$e'));
      }
    }
  }
}
