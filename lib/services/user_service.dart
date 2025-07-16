// lib/services/user_service.dart

import '../repositories/interfaces/user_repository.dart';
import '../repositories/interfaces/auth_repository.dart';
import 'package:flutter/foundation.dart';
import '../models/user_profile.dart';
import '../core/utils/logger.dart'; // Importerar AppLogger
import '../core/error/error_handler.dart';
import 'permission_service.dart';
import '../core/injection.dart';

class UserService extends ChangeNotifier {
  final UserRepository _repository;
  final AuthRepository _authRepository;

  UserService({
    required UserRepository repository,
    required AuthRepository authRepository,
  })  : _repository = repository,
        _authRepository = authRepository;

  // Cache för prestanda (30 minuter)
  UserProfile? _currentUserProfile;
  final Map<String, UserProfile> _profileCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};

  // State
  bool _isLoading = false;
  String? _error;

  // Constants
  static const int _cacheDurationMinutes = 30;

  // Getters
  UserProfile? get currentUserProfile => _currentUserProfile;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;
  String? get currentUserId => sl<PermissionService>().currentUserId;


  /// Initialize service och ladda current user profile
  Future<void> initialize() async {
    AppLogger.info('🔄 Initialiserar UserService...');

    // Lyssna på auth state changes
    _authRepository.authStateChanges().listen((user) {
      if (user != null) {
        _loadCurrentUserProfile();
      } else {
        _currentUserProfile = null;
        _profileCache.clear();
        _cacheTimestamps.clear();
        notifyListeners();
      }
    });

    // Load current user if already authenticated
    if (_authRepository.currentUser != null) {
      await _loadCurrentUserProfile();
    }
  }

  /// Create or update user profile
  Future<UserProfile?> createOrUpdateProfile({
    required String displayName,
    String? bio,
    String? avatarUrl,
    bool? isSearchable,
    bool? allowEmailSearch,
  }) async {
    final user = _authRepository.currentUser;
    if (user == null) {
      _setError('Ingen användare inloggad');
      return null;
    }

    try {
      _setLoading(true);
      _clearError();

      // Check if profile exists
      final existingProfile = await _repository.fetchProfile(user.uid);

      UserProfile profile;
      if (existingProfile != null) {
        // Update existing profile
        profile = existingProfile.copyWith(
          displayName: displayName,
          bio: bio,
          avatarUrl: avatarUrl,
          isSearchable: isSearchable,
          allowEmailSearch: allowEmailSearch,
          lastActiveAt: DateTime.now(),
        );
      } else {
        // Create new profile
        final now = DateTime.now();
        profile = UserProfile(
          uid: user.uid,
          displayName: displayName,
          email: user.email ?? '',
          bio: bio,
          avatarUrl: avatarUrl,
          isSearchable: isSearchable ?? true,
          allowEmailSearch: allowEmailSearch ?? false,
          publicRecipeCount: 0,
          friendsCount: 0,
          joinedAt: now,
          lastActiveAt: now,
          isOnline: true,
        );
      }

      // Save via repository
      await _repository.saveProfile(profile);

      // Update cache
      _currentUserProfile = profile;
      _profileCache[user.uid] = profile;
      _cacheTimestamps[user.uid] = DateTime.now();

      AppLogger.success('✅ Profil sparad: ${profile.displayName}');
      notifyListeners();
      return profile;
    } catch (e) {
      final failure = ErrorHandler.handleError(e);
      AppLogger.error('❌ Kunde inte spara profil: $e');
      _setError(failure.message);
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Search users by display name or email - OPTIMERAD VERSION
  Future<List<UserProfile>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      _setLoading(true);
      _clearError();

      final results = await _repository.searchProfiles(query);

      for (final profile in results) {
        _profileCache[profile.uid] = profile;
        _cacheTimestamps[profile.uid] = DateTime.now();
      }

      return results;
    } catch (e) {
      final failure = ErrorHandler.handleError(e);
      AppLogger.error('❌ Kunde inte söka användare: $e');
      _setError(failure.message);
      return [];
    } finally {
      _setLoading(false);
    }
  }

  /// Get user profile by ID (with caching)
  Future<UserProfile?> getUserProfile(String userId) async {
    // Check cache first
    if (_profileCache.containsKey(userId)) {
      final cached = _profileCache[userId]!;
      final cacheTime = _cacheTimestamps[userId]!;
      final isExpired = DateTime.now().difference(cacheTime).inMinutes >
          _cacheDurationMinutes;

      if (!isExpired) {
        return cached;
      }
    }

    // Fetch from repository
    try {
      final profile = await _getProfileFromRepository(userId);
      if (profile != null) {
        _profileCache[userId] = profile;
        _cacheTimestamps[userId] = DateTime.now();
      }
      return profile;
    } catch (e) {
      AppLogger.error('❌ Kunde inte hämta profil $userId: $e');
      return null;
    }
  }

  /// Get multiple profiles efficiently (batch)
  Future<List<UserProfile>> getUserProfiles(List<String> userIds) async {
    if (userIds.isEmpty) return [];

    final results = <UserProfile>[];
    final uncachedIds = <String>[];

    // Check cache first
    for (final userId in userIds) {
      if (_profileCache.containsKey(userId)) {
        final cached = _profileCache[userId]!;
        final cacheTime = _cacheTimestamps[userId]!;
        final isExpired = DateTime.now().difference(cacheTime).inMinutes >
            _cacheDurationMinutes;

        if (!isExpired) {
          results.add(cached);
        } else {
          uncachedIds.add(userId);
        }
      } else {
        uncachedIds.add(userId);
      }
    }

    if (uncachedIds.isNotEmpty) {
      try {
        final fetched = await _repository.fetchProfiles(uncachedIds);
        for (final profile in fetched) {
          results.add(profile);
          _profileCache[profile.uid] = profile;
          _cacheTimestamps[profile.uid] = DateTime.now();
        }
      } catch (e) {
        AppLogger.error('❌ Kunde inte hämta profilbatch: $e');
      }
    }

    return results;
  }

  /// Update user's online status
  Future<void> updateOnlineStatus(bool isOnline) async {
    final userId = currentUserId;
    if (userId == null || _currentUserProfile == null) return;

    try {
      await _repository.updateOnlineStatus(userId, isOnline);

      _currentUserProfile = _currentUserProfile!.copyWith(
        isOnline: isOnline,
        lastActiveAt: DateTime.now(),
      );

      _profileCache[userId] = _currentUserProfile!;
      notifyListeners();
    } catch (e) {
      AppLogger.warning('⚠️ Kunde inte uppdatera online-status: $e');
    }
  }

  /// Update profile statistics (friend count, recipe count)
  Future<void> updateProfileStats({
    int? friendsCount,
    int? publicRecipeCount,
  }) async {
    final userId = currentUserId;
    if (userId == null || _currentUserProfile == null) return;

    try {
      final updates = <String, dynamic>{};
      if (friendsCount != null) updates['friendsCount'] = friendsCount;
      if (publicRecipeCount != null) {
        updates['publicRecipeCount'] = publicRecipeCount;
      }

      if (updates.isNotEmpty) {
        await _repository.updateProfileStats(
          userId,
          friendsCount: friendsCount,
          publicRecipeCount: publicRecipeCount,
        );

        _currentUserProfile = _currentUserProfile!.copyWith(
          friendsCount: friendsCount,
          publicRecipeCount: publicRecipeCount,
        );

        _profileCache[userId] = _currentUserProfile!;
        notifyListeners();
      }
    } catch (e) {
      AppLogger.warning('⚠️ Kunde inte uppdatera profilstatistik: $e');
    }
  }

  /// Check if display name is available
  Future<bool> isDisplayNameAvailable(String displayName) async {
    if (displayName.trim().isEmpty) return false;

    try {
      return await _repository.isDisplayNameAvailable(displayName);
    } catch (e) {
      AppLogger.error('❌ Kunde inte kontrollera displayName: $e');
      return false;
    }
  }

   /// Private methods - UPPDATERAD med auto-create
  Future<void> _loadCurrentUserProfile() async {
    final user = _authRepository.currentUser;
    if (user == null) return;

    try {
      _currentUserProfile = await _repository.fetchProfile(user.uid);

      // NY: Om profil inte finns, skapa en automatiskt
      if (_currentUserProfile == null && user.email != null) {
        AppLogger.info(
            '👤 Ingen profil hittad - skapar automatiskt för ${user.email}');

        final displayName = user.displayName ??
            user.email!.split('@')[0]; // Använd email-prefix som default

        _currentUserProfile = await createOrUpdateProfile(
          displayName: displayName,
          isSearchable: true,
          allowEmailSearch: false,
        );

        if (_currentUserProfile != null) {
          AppLogger.success(
              '✅ Profil skapad automatiskt: ${_currentUserProfile!.displayName}');
        } else {
          AppLogger.error('❌ Kunde inte skapa profil automatiskt');
        }
      }

      if (_currentUserProfile != null) {
        _profileCache[user.uid] = _currentUserProfile!;
        _cacheTimestamps[user.uid] = DateTime.now();
        AppLogger.info(
            '👤 Nuvarande profil laddad: ${_currentUserProfile!.displayName}');
      } else {
        AppLogger.warning(
            '⚠️ Kunde inte ladda eller skapa profil för användare');
      }

      notifyListeners();
    } catch (e) {
      AppLogger.error('❌ Kunde inte ladda nuvarande profil: $e');
      _setError('Kunde inte ladda profil: $e');
      notifyListeners();
    }
  }

  Future<UserProfile?> _getProfileFromRepository(String userId) async {
    try {
      return await _repository.fetchProfile(userId);
    } catch (e) {
      AppLogger.error('❌ Kunde inte hämta profil $userId: $e');
      return null;
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

  /// Public error clearing
  void clearError() {
    _clearError();
    notifyListeners();
  }

  /// Clear cache (useful for testing or manual refresh)
  void clearCache() {
    _profileCache.clear();
    _cacheTimestamps.clear();
    AppLogger.info('🗑️ Profil-cache rensad');
  }

  @override
  void dispose() {
    clearCache();
    super.dispose();
  }
}
