// lib/views/social/group_detail_view.dart

import 'package:flutter/material.dart';
import 'dart:async';
import '../../viewmodels/friends_viewmodel.dart';
import '../../services/unified/unified_friends_service.dart';
import '../../models/friend_category.dart';
import '../../models/user_profile.dart';
import '../../models/group_invitation.dart';
import '../../widgets/common/social_components.dart';
import '../../widgets/common/state_widget.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../core/injection.dart';
import '../../core/events/group_events.dart';
import 'add_members_to_group_view.dart';
import '../../services/permission_service.dart';

// Import focused components
import 'group_detail/group_detail_header.dart';
import 'group_detail/group_detail_stats.dart';
import 'group_detail/group_detail_app_bar.dart';
import 'group_detail/group_members_list.dart';


class GroupDetailView extends StatefulWidget {
  final String groupId;

  const GroupDetailView({
    super.key,
    required this.groupId,
  });

  @override
  State<GroupDetailView> createState() => _GroupDetailViewState();
}

class _GroupDetailViewState extends State<GroupDetailView> {
  // State variables
  FriendCategory? _group;
  List<UserProfile> _members = [];
  List<GroupInvitation> _pendingInvitations = [];
  bool _isLoading = false;
  bool _isNavigating = false;

  // Event subscription för att lyssna på gruppändringar
  StreamSubscription<GroupEventType>? _eventSubscription;

  @override
  void initState() {
    super.initState();
    _setupEventListening();
    _loadGroupData();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }

  void _setupEventListening() {
    _eventSubscription = GroupEventBus.stream.listen((eventType) {
      if (!mounted || _isNavigating) return;

      switch (eventType) {
        case GroupEventType.created:
          break;
        case GroupEventType.updated:
        case GroupEventType.memberAdded:
        case GroupEventType.memberRemoved:
          _loadGroupData();
          break;
        case GroupEventType.deleted:
          final categoriesService = sl<UnifiedFriendsService>();
          final currentGroup =
              categoriesService.getCategoryById(widget.groupId);
          if (currentGroup == null) {
            // Gruppen blev borttagen
          } else {
            _loadGroupData();
          }
          break;
      }
    });
  }

  /// Ladda både gruppdata OCH pending inbjudningar med force refresh
  Future<void> _loadGroupData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final categoriesService = sl<UnifiedFriendsService>();
      final friendsViewModel = sl<FriendsViewModel>();
      final groupInvitationService = sl<UnifiedFriendsService>();

      // Force refresh: Säkerställ att vi har senaste datan
      await groupInvitationService.refresh();

      // Hämta gruppdata
      _group = categoriesService.getCategoryById(widget.groupId);

      if (_group != null) {
        // ✅ DEBUG: Logga gruppinformation
        _debugGroupInfo();

        // Hämta medlemmar från vänlistan
        _members = friendsViewModel.friends
            .where((friend) => _group!.friendUserIds.contains(friend.uid))
            .toList();

        // Hämta pending inbjudningar för denna grupp
        // Note: Group invitation fetching is not implemented in current version
        _pendingInvitations = [];

        debugPrint(
            '🔍 DEBUG: Efter refresh - Laddade ${_members.length} medlemmar och ${_pendingInvitations.length} väntande inbjudningar');
      }
    } catch (e) {
      debugPrint('🔍 DEBUG: Fel vid laddning av gruppdata: $e');
      _group = null;
      _members = [];
      _pendingInvitations = [];
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// ✅ NYTT: Debug gruppinformation och behörigheter
  void _debugGroupInfo() {
    if (_group == null) return;

    final permissionService = sl<PermissionService>();
    final currentUserId = permissionService.currentUserId;
    debugPrint('🔍 DEBUG: Group info för ${_group!.name}:');
    debugPrint('   - ownerId: ${_group!.ownerId}');
    debugPrint('   - createdBy: ${_group!.createdBy}');
    debugPrint('   - friendUserIds: ${_group!.friendUserIds}');
    debugPrint('   - friendCount: ${_group!.friendCount}');
    debugPrint('   - current userId: $currentUserId');

    // Kontrollera behörigheter med PermissionService
    debugPrint('   - Är jag ägare? ${permissionService.isOwner(_group!.ownerId)}');
    debugPrint('   - Är jag skapare? ${permissionService.isOwner(_group!.createdBy)}');
    debugPrint('   - Är jag admin? ${permissionService.isGroupAdmin(_group!.id)}');
    debugPrint('   - Är jag medlem? ${_group!.friendUserIds.contains(currentUserId)}');
  }

  Future<void> _refreshData() async {
    final categoriesService = sl<UnifiedFriendsService>();
    final friendsViewModel = sl<FriendsViewModel>();
    final groupInvitationService = sl<UnifiedFriendsService>();

    await Future.wait([
      categoriesService.refresh(),
      friendsViewModel.refresh(),
      groupInvitationService.refresh(),
    ]);

    await _loadGroupData();
  }



  Widget _buildGroupHeader(FriendCategory group) {
    return GroupDetailHeader.build(context, group);
  }




  void _handleMenuAction(String action, FriendCategory group) {
    switch (action) {
      case 'edit':
        _showEditGroupDialog(group);
        break;
      case 'add_members':
        _showAddMembersDialog();
        break;
      case 'delete':
        _showDeleteGroupDialog(group);
        break;
      case 'leave_group': // ✅ NYTT: Hantera lämna grupp från popup menu
        _leaveGroup(group);
        break;
    }
  }


  // ✅ UPPDATERAD: Använd SocialComponents.showEditGroupDialog
  void _showEditGroupDialog(FriendCategory group) async {
    final result = await SocialComponents.showEditGroupDialog(
      context,
      group: group,
    );

    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gruppen "${result.name}" uppdaterades! ✅'),
          backgroundColor: AppColors.success,
        ),
      );
      _loadGroupData();
    }
  }

  void _showAddMembersDialog() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddMembersToGroupView(groupId: widget.groupId),
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gruppinbjudningar skickade! 🎉'),
          backgroundColor: AppColors.success,
        ),
      );
      _loadGroupData();
    }
  }

  // ✅ UPPDATERAD: Använd SocialComponents.showDeleteGroupDialog
  void _showDeleteGroupDialog(FriendCategory group) async {
    if (_isNavigating) return;

    final shouldDelete = await SocialComponents.showDeleteGroupDialog(
      context,
      group: group,
    );

    if (shouldDelete == true && mounted && !_isNavigating) {
      setState(() {
        _isNavigating = true;
      });

      try {
        await Future.delayed(const Duration(milliseconds: 100));

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gruppen "${group.name}" har tagits bort'),
            backgroundColor: AppColors.success,
          ),
        );

        Navigator.pushReplacementNamed(
          context,
          '/friends',
          arguments: {'tabIndex': 3},
        );
      } catch (e) {
        if (mounted) {
          Navigator.pop(context);
        }
      } finally {
        if (mounted) {
          setState(() {
            _isNavigating = false;
          });
        }
      }
    }
  }



  /// Inkludera pending inbjudningar i statistik
  Widget _buildGroupStats(FriendCategory group, List<UserProfile> members) {
    return GroupDetailStats.build(context, group, members);
  }

  /// Visa både medlemmar och pending inbjudningar
  Widget _buildMembersSection(List<UserProfile> members) {
    return GroupMembersList.build(
      context,
      members: members,
      pendingInvitations: _pendingInvitations,
      group: _group!,
      onAddMembers: _showAddMembersDialog,
      onMemberRemoved: _loadGroupData,
      onInvitationCancelled: _loadGroupData,
    );
  }

  /// ✅ FIXAD: Action buttons med behörighetskontroll
  Widget _buildActionButtons(FriendCategory group) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Edit button
        if (sl<PermissionService>().isGroupAdmin(group.id)) ...[
          FilledButton.icon(
            onPressed: () => _showEditGroupDialog(group),
            icon: const Icon(Icons.edit),
            label: const Text('Redigera grupp'),
          ),
          SizedBox(height: AppDimensions.spacingL),
        ],

        // Delete or Leave button
        if (sl<PermissionService>().isGroupAdmin(group.id))
          OutlinedButton.icon(
            onPressed: () => _showDeleteGroupDialog(group),
            icon: const Icon(Icons.delete),
            label: const Text('Ta bort grupp'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
              side: BorderSide(color: Theme.of(context).colorScheme.error),
            ),
          )
        else
          OutlinedButton.icon(
            onPressed: () => _leaveGroup(group),
            icon: const Icon(Icons.exit_to_app),
            label: const Text('Lämna grupp'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.tertiary,
              side: BorderSide(color: Theme.of(context).colorScheme.tertiary),
            ),
          ),
      ],
    );
  }

  /// ✅ NYTT: Lägg till metod för att lämna grupp
  Future<void> _leaveGroup(FriendCategory group) async {
    final currentUserId = sl<PermissionService>().currentUserId;
    if (!sl<PermissionService>().isAuthenticated) return;

    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lämna grupp?'),
        content: Text('Vill du verkligen lämna gruppen "${group.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Avbryt'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.warning,
            ),
            child: const Text('Lämna grupp'),
          ),
        ],
      ),
    );

    if (shouldLeave == true && mounted) {
      final categoriesService = sl<UnifiedFriendsService>();
      final success = await categoriesService.categories.removeFriendFromCategory(
        friendId: currentUserId!,
        categoryId: group.id,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Du har lämnat gruppen 👋'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context); // Gå tillbaka till grupp-listan
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoading && _group == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Laddar...'),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Laddar gruppinformation...'),
            ],
          ),
        ),
      );
    }

    if (_group == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Grupp hittades inte'),
        ),
        body: StateWidget.empty(
          title: 'Grupp hittades inte',
          subtitle:
              'Den här gruppen kanske har tagits bort eller så saknar du behörighet.',
          icon: Icons.error_outline,
        ),
      );
    }

    return Scaffold(
      appBar: GroupDetailAppBar.build(
        context,
        group: _group!,
        isLoading: _isLoading,
        onRefresh: _refreshData,
        onMenuAction: (action) => _handleMenuAction(action, _group!),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(AppDimensions.spacingL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildGroupHeader(_group!),
              SizedBox(height: AppDimensions.spacingLg),
              _buildGroupStats(_group!, _members),
              SizedBox(height: AppDimensions.spacingLg),
              _buildMembersSection(_members),
              SizedBox(height: AppDimensions.spacingLg),
              _buildActionButtons(_group!),
            ],
          ),
        ),
      ),
    );
  }
}
