// lib/viewmodels/group_detail_viewmodel.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/messaging_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/mixins/stream_management_mixin.dart';
import 'package:butlery/core/utils/logger.dart';

/// ViewModel for group conversation detail view with member management.
///
/// Manages complete group detail display and management workflow including real-time
/// conversation updates, member list display, add/remove member operations, group
/// settings management, and leave group functionality. Follows MVVM architecture
/// with proper state management and real-time synchronization.
///
/// **Core Responsibilities:**
/// - Stream real-time conversation updates from MessagingService
/// - Display group information (title, members, creation date)
/// - Manage member addition with friend selection
/// - Handle member removal (admin only)
/// - Implement leave group functionality for current user
/// - Update group settings (title, avatar, mute)
/// - Validate permissions for admin actions
///
/// **State Management:**
/// - Real-time conversation stream with auto-updates
/// - Current user ID for permission checks
/// - Loading and error states
/// - Member operation states (adding, removing)
/// - Validation for admin-only actions
///
/// **Usage Example:**
/// ```dart
/// final viewModel = GroupDetailViewModel(
///   conversationId: conversationId,
///   messagingService: messagingService,
///   friendsService: friendsService,
///   authRepository: authRepository,
/// );
///
/// // Listen to conversation updates
/// viewModel.conversation // Reactive updates
///
/// // Add members
/// await viewModel.addMembers([friendId1, friendId2]);
///
/// // Remove member (admin only)
/// await viewModel.removeMember(memberId);
///
/// // Leave group
/// await viewModel.leaveGroup();
/// ```
class GroupDetailViewModel extends ChangeNotifier
    with StreamManagementMixin, ErrorHandlingMixin {
  final String _conversationId;
  final MessagingService _messagingService;
  final UnifiedFriendsService _friendsService;
  final AuthRepository _authRepository;

  // State
  bool _isDisposed = false;
  Conversation? _conversation;
  bool _isLoading = true;
  String? _error;
  bool _isAddingMembers = false;
  bool _isRemovingMember = false;
  bool _isLeavingGroup = false;
  bool _isUpdatingTitle = false;
  StreamSubscription<List<Conversation>>? _conversationSubscription;

  GroupDetailViewModel({
    required String conversationId,
    required MessagingService messagingService,
    required UnifiedFriendsService friendsService,
    required AuthRepository authRepository,
  })  : _conversationId = conversationId,
        _messagingService = messagingService,
        _friendsService = friendsService,
        _authRepository = authRepository {
    _initializeConversationStream();
  }

  // Getters
  Conversation? get conversation => _conversation;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAddingMembers => _isAddingMembers;
  bool get isRemovingMember => _isRemovingMember;
  bool get isLeavingGroup => _isLeavingGroup;
  bool get isUpdatingTitle => _isUpdatingTitle;
  bool get hasConversation => _conversation != null;
  String? get currentUserId => _authRepository.currentUserId;

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
    return _conversation?.title ?? 'Gruppkonversation';
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
      _conversationSubscription = _messagingService
          .getMyConversations()
          .listen(
            (conversations) {
              // Find the conversation by ID, or use the cached one as fallback
              Conversation? conversation;
              try {
                conversation = conversations.firstWhere((c) => c.id == _conversationId);
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
      _setError('Kunde inte ladda gruppinformation');
    }
  }

  /// Load conversation data initially
  Future<void> _loadConversation() async {
    try {
      final conversation = await _messagingService.getConversation(_conversationId);
      if (!_isDisposed && conversation != null) {
        _conversation = conversation;
        _isLoading = false;
        _safeNotifyListeners();
      }
    } catch (e) {
      AppLogger.error('❌ Failed to load conversation', e);
      if (!_isDisposed) {
        _setError('Kunde inte ladda gruppinformation');
      }
    }
  }

  /// Handle conversation updates from stream
  void _onConversationUpdate(Conversation? conversation) {
    if (_isDisposed) return;

    _conversation = conversation;
    _isLoading = false;
    _error = null;
    _safeNotifyListeners();

    if (conversation != null) {
      AppLogger.debug('✅ Conversation updated: ${conversation.title}');
    }
  }

  /// Handle conversation stream errors
  void _onConversationError(dynamic error) {
    if (_isDisposed) return;

    AppLogger.error('❌ Conversation stream error', error);
    _setError('Kunde inte ladda gruppinformation');
  }

  /// Set error state
  void _setError(String error) {
    _error = error;
    _isLoading = false;
    _safeNotifyListeners();
  }

  /// Add members to group
  ///
  /// [memberIds] List of user IDs to add
  /// [memberDisplayNames] Map of display names for new members
  /// [memberAvatarUrls] Optional map of avatar URLs
  ///
  /// Returns true if successful
  Future<bool> addMembers(
    List<String> memberIds,
    Map<String, String> memberDisplayNames,
    Map<String, String?>? memberAvatarUrls,
  ) async {
    if (_isDisposed || _conversation == null) return false;

    _isAddingMembers = true;
    _error = null;
    _safeNotifyListeners();

    try {
      AppLogger.info('🔄 Adding ${memberIds.length} members to group');

      await _messagingService.addParticipantsToGroup(
        conversationId: _conversationId,
        participantIds: memberIds,
        participantDisplayNames: memberDisplayNames,
        participantAvatarUrls: memberAvatarUrls ?? {},
      );

      if (_isDisposed) return false;

      AppLogger.success('✅ Successfully added ${memberIds.length} members');

      _isAddingMembers = false;
      _safeNotifyListeners();

      return true;
    } catch (e) {
      AppLogger.error('❌ Failed to add members', e);

      if (_isDisposed) return false;

      _error = 'Kunde inte lägga till medlemmar: ${e.toString()}';
      _isAddingMembers = false;
      _safeNotifyListeners();

      return false;
    }
  }

  /// Remove member from group (admin only)
  ///
  /// [memberId] User ID of member to remove
  ///
  /// Returns true if successful
  Future<bool> removeMember(String memberId) async {
    if (_isDisposed || _conversation == null) return false;

    // Verify admin permission
    if (!isAdmin) {
      _error = 'Endast administratör kan ta bort medlemmar';
      _safeNotifyListeners();
      return false;
    }

    // Prevent removing self this way (use leaveGroup instead)
    if (memberId == currentUserId) {
      _error = 'Använd "Lämna grupp" för att lämna konversationen';
      _safeNotifyListeners();
      return false;
    }

    _isRemovingMember = true;
    _error = null;
    _safeNotifyListeners();

    try {
      AppLogger.info('🔄 Removing member $memberId from group');

      await _messagingService.removeParticipantFromGroup(
        conversationId: _conversationId,
        participantId: memberId,
      );

      if (_isDisposed) return false;

      AppLogger.success('✅ Successfully removed member');

      _isRemovingMember = false;
      _safeNotifyListeners();

      return true;
    } catch (e) {
      AppLogger.error('❌ Failed to remove member', e);

      if (_isDisposed) return false;

      _error = 'Kunde inte ta bort medlem: ${e.toString()}';
      _isRemovingMember = false;
      _safeNotifyListeners();

      return false;
    }
  }

  /// Leave group (current user leaves conversation)
  ///
  /// Returns true if successful
  Future<bool> leaveGroup() async {
    if (_isDisposed || _conversation == null || currentUserId == null) {
      return false;
    }

    _isLeavingGroup = true;
    _error = null;
    _safeNotifyListeners();

    try {
      AppLogger.info('🔄 Current user leaving group');

      // Use removeParticipant with current user's ID
      await _messagingService.removeParticipantFromGroup(
        conversationId: _conversationId,
        participantId: currentUserId!,
      );

      if (_isDisposed) return false;

      AppLogger.success('✅ Successfully left group');

      _isLeavingGroup = false;
      _safeNotifyListeners();

      return true;
    } catch (e) {
      AppLogger.error('❌ Failed to leave group', e);

      if (_isDisposed) return false;

      _error = 'Kunde inte lämna grupp: ${e.toString()}';
      _isLeavingGroup = false;
      _safeNotifyListeners();

      return false;
    }
  }

  /// Update group title (admin only)
  ///
  /// [newTitle] New title for the group
  ///
  /// Returns true if successful
  Future<bool> updateGroupTitle(String newTitle) async {
    if (_isDisposed || _conversation == null) return false;

    // Verify admin permission
    if (!isAdmin) {
      _error = 'Endast administratör kan ändra gruppnamn';
      _safeNotifyListeners();
      return false;
    }

    if (newTitle.trim().isEmpty) {
      _error = 'Gruppnamn kan inte vara tomt';
      _safeNotifyListeners();
      return false;
    }

    _isUpdatingTitle = true;
    _error = null;
    _safeNotifyListeners();

    try {
      AppLogger.info('🔄 Updating group title to: $newTitle');

      await _messagingService.updateGroupTitle(
        conversationId: _conversationId,
        newTitle: newTitle.trim(),
      );

      if (_isDisposed) return false;

      AppLogger.success('✅ Successfully updated group title');

      _isUpdatingTitle = false;
      _safeNotifyListeners();

      return true;
    } catch (e) {
      AppLogger.error('❌ Failed to update group title', e);

      if (_isDisposed) return false;

      _error = 'Kunde inte uppdatera gruppnamn: ${e.toString()}';
      _isUpdatingTitle = false;
      _safeNotifyListeners();

      return false;
    }
  }

  /// Get available friends to add (not already in group)
  Future<List<UserProfile>> getAvailableFriendsToAdd() async {
    try {
      final allFriends = _friendsService.friends;

      // Filter out users already in the group
      final currentMemberIds = memberIds.toSet();
      return allFriends
          .where((friend) => !currentMemberIds.contains(friend.uid))
          .toList();
    } catch (e) {
      AppLogger.error('❌ Failed to get available friends', e);
      return [];
    }
  }

  /// Get member display name by ID
  String getMemberDisplayName(String memberId) {
    return _conversation?.participantDisplayNames[memberId] ?? 'Okänd';
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
    disposeStreamResources();
    super.dispose();
  }
}
