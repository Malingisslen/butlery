/// Service for loading and caching tag configurations from Firebase.
///
/// Implements Session 1 architecture:
/// - Firebase fetch with 3x retry + exponential backoff
/// - Session-only in-memory cache
/// - SharedPreferences fallback for offline
/// - Version check on app resume
library;

import 'dart:async';
import 'dart:convert';

import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/tagging/firebase_tag_config.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Exception thrown when tag config validation fails.
class TagConfigValidationException implements Exception {
  final List<String> errors;

  const TagConfigValidationException(this.errors);

  @override
  String toString() => 'TagConfigValidationException: ${errors.join(", ")}';
}

/// Exception thrown when tag config loading fails.
class TagConfigLoadException implements Exception {
  final String message;
  final Object? cause;

  const TagConfigLoadException(this.message, [this.cause]);

  @override
  String toString() => 'TagConfigLoadException: $message';
}

/// Service for loading tag configurations from Firebase.
///
/// Usage:
/// ```dart
/// final configService = ServiceLocator.get<TagConfigService>();
/// await configService.initialize();
/// final config = configService.config;
/// ```
class TagConfigService extends BaseService {
  static const String _cacheKey = 'tag_config_cache';
  static const String _versionKey = 'tag_config_version';
  static const int _maxRetries = 3;
  static const Duration _initialRetryDelay = Duration(milliseconds: 500);

  final FirebaseFirestore _firestore;

  /// In-memory cache for the current session.
  FirebaseTagConfig? _memoryCache;

  /// Whether initialization has completed.
  bool _initialized = false;

  /// Whether tagging is available (config loaded successfully).
  bool _taggingAvailable = false;

  TagConfigService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  String get serviceName => 'TagConfigService';

  /// Whether the service is initialized.
  bool get isInitialized => _initialized;

  /// Whether tagging is available (config loaded).
  bool get isTaggingAvailable => _taggingAvailable;

  /// Gets the current config.
  ///
  /// Throws if not initialized or config failed to load.
  FirebaseTagConfig get config {
    if (!_initialized) {
      throw StateError('TagConfigService not initialized. Call initialize().');
    }
    if (_memoryCache == null) {
      throw StateError('Tag config not loaded. Tagging is unavailable.');
    }
    return _memoryCache!;
  }

  /// Gets the config if available, null otherwise.
  FirebaseTagConfig? get configOrNull => _memoryCache;

  @override
  Future<void> onInitialize() async {
    if (_initialized) return;

    AppLogger.info('Initializing TagConfigService...', serviceName);

    try {
      // Try to load from Firebase
      _memoryCache = await _loadFromFirebaseWithRetry();
      _taggingAvailable = true;
      AppLogger.info(
        'Loaded config from Firebase (version: ${_memoryCache!.combinedVersion})',
        serviceName,
      );
    } catch (e) {
      AppLogger.warning(
        'Failed to load from Firebase: $e. Trying local cache.',
        serviceName,
      );

      // Try local cache
      try {
        _memoryCache = await _loadFromCache();
        if (_memoryCache != null) {
          _taggingAvailable = true;
          AppLogger.info(
            'Loaded config from cache (version: ${_memoryCache!.combinedVersion})',
            serviceName,
          );
        } else {
          _taggingAvailable = false;
          AppLogger.warning(
            'No local cache available. Tagging is unavailable.',
            serviceName,
          );
        }
      } catch (cacheError) {
        _taggingAvailable = false;
        AppLogger.error(
          'Failed to load from cache: $cacheError. Tagging is unavailable.',
          serviceName,
        );
      }
    }

    _initialized = true;
  }

  /// Refreshes the config if the version has changed.
  ///
  /// Call this on app resume to check for config updates.
  Future<void> refreshIfNeeded() async {
    if (!_initialized) {
      await initialize();
      return;
    }

    try {
      final currentVersion = _memoryCache?.combinedVersion ?? 0;
      final remoteVersion = await _fetchRemoteVersion();

      if (remoteVersion != currentVersion) {
        AppLogger.info(
          'Config version changed ($currentVersion -> $remoteVersion). Refreshing.',
          serviceName,
        );
        _memoryCache = await _loadFromFirebaseWithRetry();
        _taggingAvailable = true;
      }
    } catch (e) {
      // Silently ignore refresh failures - keep using cached config
      AppLogger.debug(
        'Failed to check config version: $e',
        serviceName,
      );
    }
  }

  /// Forces a refresh from Firebase.
  Future<void> forceRefresh() async {
    try {
      _memoryCache = await _loadFromFirebaseWithRetry();
      _taggingAvailable = true;
      AppLogger.info('Force refreshed config', serviceName);
    } catch (e) {
      AppLogger.error('Force refresh failed: $e', serviceName);
      rethrow;
    }
  }

  /// Loads config from Firebase with retry logic.
  Future<FirebaseTagConfig> _loadFromFirebaseWithRetry() async {
    var delay = _initialRetryDelay;

    for (var attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        return await _loadFromFirebase();
      } catch (e) {
        if (attempt == _maxRetries) {
          throw TagConfigLoadException(
            'Failed to load config after $_maxRetries attempts',
            e,
          );
        }

        AppLogger.debug(
          'Firebase fetch attempt $attempt failed, retrying in ${delay.inMilliseconds}ms',
          serviceName,
        );
        await Future<void>.delayed(delay);
        delay *= 2; // Exponential backoff
      }
    }

    // This should never be reached
    throw const TagConfigLoadException('Unexpected error in retry loop');
  }

  /// Loads config from Firebase.
  Future<FirebaseTagConfig> _loadFromFirebase() async {
    final collection = _firestore.collection('tagConfigs');

    // Fetch all documents in parallel
    final results = await Future.wait([
      collection.doc('allergens').get(),
      collection.doc('dietary').get(),
      collection.doc('cuisines').get(),
      collection.doc('properties').get(),
      collection.doc('display').get(),
    ]);

    final allergensData = results[0].data();
    final dietaryData = results[1].data();
    final cuisinesData = results[2].data();
    final propertiesData = results[3].data();
    final displayData = results[4].data();

    // Validate that all documents exist
    if (allergensData == null ||
        dietaryData == null ||
        cuisinesData == null ||
        propertiesData == null ||
        displayData == null) {
      throw const TagConfigLoadException(
        'Missing config documents in Firebase. '
        'Run migration script to populate tagConfigs collection.',
      );
    }

    // Parse config
    final config = FirebaseTagConfig.fromDocuments(
      allergensData: allergensData,
      dietaryData: dietaryData,
      cuisinesData: cuisinesData,
      propertiesData: propertiesData,
      displayData: displayData,
    );

    // Validate config
    final errors = config.validate();
    if (errors.isNotEmpty) {
      AppLogger.warning(
        'Config validation errors: ${errors.join(", ")}',
        serviceName,
      );
      // Log but don't throw - continue with valid entries
    }

    // Save to cache for offline use
    await _saveToCache(config);

    return config;
  }

  /// Fetches just the version numbers for quick comparison.
  Future<int> _fetchRemoteVersion() async {
    final collection = _firestore.collection('tagConfigs');

    final results = await Future.wait([
      collection.doc('allergens').get(const GetOptions(source: Source.server)),
      collection.doc('dietary').get(const GetOptions(source: Source.server)),
      collection.doc('cuisines').get(const GetOptions(source: Source.server)),
      collection.doc('properties').get(const GetOptions(source: Source.server)),
      collection.doc('display').get(const GetOptions(source: Source.server)),
    ]);

    int totalVersion = 0;
    for (final result in results) {
      final data = result.data();
      if (data != null) {
        totalVersion += (data['version'] as int?) ?? 0;
      }
    }

    return totalVersion;
  }

  /// Loads config from SharedPreferences cache.
  Future<FirebaseTagConfig?> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_cacheKey);

      if (cachedJson == null) return null;

      final data = jsonDecode(cachedJson) as Map<String, dynamic>;

      return FirebaseTagConfig.fromDocuments(
        allergensData: data['allergens'] as Map<String, dynamic>,
        dietaryData: data['dietary'] as Map<String, dynamic>,
        cuisinesData: data['cuisines'] as Map<String, dynamic>,
        propertiesData: data['properties'] as Map<String, dynamic>,
        displayData: data['display'] as Map<String, dynamic>,
      );
    } catch (e) {
      AppLogger.error('Error loading from cache: $e', serviceName);
      return null;
    }
  }

  /// Saves config to SharedPreferences for offline use.
  Future<void> _saveToCache(FirebaseTagConfig config) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Serialize config to JSON
      final data = {
        'allergens': _allergenDocToMap(config.allergens),
        'dietary': _dietaryDocToMap(config.dietary),
        'cuisines': _cuisineDocToMap(config.cuisines),
        'properties': _propertiesDocToMap(config.properties),
        'display': _displayDocToMap(config.display),
      };

      await prefs.setString(_cacheKey, jsonEncode(data));
      await prefs.setInt(_versionKey, config.combinedVersion);

      AppLogger.debug('Saved config to cache', serviceName);
    } catch (e) {
      AppLogger.warning('Failed to save to cache: $e', serviceName);
    }
  }

  // Serialization helpers for cache storage

  Map<String, dynamic> _allergenDocToMap(AllergenConfigDocument doc) {
    return {
      'schemaVersion': doc.schemaVersion,
      'version': doc.version,
      'updatedAt': doc.updatedAt.toIso8601String(),
      'updatedBy': doc.updatedBy,
      'displayOrder': doc.displayOrder,
      'entries': doc.entries.map(_allergenEntryToMap).toList(),
    };
  }

  Map<String, dynamic> _allergenEntryToMap(AllergenEntry entry) {
    return {
      'key': entry.key,
      'triggerProperties': entry.triggerProperties,
      'tags': entry.tags.map(
        (locale, tags) => MapEntry(locale, {
          'contains': tags.contains,
          if (tags.free != null) 'free': tags.free,
        }),
      ),
      'isEuAllergen': entry.isEuAllergen,
      if (entry.uiGroup != null) 'uiGroup': entry.uiGroup,
      'description': entry.description,
      'enabled': entry.enabled,
      'priority': entry.priority,
    };
  }

  Map<String, dynamic> _dietaryDocToMap(DietaryConfigDocument doc) {
    return {
      'schemaVersion': doc.schemaVersion,
      'version': doc.version,
      'updatedAt': doc.updatedAt.toIso8601String(),
      'updatedBy': doc.updatedBy,
      'displayOrder': doc.displayOrder,
      'entries': doc.entries.map(_dietaryEntryToMap).toList(),
    };
  }

  Map<String, dynamic> _dietaryEntryToMap(DietaryEntry entry) {
    return {
      'key': entry.key,
      'tags': entry.tags,
      'excludedProperties': entry.excludedProperties,
      'requiredProperties': entry.requiredProperties,
      'requiresFullCoverage': entry.requiresFullCoverage,
      'description': entry.description,
      'enabled': entry.enabled,
      'priority': entry.priority,
    };
  }

  Map<String, dynamic> _cuisineDocToMap(CuisineConfigDocument doc) {
    return {
      'schemaVersion': doc.schemaVersion,
      'version': doc.version,
      'updatedAt': doc.updatedAt.toIso8601String(),
      'updatedBy': doc.updatedBy,
      'displayOrder': doc.displayOrder,
      'entries': doc.entries.map(_cuisineEntryToMap).toList(),
    };
  }

  Map<String, dynamic> _cuisineEntryToMap(CuisineEntry entry) {
    return {
      'key': entry.key,
      'tags': entry.tags,
      'titleKeywords': entry.titleKeywords,
      'ingredientKeywords': entry.ingredientKeywords,
      'ingredientGroups': entry.ingredientGroups,
      'minIngredientMatches': entry.minIngredientMatches,
      'matchMode': _matchModeToString(entry.matchMode),
      'titleMatchWeight': entry.titleMatchWeight,
      'ingredientMatchWeight': entry.ingredientMatchWeight,
      'enabled': entry.enabled,
      'priority': entry.priority,
    };
  }

  String _matchModeToString(CuisineMatchMode mode) {
    return switch (mode) {
      CuisineMatchMode.titleOrIngredients => 'title_or_ingredients',
      CuisineMatchMode.titleAndIngredients => 'title_and_ingredients',
      CuisineMatchMode.titleOnly => 'title_only',
      CuisineMatchMode.ingredientsOnly => 'ingredients_only',
    };
  }

  Map<String, dynamic> _propertiesDocToMap(PropertiesConfigDocument doc) {
    return {
      'schemaVersion': doc.schemaVersion,
      'version': doc.version,
      'updatedAt': doc.updatedAt.toIso8601String(),
      'updatedBy': doc.updatedBy,
      'validProperties': doc.validProperties.toList(),
    };
  }

  Map<String, dynamic> _displayDocToMap(DisplayConfigDocument doc) {
    return {
      'schemaVersion': doc.schemaVersion,
      'version': doc.version,
      'updatedAt': doc.updatedAt.toIso8601String(),
      'updatedBy': doc.updatedBy,
      'categoryOrder': doc.categoryOrder,
      'uiGroupNames': doc.uiGroupNames,
    };
  }

  /// Checks if the service is healthy (initialized and config loaded).
  Future<bool> healthCheck() async {
    return _initialized && _taggingAvailable;
  }
}
