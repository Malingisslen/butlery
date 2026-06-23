// lib/viewmodels/create_group_conversation_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/messaging_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/mixins/async_operation_mixin.dart';
import 'package:butlery/core/mixins/state_notifier_mixin.dart';
import 'package:butlery/core/l10n/app_locale.dart';

/// ViewModel for messaging group conversation creation with friend selection and validation.
/// Manages complete group conversation creation workflow including friend list loading,
/// member selection, group name validation, and conversation creation through MessagingService.
/// Follows MVVM architecture with AsyncOperationMixin for state management.
/// **Core Responsibilities:**
/// - Load available friends for group member selection (loading managed by AsyncOperationMixin)
/// - Manage selected members set with add/remove operations
/// - Validate group name and member count requirements (minimum 2 members)
/// - Create group conversation via MessagingService
/// - Handle loading states and error conditions with Swedish messages
/// **State Management:**
/// - General loading/error managed by StateNotifierMixin
/// - Operation-specific _isCreatingGroup for distinct UI treatment
/// - Available friends list from UnifiedFriendsService
/// - Selected members set for multi-selection
/// - Group name and optional avatar URL
/// - Validation state for creation button
/// **Usage Example:**
/// ```dart
/// final viewModel = CreateGroupConversationViewModel(
///   messagingService: messagingService,
///   friendsService: friendsService,
/// );
/// // Load friends
/// await viewModel.loadFriends();
/// // Select members
/// viewModel.toggleMemberSelection(friend.uid);
/// // Set group name
/// viewModel.updateGroupName('Min familj');
/// // Create conversation
/// final conversationId = await viewModel.createGroupConversation();
/// if (conversationId != null) {
///   // Navigate to chat
/// }
/// ```
class CreateGroupConversationViewModel extends ChangeNotifier
    with ErrorHandlingMixin, StateNotifierMixin, AsyncOperationMixin {
  final MessagingService _messagingService;
  final UnifiedFriendsService _friendsService;

  // State
  bool _isDisposed = false;
  List<UserProfile> _availableFriends = [];
  final Set<String> _selectedMemberIds = {};
  String _groupName = '';
  String? _groupAvatarUrl;

  /// isLoading, error, hasError provided by StateNotifierMixin
  bool _isCreatingGroup = false; // Operation-specific state for group creation
  String? _validationError;

  CreateGroupConversationViewModel({
    required MessagingService messagingService,
    required UnifiedFriendsService friendsService,
  }) : _messagingService = messagingService,
       _friendsService = friendsService;

  // Getters
  List<UserProfile> get availableFriends => _availableFriends;
  Set<String> get selectedMemberIds => _selectedMemberIds;
  List<UserProfile> get selectedMembers => _availableFriends
      .where((f) => _selectedMemberIds.contains(f.uid))
      .toList();
  String get groupName => _groupName;
  String? get groupAvatarUrl => _groupAvatarUrl;

  /// isLoading, error, hasError provided by StateNotifierMixin
  bool get isCreatingGroup => _isCreatingGroup; // Operation-specific state
  String? get validationError => _validationError;
  int get selectedMemberCount => _selectedMemberIds.length;
  bool get hasSelectedMembers => _selectedMemberIds.isNotEmpty;
  bool get canCreateGroup =>
      _groupName.trim().isNotEmpty &&
      _selectedMemberIds.length >= 2 &&
      !_isCreatingGroup;

  /// Load available friends for group member selection.
  /// Fetches complete friend list from UnifiedFriendsService and updates
  /// available friends state. Handles loading states and errors via AsyncOperationMixin.
  Future<void> loadFriends() async {
    if (_isDisposed) return;

    try {
      await executeNamedOperation('loadFriends', () async {
        AppLogger.info('🔄 Laddar vänner för gruppkonversation...');

        final friends = _friendsService.friends;

        if (_isDisposed) return;

        _availableFriends = friends;

        AppLogger.success('✅ Laddade ${friends.length} vänner');
      });
    } catch (e) {
      AppLogger.error('❌ Misslyckades ladda vänner', e);

      if (_isDisposed) return;

      setError(AppLocale.current.errorGeneric);
    }
  }

  /// Toggle friend selection for group membership.
  /// [friendId] User ID of friend to toggle
  void toggleMemberSelection(String friendId) {
    if (_isDisposed) return;

    if (_selectedMemberIds.contains(friendId)) {
      _selectedMemberIds.remove(friendId);
      AppLogger.debug('Ta bort vän $friendId från grupp');
    } else {
      _selectedMemberIds.add(friendId);
      AppLogger.debug('Lägg till vän $friendId i grupp');
    }

    _validateGroupCreation();
    _safeNotifyListeners();
  }

  /// Check if friend is selected.
  /// [friendId] User ID to check
  /// Returns true if selected
  bool isMemberSelected(String friendId) {
    return _selectedMemberIds.contains(friendId);
  }

  /// Update group name with validation.
  /// [name] New group name
  void updateGroupName(String name) {
    if (_isDisposed) return;

    _groupName = name;
    _validateGroupCreation();
    _safeNotifyListeners();
  }

  /// Update optional group avatar URL.
  /// [avatarUrl] URL of group avatar
  void updateGroupAvatar(String? avatarUrl) {
    if (_isDisposed) return;

    _groupAvatarUrl = avatarUrl;
    _safeNotifyListeners();
  }

  /// Clear current member selection.
  void clearSelection() {
    if (_isDisposed) return;

    _selectedMemberIds.clear();
    _validateGroupCreation();
    _safeNotifyListeners();
  }

  /// Validate group creation requirements.
  /// Requires non-empty group name and at least 2 members.
  void _validateGroupCreation() {
    if (_groupName.trim().isEmpty) {
      _validationError = AppLocale.current.errorFillRequiredFields;
    } else if (_selectedMemberIds.length < 2) {
      _validationError = AppLocale.current.errorSelectAtLeastOneFriend;
    } else {
      _validationError = null;
    }
  }

  /// Create group conversation with selected members.
  /// Returns conversation ID if successful, null if failed.
  Future<String?> createGroupConversation() async {
    if (_isDisposed) return null;

    // Validate before creation
    _validateGroupCreation();
    if (_validationError != null) {
      setError(_validationError!);
      return null;
    }

    _isCreatingGroup = true;
    clearError();
    _safeNotifyListeners();

    try {
      AppLogger.info(
        '🔄 Skapar gruppkonversation: $_groupName med ${_selectedMemberIds.length} medlemmar',
      );

      // Build participant maps for group conversation
      final participantIds = _selectedMemberIds.toList();
      final participantDisplayNames = <String, String>{};
      final participantAvatarUrls = <String, String?>{};

      // Get display names and avatar URLs for selected members
      for (final friendId in _selectedMemberIds) {
        final friend = _availableFriends.firstWhere(
          (f) => f.uid == friendId,
          orElse: () => throw Exception('Friend not found: $friendId'),
        );
        participantDisplayNames[friendId] = friend.displayName;
        participantAvatarUrls[friendId] = friend.avatarUrl;
      }

      // Create group conversation
      final conversationId = await _messagingService.createGroupConversation(
        participantIds: participantIds,
        participantDisplayNames: participantDisplayNames,
        participantAvatarUrls: participantAvatarUrls,
        title: _groupName.trim(),
      );

      if (_isDisposed) return null;

      AppLogger.success('✅ Gruppkonversation skapad: $conversationId');

      _isCreatingGroup = false;
      _safeNotifyListeners();

      return conversationId;
    } catch (e) {
      AppLogger.error('❌ Misslyckades skapa gruppkonversation', e);

      if (_isDisposed) return null;

      setError(AppLocale.current.errorCouldNotCreateGroup);
      _isCreatingGroup = false;
      _safeNotifyListeners();

      return null;
    }
  }

  /// Search and filter friends by display name.
  /// [query] Search query
  /// Returns filtered friend list
  List<UserProfile> searchFriends(String query) {
    if (query.trim().isEmpty) {
      return _availableFriends;
    }

    final lowerQuery = query.trim().toLowerCase();
    return _availableFriends
        .where(
          (friend) => friend.displayName.toLowerCase().contains(lowerQuery),
        )
        .toList();
  }

  /// Safe notify listeners with disposal check.
  void _safeNotifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
