// lib/core/startup/app_initializer.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../repositories/firebase/firebase_auth_repository.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:package_info_plus/package_info_plus.dart';

// Services
import '../../services/offline_service.dart';
import '../../services/analytics_service.dart';
import '../../services/deep_link_service.dart';

// Dependency Injection
import '../injection.dart';
import '../../services/unified/unified_recipe_service.dart';
import '../../services/unified/unified_friends_service.dart';
import '../../repositories/interfaces/auth_repository.dart';
import '../../repositories/firestore_repository.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../services/persistence_service.dart';

// Firebase config
import '../../firebase_options.dart';

/// 🚀 AppInitializer
///
/// Centraliserad klass för all app-initialization.
/// Ersätter den komplexa main()-funktionen med strukturerad initialization.
///
/// Användning:
/// ```dart
/// Future<void> main() async {
///   await AppInitializer.initialize();
///   runApp(const ButleryApp());
/// }
/// ```
class AppInitializer {
  static bool _isBackgroundInitialized = false;
  static bool get isBackgroundInitialized => _isBackgroundInitialized;
  /// 🚀 PERFORMANCE FIX: Critical initialization only (before runApp)
  ///
  /// Kör bara absolut nödvändiga steg:
  /// 1. Flutter-bindningar
  /// 2. Environment variables
  /// 3. Svenska lokaliseringar
  static Future<void> initializeCritical() async {
    if (kDebugMode) {
      debugPrint('🚀 === BUTLERY APP INITIALIZATION START ===');
    }

    try {
      // 1️⃣ Säkerställ Flutter-bindningar (KRITISKT)
      await _initializeFlutterBindings();

      // 2️⃣ Ladda environment variables (KRITISKT för API-säkerhet)
      await _initializeEnvironmentVariables();

      // 3️⃣ Initiera svenska lokaliseringar (KRITISKT för UI)
      await _initializeLocalization();

      if (kDebugMode) {
        debugPrint('✅ Critical initialization complete - starting UI');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ KRITISKT FEL vid critical initialization: $e');
        debugPrint('Stack trace: $stackTrace');
      }
      rethrow; // Critical errors should stop the app
    }
  }

  /// 🚀 PERFORMANCE FIX: Background initialization (after runApp starts)
  ///
  /// Kör tunga steg i bakgrunden:
  /// 3. Firebase initialization
  /// 4. Analytics setup
  /// 5. Dependency Injection
  /// 6. Offline Service (Hive)
  static Future<void> initializeBackground() async {
    try {
      // 3️⃣ Initiera Firebase (TUNGT - kan köras i bakgrunden)
      await _initializeFirebase();

      // 4️⃣ Initiera Analytics (TUNGT - kan köras i bakgrunden)
      await _initializeAnalytics();

      // 5️⃣ Initiera Dependency Injection (TUNGT - kan köras i bakgrunden)
      await _initializeDependencyInjection();

      // 6️⃣ Initiera Offline Service (TUNGT - kan köras i bakgrunden)
      await _initializeOfflineService();

      // 7️⃣ Initiera Deep Link Service (LÄTT - kan köras i bakgrunden)
      await _initializeDeepLinkService();

      _isBackgroundInitialized = true;
      if (kDebugMode) {
        debugPrint('✅ === BUTLERY APP INITIALIZATION COMPLETE ===');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ FEL vid background initialization: $e');
        debugPrint('Stack trace: $stackTrace');
      }

      // Background errors shouldn't crash the app, men logga allvarligt
      if (kDebugMode) {
        debugPrint('⚠️ Appen fortsätter med begränsad funktionalitet');
      }
      _isBackgroundInitialized = true; // Mark as "done" even on error
    }
  }

  /// @deprecated Use initializeCritical() and initializeBackground() instead
  static Future<void> initialize() async {
    await initializeCritical();
    await initializeBackground();
  }

  /// 1️⃣ Säkerställer att Flutter-bindningar är klara
  static Future<void> _initializeFlutterBindings() async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      debugPrint('✅ Flutter-bindningar initierade');
    } catch (e) {
      debugPrint('❌ Fel vid Flutter-bindningar: $e');
      rethrow; // Kritiskt fel - appen kan inte fortsätta
    }
  }

  /// 2️⃣ Laddar environment variables för säker API-hantering
  static Future<void> _initializeEnvironmentVariables() async {
    try {
      // Get environment from compile-time constant, default to 'development'
      const env = String.fromEnvironment('ENV', defaultValue: 'development');
      final fileName = '.env.$env';
      
      await dotenv.load(fileName: fileName);
      debugPrint('✅ Environment variables laddade från $fileName');
      debugPrint('ℹ️ Running in $env environment');
    } catch (e) {
      debugPrint('❌ Kunde inte ladda environment file: $e');
      
      // Fallback to default .env file
      try {
        await dotenv.load(fileName: '.env.development');
        debugPrint('✅ Fallback till .env.development');
      } catch (e2) {
        debugPrint('❌ Kunde inte ladda fallback .env.development: $e2');
        debugPrint('ℹ️ Fortsätter utan environment variables');
        // Inte kritiskt - appen fungerar utan API-keys
      }
    }
  }

  /// 3️⃣ Initierar svenska lokaliseringar för datum och formatering
  static Future<void> _initializeLocalization() async {
    try {
      // Initiera svenska först
      await initializeDateFormatting('sv_SE', null);
      await initializeDateFormatting('sv', null); // Fallback

      debugPrint('✅ Svenska lokaliseringar initierade');
    } catch (e) {
      debugPrint('❌ Kunde inte initiera svenska lokaliseringar: $e');
      debugPrint('ℹ️ Fortsätter med engelska som fallback');
      // Inte kritiskt - appen fungerar med engelska datum
    }
  }

  /// 3️⃣ Initierar Firebase med komplett felhantering
  static Future<void> _initializeFirebase() async {
    try {
      // Kontrollera om Firebase redan är initierat
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        debugPrint('✅ Firebase initierad för första gången');
      } else {
        debugPrint('✅ Firebase redan initierad (${Firebase.apps.length} apps)');
      }

      // Initiera App Check för säkerhet
      await _initializeAppCheck();

      // Konfigurera Firestore för bättre prestanda och offline-support
      await _configureFirestore();

      // Utför Firestore-ping om användare är inloggad
      await _performFirestorePing();
    } on FirebaseException catch (e) {
      if (e.code == 'duplicate-app') {
        debugPrint('✅ Firebase redan initierad - duplicate error ignorerad');
      } else {
        debugPrint('❌ Firebase-fel (${e.code}): ${e.message}');
        debugPrint('⚠️ Fortsätter med begränsad Firebase-funktionalitet');
      }
    } catch (e) {
      debugPrint('❌ Generellt Firebase-fel: $e');
      debugPrint('⚠️ Vissa Firebase-funktioner kanske inte fungerar');
    }
  }

  /// Initierar Firebase App Check för säkerhet
  static Future<void> _initializeAppCheck() async {
    try {
      await FirebaseAppCheck.instance.activate(
        // För development/debug använd debug provider
        // För production ska du använda rätt provider för varje plattform
        androidProvider: AndroidProvider.debug,
        appleProvider: AppleProvider.debug,
        webProvider: ReCaptchaV3Provider('recaptcha-v3-site-key'),
      );
      debugPrint('✅ Firebase App Check aktiverat');
    } catch (e) {
      debugPrint('⚠️ App Check kunde inte aktiveras: $e');
      debugPrint('⚠️ Fortsätter utan App Check (utvecklingsläge)');
    }
  }

  /// Konfigurerar Firestore för optimal prestanda och offline-support
  static Future<void> _configureFirestore() async {
    try {
      // Kontrollera om Firestore redan har konfigurerats
      final firestore = FirebaseFirestore.instance;
      
      // Konfigurera Firestore-inställningar
      firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        sslEnabled: true,
      );
      
      debugPrint('✅ Firestore konfigurerat för offline-support');
    } catch (e) {
      debugPrint('⚠️ Firestore-konfiguration misslyckades: $e');
      debugPrint('⚠️ Fortsätter med standard Firestore-inställningar');
    }
  }

  /// Utför Firestore-ping för att testa anslutning
  ///
  /// Endast om användare är inloggad för att undvika onödiga fel
  static Future<void> _performFirestorePing() async {
    try {
      final currentUser = FirebaseAuthRepository().currentUser;

      if (currentUser == null) {
        debugPrint('ℹ️ Ingen användare inloggad, hoppar över Firestore-ping');
        return;
      }

      // Get actual package info
      final packageInfo = await PackageInfo.fromPlatform();
      final appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';

      // Skapa en test-ping till användarens collection
      final doc = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('connection_tests')
          .doc('ping');

      await doc.set({
        'checkedAt': FieldValue.serverTimestamp(),
        'appVersion': appVersion,
      });

      final snapshot = await doc.get();
      if (snapshot.exists) {
        debugPrint('✅ Firestore-ping lyckades för: ${currentUser.email}');
      }
    } catch (e) {
      debugPrint('⚠️ Firestore-ping misslyckades (kan vara permissions): $e');
      // Inte kritiskt - kan vara nätverksproblem eller permissions
    }
  }

  /// 4️⃣ Initierar Analytics Service
  static Future<void> _initializeAnalytics() async {
    try {
      final analyticsService = AnalyticsService();
      await analyticsService.initialize();
      debugPrint('✅ Analytics Service initierad');
    } catch (e) {
      debugPrint('❌ Fel vid Analytics initialization: $e');
      debugPrint('ℹ️ Analytics är inte kritiskt - appen fortsätter');
      // Analytics är inte kritiskt för app-funktionalitet
    }
  }

  /// 5️⃣ Initierar Dependency Injection med GetIt
  static Future<void> _initializeDependencyInjection() async {
    try {
      await initializeDependencies();
      debugPrint('✅ Dependency Injection initierad');

      // Testa att kritiska services fungerar
      await _validateCriticalServices();
    } catch (e) {
      debugPrint('❌ KRITISKT: Fel vid Dependency Injection: $e');
      rethrow; // DI är kritiskt - appen kan inte fungera utan services
    }
  }

  /// Validerar att kritiska services kan skapas
  static Future<void> _validateCriticalServices() async {
    try {
      // Validate core repositories (most critical)
      sl<AuthRepository>();
      debugPrint('✅ AuthRepository validation passed');

      sl<FirestoreRepository>();
      debugPrint('✅ FirestoreRepository validation passed');

      // Validate core services
      sl<AuthService>();
      debugPrint('✅ AuthService validation passed');

      sl<UserService>();
      debugPrint('✅ UserService validation passed');

      // Validate unified services (phase 5 critical services)
      sl<UnifiedRecipeService>();
      debugPrint('✅ UnifiedRecipeService validation passed');

      sl<UnifiedFriendsService>();
      debugPrint('✅ UnifiedFriendsService validation passed');

      // Validate utility services
      sl<PersistenceService>();
      debugPrint('✅ PersistenceService validation passed');

      sl<OfflineService>();
      debugPrint('✅ OfflineService validation passed');

      debugPrint('✅ All critical services validated successfully');
    } catch (e) {
      debugPrint('❌ CRITICAL: Service validation failed: $e');
      debugPrint('❌ App cannot continue without these services');
      rethrow; // Critical failure - app cannot function
    }
  }

  /// 6️⃣ Initierar Offline Service (Hive)
  static Future<void> _initializeOfflineService() async {
    try {
      // Use dependency injection to get the singleton instance
      final offlineService = sl<OfflineService>();
      await offlineService.initialize();
      debugPrint('✅ Offline Service initierad');
    } catch (e) {
      debugPrint('❌ Fel vid Offline Service initialization: $e');
      debugPrint('ℹ️ Offline-funktioner kommer inte fungera');
      // Offline-stöd är inte kritiskt - appen fungerar online
    }
  }

  /// 7️⃣ Initierar Deep Link Service
  static Future<void> _initializeDeepLinkService() async {
    try {
      await DeepLinkService.initializeDynamicLinks();
      debugPrint('✅ Deep Link Service initierad');
    } catch (e) {
      debugPrint('❌ Fel vid Deep Link Service initialization: $e');
      debugPrint('ℹ️ Deep linking kommer inte fungera fullt ut');
      // Deep linking är inte kritiskt - appen fungerar utan det
    }
  }

  /// 🔍 Debug-metod för att visa initialization-status
  ///
  /// Användbar för troubleshooting och development
  static Future<Map<String, bool>> getInitializationStatus() async {
    final status = <String, bool>{};

    try {
      // Kontrollera Firebase
      status['firebase'] = Firebase.apps.isNotEmpty;

      // Kontrollera Auth
      status['auth'] = FirebaseAuthRepository().currentUser != null;

      // Kontrollera DI
      try {
        sl<UnifiedRecipeService>();
        status['dependency_injection'] = true;
      } catch (e) {
        status['dependency_injection'] = false;
      }

      // Kontrollera Offline Service
      try {
        final offlineService = OfflineService();
        status['offline_service'] = offlineService.isInitialized;
      } catch (e) {
        status['offline_service'] = false;
      }

      // Kontrollera Analytics
      try {
        // AnalyticsService har ingen isInitialized property, så vi antar den är ok
        status['analytics'] = true;
      } catch (e) {
        status['analytics'] = false;
      }
    } catch (e) {
      debugPrint('❌ Fel vid status-check: $e');
    }

    return status;
  }

  /// 🚨 Emergency initialization för när normal init misslyckas
  ///
  /// Kör bara det absolut nödvändiga för att appen ska starta
  static Future<void> emergencyInitialize() async {
    debugPrint('🚨 === EMERGENCY INITIALIZATION ===');

    try {
      // Bara Flutter-bindningar och DI
      WidgetsFlutterBinding.ensureInitialized();
      await initializeDependencies();

      debugPrint('✅ Emergency initialization klar');
    } catch (e) {
      debugPrint('❌ Emergency initialization misslyckades: $e');
      // Om detta misslyckas måste appen visa ett error-screen
      rethrow;
    }
  }
}
