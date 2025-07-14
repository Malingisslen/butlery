// lib/services/friends_service.dart

import 'package:flutter/foundation.dart';
import '../repositories/interfaces/friends_repository.dart';
import '../repositories/interfaces/auth_repository.dart';
import '../models/user_profile.dart';
import '../models/friend_request.dart';
import '../core/utils/logger.dart';
import '../core/error/error_handler.dart';

class FriendsService extends ChangeNotifier {
  final FriendsRepository _repository;
  final AuthRepository _authRepository;

  FriendsService({
    required FriendsRepository repository,
    required AuthRepository authRepository,
  })  : _repository = repository,
        _authRepository = authRepository;

  // State
  List<UserProfile> _friends = [];
  List<FriendRequest> _incomingRequests = [];
  List<FriendRequest> _sentRequests = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<UserProfile> get friends => List.unmodifiable(_friends);
  List<FriendRequest> get incomingRequests =>
      List.unmodifiable(_incomingRequests);
  List<FriendRequest> get sentRequests => List.unmodifiable(_sentRequests);
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;
  String? get currentUserId => _authRepository.currentUserId;
  int get friendsCount => _friends.length;
  int get pendingRequestsCount => _incomingRequests.length;


  /// Initialize service
  Future<void> initialize() async {
    AppLogger.info('🔄 Initialiserar FriendsService...');

    _authRepository.authStateChanges().listen((user) {
      if (user != null) {
        _loadFriends();
        _loadFriendRequests();
      } else {
        _friends.clear();
        _incomingRequests.clear();
        _sentRequests.clear();
        notifyListeners();
      }
    });

    if (_authRepository.getCurrentUser() != null) {
      await _loadFriends();
      await _loadFriendRequests();
    }
  }

  /// Send friend request
  Future<bool> sendFriendRequest(String toUserId, {String? message}) async {
    final fromUserId = currentUserId;
    if (fromUserId == null) {
      _setError('Ingen användare inloggad');
      return false;
    }

    if (fromUserId == toUserId) {
      _setError('Du kan inte skicka vänförfrågan till dig själv');
      return false;
    }

    try {
      _setLoading(true);
      _clearError();

      // Check if already friends
      if (await _areAlreadyFriends(fromUserId, toUserId)) {
        _setError('Ni är redan vänner');
        return false;
      }

      // Check if request already exists
      if (await _requestExists(fromUserId, toUserId)) {
        _setError('Vänförfrågan redan skickad');
        return false;
      }

      final success =
          await _repository.sendFriendRequest(toUserId, message: message);
      if (success) {
        await _loadFriendRequests();
        AppLogger.success('✅ Vänförfrågan skickad till $toUserId');
        notifyListeners();
      }
      return success;
    } catch (e) {
      final failure = ErrorHandler.handleError(e);
      AppLogger.error('Kunde inte skicka vänförfrågan', e);
      _setError(failure.message);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Accept friend request
  Future<bool> acceptFriendRequest(String requestId) async {
    final userId = currentUserId;
    if (userId == null) {
      _setError('Ingen användare inloggad');
      return false;
    }

    try {
      _setLoading(true);
      _clearError();

      final success = await _repository.acceptFriendRequest(requestId);
      if (success) {
        await _loadFriendRequests();
        await _loadFriends();
        AppLogger.success('✅ Vänförfrågan accepterad');
        notifyListeners();
      }
      return success;
    } catch (e) {
      final failure = ErrorHandler.handleError(e);
      AppLogger.error('Kunde inte acceptera vänförfrågan', e);
      _setError(failure.message);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Reject friend request
  Future<bool> rejectFriendRequest(String requestId) async {
    final userId = currentUserId;
    if (userId == null) {
      _setError('Ingen användare inloggad');
      return false;
    }

    try {
      _setLoading(true);
      _clearError();

      final success = await _repository.rejectFriendRequest(requestId);
      if (success) {
        await _loadFriendRequests();
        AppLogger.info('❌ Vänförfrågan avvisad');
        notifyListeners();
      }
      return success;
    } catch (e) {
      final failure = ErrorHandler.handleError(e);
      AppLogger.error('Kunde inte avvisa vänförfrågan', e);
      _setError(failure.message);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Remove friend (unfriend)
  Future<bool> removeFriend(String friendUserId) async {
    final userId = currentUserId;
    if (userId == null) {
      _setError('Ingen användare inloggad');
      return false;
    }

    try {
      _setLoading(true);
      _clearError();

      final success = await _repository.removeFriend(friendUserId);
      if (!success) {
        _setError('Kunde inte ta bort vän');
        return false;
      }

      // Remove from local list
      _friends.removeWhere((f) => f.uid == friendUserId);

      AppLogger.info('👋 Vänskap avslutad med $friendUserId');
      notifyListeners();
      return true;
    } catch (e) {
      final failure = ErrorHandler.handleError(e);
      AppLogger.error('Kunde inte ta bort vän', e);
      _setError(failure.message);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Cancel sent friend request
  Future<bool> cancelSentRequest(String requestId) async {
    try {
      _setLoading(true);
      _clearError();

      final success = await _repository.cancelFriendRequest(requestId);
      if (success) {
        await _loadFriendRequests();
        AppLogger.info('🚫 Skickad vänförfrågan avbruten');
        notifyListeners();
      }
      return success;
    } catch (e) {
      final failure = ErrorHandler.handleError(e);
      AppLogger.error('Kunde inte avbryta vänförfrågan', e);
      _setError(failure.message);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Check if two users are friends
  Future<bool> areFriends(String userId1, String userId2) async {
    try {
      return await _repository.areFriends(userId1, userId2);
    } catch (e) {
      AppLogger.error('Kunde inte kontrollera vänskap', e);
      return false;
    }
  }

  /// Get mutual friends between current user and another user
  Future<List<UserProfile>> getMutualFriends(String otherUserId) async {
    final userId = currentUserId;
    if (userId == null) return [];

    try {
      // Get other user's friends
      final otherFriendIds =
          (await _repository.fetchFriendIds(otherUserId)).toSet();

      // Find mutual friends
      final mutualFriendIds = _friends
          .map((f) => f.uid)
          .where((id) => otherFriendIds.contains(id))
          .toList();

      // Return the UserProfile objects for mutual friends
      return _friends.where((f) => mutualFriendIds.contains(f.uid)).toList();
    } catch (e) {
      AppLogger.error('Kunde inte hämta gemensamma vänner', e);
      return [];
    }
  }

  /// Private methods
  Future<void> _loadFriends() async {
    final userId = currentUserId;
    if (userId == null) return;

    try {
      final friendIds = await _repository.fetchFriendIds(userId);
      if (friendIds.isNotEmpty) {
        _friends = await _repository.fetchFriendProfiles(friendIds);
      } else {
        _friends = [];
      }

      AppLogger.info('👥 ${_friends.length} vänner laddade');
      notifyListeners();
    } catch (e) {
      AppLogger.error('Kunde inte ladda vänner', e);
    }
  }

  Future<void> _loadFriendRequests() async {
    final userId = currentUserId;
    if (userId == null) return;

    try {
      // Load incoming requests
      _incomingRequests = await _repository.getIncomingRequests();

      // Load sent requests
      _sentRequests = await _repository.getSentRequests();

      AppLogger.info(
        '📨 ${_incomingRequests.length} inkommande, ${_sentRequests.length} skickade förfrågningar',
      );
      notifyListeners();
    } catch (e) {
      AppLogger.error('Kunde inte ladda vänförfrågningar', e);
    }
  }

  Future<bool> _areAlreadyFriends(String userId1, String userId2) async {
    try {
      return await _repository.areFriends(userId1, userId2);
    } catch (e) {
      return false;
    }
  }

  Future<bool> _requestExists(String fromUserId, String toUserId) async {
    try {
      return await _repository.requestExists(fromUserId, toUserId);
    } catch (e) {
      return false;
    }
  }


  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String message) {
    _error = message;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }

  void clearError() {
    _clearError();
    notifyListeners();
  }

  /// Refresh all data
  Future<void> refresh() async {
    await _loadFriends();
    await _loadFriendRequests();
  }

  /// Public method to load friends - ADDED FOR VECKOMENY_VIEW
  Future<void> loadFriends() async {
    AppLogger.info('🔄 Public loadFriends called');
    await _loadFriends();
  }
}
