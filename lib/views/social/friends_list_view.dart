// lib/views/social/friends_list_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/friends_viewmodel.dart';
import '../../services/group_invitation_service.dart';
import '../../models/group_invitation.dart';
import '../../widgets/user/user_display_widgets.dart';
import '../../widgets/common/layout_components.dart';
import '../../widgets/common/search_filter_widget.dart';
import '../../widgets/common/state_widget.dart';
import '../../theme/app_theme.dart';
import '../../core/injection.dart';
import '../../models/user_profile.dart';
import '../../models/friend_request.dart';
import '../../models/friend_category.dart';
import '../../services/friend_categories_service.dart';
import 'create_group_dialog.dart';
import 'group_detail_view.dart';

class FriendsListView extends StatelessWidget {
  const FriendsListView({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: sl<FriendsViewModel>()),
        ChangeNotifierProvider.value(value: sl<GroupInvitationService>()),
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
    return Consumer2<FriendsViewModel, GroupInvitationService>(
      builder: (context, viewModel, groupInvitationService, child) {
        final categoriesService = sl<FriendCategoriesService>();
        final pendingInvitationsCount =
            groupInvitationService.pendingNotificationsCount;

        return LayoutComponents.mainMenu(
          // ✅ UPPDATERAD: LayoutComponents istället för MainLayoutMenu
          currentIndex: null,
          body: Scaffold(
            appBar: AppBar(
              title: const Text('Vänner & Grupper'),
              bottom: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelPadding:
                    EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
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
                      backgroundColor: AppTheme.warningColor,
                      child: const Icon(Icons.group),
                    ),
                    text: 'Grupper (${categoriesService.categories.length})',
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
                    padding: EdgeInsets.all(AppTheme.spacingMd),
                    margin: EdgeInsets.all(AppTheme.spacingMd),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withValues(alpha: 0.1),
                      borderRadius: AppTheme.smallRadius,
                      border: Border.all(
                          color: AppTheme.errorColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: AppTheme.errorColor),
                        SizedBox(width: AppTheme.spacingSm),
                        Expanded(
                          child: Text(
                            viewModel.error!,
                            style: TextStyle(color: AppTheme.errorColor),
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
                    padding: EdgeInsets.all(AppTheme.spacingMd),
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
                      _buildGroupsTab(
                          categoriesService, groupInvitationService),
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
    if (viewModel.isLoading && viewModel.friends.isEmpty) {
      return StateWidget.loading(message: 'Laddar vänner...');
    }

    if (viewModel.friends.isEmpty) {
      return StateWidget.empty(
        title: 'Inga vänner än',
        subtitle:
            'Sök efter användare och skicka vänskapsförfrågningar för att bygga ditt nätverk!',
        icon: Icons.people_outline,
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await viewModel.refresh();
      },
      child: ListView.separated(
        padding: EdgeInsets.all(AppTheme.spacingMd),
        itemCount: viewModel.friends.length,
        separatorBuilder: (context, index) =>
            SizedBox(height: AppTheme.spacingSm),
        itemBuilder: (context, index) {
          final friend = viewModel.friends[index];
          return _buildFriendCard(friend, viewModel);
        },
      ),
    );
  }

  Widget _buildRequestsTab(FriendsViewModel viewModel) {
    if (viewModel.isLoading && viewModel.incomingRequests.isEmpty) {
      return StateWidget.loading(message: 'Laddar förfrågningar...');
    }

    if (viewModel.incomingRequests.isEmpty) {
      return StateWidget.empty(
        title: 'Inga vänskapsförfrågningar',
        subtitle: 'När någon skickar dig en vänskapsförfrågning visas den här.',
        icon: Icons.notifications_none,
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await viewModel.refresh();
      },
      child: ListView.separated(
        padding: EdgeInsets.all(AppTheme.spacingMd),
        itemCount: viewModel.incomingRequests.length,
        separatorBuilder: (context, index) =>
            SizedBox(height: AppTheme.spacingSm),
        itemBuilder: (context, index) {
          final request = viewModel.incomingRequests[index];
          return _buildRequestCard(request, viewModel);
        },
      ),
    );
  }

  Widget _buildSearchTab(FriendsViewModel viewModel) {
    if (_searchQuery.isEmpty) {
      return StateWidget.empty(
        title: 'Sök efter nya vänner',
        subtitle:
            'Skriv ett namn eller användarnamn i sökfältet ovan för att hitta nya vänner.',
        icon: Icons.search,
      );
    }

    if (viewModel.isSearching) {
      return StateWidget.loading(message: 'Söker användare...');
    }

    if (viewModel.searchResults.isEmpty) {
      return StateWidget.noSearchResults();
    }

    return ListView.separated(
      padding: EdgeInsets.all(AppTheme.spacingMd),
      itemCount: viewModel.searchResults.length,
      separatorBuilder: (context, index) =>
          SizedBox(height: AppTheme.spacingSm),
      itemBuilder: (context, index) {
        final user = viewModel.searchResults[index];
        return _buildSearchResultCard(user, viewModel);
      },
    );
  }

  Widget _buildGroupsTab(FriendCategoriesService categoriesService,
      GroupInvitationService groupInvitationService) {
    return AnimatedBuilder(
      animation: Listenable.merge([categoriesService, groupInvitationService]),
      builder: (context, child) {
        final groups = categoriesService.categories;
        final pendingInvitations =
            groupInvitationService.pendingReceivedInvitations;

        if (categoriesService.isLoading &&
            groups.isEmpty &&
            pendingInvitations.isEmpty) {
          return StateWidget.loading(message: 'Laddar grupper...');
        }

        return RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              categoriesService.refresh(),
              groupInvitationService.refresh(),
            ]);
          },
          child: CustomScrollView(
            slivers: [
              // Pending inbjudningar sektion
              if (pendingInvitations.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: AppTheme.screenPadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.mail_outline,
                                color: AppTheme.warningColor, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Gruppinbjudningar (${pendingInvitations.length})',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.warningColor,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Du har fått inbjudningar att gå med i grupper',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final invitation = pendingInvitations[index];
                      return Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingMd,
                          vertical: AppTheme.spacingXs,
                        ),
                        child: _buildInvitationCard(
                            invitation, groupInvitationService),
                      );
                    },
                    childCount: pendingInvitations.length,
                  ),
                ),
                // Separator
                if (groups.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: AppTheme.screenPadding,
                      child: Column(
                        children: [
                          const SizedBox(height: 16),
                          Divider(color: AppTheme.dividerColor),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
              ],

              // Befintliga grupper sektion
              if (groups.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: AppTheme.screenPadding,
                    child: Row(
                      children: [
                        Icon(Icons.groups,
                            color: AppTheme.primaryColor, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Mina grupper (${groups.length})',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final group = groups[index];
                      return Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingMd,
                          vertical: AppTheme.spacingXs,
                        ),
                        child: _buildGroupCard(group, categoriesService),
                      );
                    },
                    childCount: groups.length,
                  ),
                ),
              ],

              // Empty state
              if (groups.isEmpty && pendingInvitations.isEmpty) ...[
                SliverFillRemaining(
                  child: StateWidget.empty(
                    title: 'Inga grupper än',
                    subtitle:
                        'Skapa din första grupp eller vänta på inbjudningar från vänner.',
                    icon: Icons.groups_outlined,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildInvitationCard(
      GroupInvitation invitation, GroupInvitationService service) {
    return Card(
      color: AppTheme.warningColor.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: AppTheme.mediumRadius,
        side: BorderSide(
          color: AppTheme.warningColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: AppTheme.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withValues(alpha: 0.1),
                    borderRadius: AppTheme.smallRadius,
                  ),
                  child: Center(
                    child: Text(
                      invitation.groupEmoji,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invitation.groupName,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      Text(
                        'Inbjudan från ${invitation.fromUserName}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                      ),
                      Text(
                        'Skickat: ${invitation.timeAgoText}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.warningColor,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (invitation.personalMessage?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(AppTheme.spacingSm),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.05),
                  borderRadius: AppTheme.smallRadius,
                ),
                child: Text(
                  invitation.personalMessage!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: service.isLoading
                        ? null
                        : () => _rejectInvitation(invitation.id, service),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.errorColor,
                      side: BorderSide(color: AppTheme.errorColor),
                    ),
                    child: const Text('Avvisa'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: service.isLoading
                        ? null
                        : () => _acceptInvitation(invitation.id, service),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.successColor,
                    ),
                    child: const Text('Acceptera'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupCard(
      FriendCategory group, FriendCategoriesService categoriesService) {
    return Card(
      child: ListTile(
        onTap: () => _navigateToGroupDetail(group),
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
          child: Text(
            group.emoji ?? '👥',
            style: const TextStyle(fontSize: 20),
          ),
        ),
        title: Text(
          group.name,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (group.description?.isNotEmpty == true)
              Text(
                group.description!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            SizedBox(height: AppTheme.spacingXs),
            Text(
              group.summary,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendCard(UserProfile friend, FriendsViewModel viewModel) {
    return Card(
      child: ListTile(
        onTap: () {
          Navigator.pushNamed(
            context,
            '/friend-profile',
            arguments: friend,
          );
        },
        leading: UserDisplayWidgets.avatar(
          imageUrl: friend.avatarUrl,
          displayName: friend.displayName,
          size: ImageSize.small,
        ),
        title: Text(
          friend.displayName,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: friend.bio?.isNotEmpty == true
            ? Text(
                friend.bio!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) {
            switch (value) {
              case 'remove':
                _showRemoveFriendDialog(friend, viewModel);
                break;
              case 'profile':
                Navigator.pushNamed(
                  context,
                  '/friend-profile',
                  arguments: friend,
                );
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'profile',
              child: Row(
                children: [
                  Icon(Icons.person),
                  SizedBox(width: 8),
                  Text('Visa profil'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'remove',
              child: Row(
                children: [
                  Icon(Icons.person_remove, color: AppTheme.errorColor),
                  SizedBox(width: 8),
                  Text('Ta bort vän',
                      style: TextStyle(color: AppTheme.errorColor)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestCard(FriendRequest request, FriendsViewModel viewModel) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          children: [
            Row(
              children: [
                UserDisplayWidgets.avatar(
                  size: ImageSize.small,
                  imageUrl: viewModel.getAvatarUrlForUser(request.fromUserId),
                  displayName:
                      viewModel.getDisplayNameForUser(request.fromUserId),
                ),
                SizedBox(width: AppTheme.spacingMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vänskapsförfrågan',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (request.message?.isNotEmpty == true)
                        Text(
                          request.message!,
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      SizedBox(height: AppTheme.spacingXs),
                      Text(
                        'Skickat ${request.timeAgoText}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: AppTheme.spacingMd),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: viewModel.isLoading
                        ? null
                        : () => _rejectRequest(request, viewModel),
                    icon: const Icon(Icons.close),
                    label: const Text('Avböj'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.errorColor,
                      side: BorderSide(color: AppTheme.errorColor),
                    ),
                  ),
                ),
                SizedBox(width: AppTheme.spacingMd),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: viewModel.isLoading
                        ? null
                        : () => _acceptRequest(request, viewModel),
                    icon: const Icon(Icons.check),
                    label: const Text('Acceptera'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.successColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResultCard(UserProfile user, FriendsViewModel viewModel) {
    final isFriend = viewModel.friends.any((friend) => friend.uid == user.uid);
    final hasPendingRequest =
        viewModel.sentRequests.any((req) => req.toUserId == user.uid);

    return Card(
      child: ListTile(
        leading: UserDisplayWidgets.avatar(
          size: ImageSize.small,
          imageUrl: viewModel.getAvatarUrlForUser(user.uid),
          displayName: viewModel.getDisplayNameForUser(user.uid),
        ),
        title: Text(
          user.displayName,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: user.bio?.isNotEmpty == true
            ? Text(
                user.bio!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing:
            _buildActionButton(user, viewModel, isFriend, hasPendingRequest),
      ),
    );
  }

  Widget _buildActionButton(UserProfile user, FriendsViewModel viewModel,
      bool isFriend, bool hasPendingRequest) {
    if (isFriend) {
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppTheme.spacingSm,
          vertical: AppTheme.spacingXs,
        ),
        decoration: BoxDecoration(
          color: AppTheme.successColor.withValues(alpha: 0.1),
          borderRadius: AppTheme.smallRadius,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle,
              color: AppTheme.successColor,
              size: AppTheme.iconSizeInfo,
            ),
            SizedBox(width: AppTheme.spacingXs),
            Text(
              'Vänner',
              style: TextStyle(
                color: AppTheme.successColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (hasPendingRequest) {
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppTheme.spacingSm,
          vertical: AppTheme.spacingXs,
        ),
        decoration: BoxDecoration(
          color: AppTheme.warningColor.withValues(alpha: 0.1),
          borderRadius: AppTheme.smallRadius,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.schedule,
              color: AppTheme.warningColor,
              size: AppTheme.iconSizeInfo,
            ),
            SizedBox(width: AppTheme.spacingXs),
            Text(
              'Väntande',
              style: TextStyle(
                color: AppTheme.warningColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return FilledButton.icon(
      onPressed: viewModel.isLoading
          ? null
          : () => _sendFriendRequest(user, viewModel),
      icon: viewModel.isLoading
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(
                  Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            )
          : const Icon(Icons.person_add),
      label: const Text('Lägg till'),
    );
  }

  // Navigation methods
  void _navigateToGroupDetail(FriendCategory group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupDetailView(groupId: group.id),
      ),
    );
  }

  Future<void> _showCreateGroupDialog(FriendsViewModel viewModel) async {
    await showDialog(
      context: context,
      builder: (context) => const CreateGroupDialog(),
    );

    if (mounted) {
      setState(() {});
    }
  }

  // Invitation actions
  Future<void> _acceptInvitation(
      String invitationId, GroupInvitationService service) async {
    final success = await service.acceptGroupInvitation(invitationId);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inbjudan accepterad! Välkommen till gruppen! 🎉'),
          backgroundColor: AppTheme.successColor,
        ),
      );
      final viewModel = context.read<FriendsViewModel>();
      viewModel.refresh();
    } else if (mounted && service.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fel: ${service.error}'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _rejectInvitation(
      String invitationId, GroupInvitationService service) async {
    final success = await service.rejectGroupInvitation(invitationId);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inbjudan avvisad'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
    } else if (mounted && service.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fel: ${service.error}'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  // Friend actions
  Future<void> _sendFriendRequest(
      UserProfile user, FriendsViewModel viewModel) async {
    final success = await viewModel.sendFriendRequest(user.uid);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Vänskapsförfrågan skickad till ${user.displayName}! ✉️'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    }
  }

  Future<void> _acceptRequest(
      FriendRequest request, FriendsViewModel viewModel) async {
    final success = await viewModel.acceptFriendRequest(request.id);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vänskapsförfrågan accepterad! 🎉'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    }
  }

  Future<void> _rejectRequest(
      FriendRequest request, FriendsViewModel viewModel) async {
    final success = await viewModel.rejectFriendRequest(request.id);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vänskapsförfrågan avböjd'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
    }
  }

  Future<void> _showRemoveFriendDialog(
      UserProfile friend, FriendsViewModel viewModel) async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ta bort vän?'),
        content: Text(
            'Är du säker på att du vill ta bort ${friend.displayName} från din vänlista?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Avbryt'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Ta bort'),
          ),
        ],
      ),
    );

    if (shouldRemove == true && mounted) {
      final success = await viewModel.removeFriend(friend.uid);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${friend.displayName} borttagen från vänlista'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    }
  }
}
