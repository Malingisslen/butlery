// lib/views/social/friends_list_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/friends_viewmodel.dart';
import '../../services/unified/unified_friends_service.dart';
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
import 'friends_list/group_search_tab.dart';

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
    _tabController = TabController(length: 3, vsync: this);
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
        if (tabIndex >= 0 && tabIndex < 3) {
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

        return LayoutComponents.mainMenu(
          currentIndex: null,
          title: 'Vänner & Grupper',
          body: Column(
            children: [
              // TabBar with proper styling
              Container(
                color: Theme.of(context).colorScheme.surface,
                child: TabBar(
                  controller: _tabController,
                  isScrollable: false, // Center the tabs
                  tabAlignment: TabAlignment.fill, // Fill available space
                  labelColor: AppColors.primaryBlue,
                  unselectedLabelColor: AppColors.textMedium,
                  indicatorColor: AppColors.primaryBlue,
                  indicatorWeight: AppDimensions.borderWidthThick,
                  tabs: [
                    Tab(
                      icon: const Icon(Icons.people),
                      text: 'Vänner',
                    ),
                    Tab(
                      icon: const Icon(Icons.groups),
                      text: 'Grupper',
                    ),
                    Tab(
                      icon: Badge(
                        isLabelVisible: viewModel.incomingRequests.isNotEmpty,
                        label: Text('${viewModel.incomingRequests.length}'),
                        child: const Icon(Icons.person_add),
                      ),
                      text: 'Förfrågningar',
                    ),
                  ],
                ),
              ),
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

              // Search functionality in both friends and groups tabs
              if (_currentTabIndex == 0)
                SearchFilterWidget.searchOnly(
                  searchQuery: _searchQuery,
                  onSearchChanged: _onSearchChanged,
                  searchHint: 'Sök efter vänner...',
                  autofocus: false,
                  padding: EdgeInsets.all(AppDimensions.spacingL),
                  showStats: true,
                  resultCount: viewModel.searchResults.length,
                ),
              if (_currentTabIndex == 1)
                SearchFilterWidget.searchOnly(
                  searchQuery: _searchQuery,
                  onSearchChanged: _onSearchChanged,
                  searchHint: 'Sök efter grupper...',
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
                    _buildFriendsTab(viewModel), // Vänner
                    _buildGroupsTab(friendsService), // Grupper (with search)
                    _buildRequestsTab(viewModel), // Förfrågningar
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: _currentTabIndex == 1
              ? FloatingActionButton(
                  onPressed: () => _showCreateGroupDialog(viewModel),
                  child: Stack(
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
                        child: Container(
                          width: AppDimensions.iconSizeS,
                          height: AppDimensions.iconSizeS,
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.add, 
                            size: AppDimensions.iconSizeS,
                            color: AppColors.cardWhite,
                          ),
                        ),
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
    // Friends tab with search functionality
    return _searchQuery.isEmpty 
        ? FriendsTab.build(context, viewModel)
        : SearchTab.build(context, viewModel, _searchQuery, isGroupsSearch: false);
  }

  Widget _buildRequestsTab(FriendsViewModel viewModel) {
    return RequestsTab.build(context, viewModel);
  }

  Widget _buildGroupsTab(UnifiedFriendsService friendsService) {
    // Groups tab with search functionality
    return _searchQuery.isEmpty 
        ? GroupsTab.build(context, friendsService)
        : GroupSearchTab.build(context, friendsService, _searchQuery);
  }


  // ✅ UPPDATERAD: Använd SocialComponents.showCreateGroupDialog
  Future<void> _showCreateGroupDialog(FriendsViewModel viewModel) async {
    final result = await SocialComponents.showCreateGroupDialog(
      context: context,
    );

    if (result == true && mounted) {
      SnackBarUtils.showSuccess(context, 'Gruppen skapades! 🎉');
      setState(() {}); // Uppdatera vyn
    }
  }

}
