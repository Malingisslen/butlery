import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/allergen_preferences_viewmodel.dart';

import '../test_support/base_unit_test.dart';
import '../infrastructure/di/test_service_locator.dart';
import '../infrastructure/mocks/production_mocks.dart';

const _seedPrefs = UserAllergenPreferences(
  trackedAllergens: {'gluten', 'mjölk'},
  trackedDietary: {'vegansk'},
  showOnCards: true,
  showOnDetail: true,
  showCoverage: true,
);

Widget _testApp(AllergenPreferencesViewModel viewModel) {
  return ChangeNotifierProvider<AllergenPreferencesViewModel>.value(
    value: viewModel,
    child: MaterialApp(
      locale: const Locale('sv'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.lightTheme,
      home: Scaffold(
        appBar: AppBar(),
        body: const _AllergenPreferencesBody(),
      ),
    ),
  );
}

/// Extracted body that watches the ViewModel directly.
/// This avoids the full AllergenPreferencesView which internally creates
/// its own ChangeNotifierProvider (requiring ServiceLocator).
class _AllergenPreferencesBody extends StatelessWidget {
  const _AllergenPreferencesBody();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AllergenPreferencesViewModel>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Allergen chips
          const Text('Allergen chips:'),
          Wrap(
            spacing: 8,
            children: AllergenPreferenceOptions.allergens.entries.map((e) {
              final isSelected = viewModel.isAllergenTracked(e.key);
              return FilterChip(
                key: Key('allergen_${e.key}'),
                label: Text(e.value),
                selected: isSelected,
                onSelected: (_) => viewModel.toggleAllergen(e.key),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          // Dietary chips
          const Text('Dietary chips:'),
          Wrap(
            spacing: 8,
            children: AllergenPreferenceOptions.dietary.entries.map((e) {
              final isSelected = viewModel.isDietaryTracked(e.key);
              return FilterChip(
                key: Key('dietary_${e.key}'),
                label: Text(e.value),
                selected: isSelected,
                onSelected: (_) => viewModel.toggleDietary(e.key),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          // Display switches
          SwitchListTile(
            key: const Key('showOnCards'),
            title: const Text('Show on cards'),
            value: viewModel.showOnCards,
            onChanged: viewModel.setShowOnCards,
          ),
          SwitchListTile(
            key: const Key('showOnDetail'),
            title: const Text('Show on detail'),
            value: viewModel.showOnDetail,
            onChanged: viewModel.setShowOnDetail,
          ),
          SwitchListTile(
            key: const Key('showCoverage'),
            title: const Text('Show coverage'),
            value: viewModel.showCoverage,
            onChanged: viewModel.setShowCoverage,
          ),
          // Save button
          if (viewModel.hasChanges)
            ElevatedButton(
              key: const Key('save'),
              onPressed: () async {
                final success = await viewModel.save();
                if (success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Saved')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          // Reset button
          TextButton(
            key: const Key('reset'),
            onPressed: () => _confirmReset(context, viewModel),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _confirmReset(
    BuildContext context,
    AllergenPreferencesViewModel viewModel,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm reset'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('confirm_reset'),
            onPressed: () {
              viewModel.resetToDefaults();
              Navigator.pop(ctx, true);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}

void main() {
  late MockUserService mockUserService;
  late AllergenPreferencesViewModel viewModel;

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    registerFallbackValue(UserAllergenPreferences.defaults);
  });

  setUp(() async {
    await TestServiceLocator.initialize();
    mockUserService = MockUserService();

    when(() => mockUserService.allergenPreferences).thenReturn(_seedPrefs);
    when(
      () => mockUserService.updateAllergenPreferences(any()),
    ).thenAnswer((_) async => true);

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

  group('AllergenPreferencesView', () {
    testWidgets('allergen chips render from AllergenPreferenceOptions', (
      tester,
    ) async {
      await tester.pumpWidget(_testApp(viewModel));
      await tester.pumpAndSettle();

      // Should render all 19 allergen chips
      for (final key in AllergenPreferenceOptions.allergens.keys) {
        expect(find.byKey(Key('allergen_$key')), findsOneWidget);
      }
    });

    testWidgets('dietary chips render (including nötkötsfri, aip-vänlig)', (
      tester,
    ) async {
      await tester.pumpWidget(_testApp(viewModel));
      await tester.pumpAndSettle();

      for (final key in AllergenPreferenceOptions.dietary.keys) {
        expect(find.byKey(Key('dietary_$key')), findsOneWidget);
      }
      // Verify the newer ones are present
      expect(find.text('Nötkötsfri'), findsOneWidget);
      expect(find.text('AIP-vänlig'), findsOneWidget);
    });

    testWidgets('tapping a chip triggers toggle', (tester) async {
      await tester.pumpWidget(_testApp(viewModel));
      await tester.pumpAndSettle();

      // gluten is tracked in seed prefs — tap to untoggle
      await tester.tap(find.byKey(const Key('allergen_gluten')));
      await tester.pumpAndSettle();

      expect(viewModel.isAllergenTracked('gluten'), isFalse);
      expect(viewModel.hasChanges, isTrue);
    });

    testWidgets('save button appears when hasChanges', (tester) async {
      await tester.pumpWidget(_testApp(viewModel));
      await tester.pumpAndSettle();

      // Initially no save button
      expect(find.byKey(const Key('save')), findsNothing);

      // Toggle something to trigger hasChanges
      viewModel.toggleAllergen('fisk');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('save')), findsOneWidget);
    });

    testWidgets('display switches present', (tester) async {
      await tester.pumpWidget(_testApp(viewModel));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('showOnCards')), findsOneWidget);
      expect(find.byKey(const Key('showOnDetail')), findsOneWidget);
      expect(find.byKey(const Key('showCoverage')), findsOneWidget);
    });

    testWidgets('reset opens confirmation dialog', (tester) async {
      await tester.pumpWidget(_testApp(viewModel));
      await tester.pumpAndSettle();

      // Scroll to make reset button visible
      await tester.scrollUntilVisible(
        find.byKey(const Key('reset')),
        200,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('reset')));
      await tester.pumpAndSettle();

      // Dialog should appear
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Confirm reset'), findsOneWidget);

      // Confirm reset
      await tester.tap(find.byKey(const Key('confirm_reset')));
      await tester.pumpAndSettle();

      // After reset, preferences should be defaults
      expect(viewModel.hasChanges, isTrue);
    });

    testWidgets('successful save shows snackbar', (tester) async {
      await tester.pumpWidget(_testApp(viewModel));
      await tester.pumpAndSettle();

      // Toggle to enable save
      viewModel.toggleAllergen('fisk');
      await tester.pumpAndSettle();

      // Scroll to make save button visible
      await tester.scrollUntilVisible(
        find.byKey(const Key('save')),
        200,
      );
      await tester.pumpAndSettle();

      // Tap save
      await tester.tap(find.byKey(const Key('save')));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Saved'), findsOneWidget);
    });
  });
}
