// lib/viewmodels/conversations_viewmodel.dart

import 'package:clock/clock.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/repositories/interfaces/chat_group_repository.dart';
import 'package:butlery/services/messaging_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/core/errors/chat_group_error_mapper.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/mixins/stream_management_mixin.dart';
import 'package:butlery/core/mixins/state_notifier_mixin.dart';
import 'package:butlery/core/mixins/async_operation_mixin.dart';
import 'package:butlery/core/l10n/app_locale.dart';

class ConversationsViewModel extends ChangeNotifier
    with
        StreamManagementMixin,
        ErrorHandlingMixin,
        StateNotifierMixin,
        AsyncOperationMixin {
  final MessagingService _messagingService;
  final ChatGroupRepository _chatGroupRepository;

  // State
  bool _isDisposed = false;
  List<Conversation> _allConversations = [];
  List<Conversation> _filteredConversations = [];
  bool _isLoadingConversations = true;
  String? _conversationsError;
  String _searchQuery = '';
  final bool _isSearching = false;
  StreamSubscription<List<Conversation>>? _conversationsSubscription;

  ConversationsViewModel({
    required MessagingService messagingService,
    ChatGroupRepository? chatGroupRepository,
  }) : _messagingService = messagingService,
       _chatGroupRepository =
           chatGroupRepository ?? ServiceLocator.get<ChatGroupRepository>() {
    _initializeConversations();
  }

  // Getters
  List<Conversation> get conversations => _filteredConversations;
  bool get isLoadingConversations => _isLoadingConversations;
  String? get conversationsError => _conversationsError;
  String get searchQuery => _searchQuery;
  bool get isSearching => _isSearching;
  // isLoading and errorMessage provided by AsyncOperationMixin
  bool get hasConversations => _filteredConversations.isNotEmpty;
  String? get currentUserId =>
      ServiceLocator.get<PermissionService>().currentUserId;

  void _initializeConversations() {
    if (_isDisposed) return;

    try {
      _conversationsSubscription = _messagingService
          .getMyConversations()
          .listen(
            _onConversationsUpdate,
            onError: _onConversationsError,
          );
    } catch (e) {
      AppLogger.error('Failed to initialize conversations', e);
      _setConversationsError(
        AppLocale.current.errorCouldNotLoad('konversationer'),
      );
    }
  }

  void _onConversationsUpdate(List<Conversation> conversations) {
    if (_isDisposed) return;

    _allConversations = conversations;
    _applySearch();
    _isLoadingConversations = false;
    _conversationsError = null;
    _safeNotifyListeners();
  }

  void _onConversationsError(dynamic error) {
    if (_isDisposed) return;

    AppLogger.error('Conversations stream error', error);
    _setConversationsError(
      AppLocale.current.errorCouldNotLoad('konversationer'),
    );
  }

  void _setConversationsError(String error) {
    _conversationsError = error;
    _isLoadingConversations = false;
    _safeNotifyListeners();
  }

  void updateSearchQuery(String query) {
    if (_isDisposed) return;

    _searchQuery = query.trim().toLowerCase();
    _applySearch();
    _safeNotifyListeners();
  }

  void clearSearch() {
    if (_isDisposed) return;

    _searchQuery = '';
    _applySearch();
    _safeNotifyListeners();
  }

  void _applySearch() {
    if (_searchQuery.isEmpty) {
      _filteredConversations = List.from(_allConversations);
    } else {
      // Hoisted: `currentUserId` resolves a service each time, and this runs
      // once per row per keystroke.
      final readerId = currentUserId.orEmpty();
      _filteredConversations = _allConversations.where((conversation) {
        final title = conversation.getDisplayTitle(readerId).toLowerCase();
        // BUT-1838: search the preview only if this member may READ it. The
        // list stopped SHOWING a pre-join message; matching on its text would
        // let a late joiner confirm words in it by typing them and watching the
        // row appear — the same disclosure through a narrower door, and against
        // the same decision ("a new member sees only from now on"). Same
        // predicate as the row itself, deliberately not a second spelling of it.
        final lastMessage = conversation.lastMessage;
        final lastMessageContent =
            lastMessage != null &&
                conversation.canReadMessageAt(lastMessage.sentAt, readerId)
            ? lastMessage.content.toLowerCase()
            : '';

        return title.contains(_searchQuery) ||
            lastMessageContent.contains(_searchQuery);
      }).toList();
    }
  }

  Future<String?> startDirectConversation({
    required String otherUserId,
    required String otherUserDisplayName,
    String? otherUserAvatarUrl,
  }) async {
    if (_isDisposed) return null;

    try {
      return await executeAsync<String?>(
        () async {
          final conversationId = await _messagingService
              .startDirectConversation(
                otherUserId: otherUserId,
                otherUserDisplayName: otherUserDisplayName,
                otherUserAvatarUrl: otherUserAvatarUrl,
              );

          AppLogger.success('Direct conversation started: $conversationId');
          return conversationId;
        },
        errorPrefix: AppLocale.current.errorCouldNotStartConversation,
      );
    } catch (e) {
      // Error state already set by executeAsync, just return null
      return null;
    }
  }

  Future<String?> createGroupConversation({
    required List<String> participantIds,
    required Map<String, String> participantDisplayNames,
    required Map<String, String?> participantAvatarUrls,
    required String title,
  }) async {
    if (_isDisposed) return null;

    try {
      return await executeAsync<String?>(
        () async {
          final conversationId = await _messagingService
              .createGroupConversation(
                participantIds: participantIds,
                participantDisplayNames: participantDisplayNames,
                participantAvatarUrls: participantAvatarUrls,
                title: title,
              );

          AppLogger.success('Group conversation created: $conversationId');
          return conversationId;
        },
        errorPrefix: AppLocale.current.errorCouldNotCreate('gruppchatt'),
      );
    } catch (e) {
      // Error state already set by executeAsync, just return null
      return null;
    }
  }

  Future<void> markConversationAsRead(String conversationId) async {
    if (_isDisposed) return;

    try {
      await _messagingService.markConversationAsRead(conversationId);
      AppLogger.debug('Conversation marked as read: $conversationId');
    } catch (e) {
      AppLogger.error('Failed to mark conversation as read', e);
      // Don't show error to user for this operation
    }
  }

  Future<bool> leaveGroup(String conversationId) async {
    if (_isDisposed) return false;

    try {
      final currentUser = currentUserId;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final conversation = _allConversations.firstWhere(
        (c) => c.id == conversationId,
        orElse: () => throw StateError(
          'Conversation $conversationId not in the loaded list',
        ),
      );
      final groupId = conversation.groupId;
      if (groupId == null) {
        throw StateError('Conversation $conversationId has no chat group');
      }

      // Omitting `userId` is the repository's "leave yourself" contract.
      await _chatGroupRepository.removeMember(groupId: groupId);

      await ServiceLocator.tryGet<AnalyticsService>()?.social.logGroupLeft(
        groupId: conversationId,
      );

      AppLogger.success('Left group conversation: $conversationId');
      return true;
    } catch (e) {
      AppLogger.error('Failed to leave group', e);
      setError(
        ChatGroupErrorMapper.map(
          e,
          genericFallback: AppLocale.current.errorCouldNotLeaveGroup,
        ),
      );
      return false;
    }
  }

  bool get hasArchivedConversations =>
      _allConversations.any((c) => c.isArchived);

  List<Conversation> get pinnedConversations =>
      _filteredConversations.where((c) => c.isPinned && !c.isArchived).toList();

  List<Conversation> get regularConversations => _filteredConversations
      .where((c) => !c.isPinned && !c.isArchived)
      .toList();

  List<Conversation> get archivedConversations =>
      _filteredConversations.where((c) => c.isArchived).toList();

  Future<void> togglePin(String conversationId) async {
    if (_isDisposed) return;
    final index = _allConversations.indexWhere((c) => c.id == conversationId);
    if (index == -1) return;
    final conversation = _allConversations[index];
    final newPinned = !conversation.isPinned;

    // Optimistic update so the UI responds immediately
    _allConversations[index] = conversation.copyWith(
      isPinned: newPinned,
      pinnedAt: newPinned ? clock.now() : null,
    );
    _applySearch();
    _safeNotifyListeners();

    try {
      if (newPinned) {
        await _messagingService.pinConversation(conversationId);
      } else {
        await _messagingService.unpinConversation(conversationId);
      }
    } catch (e) {
      // Roll back on failure
      AppLogger.error('Failed to toggle pin', e);
      _allConversations[index] = conversation;
      _applySearch();
      _safeNotifyListeners();
    }
  }

  Future<void> toggleArchive(String conversationId) async {
    if (_isDisposed) return;
    final index = _allConversations.indexWhere((c) => c.id == conversationId);
    if (index == -1) return;
    final conversation = _allConversations[index];
    final newArchived = !conversation.isArchived;

    // Optimistic update so the UI responds immediately
    _allConversations[index] = conversation.copyWith(
      isArchived: newArchived,
      archivedAt: newArchived ? clock.now() : null,
    );
    _applySearch();
    _safeNotifyListeners();

    try {
      if (newArchived) {
        await _messagingService.archiveConversation(conversationId);
      } else {
        await _messagingService.unarchiveConversation(conversationId);
      }
    } catch (e) {
      // Roll back on failure
      AppLogger.error('Failed to toggle archive', e);
      _allConversations[index] = conversation;
      _applySearch();
      _safeNotifyListeners();
    }
  }

  Future<bool> deleteConversation(String conversationId) async {
    if (_isDisposed) return false;

    try {
      await _messagingService.deleteConversation(conversationId);
      return true;
    } catch (e) {
      AppLogger.error('Failed to delete conversation', e);
      return false;
    }
  }

  Future<void> refresh() async {
    if (_isDisposed) return;

    // Stream will automatically update, this is just for UI feedback
    await Future.delayed(const Duration(milliseconds: 500));
  }

  void clearAllErrors() {
    if (_isDisposed) return;

    _conversationsError = null;
    clearError(); // Clear operation errors from StateNotifierMixin
    _safeNotifyListeners();
  }

  void _safeNotifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _conversationsSubscription?.cancel();
    super.dispose();
  }
}
