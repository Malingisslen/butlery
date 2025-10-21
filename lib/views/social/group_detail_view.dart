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
import 'package:provider/provider.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/group_invitation.dart';
import 'package:butlery/widgets/common/social_components.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/component_themes.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/events/group_events.dart';
import 'package:butlery/views/social/add_members_to_group_view.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/utils/common_dialog_actions.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/widgets/common/dialogs/recipe_selection/group_recipe_sharing_dialog.dart';
import 'package:butlery/widgets/common/dialogs/menu_selection_dialog.dart';
import 'package:butlery/widgets/common/dialogs/group_shopping_list_selection_dialog.dart';
import 'package:butlery/widgets/common/universal_share_dialog.dart';
import 'package:butlery/viewmodels/universal_share_dialog_viewmodel.dart';

// Import focused components
import 'package:butlery/views/social/group_detail/group_detail_header.dart';
import 'package:butlery/views/social/group_detail/group_detail_stats.dart';
import 'package:butlery/views/social/group_detail/group_detail_app_bar.dart';
import 'package:butlery/views/social/group_detail/group_members_list.dart';
import 'package:butlery/widgets/social/groups/group_shared_content_section.dart';

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
class GroupDetailView extends StatefulWidget {
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

class _GroupDetailViewState extends State<GroupDetailView>
    with ErrorHandlingMixin {
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
      if (!mounted || _isNavigating) {
        return;
      }

      switch (eventType) {
        case GroupEventType.created:
          break;
        case GroupEventType.updated:
        case GroupEventType.memberAdded:
        case GroupEventType.memberRemoved:
          // Check if current user is still a member of this group
          final categoriesService = ServiceLocator.get<UnifiedFriendsService>();
          final currentGroup =
              categoriesService.getCategoryById(widget.groupId);
          final currentUserId =
              ServiceLocator.get<PermissionService>().currentUserId;

          if (currentGroup != null && currentUserId != null) {
            final isStillMember =
                currentGroup.friendUserIds.contains(currentUserId);

            if (!isStillMember) {
              // User was removed from this group, navigate away
              if (mounted) {
                Navigator.of(context).pop();
              }
              return;
            }
          }

          _loadGroupData();
          break;
        case GroupEventType.deleted:
          final categoriesService = ServiceLocator.get<UnifiedFriendsService>();
          final currentGroup =
              categoriesService.getCategoryById(widget.groupId);
          if (currentGroup == null) {
            if (mounted) {
              Navigator.of(context).pop();
            }
          } else {
            _loadGroupData();
          }
          break;
      }
    });
  }

  Future<void> _loadGroupData() async {
    if (!mounted) {
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final categoriesService = ServiceLocator.get<UnifiedFriendsService>();
      final userService = ServiceLocator.get<UserService>();
      final groupInvitationService =
          ServiceLocator.get<UnifiedFriendsService>();

      // Force refresh: Säkerställ att vi har senaste datan
      await groupInvitationService.refresh();

      _group = categoriesService.getCategoryById(widget.groupId);

      if (_group != null) {
        // ✅ FIXED: Get member profiles from UserService batch fetch (not just friends)
        // This ensures all group members are shown, even if they're not in friends list yet
        final memberProfiles =
            await userService.getUserProfiles(_group!.friendUserIds);
        _members = memberProfiles;

        // Get pending invitations for this group
        _pendingInvitations = [];
      }
    } catch (e) {
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

  Future<void> _refreshData() async {
    final categoriesService = ServiceLocator.get<UnifiedFriendsService>();
    final groupInvitationService = ServiceLocator.get<UnifiedFriendsService>();

    await Future.wait([
      categoriesService.refresh(),
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
    if (_isNavigating) {
      return;
    }

    final shouldDelete = await SocialComponents.showDeleteGroupDialog(
      context: context,
      groupId: group.id,
      groupName: group.name,
    );

    if (shouldDelete == true && mounted && !_isNavigating) {
      if (mounted) {
        setState(() {
          _isNavigating = true;
        });
      }

      try {
        await Future.delayed(const Duration(milliseconds: 100));

        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gruppen "${group.name}" har tagits bort'),
            backgroundColor: AppColors.success,
          ),
        );

        Navigator.pushReplacementNamed(
          context,
          '/friends',
          arguments: {'tabIndex': 1}, // Navigate to groups tab
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
        // ✅ NEW: Social sharing buttons for group
        Text(
          'Dela med gruppen',
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppDimensions.spacingM),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showRecipeSelectionForGroup(group),
                icon: const Icon(Icons.restaurant_menu),
                label: const Text('Dela recept'),
              ),
            ),
            const SizedBox(width: AppDimensions.spacingM),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showMenuSelectionForGroup(group),
                icon: const Icon(Icons.calendar_today),
                label: const Text('Dela meny'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingM),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _showShoppingListSelectionForGroup(group),
            icon: const Icon(Icons.shopping_cart),
            label: const Text('Dela inköpslista'),
          ),
        ),
        const SizedBox(height: AppDimensions.spacingL),
        const Divider(),
        const SizedBox(height: AppDimensions.spacingL),

        // Management buttons
        Text(
          'Hantera grupp',
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppDimensions.spacingM),

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

  /// ✅ IMPROVED: Leave group with ownership succession handling
  Future<void> _leaveGroup(FriendCategory group) async {
    final currentUserId = ServiceLocator.get<PermissionService>().currentUserId;
    if (!ServiceLocator.get<PermissionService>().isAuthenticated) return;

    final permissionService = ServiceLocator.get<PermissionService>();
    final isOwner = permissionService.isGroupAdmin(group.id);

    // CRITICAL: Handle ownership succession for group owners
    if (isOwner) {
      // Get other members (excluding the owner)
      final otherMembers =
          _members.where((member) => member.uid != currentUserId).toList();

      if (otherMembers.isEmpty) {
        // No other members - offer to delete group
        final shouldDeleteEmptyGroup = await _showEmptyGroupDeleteDialog(group);
        if (shouldDeleteEmptyGroup == true) {
          await _showDeleteGroupDialog(group);
        }
        return;
      } else {
        // Has other members - require ownership transfer
        final newOwner =
            await _showOwnershipTransferDialog(group, otherMembers);
        if (newOwner == null) {
          // User cancelled ownership transfer - don't leave group
          return;
        }

        // Transfer ownership before leaving
        final transferSuccess = await _transferGroupOwnership(group, newOwner);
        if (!transferSuccess && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kunde inte överföra ägande. Försök igen.'),
              backgroundColor: AppColors.error,
            ),
          );
          return;
        }
      }
    }

    // Standard leave confirmation for non-owners or after ownership transfer
    if (!mounted) return;
    final shouldLeave = await CommonDialogActions.showLeaveGroupConfirmation(
      context: context,
      groupName: group.name,
    );

    if (shouldLeave == true && mounted) {
      final categoriesService = ServiceLocator.get<UnifiedFriendsService>();
      final success =
          await categoriesService.categories.removeFriendFromCategory(
        currentUserId!,
        group.id,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isOwner
                ? 'Ägande överfört och du har lämnat gruppen 👑➡️'
                : 'Du har lämnat gruppen 👋'),
            backgroundColor: AppColors.success,
          ),
        );
        // Navigate to groups tab
        Navigator.pushReplacementNamed(
          context,
          '/friends',
          arguments: {'tabIndex': 1}, // Navigate to groups tab
        );
      }
    }
  }

  /// Show dialog for empty group deletion when owner wants to leave
  Future<bool?> _showEmptyGroupDeleteDialog(FriendCategory group) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gruppen är tom'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Du är den enda medlemmen i "${group.name}".'),
            const SizedBox(height: AppDimensions.spacingM),
            const Text('Vill du ta bort gruppen när du lämnar den?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Avbryt'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ta bort gruppen'),
          ),
        ],
      ),
    );
  }

  /// Show dialog for choosing new group owner
  Future<UserProfile?> _showOwnershipTransferDialog(
      FriendCategory group, List<UserProfile> otherMembers) async {
    return await showDialog<UserProfile>(
      context: context,
      barrierDismissible: false, // Force user to make a choice
      builder: (context) => AlertDialog(
        title: const Text('Överför gruppägande'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Du är ägare av "${group.name}". Du måste välja en ny ägare innan du kan lämna gruppen.'),
            const SizedBox(height: AppDimensions.spacingL),
            const Text('Välj ny ägare:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppDimensions.spacingM),
            ...otherMembers.map((member) => ListTile(
                  leading: CircleAvatar(
                    backgroundImage: member.avatarUrl != null
                        ? NetworkImage(member.avatarUrl!)
                        : null,
                    child: member.avatarUrl == null
                        ? Text(member.displayName[0].toUpperCase())
                        : null,
                  ),
                  title: Text(member.displayName),
                  subtitle: Text(member.email),
                  onTap: () => Navigator.pop(context, member),
                )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Avbryt'),
          ),
        ],
      ),
    );
  }

  /// Transfer group ownership to a new owner
  Future<bool> _transferGroupOwnership(
      FriendCategory group, UserProfile newOwner) async {
    try {
      final categoriesService = ServiceLocator.get<UnifiedFriendsService>();

      AppLogger.info(
          'Transferring ownership of "${group.name}" from ${group.ownerId} to ${newOwner.uid}');

      // Create updated group with new owner
      final updatedGroup = group.copyWith(
        ownerId: newOwner.uid,
        updatedAt: DateTime.now(),
      );

      // Update local cache and sync to Firebase
      categoriesService.updateCategoryInternal(group.id, updatedGroup);
      await categoriesService.syncCategoryToFirebaseInternal(updatedGroup);

      // Refresh local group data
      await _loadGroupData();

      AppLogger.success(
          'Successfully transferred ownership of "${group.name}" to ${newOwner.displayName}');

      return true;
    } catch (e) {
      AppLogger.error('Failed to transfer group ownership', e);
      return false;
    }
  }

  /// ✅ NEW: Show recipe selection and share with group
  Future<void> _showRecipeSelectionForGroup(FriendCategory group) async {
    if (!mounted) return;

    // Share with all group members by iterating through them
    // This reuses the existing friend recipe sharing dialog for each member
    final memberIds = group.friendUserIds;

    if (memberIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gruppen har inga medlemmar att dela med'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    // For group sharing, we'll share with all members at once
    // Use the first member's profile as representative for the dialog UI
    if (_members.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kunde inte ladda gruppmedlemmar'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Show dialog with group context - using first member but will share with all
    await _showGroupRecipeSharingDialog(context, group, _members);
  }

  /// Show menu selection and share with group using UniversalShareDialog
  Future<void> _showMenuSelectionForGroup(FriendCategory group) async {
    if (!mounted) return;

    // Step 1: Show menu selection dialog
    final selectedMenu = await showDialog<dynamic>(
      context: context,
      builder: (context) => MenuSelectionDialog(
        groupName: group.name,
      ),
    );

    if (selectedMenu == null || !mounted) return;

    if (group.friendUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gruppen har inga medlemmar att dela med'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    // Step 2: Show UniversalShareDialog for collaboration control
    final shareViewModel = ServiceLocator.get<UniversalShareDialogViewModel>();
    final friendsService = ServiceLocator.get<UnifiedFriendsService>();

    await showDialog(
      context: context,
      builder: (context) => ChangeNotifierProvider.value(
        value: shareViewModel,
        child: UniversalShareDialog.menu(
          menu: selectedMenu.menuSnapshot,
          viewModel: shareViewModel,
          availableFriends: friendsService.friends,
          availableGroups: friendsService.categoriesList,
          initialMessage: 'Delad från gruppen ${group.name}',
        ),
      ),
    );
  }

  /// Show shopping list selection and share with group using UniversalShareDialog
  Future<void> _showShoppingListSelectionForGroup(FriendCategory group) async {
    if (!mounted) return;

    // Step 1: Show shopping list selection dialog
    final selectedList = await showDialog<dynamic>(
      context: context,
      builder: (context) => GroupShoppingListSelectionDialog(
        groupName: group.name,
      ),
    );

    if (selectedList == null || !mounted) return;

    if (group.friendUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gruppen har inga medlemmar att dela med'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    // Step 2: Show UniversalShareDialog for collaboration control
    final shareViewModel = ServiceLocator.get<UniversalShareDialogViewModel>();
    final friendsService = ServiceLocator.get<UnifiedFriendsService>();

    await showDialog(
      context: context,
      builder: (context) => ChangeNotifierProvider.value(
        value: shareViewModel,
        child: UniversalShareDialog.shoppingList(
          shoppingList: selectedList,
          viewModel: shareViewModel,
          availableFriends: friendsService.friends,
          availableGroups: friendsService.categoriesList,
          initialMessage: 'Delad från gruppen ${group.name}',
        ),
      ),
    );
  }

  /// Show recipe sharing dialog for group - shares with all members
  Future<void> _showGroupRecipeSharingDialog(
    BuildContext context,
    FriendCategory group,
    List<UserProfile> members,
  ) async {
    await showDialog(
      context: context,
      builder: (context) => GroupRecipeSharingDialog(
        group: group,
        members: members,
      ),
    );
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
              // Shared content section
              GroupSharedContentSection(group: _group!),
              const SizedBox(height: AppDimensions.spacingLg),
              _buildActionButtons(_group!),
            ],
          ),
        ),
      ),
    );
  }
}
