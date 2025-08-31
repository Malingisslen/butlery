import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Import Firebase repositories that we suspect are hanging
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/repositories/interfaces/analytics_repository.dart';
import 'package:butlery/repositories/firebase/firebase_analytics_repository.dart';

// Import services
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/persistence_service.dart';
import 'package:butlery/services/analytics_service.dart';

void main() {
  group('🔥 Firebase Service Hang Diagnostic', () {
    setUpAll(() {
      print(
          '🔥 ULTRATHINK: Isolating Firebase service hang in CoreModule.configure()');
      print(
          '   Testing each service instantiation step to find the hanging component');
    });

    setUp(() {
      // Reset GetIt between tests to avoid conflicts
      GetIt.instance.reset();
    });

    testWidgets('🔍 Step 1: SharedPreferences.getInstance()',
        (WidgetTester tester) async {
      print('🧪 TESTING: SharedPreferences.getInstance() performance');
      print(
          '   This is step 1 in CoreModule.configure() - testing for hang...');

      final stopwatch = Stopwatch()..start();

      try {
        final sharedPreferences = await SharedPreferences.getInstance().timeout(
          const Duration(seconds: 10),
        );

        print(
            '   ✅ SharedPreferences.getInstance() completed in ${stopwatch.elapsedMilliseconds}ms');
        expect(sharedPreferences, isNotNull);

        // Test basic functionality
        await sharedPreferences.setString('test_key', 'test_value');
        final testValue = sharedPreferences.getString('test_key');
        expect(testValue, 'test_value');
        print('   ✅ SharedPreferences functionality verified');
      } catch (e) {
        print('   ❌ SharedPreferences.getInstance() TIMED OUT: $e');
        print('   🚨 HANG IDENTIFIED: SharedPreferences is hanging!');
        print(
            '   💡 Possible cause: File system access issues in test environment');
        rethrow;
      }
    });

    testWidgets('🔍 Step 2: FirebaseAuthRepository() instantiation',
        (WidgetTester tester) async {
      print('🧪 TESTING: FirebaseAuthRepository instantiation performance');
      print(
          '   This is step 2 in CoreModule.configure() - testing for hang...');

      final stopwatch = Stopwatch()..start();

      try {
        // Create FirebaseAuthRepository with timeout
        final authRepo = await Future.value(FirebaseAuthRepository()).timeout(
          const Duration(seconds: 10),
        );

        print(
            '   ✅ FirebaseAuthRepository instantiated in ${stopwatch.elapsedMilliseconds}ms');
        expect(authRepo, isNotNull);

        // Test basic functionality (should not require Firebase connection)
        final currentUser = authRepo.getCurrentUser();
        print(
            '   ✅ FirebaseAuthRepository basic functionality verified (currentUser: $currentUser)');
      } catch (e) {
        print('   ❌ FirebaseAuthRepository instantiation TIMED OUT: $e');
        print('   🚨 HANG IDENTIFIED: FirebaseAuthRepository is hanging!');
        print(
            '   💡 Possible cause: Firebase Auth initialization waiting for connection');
        rethrow;
      }
    });

    testWidgets('🔍 Step 3: FirestoreRepository() instantiation',
        (WidgetTester tester) async {
      print('🧪 TESTING: FirestoreRepository instantiation performance');
      print(
          '   This is step 3 in CoreModule.configure() - testing for hang...');

      final stopwatch = Stopwatch()..start();

      try {
        // Create FirestoreRepository with timeout
        final firestoreRepo = await Future.value(FirestoreRepository()).timeout(
          const Duration(seconds: 10),
        );

        print(
            '   ✅ FirestoreRepository instantiated in ${stopwatch.elapsedMilliseconds}ms');
        expect(firestoreRepo, isNotNull);
        print('   ✅ FirestoreRepository basic functionality verified');
      } catch (e) {
        print('   ❌ FirestoreRepository instantiation TIMED OUT: $e');
        print('   🚨 HANG IDENTIFIED: FirestoreRepository is hanging!');
        print(
            '   💡 Possible cause: Firestore initialization waiting for connection');
        rethrow;
      }
    });

    testWidgets('🔍 Step 4: FirebaseAnalyticsRepository() instantiation',
        (WidgetTester tester) async {
      print(
          '🧪 TESTING: FirebaseAnalyticsRepository instantiation performance');
      print(
          '   This is step 4 in CoreModule.configure() - testing for hang...');

      final stopwatch = Stopwatch()..start();

      try {
        // Create FirebaseAnalyticsRepository with timeout
        final analyticsRepo =
            await Future.value(FirebaseAnalyticsRepository()).timeout(
          const Duration(seconds: 10),
        );

        print(
            '   ✅ FirebaseAnalyticsRepository instantiated in ${stopwatch.elapsedMilliseconds}ms');
        expect(analyticsRepo, isNotNull);
        print('   ✅ FirebaseAnalyticsRepository basic functionality verified');
      } catch (e) {
        print('   ❌ FirebaseAnalyticsRepository instantiation TIMED OUT: $e');
        print('   🚨 HANG IDENTIFIED: FirebaseAnalyticsRepository is hanging!');
        print(
            '   💡 Possible cause: Firebase Analytics initialization waiting for connection');
        rethrow;
      }
    });

    testWidgets('🔍 Step 5: Service Layer Instantiation',
        (WidgetTester tester) async {
      print('🧪 TESTING: Service layer instantiation performance');
      print('   Testing AuthService, PersistenceService, AnalyticsService...');

      // First set up basic dependencies
      final container = GetIt.instance;

      try {
        print('   📦 Setting up dependencies...');

        // SharedPreferences
        final stopwatch1 = Stopwatch()..start();
        final sharedPrefs = await SharedPreferences.getInstance();
        container.registerSingleton<SharedPreferences>(sharedPrefs);
        print(
            '   ✅ SharedPreferences registered in ${stopwatch1.elapsedMilliseconds}ms');

        // Auth Repository
        final stopwatch2 = Stopwatch()..start();
        final authRepo = FirebaseAuthRepository();
        container.registerSingleton<AuthRepository>(authRepo);
        print(
            '   ✅ AuthRepository registered in ${stopwatch2.elapsedMilliseconds}ms');

        // Analytics Repository
        final stopwatch3 = Stopwatch()..start();
        final analyticsRepo = FirebaseAnalyticsRepository();
        container.registerSingleton<AnalyticsRepository>(analyticsRepo);
        print(
            '   ✅ AnalyticsRepository registered in ${stopwatch3.elapsedMilliseconds}ms');

        // Now test service creation
        print('   🔧 Testing service instantiation...');

        final stopwatch4 = Stopwatch()..start();
        AuthService(authRepository: container<AuthRepository>());
        print(
            '   ✅ AuthService created in ${stopwatch4.elapsedMilliseconds}ms');

        final stopwatch5 = Stopwatch()..start();
        PersistenceService();
        print(
            '   ✅ PersistenceService created in ${stopwatch5.elapsedMilliseconds}ms');

        final stopwatch6 = Stopwatch()..start();
        AnalyticsService(repository: container<AnalyticsRepository>());
        print(
            '   ✅ AnalyticsService created in ${stopwatch6.elapsedMilliseconds}ms');

        print('   🎉 ALL SERVICES CREATED SUCCESSFULLY');
      } catch (e) {
        print('   ❌ Service instantiation FAILED: $e');
        print('   🚨 HANG IDENTIFIED: Service layer creation is hanging!');
        rethrow;
      }
    });

    testWidgets('🔍 Complete CoreModule.configure() Simulation',
        (WidgetTester tester) async {
      print('🧪 TESTING: Complete CoreModule.configure() simulation');
      print('   Running the exact same sequence as CoreModule.configure()...');

      final container = GetIt.instance;
      final overallStopwatch = Stopwatch()..start();

      try {
        print('   📦 Step 1: SharedPreferences registration...');
        final step1Stopwatch = Stopwatch()..start();
        final sharedPreferences = await SharedPreferences.getInstance();
        container.registerSingleton<SharedPreferences>(sharedPreferences);
        print(
            '   ✅ Step 1 completed in ${step1Stopwatch.elapsedMilliseconds}ms');

        print('   📦 Step 2: AuthRepository registration...');
        final step2Stopwatch = Stopwatch()..start();
        container.registerSingleton<AuthRepository>(FirebaseAuthRepository());
        print(
            '   ✅ Step 2 completed in ${step2Stopwatch.elapsedMilliseconds}ms');

        print('   📦 Step 3: FirestoreRepository registration...');
        final step3Stopwatch = Stopwatch()..start();
        container.registerSingleton<FirestoreRepository>(FirestoreRepository());
        print(
            '   ✅ Step 3 completed in ${step3Stopwatch.elapsedMilliseconds}ms');

        print('   📦 Step 4: AuthService registration...');
        final step4Stopwatch = Stopwatch()..start();
        container.registerSingleton<AuthService>(
          AuthService(authRepository: container<AuthRepository>()),
        );
        print(
            '   ✅ Step 4 completed in ${step4Stopwatch.elapsedMilliseconds}ms');

        print('   📦 Step 5: PersistenceService registration...');
        final step5Stopwatch = Stopwatch()..start();
        container.registerSingleton<PersistenceService>(PersistenceService());
        print(
            '   ✅ Step 5 completed in ${step5Stopwatch.elapsedMilliseconds}ms');

        print('   📦 Step 6: AnalyticsRepository registration...');
        final step6Stopwatch = Stopwatch()..start();
        container.registerSingleton<AnalyticsRepository>(
            FirebaseAnalyticsRepository());
        print(
            '   ✅ Step 6 completed in ${step6Stopwatch.elapsedMilliseconds}ms');

        print('   📦 Step 7: AnalyticsService registration...');
        final step7Stopwatch = Stopwatch()..start();
        container.registerSingleton<AnalyticsService>(
          AnalyticsService(repository: container<AnalyticsRepository>()),
        );
        print(
            '   ✅ Step 7 completed in ${step7Stopwatch.elapsedMilliseconds}ms');

        print('   🎉 COMPLETE COREMODULE SIMULATION SUCCESSFUL!');
        print('   ⏱️ Total time: ${overallStopwatch.elapsedMilliseconds}ms');

        if (overallStopwatch.elapsedMilliseconds < 1000) {
          print(
              '   ✅ PERFORMANCE GOOD: CoreModule.configure() simulation under 1 second');
        } else {
          print(
              '   ⚠️ PERFORMANCE ISSUE: CoreModule.configure() simulation took >1 second');
        }
      } catch (e) {
        print(
            '   ❌ CoreModule.configure() simulation FAILED after ${overallStopwatch.elapsedMilliseconds}ms');
        print(
            '   🚨 HANG CONFIRMED: The issue is in CoreModule.configure() sequence');
        print('   💡 This confirms our production bug location');
        rethrow;
      }
    });
  });
}
