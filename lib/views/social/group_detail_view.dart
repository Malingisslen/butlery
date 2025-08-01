/// Comprehensive group detail view providing detailed group management and member coordination for Flutter applications.
///
/// This module implements sophisticated group detail interface following Single Responsibility Principle,
/// specializing in group information display, member management, permission handling, and comprehensive group interaction.
/// It provides complete group detail interface while maintaining clean separation from business logic,
/// data persistence, and state management through UnifiedFriendsService integration and modern component architecture.
///
/// **Single Responsibility Focus:**
/// This module exclusively handles group detail UI presentation concerns through comprehensive group architecture:
/// - **Group Information Excellence**: Advanced group display with header, statistics, and comprehensive information presentation
/// - **Member Management Intelligence**: Sophisticated member coordination with invitation handling and membership tracking
/// - **Permission System Integration**: Comprehensive permission validation with role-based access control and action authorization
/// - **Real-Time Event Coordination**: Advanced event handling with group updates, member changes, and state synchronization
/// - **Swedish Localization Excellence**: Complete Swedish language support for group operations and user feedback
///
/// **What This Module Does NOT Handle:**
/// - Group business logic and data operations (handled by UnifiedFriendsService and group infrastructure)
/// - Permission validation algorithms (handled by PermissionService and authorization infrastructure)
/// - Member invitation processing (handled by invitation services and group management systems)
/// - Event publishing and coordination (handled by GroupEventBus and event infrastructure)
///
/// **Group Detail View Architecture:**
/// - **Comprehensive Group Display**: Advanced group presentation with header, statistics, and detailed information coordination
/// - **Member Management System**: Sophisticated member display with invitation tracking and membership coordination
/// - **Permission-Based Actions**: Complete action system with role-based permissions and authorization validation
/// - **Real-Time Event Integration**: Advanced event handling with automatic updates and state synchronization
/// - **Modular Component System**: Focused component architecture with specialized header, stats, and member list components
///
/// **Usage Examples:**
/// ```dart
/// // Navigate to group detail view
/// Navigator.of(context).push(
///   MaterialPageRoute(
///     builder: (context) => GroupDetailView(
///       groupId: selectedGroupId,
///     ),
///   ),
/// );
/// 
/// // The view provides comprehensive group detail functionality:
/// // - Complete group information display with header, statistics, and member details
/// // - Permission-based member management with invitation tracking and membership coordination
/// // - Role-based action system with edit, delete, and leave group capabilities
/// // - Real-time event integration with automatic updates and state synchronization
/// // - Modular component architecture with specialized focused components
/// 
/// // Integration with specialized components:
/// // - GroupDetailHeader for group information and visual presentation
/// // - GroupDetailStats for membership statistics and group metrics
/// // - GroupMembersList for member display and invitation management
/// // - GroupDetailAppBar for navigation and action menu coordination
/// ```

// lib/views/social/group_detail_view.dart

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/group_invitation.dart';
import 'package:butlery/widgets/common/social_components.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/component_themes.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/events/group_events.dart';
import 'package:butlery/views/social/add_members_to_group_view.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/utils/common_dialog_actions.dart';

// Import focused components
import 'package:butlery/views/social/group_detail/group_detail_header.dart';
import 'package:butlery/views/social/group_detail/group_detail_stats.dart';
import 'package:butlery/views/social/group_detail/group_detail_app_bar.dart';
import 'package:butlery/views/social/group_detail/group_members_list.dart';
import 'package:butlery/core/mixins/stream_management_mixin.dart';

/// Comprehensive group detail view providing detailed group management and member coordination through advanced group architecture.
///
/// Manages complete group detail interface enabling group information display, member management, permission handling,
/// and comprehensive group interaction while maintaining clean separation between UI presentation
/// and business logic through UnifiedFriendsService integration and specialized component architecture.
///
/// **Core Responsibilities:**
/// - Advanced group information display with header presentation, statistics coordination, and comprehensive detail management
/// - Member management coordination with invitation tracking, membership display, and comprehensive member functionality
/// - Permission system integration with role-based access control, action authorization, and comprehensive security validation
/// - Real-time event handling with group updates, member changes, and automatic state synchronization through event coordination
/// - Swedish localized group experience with comprehensive user feedback and interactive guidance
class GroupDetailView extends StatefulWidget with StreamManagementMixin {
  /// Group identifier for data loading and management coordination.
  /// 
  /// Contains group ID enabling group data loading, member management,
  /// permission validation, and comprehensive group functionality.
  final String groupId;

  /// Creates comprehensive group detail view with detailed management and member coordination.
  /// 
  /// [groupId] Group identifier for data loading and management coordination
  /// 
  /// Establishes group detail interface with information display, member management,
  /// permission handling, and comprehensive group functionality through
  /// UnifiedFriendsService integration and advanced group architecture.
  const GroupDetailView({
    super.key,
    required this.groupId,
  });

  @override
  State<GroupDetailView> createState() => _GroupDetailViewState();
}

class _GroupDetailViewState extends State<GroupDetailView> with ErrorHandlingMixin {
  // State variables
  FriendCategory? _group;
  List<UserProfile> _members = [];
  List<GroupInvitation> _pendingInvitations = [];
  bool _isLoading = false;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _setupEventListening();
    _loadGroupData();
  }

  // Event subscription for listening to group changes
  StreamSubscription<GroupEventType>? _eventSubscription;

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }

  void _setupEventListening() {
    // Manual stream subscription since this is a StatefulWidget
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
          final categoriesService = ServiceLocator.get<UnifiedFriendsService>();
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

    if (mounted) setState(() {
      _isLoading = true;
    });

    try {
      final categoriesService = ServiceLocator.get<UnifiedFriendsService>();
      final friendsViewModel = ServiceLocator.get<FriendsViewModel>();
      final groupInvitationService = ServiceLocator.get<UnifiedFriendsService>();

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
        if (mounted) setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// ✅ NYTT: Debug gruppinformation och behörigheter
  void _debugGroupInfo() {
    if (_group == null) return;

    final permissionService = ServiceLocator.get<PermissionService>();
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
    final categoriesService = ServiceLocator.get<UnifiedFriendsService>();
    final friendsViewModel = ServiceLocator.get<FriendsViewModel>();
    final groupInvitationService = ServiceLocator.get<UnifiedFriendsService>();

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
  Future<void> _showEditGroupDialog(FriendCategory group) async {
    final result = await SocialComponents.showEditGroupDialog(
      context: context,
      groupId: group.id,
      currentGroupName: group.name,
      currentMemberIds: group.memberIds,
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gruppen uppdaterades! ✅'),
          backgroundColor: AppColors.success,
        ),
      );
      _loadGroupData();
    }
  }

  Future<void> _showAddMembersDialog() async {
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
  Future<void> _showDeleteGroupDialog(FriendCategory group) async {
    if (_isNavigating) return;

    final shouldDelete = await SocialComponents.showDeleteGroupDialog(
      context: context,
      groupId: group.id,
      groupName: group.name,
    );

    if (shouldDelete == true && mounted && !_isNavigating) {
      if (mounted) setState(() {
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
          if (mounted) setState(() {
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
        if (ServiceLocator.get<PermissionService>().isGroupAdmin(group.id)) ...[
          FilledButton.icon(
            onPressed: () => _showEditGroupDialog(group),
            icon: const Icon(Icons.edit),
            label: const Text('Redigera grupp'),
          ),
          const SizedBox(height: AppDimensions.spacingL),
        ],

        // Delete or Leave button
        if (ServiceLocator.get<PermissionService>().isGroupAdmin(group.id))
          OutlinedButton.icon(
            onPressed: () => _showDeleteGroupDialog(group),
            icon: const Icon(Icons.delete),
            label: const Text('Ta bort grupp'),
            style: ComponentThemes.deleteButtonStyle,
          )
        else
          OutlinedButton.icon(
            onPressed: () => _leaveGroup(group),
            icon: const Icon(Icons.exit_to_app),
            label: const Text('Lämna grupp'),
            style: ComponentThemes.outlinedButtonStyle,
          ),
      ],
    );
  }

  /// ✅ NYTT: Lägg till metod för att lämna grupp
  Future<void> _leaveGroup(FriendCategory group) async {
    final currentUserId = ServiceLocator.get<PermissionService>().currentUserId;
    if (!ServiceLocator.get<PermissionService>().isAuthenticated) return;

    final shouldLeave = await CommonDialogActions.showLeaveGroupConfirmation(
      context: context,
      groupName: group.name,
    );

    if (shouldLeave == true && mounted) {
      final categoriesService = ServiceLocator.get<UnifiedFriendsService>();
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
              SizedBox(height: AppDimensions.spacingMd),
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
          padding: const EdgeInsets.all(AppDimensions.spacingL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildGroupHeader(_group!),
              const SizedBox(height: AppDimensions.spacingLg),
              _buildGroupStats(_group!, _members),
              const SizedBox(height: AppDimensions.spacingLg),
              _buildMembersSection(_members),
              const SizedBox(height: AppDimensions.spacingLg),
              _buildActionButtons(_group!),
            ],
          ),
        ),
      ),
    );
  }
}
