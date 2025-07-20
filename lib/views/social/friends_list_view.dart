// lib/views/social/friends_list_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/friends_viewmodel.dart';
import '../../services/unified/unified_friends_service.dart';
import '../../models/group_invitation.dart';
import '../../widgets/common/social_components.dart';
import '../../widgets/common/layout_components.dart';
import '../../widgets/common/search_filter_widget.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../core/injection.dart';
import '../../core/utils/snackbar_utils.dart';

// Import focused components
import 'friends_list/friends_tab.dart';
import 'friends_list/requests_tab.dart';
import 'friends_list/search_tab.dart';
import 'friends_list/groups_tab.dart';

class FriendsListView extends StatelessWidget {
  const FriendsListView({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: sl<FriendsViewModel>()),
        ChangeNotifierProvider.value(value: sl<UnifiedFriendsService>()),
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
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _currentTabIndex = _tabController.index;
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null && args['tabIndex'] != null) {
        final tabIndex = args['tabIndex'] as int;
        if (tabIndex >= 0 && tabIndex < 4) {
          _tabController.animateTo(tabIndex);
          setState(() {
            _currentTabIndex = tabIndex;
          });
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
    setState(() {
      _searchQuery = query;
    });
    final viewModel = context.read<FriendsViewModel>();
    viewModel.updateSearch(query);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<FriendsViewModel, UnifiedFriendsService>(
      builder: (context, viewModel, friendsService, child) {
        final pendingInvitationsCount =
            friendsService.sentInvitations.where((inv) => inv.status == GroupInvitationStatus.pending).length;

        return LayoutComponents.mainMenu(
          currentIndex: null,
          body: Scaffold(
            appBar: AppBar(
              title: const Text('Vänner & Grupper'),
              bottom: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelPadding:
                    EdgeInsets.symmetric(horizontal: AppDimensions.spacingL),
                tabs: [
                  Tab(
                    icon: const Icon(Icons.people),
                    text: 'Vänner (${viewModel.friends.length})',
                  ),
                  Tab(
                    icon: Badge(
                      isLabelVisible: viewModel.incomingRequests.isNotEmpty,
                      label: Text('${viewModel.incomingRequests.length}'),
                      child: const Icon(Icons.person_add),
                    ),
                    text: 'Förfrågningar',
                  ),
                  Tab(
                    icon: const Icon(Icons.search),
                    text: 'Sök',
                  ),
                  Tab(
                    icon: Badge(
                      isLabelVisible: pendingInvitationsCount > 0,
                      label: Text('$pendingInvitationsCount'),
                      backgroundColor: AppColors.warning,
                      child: const Icon(Icons.group),
                    ),
                    text: 'Grupper (${friendsService.categories.categoriesList.length})',
                  ),
                ],
              ),
            ),
            body: Column(
              children: [
                // Error display
                if (viewModel.hasError)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(AppDimensions.spacingL),
                    margin: EdgeInsets.all(AppDimensions.spacingL),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
                      border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: AppColors.error),
                        SizedBox(width: AppDimensions.spacingS),
                        Expanded(
                          child: Text(
                            viewModel.error!,
                            style: TextStyle(color: AppColors.error),
                          ),
                        ),
                        TextButton(
                          onPressed: viewModel.clearError,
                          child: const Text('Stäng'),
                        ),
                      ],
                    ),
                  ),

                // SearchFilterWidget för sök-tab (index 2)
                if (_currentTabIndex == 2)
                  SearchFilterWidget.searchOnly(
                    searchQuery: _searchQuery,
                    onSearchChanged: _onSearchChanged,
                    searchHint: 'Sök efter vänner...',
                    autofocus: false,
                    padding: EdgeInsets.all(AppDimensions.spacingL),
                    showStats: true,
                    resultCount: viewModel.searchResults.length,
                  ),

                // Tab content
                Expanded(
                  child: IndexedStack(
                    index: _currentTabIndex,
                    children: [
                      _buildFriendsTab(viewModel),
                      _buildRequestsTab(viewModel),
                      _buildSearchTab(viewModel),
                      _buildGroupsTab(friendsService),
                    ],
                  ),
                ),
              ],
            ),
            floatingActionButton: _currentTabIndex == 3
                ? FloatingActionButton.extended(
                    onPressed: () => _showCreateGroupDialog(viewModel),
                    icon: const Icon(Icons.add),
                    label: const Text('Skapa grupp'),
                  )
                : null,
          ),
        );
      },
    );
  }

  Widget _buildFriendsTab(FriendsViewModel viewModel) {
    return FriendsTab.build(context, viewModel);
  }

  Widget _buildRequestsTab(FriendsViewModel viewModel) {
    return RequestsTab.build(context, viewModel);
  }

  Widget _buildSearchTab(FriendsViewModel viewModel) {
    return SearchTab.build(context, viewModel, _searchQuery);
  }

  Widget _buildGroupsTab(UnifiedFriendsService friendsService) {
    return GroupsTab.build(context, friendsService);
  }

  // ✅ UPPDATERAD: Använd SocialComponents.showCreateGroupDialog
  Future<void> _showCreateGroupDialog(FriendsViewModel viewModel) async {
    final result = await SocialComponents.showCreateGroupDialog(context);

    if (result != null && mounted) {
      SnackBarUtils.showSuccess(context, 'Gruppen "${result.name}" skapades! 🎉');
      setState(() {}); // Uppdatera vyn
    }
  }

}
