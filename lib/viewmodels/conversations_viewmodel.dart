// lib/viewmodels/conversations_viewmodel.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/services/messaging_service.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/mixins/stream_management_mixin.dart';

class ConversationsViewModel extends ChangeNotifier with StreamManagementMixin, ErrorHandlingMixin {
  final MessagingService _messagingService;
  final AuthRepository _authRepository;

  // State
  bool _isDisposed = false;
  List<Conversation> _allConversations = [];
  List<Conversation> _filteredConversations = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  final bool _isSearching = false;
  bool _isCreatingConversation = false;
  String? _conversationCreationError;
  StreamSubscription<List<Conversation>>? _conversationsSubscription;

  ConversationsViewModel({
    required MessagingService messagingService,
    required AuthRepository authRepository,
  }) : _messagingService = messagingService,
       _authRepository = authRepository {
    _initializeConversations();
  }

  // Getters
  List<Conversation> get conversations => _filteredConversations;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  bool get isSearching => _isSearching;
  bool get isCreatingConversation => _isCreatingConversation;
  String? get conversationCreationError => _conversationCreationError;
  bool get hasConversations => _filteredConversations.isNotEmpty;
  String? get currentUserId => _authRepository.currentUserId;

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
      _setError('Kunde inte ladda konversationer');
    }
  }

  void _onConversationsUpdate(List<Conversation> conversations) {
    if (_isDisposed) return;
    
    _allConversations = conversations;
    _applySearch();
    _isLoading = false;
    _error = null;
    _safeNotifyListeners();
  }

  void _onConversationsError(dynamic error) {
    if (_isDisposed) return;
    
    AppLogger.error('Conversations stream error', error);
    _setError('Kunde inte ladda konversationer');
  }

  void _setError(String error) {
    _error = error;
    _isLoading = false;
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
      _filteredConversations = _allConversations.where((conversation) {
        final title = conversation.getDisplayTitle(currentUserId ?? '').toLowerCase();
        final lastMessageContent = conversation.lastMessage?.content.toLowerCase() ?? '';
        
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
    
    _isCreatingConversation = true;
    _conversationCreationError = null;
    _safeNotifyListeners();

    try {
      final conversationId = await _messagingService.startDirectConversation(
        otherUserId: otherUserId,
        otherUserDisplayName: otherUserDisplayName,
        otherUserAvatarUrl: otherUserAvatarUrl,
      );

      _isCreatingConversation = false;
      _safeNotifyListeners();
      
      AppLogger.success('Direct conversation started: $conversationId');
      return conversationId;
    } catch (e) {
      AppLogger.error('Failed to start direct conversation', e);
      _conversationCreationError = 'Kunde inte starta konversation: ${e.toString()}';
      _isCreatingConversation = false;
      _safeNotifyListeners();
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
    
    _isCreatingConversation = true;
    _conversationCreationError = null;
    _safeNotifyListeners();

    try {
      final conversationId = await _messagingService.createGroupConversation(
        participantIds: participantIds,
        participantDisplayNames: participantDisplayNames,
        participantAvatarUrls: participantAvatarUrls,
        title: title,
      );

      _isCreatingConversation = false;
      _safeNotifyListeners();
      
      AppLogger.success('Group conversation created: $conversationId');
      return conversationId;
    } catch (e) {
      AppLogger.error('Failed to create group conversation', e);
      _conversationCreationError = 'Kunde inte skapa gruppchatt: ${e.toString()}';
      _isCreatingConversation = false;
      _safeNotifyListeners();
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

      await _messagingService.removeParticipantFromGroup(
        conversationId: conversationId,
        participantId: currentUser,
      );
      
      AppLogger.success('Left group conversation: $conversationId');
      return true;
    } catch (e) {
      AppLogger.error('Failed to leave group', e);
      return false;
    }
  }

  Future<void> refresh() async {
    if (_isDisposed) return;
    
    // Stream will automatically update, this is just for UI feedback
    await Future.delayed(const Duration(milliseconds: 500));
  }

  void clearError() {
    if (_isDisposed) return;
    
    _error = null;
    _conversationCreationError = null;
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