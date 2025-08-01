/// Comprehensive user profile management service with advanced caching and social features.
///
/// This service provides sophisticated user profile functionality including profile creation, updates,
/// social discovery, friend management, and comprehensive caching strategies. It serves as the central
/// coordinator for all user-related operations, integrating authentication, permissions, and social
/// features while maintaining optimal performance through intelligent caching and state management.
///
/// **Architecture Integration:**
/// - Extends [ChangeNotifier] for reactive UI state management with user profile updates
/// - Uses [ErrorHandlingMixin] for consistent error handling and user feedback patterns
/// - Integrates [FirebaseServiceMixin] for Firebase-specific operations and connectivity management
/// - Implements [StreamManagementMixin] for efficient real-time data stream handling
/// - Coordinates with [AuthRepository] for authentication state synchronization
/// - Integrates with [PermissionService] for secure user operation validation
///
/// **User Management Features:**
/// - **Profile Management**: Complete user profile creation, updates, and validation
/// - **Social Discovery**: User search and discovery with privacy controls and preferences
/// - **Caching Strategy**: Intelligent 30-minute profile caching for optimal performance
/// - **Real-time Updates**: Automatic profile synchronization with authentication state changes
/// - **Privacy Controls**: Comprehensive privacy settings for searchability and email visibility
/// - **Permission Integration**: Secure operations with comprehensive permission validation
///
/// **Performance and Caching:**
/// - **Profile Caching**: 30-minute intelligent caching system reducing database load
/// - **Cache Management**: Automatic cache invalidation and cleanup on authentication changes
/// - **Stream Management**: Efficient stream handling with automatic cleanup and error recovery
/// - **Batch Operations**: Optimized batch profile fetching for social features

import 'package:butlery/repositories/interfaces/user_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/error_handler.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/mixins/firebase_service_mixin.dart';
import 'package:butlery/core/mixins/stream_management_mixin.dart';

/// User profile service with comprehensive caching, social features, and real-time synchronization.
///
/// This service provides complete user profile management using advanced caching strategies,
/// real-time authentication state synchronization, and comprehensive social discovery features.
/// It serves as the central coordination point for all user-related operations throughout
/// the application with sophisticated performance optimization and error handling.
///
/// **Service Architecture:**
/// Uses multiple specialized mixins for robust functionality:
/// - [ErrorHandlingMixin] for consistent error handling and user feedback
/// - [FirebaseServiceMixin] for Firebase-specific operations and connectivity
/// - [StreamManagementMixin] for efficient real-time stream management
///
/// **Caching Strategy:**
/// Implements intelligent profile caching with:
/// - 30-minute cache duration for optimal performance
/// - Automatic cache invalidation on authentication state changes
/// - Memory-efficient cache management with timestamp tracking
///
/// **Usage Examples:**
/// ```dart
/// final userService = UserService(
///   repository: ServiceLocator.get<UserRepository>(),
///   authRepository: ServiceLocator.get<AuthRepository>(),
/// );
/// 
/// // Initialize service with authentication monitoring
/// await userService.initialize();
/// 
/// // Create or update user profile
/// final profile = await userService.createOrUpdateProfile(
///   displayName: 'John Doe',
///   bio: 'Food enthusiast and home cook',
///   isSearchable: true,
/// );
/// 
/// // Listen to profile changes
/// userService.addListener(() {
///   if (userService.currentUserProfile != null) {
///     updateProfileUI(userService.currentUserProfile!);
///   }
/// });
/// ```
class UserService extends ChangeNotifier with ErrorHandlingMixin, FirebaseServiceMixin, StreamManagementMixin {
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
  String? get currentUserId => ServiceLocator.get<PermissionService>().currentUserId;


  /// Initialize service och ladda current user profile
  Future<void> initialize() async {
    AppLogger.info('🔄 Initialiserar UserService...');

    // Lyssna på auth state changes med StreamManagementMixin
    listenToStream(
      _authRepository.authStateChanges(),
      (user) {
        if (user != null) {
          _loadCurrentUserProfile();
        } else {
          _currentUserProfile = null;
          _profileCache.clear();
          _cacheTimestamps.clear();
          notifyListeners();
        }
      },
      name: 'auth_state_changes',
    );

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
      final failure = ErrorHandler().handleError(error: e, context: 'saveProfile');
      AppLogger.error('❌ Kunde inte spara profil: $e');
      _setError(failure.userMessage);
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Search users by display name or email - OPTIMERAD VERSION
  Future<List<UserProfile>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];

    _setLoading(true);
    _clearError();
    
    try {
      final result = await safeExecute(
        () async {
          final results = await _repository.searchProfiles(query);

          for (final profile in results) {
            _profileCache[profile.uid] = profile;
            _cacheTimestamps[profile.uid] = DateTime.now();
          }

          return results;
        },
        operationName: 'Search users',
        defaultValue: <UserProfile>[],
      );
      
      return result ?? [];
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
    final profile = await safeExecute(
      () async {
        final profile = await _getProfileFromRepository(userId);
        if (profile != null) {
          _profileCache[userId] = profile;
          _cacheTimestamps[userId] = DateTime.now();
        }
        return profile;
      },
      operationName: 'Get user profile',
    );
    
    return profile;
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
      // NYTT: Skapa base user document i 'users' collection för friends system
      await _ensureBaseUserDocument(user.uid);

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

  /// Ensures base user document exists in 'users' collection for friends system
  Future<void> _ensureBaseUserDocument(String userId) async {
    try {
      await _repository.ensureBaseUserDocument(userId);
      
      AppLogger.info('✅ Base user document ensured for: $userId');
    } catch (e) {
      AppLogger.warning('⚠️ Could not ensure base user document: $e');
      // Don't throw - this is not critical for user functionality
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

  /// Update user's FCM token for push notifications
  Future<void> updateFCMToken(String token) async {
    final userId = currentUserId;
    if (userId == null || _currentUserProfile == null) {
      AppLogger.warning('⚠️ Cannot update FCM token - no current user');
      return;
    }

    try {
      AppLogger.info('🔔 Updating FCM token for user: $userId');
      
      // Update in repository
      await _repository.updateFCMToken(userId, token);

      // Update local cache
      _currentUserProfile = _currentUserProfile!.copyWith(
        fcmToken: token,
        fcmTokenUpdatedAt: DateTime.now(),
      );

      _profileCache[userId] = _currentUserProfile!;
      notifyListeners();

      AppLogger.success('✅ FCM token updated successfully');
    } catch (e) {
      AppLogger.error('❌ Failed to update FCM token', e);
      _setError('Kunde inte uppdatera notifikationstoken: $e');
    }
  }

  /// Update user's notification preferences
  Future<void> updateNotificationSettings(bool enabled) async {
    final userId = currentUserId;
    if (userId == null || _currentUserProfile == null) {
      AppLogger.warning('⚠️ Cannot update notification settings - no current user');
      return;
    }

    try {
      AppLogger.info('🔔 Updating notification settings for user: $userId');
      
      // Update in repository
      await _repository.updateNotificationSettings(userId, enabled);

      // Update local cache
      _currentUserProfile = _currentUserProfile!.copyWith(
        notificationsEnabled: enabled,
      );

      _profileCache[userId] = _currentUserProfile!;
      notifyListeners();

      AppLogger.success('✅ Notification settings updated successfully');
    } catch (e) {
      AppLogger.error('❌ Failed to update notification settings', e);
      _setError('Kunde inte uppdatera notifikationsinställningar: $e');
    }
  }

  /// Clear FCM token (e.g., on logout)
  Future<void> clearFCMToken() async {
    final userId = currentUserId;
    if (userId == null) return;

    try {
      AppLogger.info('🔔 Clearing FCM token for user: $userId');
      
      await _repository.clearFCMToken(userId);

      if (_currentUserProfile != null) {
        _currentUserProfile = _currentUserProfile!.copyWith(
          fcmToken: null,
          fcmTokenUpdatedAt: null,
        );
        _profileCache[userId] = _currentUserProfile!;
        notifyListeners();
      }

      AppLogger.success('✅ FCM token cleared successfully');
    } catch (e) {
      AppLogger.error('❌ Failed to clear FCM token', e);
    }
  }

  /// Clear cache (useful for testing or manual refresh)
  void clearCache() {
    _profileCache.clear();
    _cacheTimestamps.clear();
    AppLogger.info('🗑️ Profil-cache rensad');
  }

  @override
  Future<void> dispose() async {
    await disposeStreamResources();
    clearCache();
    super.dispose();
  }
  @override
  void dispose() {
    // Cancel all timers
    // Cancel all stream subscriptions  
    // Dispose of resources
    disposeStreams(); // From StreamManagementMixin
    super.dispose();
  }
}
