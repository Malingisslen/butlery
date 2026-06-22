/// REC-07 — behaviour tests for [QuickCaptureView], the lightweight
/// title-only recipe capture screen.
///
/// The view owns a private `_QuickCaptureViewModel` that normally resolves
/// [UnifiedRecipeService] from the production [ServiceLocator]. BUT-1353 added
/// a minimal `@visibleForTesting recipeService` ctor seam (defaulting to the
/// ServiceLocator lookup, so production callers are unchanged) so a fake
/// service can be injected directly — no DI graph stand-up required.
///
/// We prove the three user-visible contracts of the save flow:
///   1. validation blocks an empty title (no save attempt);
///   2. a successful save pops the screen and routes the recipe through the
///      service's personal module exactly once;
///   3. a failed save keeps the user on the screen (does NOT pop).
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/views/quick_capture_view.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/unified/types/recipe_types.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/theme/app_theme.dart';

import '../../../infrastructure/mocks/production_mocks.dart';

class _FakeRecipe extends Fake implements Recipe {}

void main() {
  late MockUnifiedRecipeService recipeService;
  late MockPersonalRecipeOperations personalOps;
  final sv = AppLocalizationsSv();

  setUpAll(() {
    registerFallbackValue(_FakeRecipe());
  });

  setUp(() {
    personalOps = MockPersonalRecipeOperations();
    recipeService = MockUnifiedRecipeService();
    // The view's VM calls `service.personal.addUnifiedRecipe(...)`; wire the
    // personal module through the mock service so that getter resolves.
    recipeService.setRecipeState(
      isInitialized: true,
      personalOperations: personalOps,
    );
  });

  // A navigator observer that records pops so the success/failure routing
  // contract can be asserted without depending on the snackbar internals.
  Widget testApp(NavigatorObserver observer) {
    return MaterialApp(
      locale: const Locale('sv'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.lightTheme,
      navigatorObservers: [observer],
      // Push the view onto a route so a successful save's Navigator.pop has a
      // route to return to (the home route below).
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      QuickCaptureView(recipeService: recipeService),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openCapture(WidgetTester tester, _PopObserver observer) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(testApp(observer));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('renders the title field and save button', (tester) async {
    // Baseline: the capture screen identifies itself and exposes the save CTA.
    await openCapture(tester, _PopObserver());

    expect(find.text(sv.quickCaptureTitle), findsOneWidget);
    expect(
        find.byKey(const ValueKey('test-quick-capture-save')), findsOneWidget);
  });

  testWidgets('empty title fails validation and does not call the service',
      (tester) async {
    // Proves: the form guard blocks a blank title — the service is never asked
    // to persist an untitled recipe, and the validation message surfaces.
    final observer = _PopObserver();
    await openCapture(tester, observer);
    final popsBefore = observer.popCount;

    await tester.tap(find.byKey(const ValueKey('test-quick-capture-save')));
    await tester.pumpAndSettle();

    expect(find.text(sv.validationTitleCannotBeEmpty), findsOneWidget);
    verifyNever(() => personalOps.addUnifiedRecipe(any()));
    // The screen stays put — no pop happened on a failed validation.
    expect(observer.popCount, popsBefore);
  });

  testWidgets('successful save persists the recipe and pops the screen',
      (tester) async {
    // Proves: a valid title routes through the personal module and, on success,
    // returns the user to the previous screen (Navigator.pop).
    when(() => personalOps.addUnifiedRecipe(any())).thenAnswer(
      (_) async => RecipeOperationResult.success('ok'),
    );

    final observer = _PopObserver();
    await openCapture(tester, observer);
    final popsBefore = observer.popCount;

    await tester.enterText(
        find.byType(TextFormField), 'Köttbullar med potatismos');
    await tester.tap(find.byKey(const ValueKey('test-quick-capture-save')));
    await tester.pumpAndSettle();

    final captured = verify(() => personalOps.addUnifiedRecipe(captureAny()))
        .captured
        .single as Recipe;
    expect(captured.title, 'Köttbullar med potatismos');
    expect(observer.popCount, greaterThan(popsBefore),
        reason: 'A successful quick-save must return to the previous screen.');
  });

  testWidgets('failed save keeps the user on the capture screen',
      (tester) async {
    // Proves: when persistence fails the user is NOT navigated away — they keep
    // their typed title and can retry, rather than silently losing the screen.
    when(() => personalOps.addUnifiedRecipe(any())).thenAnswer(
      (_) async => RecipeOperationResult.failure('boom'),
    );

    final observer = _PopObserver();
    await openCapture(tester, observer);
    final popsBefore = observer.popCount;

    await tester.enterText(find.byType(TextFormField), 'Pannkakor');
    await tester.tap(find.byKey(const ValueKey('test-quick-capture-save')));
    await tester.pumpAndSettle();

    expect(observer.popCount, popsBefore,
        reason: 'A failed save must keep the user on the capture screen.');
    // The title field still shows what the user typed (still on the screen).
    expect(find.text('Pannkakor'), findsOneWidget);
  });
}

/// Counts route pops so save success/failure routing can be asserted without
/// reaching into snackbar or route-name internals.
class _PopObserver extends NavigatorObserver {
  int popCount = 0;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    popCount++;
    super.didPop(route, previousRoute);
  }
}
