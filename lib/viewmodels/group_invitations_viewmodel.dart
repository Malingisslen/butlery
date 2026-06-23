// lib/viewmodels/group_invitations_viewmodel.dart - UPPDATERAD med GroupInvitationService

import 'package:flutter/foundation.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/group_invitation.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/mixins/async_operation_mixin.dart';
import 'package:butlery/core/mixins/state_notifier_mixin.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/user_service.dart';

class GroupInvitationsViewModel extends ChangeNotifier
    with ErrorHandlingMixin, StateNotifierMixin, AsyncOperationMixin {
  final UnifiedFriendsService _friendsService;

  List<FriendCategory> _availableGroups = [];
  final Map<String, List<UserProfile>> _groupMembers = {};
  final Set<String> _joiningGroupIds =
      {}; // Operation-specific tracking for concurrent joins
  List<GroupInvitation> _receivedInvitations = [];
  final Set<String> _respondingInvitationIds =
      {}; // Operation-specific tracking for concurrent responses

  late final AnalyticsService? _analytics =
      ServiceLocator.tryGet<AnalyticsService>();

  GroupInvitationsViewModel({
    required UnifiedFriendsService friendsService,
  }) : _friendsService = friendsService {
    _initializeData();
  }

  /// Available groups that the user can join
  List<FriendCategory> get availableGroups =>
      List.unmodifiable(_availableGroups);

  /// Get members for a specific group
  List<UserProfile> getMembersForGroup(String groupId) {
    return _groupMembers[groupId] ?? [];
  }

  /// Check if a specific group is being joined
  bool isJoiningGroup(String groupId) => _joiningGroupIds.contains(groupId);

  /// Received group invitations (pending)
  List<GroupInvitation> get receivedInvitations => List.unmodifiable(
    _receivedInvitations
        .where((inv) => inv.status == GroupInvitationStatus.pending)
        .toList(),
  );

  /// Alla mottagna inbjudningar (inklusive avslutade)
  List<GroupInvitation> get allReceivedInvitations =>
      List.unmodifiable(_receivedInvitations);

  /// Number of pending invitations (for badge/notification)
  int get pendingInvitationsCount => receivedInvitations.length;

  /// Check if a specific invitation is being responded to
  bool isRespondingToInvitation(String invitationId) =>
      _respondingInvitationIds.contains(invitationId);

  /// isLoading, error, hasError provided by StateNotifierMixin

  /// Current user
  String? get _currentUserId =>
      ServiceLocator.get<PermissionService>().currentUserId;

  /// Kombinerat "har något att visa" state
  bool get hasContent =>
      availableGroups.isNotEmpty || receivedInvitations.isNotEmpty;
  Future<void> _initializeData() async {
    await Future.wait([
      _loadAvailableGroups(),
      _loadReceivedInvitations(),
    ]);
  }

  Future<void> _loadAvailableGroups() async {
    try {
      await executeNamedOperation('loadGroups', () async {
        AppLogger.info('🔄 Laddar tillgängliga grupper för användare...');

        final currentUserId = _currentUserId;
        if (currentUserId == null) {
          throw Exception(AppLocale.current.errorNoUserLoggedIn);
        }

        // Fetch all groups
        final allGroups = _friendsService.categories.getAllCategories();

        // Filter out groups where the user is already a member or admin
        _availableGroups = allGroups.where((group) {
          // Skip groups where the user is already a member
          if (group.friendUserIds.contains(currentUserId)) {
            return false;
          }

          // Skip groups that the user owns
          if (group.createdBy == currentUserId) {
            return false;
          }

          return true;
        }).toList();

        AppLogger.info(
          '📋 ${_availableGroups.length} tillgängliga grupper att gå med i',
        );

        // Load members for each group
        await _loadMembersForGroups();
      });
    } catch (e) {
      AppLogger.error('❌ Kunde inte ladda tillgängliga grupper', e);
      setError(extractUserMessage(e));
    }
  }

  Future<void> _loadMembersForGroups() async {
    for (final group in _availableGroups) {
      try {
        // Fetch friend profiles for group members
        final allFriends = _friendsService.management.getAllFriends();
        final groupMembers = allFriends
            .where((friend) => group.friendUserIds.contains(friend.uid))
            .toList();

        _groupMembers[group.id] = groupMembers;

        AppLogger.info(
          '👥 ${groupMembers.length} medlemmar laddade för grupp "${group.name}"',
        );
      } catch (e) {
        AppLogger.warning(
          '⚠️ Kunde inte ladda medlemmar för grupp "${group.name}": $e',
        );
        _groupMembers[group.id] = [];
      }
    }
  }

  Future<void> _loadReceivedInvitations() async {
    try {
      AppLogger.info('🔄 Laddar mottagna gruppinbjudningar...');

      // Friends service invitations is always available

      // Get received invitations properly via repository
      _receivedInvitations =
          _friendsService.invitations.pendingReceivedInvitations;

      // Add detailed debugging information
      AppLogger.info('📊 Invitation loading details:');
      AppLogger.info(
        '  - Raw invitations count: ${_receivedInvitations.length}',
      );
      AppLogger.info(
        '  - Pending invitations count: ${receivedInvitations.length}',
      );

      // Log individual invitations for debugging
      for (int i = 0; i < _receivedInvitations.length && i < 5; i++) {
        final invitation = _receivedInvitations[i];
        AppLogger.info(
          '  - Invitation $i: from=${invitation.fromUserName}, group=${invitation.groupName}, status=${invitation.status}',
        );
      }

      if (_receivedInvitations.length > 5) {
        AppLogger.info(
          '  - And ${_receivedInvitations.length - 5} more invitations...',
        );
      }

      AppLogger.success(
        '✅ Successfully loaded ${receivedInvitations.length} pending invitations',
      );
    } catch (e, stackTrace) {
      AppLogger.error('❌ Failed to load received invitations', e);
      AppLogger.debug('Stack trace: $stackTrace');

      // Ensure we always have a valid state
      _receivedInvitations = [];

      // Add user-friendly error state
      AppLogger.warning('⚠️ Using empty invitations list as fallback');
    } finally {
      // Always notify listeners to update UI
      notifyListeners();
    }
  }

  /// Join a group (existing functionality)
  Future<void> joinGroup(String groupId) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      setError(AppLocale.current.errorNoUserLoggedIn);
      return;
    }

    if (_joiningGroupIds.contains(groupId)) {
      AppLogger.warning('⚠️ Redan håller på att gå med i grupp $groupId');
      return;
    }

    try {
      _joiningGroupIds.add(groupId);
      clearError();
      notifyListeners();

      final group = _availableGroups.firstWhere(
        (g) => g.id == groupId,
        orElse: () => throw Exception(AppLocale.current.errorGroupNotFound),
      );

      AppLogger.info('🔄 Går med i grupp "${group.name}"...');

      // Use UnifiedFriendsService to add the user as a member
      final success = await _friendsService.categories.assignFriendToCategory(
        currentUserId,
        groupId,
      );

      if (success) {
        AppLogger.success('✅ Gick med i grupp "${group.name}" framgångsrikt!');

        // Remove the group from available groups
        _availableGroups.removeWhere((g) => g.id == groupId);
        _groupMembers.remove(groupId);

        // Logga analytics event
        _logJoinGroupEvent(group);
      } else {
        final errorMessage =
            _friendsService.error ??
            AppLocale.current.errorCouldNotUpdate('grupp');
        throw Exception(errorMessage);
      }
    } catch (e) {
      AppLogger.error('❌ Fel vid gruppmedlemskap', e);
      setError(extractUserMessage(e));
    } finally {
      _joiningGroupIds.remove(groupId);
      notifyListeners();
    }
  }

  /// Acceptera gruppinbjudan
  Future<void> acceptInvitation(String invitationId) async {
    if (_respondingInvitationIds.contains(invitationId)) {
      AppLogger.warning(
        '⚠️ Redan håller på att besvara inbjudan $invitationId',
      );
      return;
    }

    try {
      _respondingInvitationIds.add(invitationId);
      clearError();
      notifyListeners();

      final invitation = _receivedInvitations.firstWhere(
        (inv) => inv.id == invitationId,
        orElse: () =>
            throw Exception(AppLocale.current.errorInvitationNotFound),
      );

      AppLogger.info(
        '🔄 Accepterar inbjudan från "${invitation.fromUserName}"...',
      );

      // Use UnifiedFriendsService to accept invitation and join the group
      // BUG-018 FIX: Use acceptGroupInvitation which adds user to friendUserIds
      final success = await _friendsService.invitations.acceptGroupInvitation(
        invitationId,
      );

      if (success) {
        AppLogger.success(
          '✅ Inbjudan accepterad från "${invitation.fromUserName}"',
        );

        // Update local state - remove from pending invitations
        await _loadReceivedInvitations();

        // Update available groups (remove the group since we are now members)
        await _loadAvailableGroups();

        // Logga analytics event
        _logAcceptInvitationEvent(invitation);
      } else {
        final errorMessage =
            _friendsService.error ??
            AppLocale.current.errorCouldNotUpdate('inbjudan');
        throw Exception(errorMessage);
      }
    } catch (e) {
      AppLogger.error('❌ Fel vid acceptans av inbjudan', e);
      setError(extractUserMessage(e));
    } finally {
      _respondingInvitationIds.remove(invitationId);
      notifyListeners();
    }
  }

  /// Avvisa gruppinbjudan
  Future<void> rejectInvitation(String invitationId) async {
    if (_respondingInvitationIds.contains(invitationId)) {
      AppLogger.warning(
        '⚠️ Redan håller på att besvara inbjudan $invitationId',
      );
      return;
    }

    try {
      _respondingInvitationIds.add(invitationId);
      clearError();
      notifyListeners();

      final invitation = _receivedInvitations.firstWhere(
        (inv) => inv.id == invitationId,
        orElse: () =>
            throw Exception(AppLocale.current.errorInvitationNotFound),
      );

      AppLogger.info(
        '🔄 Avvisar inbjudan från "${invitation.fromUserName}"...',
      );

      // Use UnifiedFriendsService to decline
      final success = await _friendsService.invitations.cancelInvitation(
        invitationId,
      );

      if (success) {
        AppLogger.info('❌ Inbjudan avvisad från "${invitation.fromUserName}"');

        // Uppdatera lokal state
        await _loadReceivedInvitations();

        // Logga analytics event
        _logRejectInvitationEvent(invitation);
      } else {
        final errorMessage =
            _friendsService.error ??
            AppLocale.current.errorCouldNotDelete('inbjudan');
        throw Exception(errorMessage);
      }
    } catch (e) {
      AppLogger.error('❌ Fel vid avvisning av inbjudan', e);
      setError(extractUserMessage(e));
    } finally {
      _respondingInvitationIds.remove(invitationId);
      notifyListeners();
    }
  }

  /// Uppdatera data
  Future<void> refresh() async {
    AppLogger.info('🔄 Refreshar gruppinbjudningsdata...');

    try {
      // Refresh underlying services first
      // UnifiedFriendsService hanterar refresh internt

      // Reload both types of data
      await _initializeData();

      AppLogger.success('✅ Gruppinbjudningsdata refreshad');
    } catch (e) {
      AppLogger.error('❌ Fel vid refresh av gruppinbjudningsdata', e);
      // Do not show error here - user already sees data from cache
    }
  }

  /// Get group statistics (existing + new data)
  Map<String, dynamic> getGroupStats() {
    return {
      'availableGroups': _availableGroups.length,
      'pendingInvitations': receivedInvitations.length,
      'totalInvitations': _receivedInvitations.length,
      'totalMembers': _groupMembers.values
          .expand((members) => members)
          .toSet()
          .length,
      'averageMembersPerGroup': _availableGroups.isEmpty
          ? 0
          : _availableGroups.map((g) => g.friendCount).reduce((a, b) => a + b) /
                _availableGroups.length,
    };
  }

  /// Check if a group is available for membership
  bool isGroupAvailable(String groupId) {
    return _availableGroups.any((group) => group.id == groupId);
  }

  /// Get group object by ID
  FriendCategory? getGroupById(String groupId) {
    try {
      return _availableGroups.firstWhere((group) => group.id == groupId);
    } catch (e) {
      return null;
    }
  }

  /// Public method to clear errors (for external/test use)
  /// Overrides protected clearError from StateNotifierMixin to make it public
  @override
  void clearError() {
    super.clearError();
  }

  /// Log analytics for group membership (existing)
  void _logJoinGroupEvent(FriendCategory group) {
    try {
      AppLogger.info(
        '📊 Analytics: Användare gick med i grupp "${group.name}" (${group.friendCount} medlemmar)',
      );
    } catch (e) {
      AppLogger.warning('⚠️ Kunde inte logga join group event: $e');
    }
  }

  /// Log analytics for accepted invitation
  void _logAcceptInvitationEvent(GroupInvitation invitation) {
    try {
      AppLogger.info(
        '📊 Analytics: Användare accepterade inbjudan från ${invitation.fromUserName}',
      );
      _analytics?.social.logGroupJoined(
        groupId: invitation.groupId,
        source: 'invitation',
      );

      // First-group milestone fires at most once per user (BUT-593) — covers
      // both the join path and the create path.
      final userService = ServiceLocator.tryGet<UserService>();
      _analytics?.social.logFirstGroupIfMilestone(
        userId: userService?.currentUserId,
        joinedAt: userService?.currentUserProfile?.joinedAt,
      );
    } catch (e) {
      AppLogger.warning('⚠️ Kunde inte logga accept invitation event: $e');
    }
  }

  /// Log analytics for declined invitation
  void _logRejectInvitationEvent(GroupInvitation invitation) {
    try {
      AppLogger.info(
        '📊 Analytics: Användare avvisade inbjudan från ${invitation.fromUserName}',
      );
    } catch (e) {
      AppLogger.warning('⚠️ Kunde inte logga reject invitation event: $e');
    }
  }

  @override
  void dispose() {
    AppLogger.info('🗑️ GroupInvitationsViewModel disposed');
    super.dispose();
  }
}
