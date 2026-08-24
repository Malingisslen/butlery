/// Social group detail ViewModel providing business logic for group management and member coordination.
/// This ViewModel handles all business logic for social groups (FriendCategory), including:
/// - Group data loading and refresh
/// - Event subscription management (GroupEventBus)
/// - Leave group logic with ownership succession
/// - Ownership transfer coordination
/// - Permission checks
/// - Content sharing coordination
/// **Note**: This is separate from `GroupDetailViewModel` which handles messaging group conversations.
/// This ViewModel is specifically for social groups (FriendCategory instances).
/// **Architecture**:
/// - Uses AsyncOperationMixin for loading states
/// - Uses ErrorHandlingMixin for error management
/// - Extends ChangeNotifier for reactive updates
/// - Constructor injection for testability
/// **Usage**:
/// ```dart
/// final viewModel = SocialGroupDetailViewModel(
///   groupId: 'group_123',
///   friendsService: ServiceLocator.get<UnifiedFriendsService>(),
///   userService: ServiceLocator.get<UserService>(),
///   permissionService: ServiceLocator.get<PermissionService>(),
/// );
/// await viewModel.loadGroupData();
/// ```
library;

import 'package:clock/clock.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/menu_service.dart';
import 'package:butlery/services/messaging_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/group_invitation.dart';
import 'package:butlery/models/messaging/poll.dart';
import 'package:butlery/core/events/group_events.dart';
import 'package:butlery/core/errors/chat_group_error_mapper.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/mixins/async_operation_mixin.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/mixins/state_notifier_mixin.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/viewmodels/menu/menu_generator.dart';

/// Information about ownership succession when owner leaves group.
/// Used to communicate leave group requirements to the UI.
class LeaveGroupDecision {
  final bool requiresOwnershipTransfer;
  final bool groupIsEmpty;
  final List<UserProfile> availableNewOwners;

  const LeaveGroupDecision({
    required this.requiresOwnershipTransfer,
    required this.groupIsEmpty,
    required this.availableNewOwners,
  });
}

/// ViewModel for social group detail view business logic.
/// Manages state, business logic, and service coordination for social group (FriendCategory) details.
/// Separates concerns from UI presentation in GroupDetailView.
class SocialGroupDetailViewModel extends ChangeNotifier
    with StateNotifierMixin, AsyncOperationMixin, ErrorHandlingMixin {
  // Dependencies (injected)
  final String groupId;
  final UnifiedFriendsService _friendsService;
  final UserService _userService;
  final PermissionService _permissionService;

  // State
  FriendCategory? _group;
  List<UserProfile> _members = [];
  List<GroupInvitation> _pendingInvitations = [];
  StreamSubscription<GroupEventType>? _eventSubscription;
  DateTime? _lastRefresh;

  /// Creates ViewModel with required dependencies.
  SocialGroupDetailViewModel({
    required this.groupId,
    required UnifiedFriendsService friendsService,
    required UserService userService,
    required PermissionService permissionService,
  }) : _friendsService = friendsService,
       _userService = userService,
       _permissionService = permissionService {
    _initialize();
  }

  /// Current group data (null if not loaded or deleted).
  FriendCategory? get group => _group;

  /// List of group members with full profiles.
  List<UserProfile> get members => List.unmodifiable(_members);

  /// List of pending invitations for this group.
  List<GroupInvitation> get pendingInvitations =>
      List.unmodifiable(_pendingInvitations);

  /// Whether group data is currently loading.
  @override
  bool get isLoading => super.isLoading;

  /// Current error message (null if no error).
  String? get errorMessage => error;

  /// Whether current user is admin/owner of this group.
  bool get isAdmin {
    if (_group == null) return false;
    return _permissionService.isGroupAdmin(_group!.id);
  }

  /// Whether this group is marked as the user's household.
  bool get isHousehold => _group?.isHousehold ?? false;

  /// Toggle household status. Only one group can be household at a time.
  Future<void> toggleHousehold(bool value) async {
    if (_group == null) return;
    await executeAsync(() async {
      await _friendsService.categories.toggleHousehold(_group!.id, value);
      await loadGroupData();
    });
  }

  /// Whether current user can edit this group.
  bool get canEditGroup {
    if (_group == null) return false;
    return _permissionService.isGroupAdmin(_group!.id);
  }

  /// Whether current user can delete this group.
  bool get canDeleteGroup {
    if (_group == null) return false;
    return _permissionService.isGroupAdmin(_group!.id);
  }

  /// Whether current user can add members to this group.
  bool get canAddMembers {
    if (_group == null) return false;
    return _permissionService.isGroupAdmin(_group!.id);
  }

  /// Whether current user can leave this group.
  bool get canLeaveGroup {
    if (_group == null) return false;
    final currentUserId = _permissionService.currentUserId;
    if (currentUserId == null) return false;
    return _group!.friendUserIds.contains(currentUserId);
  }

  void _initialize() {
    _setupEventListening();
    loadGroupData();
  }

  /// Set up event listening for group changes.
  void _setupEventListening() {
    _eventSubscription = GroupEventBus.stream.listen((eventType) {
      switch (eventType) {
        case GroupEventType.created:
          // Not relevant for existing group
          break;
        case GroupEventType.updated:
        case GroupEventType.memberAdded:
        case GroupEventType.memberRemoved:
          // Check if current user is still a member
          _handleMembershipChange();
          break;
        case GroupEventType.deleted:
          // Check if this group was deleted
          _handleGroupDeletion();
          break;
      }
    });
  }

  /// Handle membership change events.
  void _handleMembershipChange() {
    final currentGroup = _friendsService.getCategoryById(groupId);
    final currentUserId = _permissionService.currentUserId;

    if (currentGroup != null && currentUserId != null) {
      final isStillMember = currentGroup.friendUserIds.contains(currentUserId);

      if (!isStillMember) {
        // User was removed from this group
        _group = null;
        notifyListeners();
        return;
      }
    }

    // Still a member, reload data
    loadGroupData();
  }

  /// Handle group deletion events.
  void _handleGroupDeletion() {
    final currentGroup = _friendsService.getCategoryById(groupId);
    if (currentGroup == null) {
      // Group was deleted
      _group = null;
      notifyListeners();
    } else {
      // Group still exists, reload data
      loadGroupData();
    }
  }

  /// Load group data from services.
  /// Only force-refreshes if data is stale (>30s) to avoid unnecessary network
  /// traffic on back-navigation. Use refreshData() for explicit pull-to-refresh.
  Future<void> loadGroupData() async {
    await executeAsync(() async {
      final now = clock.now();
      if (_lastRefresh == null ||
          now.difference(_lastRefresh!).inSeconds > 30) {
        await _friendsService.refresh();
        _lastRefresh = now;
      }

      _group = _friendsService.getCategoryById(groupId);

      if (_group != null) {
        // Get member profiles from UserService batch fetch
        // This ensures all group members are shown, even if not in friends list
        final memberProfiles = await _userService.getUserProfiles(
          _group!.friendUserIds,
        );
        _members = memberProfiles;

        // Get pending invitations for this group from sent invitations
        _pendingInvitations = _friendsService.sentInvitations
            .where((i) => i.groupId == groupId && i.isPending)
            .toList();
      } else {
        _members = [];
        _pendingInvitations = [];
      }
    });
  }

  /// Refresh group data (pull-to-refresh). Always forces network fetch.
  Future<void> refreshData() async {
    _lastRefresh = null; // Force refresh on next load
    await loadGroupData();
  }

  /// Check if leaving group requires special handling (ownership transfer).
  /// Returns information about what's needed to leave the group.
  LeaveGroupDecision checkLeaveGroupRequirements() {
    if (_group == null) {
      throw StateError('Cannot check leave requirements without loaded group');
    }

    final currentUserId = _permissionService.currentUserId;
    if (currentUserId == null) {
      throw StateError('Cannot leave group without authenticated user');
    }

    final isOwner = isAdmin;

    if (!isOwner) {
      // Non-owner can leave freely
      return const LeaveGroupDecision(
        requiresOwnershipTransfer: false,
        groupIsEmpty: false,
        availableNewOwners: [],
      );
    }

    // Owner leaving - check for other members
    final otherMembers = _members
        .where((member) => member.uid != currentUserId)
        .toList();

    if (otherMembers.isEmpty) {
      // Empty group - owner can delete it
      return const LeaveGroupDecision(
        requiresOwnershipTransfer: false,
        groupIsEmpty: true,
        availableNewOwners: [],
      );
    } else {
      // Has other members - requires ownership transfer
      return LeaveGroupDecision(
        requiresOwnershipTransfer: true,
        groupIsEmpty: false,
        availableNewOwners: otherMembers,
      );
    }
  }

  /// Leave the group (after any required ownership transfer).
  /// Returns true if successfully left the group.
  /// Throws exception if fails.
  Future<bool> leaveGroup() async {
    if (_group == null) {
      throw StateError('Cannot leave group without loaded group');
    }

    final currentUserId = _permissionService.currentUserId;
    if (currentUserId == null) {
      throw StateError('Cannot leave group without authenticated user');
    }

    try {
      final success = await _friendsService.categories.removeFriendFromCategory(
        currentUserId,
        groupId,
      );

      if (success) {
        await ServiceLocator.tryGet<AnalyticsService>()?.social.logGroupLeft(
          groupId: groupId,
        );
        _group = null;
        notifyListeners();
      }

      return success;
    } catch (e) {
      AppLogger.error('Failed to leave group', e);
      rethrow;
    }
  }

  /// Transfer group ownership to a new owner atomically via Firestore transaction.
  /// Returns true if ownership transfer succeeded.
  Future<bool> transferGroupOwnership(UserProfile newOwner) async {
    if (_group == null) {
      throw StateError('Cannot transfer ownership without loaded group');
    }

    try {
      await executeAsync(() async {
        AppLogger.info(
          'Transferring ownership of "${_group!.name}" from ${_group!.ownerId} to ${newOwner.uid}',
        );

        // Use transactional transfer to prevent TOCTOU race conditions
        await _friendsService.friendsCategoryRepositoryInternal
            .transferOwnership(_group!.ownerId, groupId, newOwner.uid);

        // Refresh from authoritative source after transaction completes
        await loadGroupData();

        AppLogger.success(
          'Successfully transferred ownership of "${_group!.name}" to ${newOwner.displayName}',
        );
      });

      return true;
    } catch (e) {
      AppLogger.error('Failed to transfer group ownership', e);
      return false;
    }
  }

  /// Coordinate recipe sharing with this group.
  /// This method validates the group state and prepares for sharing.
  /// The actual sharing dialog presentation is handled by the View.
  /// Returns true if ready to show sharing dialog.
  bool canShareRecipeWithGroup() {
    if (_group == null) return false;
    if (!_permissionService.isAuthenticated) return false;
    return true;
  }

  /// Coordinate menu sharing with this group.
  /// Returns true if ready to show sharing dialog.
  bool canShareMenuWithGroup() {
    if (_group == null) return false;
    if (!_permissionService.isAuthenticated) return false;
    return true;
  }

  /// Coordinate shopping list sharing with this group.
  /// Returns true if ready to show sharing dialog.
  bool canShareShoppingListWithGroup() {
    if (_group == null) return false;
    if (!_permissionService.isAuthenticated) return false;
    return true;
  }

  /// Pick up to [maxCount] recipe suggestions from the household-filtered
  /// recipe pool for a "Vad ska vi äta?" poll. Biases toward variety by
  /// grouping by meal type and round-robining across types.
  /// Returns an empty list when the pool is empty (UI shows import CTA).
  Future<List<Recipe>> pickMealVoteSuggestions({int maxCount = 4}) async {
    final recipeService = ServiceLocator.get<UnifiedRecipeService>();
    final menuService = ServiceLocator.get<MenuService>();
    final generator = MenuGenerator(
      menuService: menuService,
      recipeService: recipeService,
      userService: _userService,
      filterByAllergens: true,
      filterByDietary: true,
    );

    final pool = generator.availableRecipes;
    if (pool.isEmpty) return const [];

    // Group by meal type to encourage variety — cheap deterministic
    // bucketing, no LLM involvement. Fall back to title hash when meal type
    // is missing so recipes without one still get distributed.
    final buckets = <String, List<Recipe>>{};
    for (final recipe in pool) {
      final rawMealType = recipe.mealType;
      final key = rawMealType.isNotEmpty
          ? rawMealType
          : (recipe.title.hashCode & 0x3).toString();
      buckets.putIfAbsent(key, () => []).add(recipe);
    }

    final picked = <Recipe>[];
    final bucketIterators = buckets.values
        .map((b) => b.iterator)
        .toList(growable: false);
    while (picked.length < maxCount) {
      var anyAdded = false;
      for (final it in bucketIterators) {
        if (picked.length >= maxCount) break;
        if (it.moveNext()) {
          picked.add(it.current);
          anyAdded = true;
        }
      }
      if (!anyAdded) break;
    }
    return picked;
  }

  /// Post [recipes] as a poll in this social group's chat and return the
  /// conversation id, or null on failure with [errorMessage] set.
  ///
  /// BUT-1856: the chat is created on the FIRST poll and reused by every later
  /// one. The roster comes from the social group, resolved server-side — this
  /// method deliberately does not read [members], because that list is built
  /// from profiles that may fail to load, and a profile that failed used to
  /// silently shrink the chat.
  ///
  /// The try/catch is load-bearing: `executeAsync` sets the error AND rethrows,
  /// so without it this method throws instead of returning null and the view's
  /// null branch never runs.
  Future<String?> startMealVotePoll({
    required String question,
    required List<Recipe> recipes,
    bool allowMultipleChoices = false,
  }) async {
    // Both early returns clear first: they sit ABOVE `executeAsync`, so its
    // clear-on-start never runs for them, and the view now renders
    // `errorMessage` — a message from an earlier failed poll would otherwise be
    // shown again for an unrelated refusal.
    final group = _group;
    if (group == null) {
      clearError();
      AppLogger.warning('Cannot start meal vote: group not loaded');
      return null;
    }
    final currentUserId = _permissionService.currentUserId;
    if (currentUserId == null) {
      clearError();
      AppLogger.warning('Cannot start meal vote: not authenticated');
      return null;
    }

    try {
      return await executeAsync(() async {
        final messagingService = ServiceLocator.get<MessagingService>();

        final conversationId = await messagingService.ensureCategoryChat(
          ownerId: group.ownerId,
          categoryId: group.id,
        );

        final options = recipes
            .map(
              (r) => PollOption.create(
                text: r.title,
                recipeId: r.id,
                recipeImageUrl: r.primaryImageUrl,
                recipePortions: r.portions,
              ),
            )
            .toList();

        final poll = Poll.fromOptions(
          question: question,
          options: options,
          creatorId: currentUserId,
          allowMultipleChoices: allowMultipleChoices,
        );

        await messagingService.sendPollMessage(
          conversationId: conversationId,
          pollData: poll.toMap(),
        );
        return conversationId;
      });
    } catch (e) {
      setError(
        ChatGroupErrorMapper.map(
          e,
          genericFallback: AppLocale.current.mealVotePollFailed,
        ),
      );
      return null;
    }
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }
}
