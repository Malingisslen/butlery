// lib/viewmodels/group_detail_viewmodel.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/messaging_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/mixins/state_notifier_mixin.dart';
import 'package:butlery/core/mixins/async_operation_mixin.dart';
import 'package:butlery/core/mixins/stream_management_mixin.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/l10n/app_locale.dart';

/// ViewModel for group conversation detail view with member management.
/// Manages complete group detail display and management workflow including real-time
/// conversation updates, member list display, add/remove member operations, group
/// settings management, and leave group functionality. Follows MVVM architecture
/// with proper state management and real-time synchronization.
/// **Core Responsibilities:**
/// - Stream real-time conversation updates from MessagingService
/// - Display group information (title, members, creation date)
/// - Manage member addition with friend selection
/// - Handle member removal (admin only)
/// - Implement leave group functionality for current user
/// - Update group settings (title, avatar, mute)
/// - Validate permissions for admin actions
/// **State Management:**
/// - Real-time conversation stream with auto-updates
/// - Current user ID for permission checks
/// - Loading and error states
/// - Member operation states (adding, removing)
/// - Validation for admin-only actions
/// **Usage Example:**
/// ```dart
/// final viewModel = GroupDetailViewModel(
///   conversationId: conversationId,
///   messagingService: messagingService,
///   friendsService: friendsService,
///   authRepository: authRepository,
/// );
/// // Listen to conversation updates
/// viewModel.conversation // Reactive updates
/// // Add members
/// await viewModel.addMembers([friendId1, friendId2]);
/// // Remove member (admin only)
/// await viewModel.removeMember(memberId);
/// // Leave group
/// await viewModel.leaveGroup();
/// ```
class GroupDetailViewModel extends ChangeNotifier
    with
        StreamManagementMixin,
        ErrorHandlingMixin,
        StateNotifierMixin,
        AsyncOperationMixin {
  final String _conversationId;
  final MessagingService _messagingService;
  final UnifiedFriendsService _friendsService;

  // State
  bool _isDisposed = false;
  Conversation? _conversation;
  // isLoading and error provided by StateNotifierMixin
  bool _isAddingMembers = false;
  bool _isRemovingMember = false;
  bool _isLeavingGroup = false;
  bool _isUpdatingTitle = false;
  StreamSubscription<List<Conversation>>? _conversationSubscription;

  GroupDetailViewModel({
    required String conversationId,
    required MessagingService messagingService,
    required UnifiedFriendsService friendsService,
  })  : _conversationId = conversationId,
        _messagingService = messagingService,
        _friendsService = friendsService {
    // Start in loading state until conversation data arrives
    setLoading(true);
    _initializeConversationStream();
  }

  // Getters
  Conversation? get conversation => _conversation;
  // isLoading and error provided by StateNotifierMixin
  bool get isAddingMembers => _isAddingMembers;
  bool get isRemovingMember => _isRemovingMember;
  bool get isLeavingGroup => _isLeavingGroup;
  bool get isUpdatingTitle => _isUpdatingTitle;
  bool get hasConversation => _conversation != null;
  String? get currentUserId =>
      ServiceLocator.get<PermissionService>().currentUserId;

  /// Check if current user is group admin/creator
  bool get isAdmin {
    if (_conversation == null || currentUserId == null) return false;
    final creatorId = _conversation!.metadata?['creatorId'] as String?;
    return creatorId == currentUserId;
  }

  /// Get list of member user profiles
  List<String> get memberIds {
    return _conversation?.participantIds ?? [];
  }

  /// Get count of members
  int get memberCount {
    return memberIds.length;
  }

  /// Get group title
  String get groupTitle {
    return _conversation?.title ?? AppLocale.current.labelChat;
  }

  /// Get group creation date
  DateTime? get createdAt {
    return _conversation?.createdAt;
  }

  /// Initialize real-time conversation stream
  void _initializeConversationStream() {
    if (_isDisposed) return;

    try {
      // Load conversation initially
      _loadConversation();

      // Listen to conversations list stream and filter for this conversation
      _conversationSubscription = _messagingService.getMyConversations().listen(
        (conversations) {
          // Find the conversation by ID, or use the cached one as fallback
          Conversation? conversation;
          try {
            conversation =
                conversations.firstWhere((c) => c.id == _conversationId);
          } catch (_) {
            // Conversation not in list, keep using cached version
            conversation = _conversation;
          }

          if (conversation != null) {
            _onConversationUpdate(conversation);
          }
        },
        onError: _onConversationError,
      );
    } catch (e) {
      AppLogger.error('❌ Failed to initialize conversation stream', e);
      _setError(AppLocale.current.errorCouldNotLoadGroupInfo);
    }
  }

  /// Reload conversation data (for retry on error)
  Future<void> reload() async {
    clearError();
    await _loadConversation();
  }

  /// Load conversation data initially
  Future<void> _loadConversation() async {
    try {
      final conversation =
          await _messagingService.getConversation(_conversationId);
      if (!_isDisposed && conversation != null) {
        _conversation = conversation;
        setSuccess();
      }
    } catch (e) {
      AppLogger.error('Failed to load conversation', e);
      if (!_isDisposed) {
        _setError(AppLocale.current.errorCouldNotLoadGroupInfo);
      }
    }
  }

  /// Handle conversation updates from stream
  void _onConversationUpdate(Conversation? conversation) {
    if (_isDisposed) return;

    _conversation = conversation;
    setSuccess();

    if (conversation != null) {
      AppLogger.debug('Conversation updated: ${conversation.title}');
    }
  }

  /// Handle conversation stream errors
  void _onConversationError(dynamic error) {
    if (_isDisposed) return;

    AppLogger.error('❌ Conversation stream error', error);
    _setError(AppLocale.current.errorCouldNotLoadGroupInfo);
  }

  void _setError(String errorMessage) {
    setError(errorMessage);
  }

  Future<bool> addMembers(
    List<String> memberIds,
    Map<String, String> memberDisplayNames,
    Map<String, String?>? memberAvatarUrls,
  ) async {
    if (_isDisposed || _conversation == null) return false;

    if (!isAdmin) {
      setError(AppLocale.current.errorOnlyAdminCanAddMembers);
      return false;
    }

    _isAddingMembers = true;
    clearError();
    _safeNotifyListeners();

    try {
      AppLogger.info('Adding ${memberIds.length} members to group');

      await _messagingService.addParticipantsToGroup(
        conversationId: _conversationId,
        participantIds: memberIds,
        participantDisplayNames: memberDisplayNames,
        participantAvatarUrls: memberAvatarUrls ?? {},
      );

      if (_isDisposed) return false;

      AppLogger.success('Successfully added ${memberIds.length} members');

      _isAddingMembers = false;
      _safeNotifyListeners();

      return true;
    } catch (e) {
      AppLogger.error('Failed to add members', e);

      if (_isDisposed) return false;

      setError(AppLocale.current.errorCouldNotAddMembers);
      _isAddingMembers = false;
      _safeNotifyListeners();

      return false;
    }
  }

  Future<bool> removeMember(String memberId) async {
    if (_isDisposed || _conversation == null) return false;

    if (!isAdmin) {
      setError(AppLocale.current.errorOnlyAdminCanRemoveMembers);
      return false;
    }

    if (memberId == currentUserId) {
      setError(AppLocale.current.errorUseLeaveGroupToLeave);
      return false;
    }

    _isRemovingMember = true;
    clearError();
    _safeNotifyListeners();

    try {
      AppLogger.info('Removing member $memberId from group');

      await _messagingService.removeParticipantFromGroup(
        conversationId: _conversationId,
        participantId: memberId,
      );

      if (_isDisposed) return false;

      AppLogger.success('Successfully removed member');

      _isRemovingMember = false;
      _safeNotifyListeners();

      return true;
    } catch (e) {
      AppLogger.error('Failed to remove member', e);

      if (_isDisposed) return false;

      setError(AppLocale.current.errorCouldNotDelete('medlem'));
      _isRemovingMember = false;
      _safeNotifyListeners();

      return false;
    }
  }

  Future<bool> leaveGroup() async {
    if (_isDisposed || _conversation == null || currentUserId == null) {
      return false;
    }

    _isLeavingGroup = true;
    clearError();
    _safeNotifyListeners();

    try {
      AppLogger.info('Current user leaving group');

      await _messagingService.removeParticipantFromGroup(
        conversationId: _conversationId,
        participantId: currentUserId!,
      );

      if (_isDisposed) return false;

      AppLogger.success('Successfully left group');

      _isLeavingGroup = false;
      _safeNotifyListeners();

      return true;
    } catch (e) {
      AppLogger.error('Failed to leave group', e);

      if (_isDisposed) return false;

      setError(AppLocale.current.errorCouldNotLeaveGroup);
      _isLeavingGroup = false;
      _safeNotifyListeners();

      return false;
    }
  }

  Future<bool> updateGroupTitle(String newTitle) async {
    if (_isDisposed || _conversation == null) return false;

    if (!isAdmin) {
      setError(AppLocale.current.errorOnlyAdminCanChangeGroupName);
      return false;
    }

    if (newTitle.trim().isEmpty) {
      setError(AppLocale.current.errorGroupNameCannotBeEmpty);
      return false;
    }

    _isUpdatingTitle = true;
    clearError();
    _safeNotifyListeners();

    try {
      AppLogger.info('Updating group title to: $newTitle');

      await _messagingService.updateGroupTitle(
        conversationId: _conversationId,
        newTitle: newTitle.trim(),
      );

      if (_isDisposed) return false;

      AppLogger.success('Successfully updated group title');

      _isUpdatingTitle = false;
      _safeNotifyListeners();

      return true;
    } catch (e) {
      AppLogger.error('Failed to update group title', e);

      if (_isDisposed) return false;

      setError(AppLocale.current.errorCouldNotUpdate('gruppnamn'));
      _isUpdatingTitle = false;
      _safeNotifyListeners();

      return false;
    }
  }

  Future<List<UserProfile>> getAvailableFriendsToAdd() async {
    try {
      final allFriends = _friendsService.friends;

      final currentMemberIds = memberIds.toSet();
      return allFriends
          .where((friend) => !currentMemberIds.contains(friend.uid))
          .toList();
    } catch (e) {
      AppLogger.error('Failed to get available friends', e);
      return [];
    }
  }

  /// Get member display name by ID
  String getMemberDisplayName(String memberId) {
    return _conversation?.participantDisplayNames[memberId] ?? '?';
  }

  /// Get member avatar URL by ID
  String? getMemberAvatarUrl(String memberId) {
    return _conversation?.participantAvatarUrls[memberId];
  }

  /// Safe notify listeners with disposal check
  void _safeNotifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _conversationSubscription?.cancel();
    cancelAllOperations();
    disposeStreamResources();
    super.dispose();
  }
}
