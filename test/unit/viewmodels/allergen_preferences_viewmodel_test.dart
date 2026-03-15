import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/allergen_preferences_viewmodel.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/services/user_service.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('AllergenPreferencesViewModel', () {
    late AllergenPreferencesViewModel viewModel;
    late MockUserService mockUserService;

    // Shared test preferences seeded from service
    const seedPreferences = UserAllergenPreferences(
      trackedAllergens: {'gluten', 'mjölk'},
      trackedDietary: {'vegansk'},
      showOnCards: true,
      showOnDetail: true,
      showCoverage: false,
    );

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(UserAllergenPreferences.defaults);
    });

    setUp(() async {
      await TestServiceLocator.initialize();
      mockUserService = MockUserService();

      when(() => mockUserService.allergenPreferences)
          .thenReturn(seedPreferences);
      when(() => mockUserService.updateAllergenPreferences(any()))
          .thenAnswer((_) async => true);

      TestServiceLocator.registerMock<UserService>(mockUserService);
      viewModel = AllergenPreferencesViewModel(userService: mockUserService);
    });

    tearDown(() async {
      viewModel.dispose();
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    // ---- Initialization ----

    group('initialization', () {
      test('should load preferences from UserService', () {
        expect(viewModel.preferences, equals(seedPreferences));
      });

      test('should have trackedAllergens matching seed data', () {
        expect(viewModel.trackedAllergens, equals({'gluten', 'mjölk'}));
      });

      test('should have trackedDietary matching seed data', () {
        expect(viewModel.trackedDietary, equals({'vegansk'}));
      });

      test('should have hasChanges false initially', () {
        expect(viewModel.hasChanges, isFalse);
      });

      test('should have isLoading false initially', () {
        expect(viewModel.isLoading, isFalse);
      });

      test('should have no error initially', () {
        expect(viewModel.hasError, isFalse);
      });

      test('should reflect display settings from seed data', () {
        expect(viewModel.showOnCards, isTrue);
        expect(viewModel.showOnDetail, isTrue);
        expect(viewModel.showCoverage, isFalse);
      });

      test('should report tracked allergens via isAllergenTracked', () {
        expect(viewModel.isAllergenTracked('gluten'), isTrue);
        expect(viewModel.isAllergenTracked('mjölk'), isTrue);
        expect(viewModel.isAllergenTracked('nötter'), isFalse);
      });

      test('should report tracked dietary via isDietaryTracked', () {
        expect(viewModel.isDietaryTracked('vegansk'), isTrue);
        expect(viewModel.isDietaryTracked('vegetarisk'), isFalse);
      });
    });

    // ---- Toggle allergen ----

    group('toggleAllergen', () {
      test('should remove allergen when currently tracked', () {
        viewModel.toggleAllergen('gluten');

        expect(viewModel.isAllergenTracked('gluten'), isFalse);
        expect(viewModel.trackedAllergens, equals({'mjölk'}));
      });

      test('should add allergen when not currently tracked', () {
        viewModel.toggleAllergen('nötter');

        expect(viewModel.isAllergenTracked('nötter'), isTrue);
        expect(
            viewModel.trackedAllergens, equals({'gluten', 'mjölk', 'nötter'}));
      });

      test('should set hasChanges to true after toggle', () {
        viewModel.toggleAllergen('gluten');

        expect(viewModel.hasChanges, isTrue);
      });

      test('should toggle allergen back after two toggles', () {
        viewModel.toggleAllergen('gluten'); // remove
        expect(viewModel.isAllergenTracked('gluten'), isFalse);

        viewModel.toggleAllergen('gluten'); // add back
        expect(viewModel.isAllergenTracked('gluten'), isTrue);
      });

      test('should notify listeners when toggling', () {
        var notified = false;
        viewModel.addListener(() => notified = true);

        viewModel.toggleAllergen('gluten');

        expect(notified, isTrue);
      });
    });

    // ---- Toggle dietary ----

    group('toggleDietary', () {
      test('should remove dietary when currently tracked', () {
        viewModel.toggleDietary('vegansk');

        expect(viewModel.isDietaryTracked('vegansk'), isFalse);
        expect(viewModel.trackedDietary, isEmpty);
      });

      test('should add dietary when not currently tracked', () {
        viewModel.toggleDietary('vegetarisk');

        expect(viewModel.isDietaryTracked('vegetarisk'), isTrue);
        expect(viewModel.trackedDietary, equals({'vegansk', 'vegetarisk'}));
      });

      test('should set hasChanges to true after toggle', () {
        viewModel.toggleDietary('vegansk');

        expect(viewModel.hasChanges, isTrue);
      });

      test('should toggle dietary back after two toggles', () {
        viewModel.toggleDietary('vegansk'); // remove
        expect(viewModel.isDietaryTracked('vegansk'), isFalse);

        viewModel.toggleDietary('vegansk'); // add back
        expect(viewModel.isDietaryTracked('vegansk'), isTrue);
      });

      test('should notify listeners when toggling', () {
        var notified = false;
        viewModel.addListener(() => notified = true);

        viewModel.toggleDietary('vegetarisk');

        expect(notified, isTrue);
      });
    });

    // ---- Display settings ----

    group('display settings', () {
      test('should update showOnCards and set hasChanges', () {
        viewModel.setShowOnCards(false);

        expect(viewModel.showOnCards, isFalse);
        expect(viewModel.hasChanges, isTrue);
      });

      test('should update showOnDetail and set hasChanges', () {
        viewModel.setShowOnDetail(false);

        expect(viewModel.showOnDetail, isFalse);
        expect(viewModel.hasChanges, isTrue);
      });

      test('should update showCoverage and set hasChanges', () {
        viewModel.setShowCoverage(true);

        expect(viewModel.showCoverage, isTrue);
        expect(viewModel.hasChanges, isTrue);
      });

      test('should notify listeners when changing showOnCards', () {
        var notified = false;
        viewModel.addListener(() => notified = true);

        viewModel.setShowOnCards(false);

        expect(notified, isTrue);
      });

      test('should notify listeners when changing showOnDetail', () {
        var notified = false;
        viewModel.addListener(() => notified = true);

        viewModel.setShowOnDetail(false);

        expect(notified, isTrue);
      });

      test('should notify listeners when changing showCoverage', () {
        var notified = false;
        viewModel.addListener(() => notified = true);

        viewModel.setShowCoverage(true);

        expect(notified, isTrue);
      });
    });

    // ---- Save ----

    group('save', () {
      test('should call updateAllergenPreferences on success', () async {
        viewModel.toggleAllergen('gluten'); // make a change first

        final result = await viewModel.save();

        expect(result, isTrue);
        verify(() => mockUserService.updateAllergenPreferences(any()))
            .called(1);
      });

      test('should clear hasChanges on successful save', () async {
        viewModel.toggleAllergen('gluten');
        expect(viewModel.hasChanges, isTrue);

        await viewModel.save();

        expect(viewModel.hasChanges, isFalse);
      });

      test('should set hasError when service returns false', () async {
        when(() => mockUserService.updateAllergenPreferences(any()))
            .thenAnswer((_) async => false);

        viewModel.toggleAllergen('gluten');
        final result = await viewModel.save();

        // executeAsyncVoid catches the thrown exception and returns false
        expect(result, isFalse);
        expect(viewModel.hasError, isTrue);
      });

      test('should keep hasChanges when save fails', () async {
        when(() => mockUserService.updateAllergenPreferences(any()))
            .thenAnswer((_) async => false);

        viewModel.toggleAllergen('gluten');
        await viewModel.save();

        // hasChanges stays true because save() only clears it on success
        expect(viewModel.hasChanges, isTrue);
      });

      test('should set hasError when service throws', () async {
        when(() => mockUserService.updateAllergenPreferences(any()))
            .thenThrow(Exception('Network error'));

        viewModel.toggleAllergen('gluten');
        final result = await viewModel.save();

        expect(result, isFalse);
        expect(viewModel.hasError, isTrue);
      });

      test('should pass current preferences to service', () async {
        viewModel.toggleAllergen('gluten'); // removes gluten
        viewModel.setShowCoverage(true);

        await viewModel.save();

        final captured = verify(
          () => mockUserService.updateAllergenPreferences(captureAny()),
        ).captured.single as UserAllergenPreferences;

        expect(captured.trackedAllergens, equals({'mjölk'}));
        expect(captured.showCoverage, isTrue);
      });
    });

    // ---- Reset to defaults ----

    group('resetToDefaults', () {
      test('should set preferences to UserAllergenPreferences.defaults', () {
        // First make some changes so state differs from defaults
        viewModel.toggleAllergen('gluten');
        viewModel.setShowCoverage(true);

        viewModel.resetToDefaults();

        expect(viewModel.preferences, equals(UserAllergenPreferences.defaults));
      });

      test('should set hasChanges to true', () {
        viewModel.resetToDefaults();

        expect(viewModel.hasChanges, isTrue);
      });

      test('should have default tracked allergens', () {
        viewModel.resetToDefaults();

        expect(viewModel.trackedAllergens,
            equals({'gluten', 'mjölk', 'nötter', 'jordnötter'}));
      });

      test('should have default tracked dietary', () {
        viewModel.resetToDefaults();

        expect(viewModel.trackedDietary, equals({'vegetarisk', 'vegansk'}));
      });

      test('should have default display settings', () {
        viewModel.resetToDefaults();

        expect(viewModel.showOnCards, isTrue);
        expect(viewModel.showOnDetail, isTrue);
        expect(viewModel.showCoverage, isTrue);
      });

      test('should notify listeners', () {
        var notified = false;
        viewModel.addListener(() => notified = true);

        viewModel.resetToDefaults();

        expect(notified, isTrue);
      });
    });

    // ---- Discard changes ----

    group('discardChanges', () {
      test('should reload preferences from service', () {
        viewModel.toggleAllergen('gluten'); // mutate local state
        viewModel.setShowOnCards(false);

        viewModel.discardChanges();

        // Should match the seed preferences from the mock
        expect(viewModel.preferences, equals(seedPreferences));
        expect(viewModel.showOnCards, isTrue);
        expect(viewModel.isAllergenTracked('gluten'), isTrue);
      });

      test('should clear hasChanges', () {
        viewModel.toggleAllergen('gluten');
        expect(viewModel.hasChanges, isTrue);

        viewModel.discardChanges();

        expect(viewModel.hasChanges, isFalse);
      });

      test('should notify listeners', () {
        viewModel.toggleAllergen('gluten');

        var notified = false;
        viewModel.addListener(() => notified = true);

        viewModel.discardChanges();

        expect(notified, isTrue);
      });

      test('should use current service value when discarding', () {
        // Simulate the service returning different preferences after an external update
        const updatedPreferences = UserAllergenPreferences(
          trackedAllergens: {'soja'},
          trackedDietary: {'vegetarisk'},
          showOnCards: false,
          showOnDetail: false,
          showCoverage: true,
        );
        when(() => mockUserService.allergenPreferences)
            .thenReturn(updatedPreferences);

        viewModel.discardChanges();

        expect(viewModel.preferences, equals(updatedPreferences));
        expect(viewModel.trackedAllergens, equals({'soja'}));
        expect(viewModel.showOnCards, isFalse);
      });
    });
  });
}
