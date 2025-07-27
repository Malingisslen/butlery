// lib/services/analytics_service.dart

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:butlery/services/content_detector_service.dart';
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/mixins/singleton_service_mixin.dart';

/// Service för att hantera analytics och error tracking
///
/// Spårar viktiga händelser i appen, särskilt misslyckade operationer
/// som kan hjälpa oss att förbättra användarupplevelsen
/// Now using SingletonServiceMixin for standardized singleton pattern
class AnalyticsService extends BaseService with SingletonServiceMixin<AnalyticsService> {
  // Private constructor for singleton
  AnalyticsService._internal();
  
  // Factory constructor using SingletonServiceMixin
  factory AnalyticsService() => SingletonServiceMixin.createSingleton(() => AnalyticsService._internal());
  
  @override
  String get serviceName => 'AnalyticsService';

  // Firebase Analytics instance
  late final FirebaseAnalytics _analytics;

  // Observer för navigation tracking
  FirebaseAnalyticsObserver? _observer;

  /// Initialisera analytics
  @override
  Future<void> initialize() async {
    await super.initialize(); // Call BaseService initialization
    
    await executeServiceOperation(
      () async {
        _analytics = FirebaseAnalytics.instance;
        _observer = FirebaseAnalyticsObserver(analytics: _analytics);

        // Sätt grundläggande properties
        // Analytics är alltid aktiverat i release mode, inaktiverat i debug mode
        await _analytics.setAnalyticsCollectionEnabled(!kDebugMode);

        debugPrint(
          '📊 Analytics initialiserad (samling ${!kDebugMode ? "aktiverad" : "inaktiverad"})',
        );
      },
      operationName: 'Initialize analytics',
      requiresAuth: false,
      requiresNetwork: false,
    );
  }

  /// Hämta navigation observer för MaterialApp
  FirebaseAnalyticsObserver? get observer => _observer;

  /// Hämta Firebase Analytics instance
  FirebaseAnalytics get analytics => _analytics;

  // ==================== IMPORT & EXTRAKTION TRACKING ====================

  /// Logga när en import startar
  Future<void> logImportStarted({
    required String source,
    String? platform,
  }) async {
    await executeServiceOperation(
      () async {
        await _analytics.logEvent(
          name: 'import_started',
          parameters: {
            'source': source, // 'url', 'text', 'photo', 'archive', 'share'
            if (platform != null) 'platform': platform,
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
      },
      operationName: 'Log import started',
      requiresAuth: false,
      requiresNetwork: false,
    );
  }

  /// Logga lyckad import
  Future<void> logImportSuccess({
    required String source,
    String? platform,
    int? recipeLength,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'import_success',
        parameters: {
          'source': source,
          if (platform != null) 'platform': platform,
          if (recipeLength != null) 'recipe_length': recipeLength,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      debugPrint('Analytics fel: $e');
    }
  }

  /// Logga misslyckad extraktion från sociala medier
  Future<void> logExtractionError({
    required String url,
    required SourcePlatform platform,
    required String error,
    String? errorType,
  }) async {
    try {
      // Kategorisera error-typer för bättre analys
      final String category = _categorizeError(error);

      await _analytics.logEvent(
        name: 'extraction_error',
        parameters: {
          'platform': platform.toString().split('.').last,
          'error_category': category,
          'error_type': errorType ?? 'unknown',
          'error_message': error.substring(
            0,
            error.length > 100 ? 100 : error.length,
          ),
          'url_domain': Uri.tryParse(url)?.host ?? 'invalid_url',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      debugPrint('📊 Extraction error loggad: $platform - $category');
    } catch (e) {
      debugPrint('Analytics fel: $e');
    }
  }

  /// Logga när användare väljer manuell kopiering som fallback
  Future<void> logManualCopyFallback({
    required SourcePlatform platform,
    String? reason,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'manual_copy_fallback',
        parameters: {
          'platform': platform.toString().split('.').last,
          if (reason != null) 'reason': reason,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      debugPrint('Analytics fel: $e');
    }
  }

  // ==================== RECEPT-HÄNDELSER ====================

  /// Logga när ett recept skapas
  Future<void> logRecipeCreated({
    required String source,
    bool hasImage = false,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'recipe_created',
        parameters: {
          'source': source,
          'has_image': hasImage,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      debugPrint('Analytics fel: $e');
    }
  }

  /// Logga när ett recept delas
  Future<void> logRecipeShared({
    required String method, // 'text', 'json', 'link'
  }) async {
    try {
      await _analytics.logEvent(
        name: 'recipe_shared',
        parameters: {
          'method': method,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      debugPrint('Analytics fel: $e');
    }
  }

  /// NY! Logga när ett recept markeras som tillagat
  Future<void> logRecipeCooked({
    required String recipeId,
    required String recipeTitle,
    required String mealType,
    bool isFirstTime = true,
    int? daysSinceLastCooked,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'recipe_cooked',
        parameters: {
          'recipe_id': recipeId,
          'recipe_title': recipeTitle,
          'meal_type': mealType,
          'is_first_time':
              isFirstTime ? 'true' : 'false', // Konvertera bool till string
          if (daysSinceLastCooked != null)
            'days_since_last': daysSinceLastCooked,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      // Logga också user property för att spåra aktiva användare
      await setUserProperties(hasCooked: true);
    } catch (e) {
      debugPrint('Analytics fel: $e');
    }
  }

  /// Logga när veckomeny genereras
  Future<void> logMenuGenerated({
    required int recipeCount,
    required String method, // 'manual', 'prompt'
  }) async {
    try {
      await _analytics.logEvent(
        name: 'menu_generated',
        parameters: {
          'recipe_count': recipeCount,
          'method': method,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      debugPrint('Analytics fel: $e');
    }
  }

  /// Logga när ett recept tas bort
  Future<void> logRecipeDeleted({
    required String recipeId,
    required String recipeTitle,
    required String mealType,
    required bool isPersonal,
    required DateTime createdAt,
    int? daysSinceCreated,
  }) async {
    try {
      final now = DateTime.now();
      final actualDaysSinceCreated = daysSinceCreated ?? 
        now.difference(createdAt).inDays;

      await _analytics.logEvent(
        name: 'recipe_deleted',
        parameters: {
          'recipe_id': recipeId,
          'recipe_title': recipeTitle,
          'meal_type': mealType,
          'recipe_type': isPersonal ? 'personal' : 'collaborative',
          'days_since_created': actualDaysSinceCreated,
          'created_at': createdAt.toIso8601String(),
          'timestamp': now.toIso8601String(),
        },
      );

      debugPrint('📊 Recipe deletion loggad: $recipeTitle ($mealType)');
    } catch (e) {
      debugPrint('Analytics fel: $e');
    }
  }

  // ==================== APP-HÄNDELSER ====================

  /// Logga när användare loggar in
  Future<void> logLogin({required String method}) async {
    try {
      await _analytics.logLogin(loginMethod: method);
    } catch (e) {
      debugPrint('Analytics fel: $e');
    }
  }

  /// Logga när användare registrerar sig
  Future<void> logSignUp({required String method}) async {
    try {
      await _analytics.logSignUp(signUpMethod: method);
    } catch (e) {
      debugPrint('Analytics fel: $e');
    }
  }

  /// Logga när användare loggar ut
  Future<void> logLogout() async {
    try {
      await _analytics.logEvent(name: 'logout');
    } catch (e) {
      debugPrint('Analytics fel: $e');
    }
  }

  // ==================== HJÄLPMETODER ====================

  /// Kategorisera fel för bättre analytics
  String _categorizeError(String error) {
    final errorLower = error.toLowerCase();

    if (errorLower.contains('timeout')) {
      return 'timeout';
    } else if (errorLower.contains('ingen text')) {
      return 'no_content_found';
    } else if (errorLower.contains('kunde inte ladda')) {
      return 'page_load_error';
    } else if (errorLower.contains('okänd plattform')) {
      return 'unknown_platform';
    } else if (errorLower.contains('tekniskt fel')) {
      return 'technical_error';
    } else if (errorLower.contains('cors') || errorLower.contains('webben')) {
      return 'web_limitation';
    } else {
      return 'other';
    }
  }

  /// Sätt user properties för segmentering
  Future<void> setUserProperties({
    int? recipeCount,
    bool? hasUsedImport,
    bool? hasSharedRecipe,
    bool? hasCooked,
  }) async {
    try {
      if (recipeCount != null) {
        // Kategorisera användare baserat på antal recept
        String userType = 'new';
        if (recipeCount > 50) {
          userType = 'power_user';
        } else if (recipeCount > 20) {
          userType = 'active';
        } else if (recipeCount > 5) {
          userType = 'casual';
        }

        await _analytics.setUserProperty(name: 'user_type', value: userType);

        await _analytics.setUserProperty(
          name: 'recipe_count_range',
          value: _getRecipeCountRange(recipeCount),
        );
      }

      if (hasUsedImport != null) {
        await _analytics.setUserProperty(
          name: 'has_used_import',
          value: hasUsedImport.toString(),
        );
      }

      if (hasSharedRecipe != null) {
        await _analytics.setUserProperty(
          name: 'has_shared_recipe',
          value: hasSharedRecipe.toString(),
        );
      }

      if (hasCooked != null) {
        await _analytics.setUserProperty(
          name: 'has_marked_cooked',
          value: hasCooked.toString(),
        );
      }
    } catch (e) {
      debugPrint('Analytics fel: $e');
    }
  }

  /// Hämta recipe count range för analytics
  String _getRecipeCountRange(int count) {
    if (count == 0) return '0';
    if (count <= 5) return '1-5';
    if (count <= 10) return '6-10';
    if (count <= 20) return '11-20';
    if (count <= 50) return '21-50';
    return '50+';
  }
}
