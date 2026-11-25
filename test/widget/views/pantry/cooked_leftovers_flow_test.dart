/// BUT-2486 part 5: the one sheet after Klart that keeps leftovers as meal
/// boxes and takes what the recipe used from the pantry.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/models/menu/meal_box.dart';
import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/models/recipe/recipe_ingredient.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/analytics/analytics_events.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/menu/meal_box_service.dart';
import 'package:butlery/services/pantry/cooked_pantry_plan.dart';
import 'package:butlery/services/pantry/pantry_service.dart';
import 'package:butlery/views/pantry/cooked_pantry_flow.dart';
import 'package:butlery/widgets/common/buttons/hero_button.dart';
import 'package:butlery/widgets/pantry/meal_boxes/cooked_leftovers_sheet.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/helpers/base_widget_test.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';

class _MockPantry extends Mock implements PantryService {}

class _MockBoxes extends Mock implements MealBoxService {}

class _MockAnalytics extends Mock implements AnalyticsService {}

final _recipe = Recipe(
  core: RecipeCore(
    id: 'r1',
    title: 'Chili',
    description: '',
    ingredients: ['2 dl mjöl'],
    structuredIngredients: [
      RecipeIngredient(amount: 2, unit: 'dl', name: 'mjöl', raw: '2 dl mjöl'),
    ],
    instructions: ['x'],
    mealType: 'Middag',
    portions: 6,
  ),
  type: RecipeType.personal,
);

// A second ingredient, so a take can fail halfway.
final _twoIngredients = Recipe(
  core: RecipeCore(
    id: 'r2',
    title: 'Chili',
    description: '',
    ingredients: ['2 dl mjöl', '1 dl socker'],
    structuredIngredients: [
      RecipeIngredient(amount: 2, unit: 'dl', name: 'mjöl', raw: '2 dl mjöl'),
      RecipeIngredient(
        amount: 1,
        unit: 'dl',
        name: 'socker',
        raw: '1 dl socker',
      ),
    ],
    instructions: ['x'],
    mealType: 'Middag',
    portions: 6,
  ),
  type: RecipeType.personal,
);

final _sugar = PantryItem(
  id: 'b',
  ingredientName: 'Socker',
  quantity: 5,
  unit: 'dl',
  location: PantryLocation.pantry,
  addedAt: DateTime.utc(2026, 1, 1),
);

final _flour = PantryItem(
  id: 'a',
  ingredientName: 'Mjöl',
  quantity: 5,
  unit: 'dl',
  location: PantryLocation.pantry,
  addedAt: DateTime.utc(2026, 1, 1),
);

void main() {
  setUpAll(() async {
    await BaseWidgetTest.setupWidget();
    registerFallbackValue(<CookedPantryTake>[]);
    registerFallbackValue(
      MealBox(
        id: '',
        recipeTitle: 'x',
        location: MealBoxLocation.fridge,
        storedOn: DateTime(2026),
      ),
    );
  });

  late _MockPantry pantry;
  late _MockBoxes boxes;
  late _MockAnalytics analytics;
  var pantrySheets = 0;
  var leftoverSheets = 0;
  CookedLeftoversOffer? seen;

  setUp(() {
    pantry = _MockPantry();
    boxes = _MockBoxes();
    analytics = _MockAnalytics();
    // The flow looks analytics up in the production locator, which the test
    // locator does not stand up.
    production.ServiceLocator.initialize(DIContainer());
    TestServiceLocator.registerMock<AnalyticsService>(analytics);
    when(
      () => analytics.logEvent(
        name: any(named: 'name'),
        parameters: any(named: 'parameters'),
      ),
    ).thenAnswer((_) async {});
    pantrySheets = 0;
    leftoverSheets = 0;
    seen = null;
    when(() => pantry.getAll(any())).thenAnswer((_) async => [_flour]);
    when(() => pantry.takeCooked(any(), any())).thenAnswer(
      (i) async => i.positionalArguments[1] as List<CookedPantryTake>,
    );
    when(() => pantry.undoTakeCooked(any(), any())).thenAnswer((_) async {});
    when(() => boxes.add(any())).thenAnswer((_) async => 'box1');
    when(() => boxes.remove(any())).thenAnswer((_) async {});
  });

  tearDown(production.ServiceLocator.reset);

  Future<void> run(
    WidgetTester tester, {
    int? household = 4,
    bool flag = true,
    int portions = 6,
    CookedLeftoversResult? Function(CookedLeftoversOffer)? answer,
    bool useRealLeftoversSheet = false,
    Recipe? recipe,
  }) async {
    final flow = CookedPantryFlow(
      service: () => pantry,
      userId: () => 'u',
      mealBoxes: () => boxes,
      householdSize: () => household,
      mealBoxesOn: () => flag,
      openSheet: (context, takes, p) async {
        pantrySheets++;
        return takes;
      },
      openLeftoversSheet: useRealLeftoversSheet
          ? null
          : (context, offer) async {
              leftoverSheets++;
              seen = offer;
              return answer?.call(offer);
            },
    );
    tester.view.physicalSize = const Size(600, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                flow.offer(context, recipe ?? _recipe, portions: portions),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
  }

  CookedLeftoversResult spara(
    CookedLeftoversOffer offer, {
    int boxes = 2,
    MealBoxLocation location = MealBoxLocation.fridge,
    bool withPantry = true,
  }) => CookedLeftoversResult(
    boxes: boxes,
    location: location,
    pantryTakes: withPantry ? offer.pantryTakes : const [],
  );

  testWidgets('household 4 and 6 portions offers 2 boxes', (tester) async {
    await run(tester);

    expect(leftoverSheets, 1);
    expect(pantrySheets, 0);
    expect(seen!.defaultCount, 2);
    expect(seen!.eaters, 4);
    expect(seen!.pantryTakes, hasLength(1));
  });

  testWidgets('the default is clamped to 99', (tester) async {
    await run(tester, portions: 400);

    expect(seen!.defaultCount, 99);
  });

  testWidgets('an unreadable pantry still offers the boxes', (tester) async {
    when(() => pantry.getAll(any())).thenThrow(StateError('offline'));

    await run(tester, answer: (o) => spara(o, withPantry: false));

    expect(leftoverSheets, 1);
    expect(seen!.pantryTakes, isEmpty);
    verify(() => boxes.add(any())).called(1);
    verifyNever(() => pantry.takeCooked(any(), any()));
    expect(find.text('Sparade 2 matlådor i kylen'), findsOneWidget);
  });

  testWidgets('no household size: only the old pantry sheet', (tester) async {
    await run(tester, household: null);

    expect(leftoverSheets, 0);
    expect(pantrySheets, 1);
    verifyNever(() => boxes.add(any()));
  });

  testWidgets('household as big as the meal: no box offer', (tester) async {
    await run(tester, household: 6);

    expect(leftoverSheets, 0);
    expect(pantrySheets, 1);
  });

  testWidgets('flag off: the old flow and the box service stays untouched', (
    tester,
  ) async {
    await run(tester, flag: false);

    expect(leftoverSheets, 0);
    expect(pantrySheets, 1);
    verifyZeroInteractions(boxes);
  });

  testWidgets('no box offer and nothing in the pantry: nothing opens', (
    tester,
  ) async {
    when(() => pantry.getAll(any())).thenAnswer((_) async => []);

    await run(tester, household: null);

    expect(leftoverSheets + pantrySheets, 0);
  });

  testWidgets('skipping writes nothing', (tester) async {
    await run(tester, answer: (_) => null);

    verifyNever(() => boxes.add(any()));
    verifyNever(() => pantry.takeCooked(any(), any()));
  });

  testWidgets('the box is written with the recipe, place and count', (
    tester,
  ) async {
    await run(
      tester,
      answer: (o) => spara(
        o,
        boxes: 3,
        location: MealBoxLocation.freezer,
        withPantry: false,
      ),
    );

    final box =
        verify(() => boxes.add(captureAny())).captured.single as MealBox;
    expect(box.id, '');
    expect(box.recipeId, 'r1');
    expect(box.recipeTitle, 'Chili');
    expect(box.location, MealBoxLocation.freezer);
    expect(box.count, 3);
    expect(find.text('Sparade 3 matlådor i frysen'), findsOneWidget);
  });

  testWidgets('one Ångra undoes both the box and the pantry take', (
    tester,
  ) async {
    await run(tester, answer: spara);

    expect(
      find.text('Sparade 2 matlådor och drog av 1 vara'),
      findsOneWidget,
    );
    await tester.tap(find.text('Ångra'));
    await tester.pumpAndSettle();

    verify(() => boxes.remove('box1')).called(1);
    verify(() => pantry.undoTakeCooked('u', any())).called(1);
  });

  testWidgets('pantry only through the new sheet keeps the old message', (
    tester,
  ) async {
    await run(tester, answer: (o) => spara(o, boxes: 0));

    verifyNever(() => boxes.add(any()));
    expect(find.text('1 vara dragen från skafferiet'), findsOneWidget);
  });

  testWidgets('a refused box keeps Ångra for what was written', (
    tester,
  ) async {
    when(() => boxes.add(any())).thenThrow(StateError('refused'));

    await run(tester, answer: spara);

    expect(find.text('Kunde inte spara matlådorna'), findsOneWidget);
    await tester.tap(find.text('Ångra'));
    await tester.pumpAndSettle();
    verify(() => pantry.undoTakeCooked('u', any())).called(1);
    verifyNever(() => boxes.remove(any()));
  });

  testWidgets('a refused pantry take keeps Ångra for the saved box', (
    tester,
  ) async {
    when(
      () => pantry.takeCooked(any(), any()),
    ).thenThrow(CookedPantryTakeFailed(const [], StateError('refused')));

    await run(tester, answer: spara);

    expect(find.textContaining('Kunde inte dra av allt'), findsOneWidget);
    await tester.tap(find.text('Ångra'));
    await tester.pumpAndSettle();
    verify(() => boxes.remove('box1')).called(1);
  });

  group('analytics', () {
    void verifyOfferShown(int times) => verify(
      () => analytics.logEvent(
        name: AnalyticsEvents.mealBoxOfferShown,
        parameters: any(named: 'parameters'),
      ),
    ).called(times);

    void verifySavedNever() => verifyNever(
      () => analytics.logEvent(
        name: AnalyticsEvents.mealBoxOfferSaved,
        parameters: any(named: 'parameters'),
      ),
    );

    testWidgets('the offer is logged when the sheet opens, also on skip', (
      tester,
    ) async {
      await run(tester, answer: (_) => null);

      verifyOfferShown(1);
      verifySavedNever();
    });

    testWidgets('no offer, no event', (tester) async {
      await run(tester, household: 6);

      verifyZeroInteractions(analytics);
    });

    testWidgets('saved carries the count and the place', (tester) async {
      await run(
        tester,
        answer: (o) => spara(
          o,
          boxes: 3,
          location: MealBoxLocation.freezer,
          withPantry: false,
        ),
      );
      await tester.pump();

      verify(
        () => analytics.logEvent(
          name: AnalyticsEvents.mealBoxOfferSaved,
          parameters: {'count': 3, 'location': 'freezer'},
        ),
      ).called(1);
    });

    testWidgets('a refused box is offered but never reported as saved', (
      tester,
    ) async {
      when(
        () => boxes.add(any()),
      ).thenAnswer((_) => Future.error(StateError('refused')));

      await run(tester, answer: spara);

      verifyOfferShown(1);
      verifySavedNever();
    });

    testWidgets('a pantry-only save is not a box save', (tester) async {
      await run(tester, answer: (o) => spara(o, boxes: 0));

      verifyOfferShown(1);
      verifySavedNever();
    });

    testWidgets('a failing analytics service does not cost the user the save', (
      tester,
    ) async {
      when(
        () => analytics.logEvent(
          name: any(named: 'name'),
          parameters: any(named: 'parameters'),
        ),
      ).thenAnswer((_) => Future<void>.error(StateError('offline')));

      await run(tester, answer: spara);

      verify(() => boxes.add(any())).called(1);
      expect(
        find.text('Sparade 2 matlådor och drog av 1 vara'),
        findsOneWidget,
      );
    });
  });

  testWidgets('a blank recipe title offers no box, only the pantry', (
    tester,
  ) async {
    final blank = Recipe(
      core: RecipeCore(
        id: 'r3',
        title: '  ',
        description: '',
        ingredients: ['2 dl mjöl'],
        structuredIngredients: [
          RecipeIngredient(
            amount: 2,
            unit: 'dl',
            name: 'mjöl',
            raw: '2 dl mjöl',
          ),
        ],
        instructions: ['x'],
        mealType: 'Middag',
        portions: 6,
      ),
      type: RecipeType.personal,
    );

    await run(tester, recipe: blank);

    expect(leftoverSheets, 0);
    expect(pantrySheets, 1);
    verifyNever(() => boxes.add(any()));
    verify(() => pantry.takeCooked('u', any())).called(1);
    expect(find.text('1 vara dragen från skafferiet'), findsOneWidget);
  });

  group('failures', () {
    testWidgets('a refused box with nothing else written: message, no Ångra', (
      tester,
    ) async {
      when(
        () => boxes.add(any()),
      ).thenAnswer((_) => Future.error(StateError('refused')));

      await run(tester, answer: (o) => spara(o, withPantry: false));

      expect(find.text('Kunde inte spara matlådorna'), findsOneWidget);
      expect(find.text('Ångra'), findsNothing);
      verifyNever(() => pantry.takeCooked(any(), any()));
    });

    testWidgets(
      'a refused pantry take with nothing written: message, no Ångra',
      (
        tester,
      ) async {
        when(
          () => pantry.takeCooked(any(), any()),
        ).thenAnswer((_) => Future.error(StateError('refused')));

        await run(tester, answer: (o) => spara(o, boxes: 0));

        expect(find.textContaining('Kunde inte dra av allt'), findsOneWidget);
        expect(find.text('Ångra'), findsNothing);
        verifyNever(() => boxes.add(any()));
      },
    );

    testWidgets('a pantry take that reports nothing written offers no Ångra', (
      tester,
    ) async {
      when(() => pantry.takeCooked(any(), any())).thenAnswer(
        (_) => Future.error(CookedPantryTakeFailed(const [], StateError('x'))),
      );

      await run(tester, answer: (o) => spara(o, boxes: 0));

      expect(find.textContaining('Kunde inte dra av allt'), findsOneWidget);
      expect(find.text('Ångra'), findsNothing);
    });

    testWidgets('both refused: one message naming both, and nothing to undo', (
      tester,
    ) async {
      when(
        () => boxes.add(any()),
      ).thenAnswer((_) => Future.error(StateError('refused')));
      when(
        () => pantry.takeCooked(any(), any()),
      ).thenAnswer((_) => Future.error(StateError('refused')));

      await run(tester, answer: spara);

      expect(
        find.text(
          'Kunde inte spara matlådorna eller dra av från skafferiet',
        ),
        findsOneWidget,
      );
      expect(find.text('Ångra'), findsNothing);
      verifyNever(() => boxes.remove(any()));
      verifyNever(() => pantry.undoTakeCooked(any(), any()));
    });

    testWidgets(
      'Ångra after a half-written take undoes only what was written',
      (
        tester,
      ) async {
        when(
          () => pantry.getAll(any()),
        ).thenAnswer((_) async => [_flour, _sugar]);
        when(() => pantry.takeCooked(any(), any())).thenAnswer((i) {
          final takes = i.positionalArguments[1] as List<CookedPantryTake>;
          return Future.error(
            CookedPantryTakeFailed([takes.first], StateError('refused')),
          );
        });

        await run(tester, recipe: _twoIngredients, answer: spara);

        expect(find.textContaining('Kunde inte dra av allt'), findsOneWidget);
        await tester.tap(find.text('Ångra'));
        await tester.pumpAndSettle();

        final undone =
            verify(
                  () => pantry.undoTakeCooked('u', captureAny()),
                ).captured.single
                as List<CookedPantryTake>;
        expect(undone.map((t) => t.item.id), ['a']);
        verify(() => boxes.remove('box1')).called(1);
      },
    );

    testWidgets(
      'a refused box beside a half-written take names the box and undoes '
      'the pantry rows that were written',
      (tester) async {
        when(
          () => pantry.getAll(any()),
        ).thenAnswer((_) async => [_flour, _sugar]);
        when(
          () => boxes.add(any()),
        ).thenAnswer((_) => Future.error(StateError('refused')));
        when(() => pantry.takeCooked(any(), any())).thenAnswer((i) {
          final takes = i.positionalArguments[1] as List<CookedPantryTake>;
          return Future.error(
            CookedPantryTakeFailed([takes.first], StateError('refused')),
          );
        });

        await run(tester, recipe: _twoIngredients, answer: spara);

        expect(find.text('Kunde inte spara matlådorna'), findsOneWidget);
        await tester.tap(find.text('Ångra'));
        await tester.pumpAndSettle();

        final undone =
            verify(
                  () => pantry.undoTakeCooked('u', captureAny()),
                ).captured.single
                as List<CookedPantryTake>;
        expect(undone.map((t) => t.item.id), ['a']);
        verifyNever(() => boxes.remove(any()));
      },
    );
  });

  group('undo failures', () {
    testWidgets('a refused box undo says so and still undoes the pantry', (
      tester,
    ) async {
      when(
        () => boxes.remove(any()),
      ).thenAnswer((_) => Future.error(StateError('refused')));

      await run(tester, answer: spara);
      await tester.tap(find.text('Ångra'));
      await tester.pumpAndSettle();

      expect(find.text('Kunde inte ångra matlådorna'), findsOneWidget);
      verify(() => pantry.undoTakeCooked('u', any())).called(1);
    });

    testWidgets('a refused pantry undo says so', (tester) async {
      when(
        () => pantry.undoTakeCooked(any(), any()),
      ).thenAnswer((_) => Future.error(StateError('refused')));

      await run(tester, answer: spara);
      await tester.tap(find.text('Ångra'));
      await tester.pumpAndSettle();

      expect(
        find.text('Kunde inte ångra avdraget i skafferiet'),
        findsOneWidget,
      );
      verify(() => boxes.remove('box1')).called(1);
    });
  });

  group('the sheet', () {
    testWidgets('Hoppa över closes it and writes nothing', (tester) async {
      await run(tester, useRealLeftoversSheet: true);

      await tester.tap(find.byKey(const ValueKey('leftovers-skip')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('leftovers-save')), findsNothing);
      verifyNever(() => boxes.add(any()));
      verifyNever(() => pantry.takeCooked(any(), any()));
      verify(
        () => analytics.logEvent(
          name: AnalyticsEvents.mealBoxOfferShown,
          parameters: any(named: 'parameters'),
        ),
      ).called(1);
    });

    testWidgets('shows the mockup content and saves what is chosen', (
      tester,
    ) async {
      await run(tester, useRealLeftoversSheet: true);

      expect(find.text('Klart! Du lagade 6 portioner'), findsOneWidget);
      expect(find.text('BLEV DET ÖVER?'), findsOneWidget);
      expect(find.text('Ni var 4 som åt'), findsOneWidget);
      expect(find.text('DRA AV FRÅN SKAFFERIET'), findsOneWidget);
      expect(find.text('1 vara dras av'), findsOneWidget);
      expect(find.text('Mjöl'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('meal-box-value'))).data,
        '2',
      );

      await tester.tap(find.text('Frysen'));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('leftovers-save')));
      await tester.pumpAndSettle();

      final box =
          verify(() => boxes.add(captureAny())).captured.single as MealBox;
      expect(box.location, MealBoxLocation.freezer);
      expect(box.count, 2);
      verify(() => pantry.takeCooked('u', any())).called(1);
    });

    testWidgets('Spara is off at 0 boxes with an empty pantry plan', (
      tester,
    ) async {
      when(() => pantry.getAll(any())).thenAnswer((_) async => []);
      await run(tester, useRealLeftoversSheet: true, portions: 5);

      expect(find.text('DRA AV FRÅN SKAFFERIET'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('meal-box-minus')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('meal-box-minus')));
      await tester.pump();

      expect(
        tester
            .widget<FormButton>(find.byKey(const ValueKey('leftovers-save')))
            .onPressed,
        isNull,
      );
      verifyNever(() => boxes.add(any()));
    });

    testWidgets('Ändra replaces the selection, and may empty it', (
      tester,
    ) async {
      await run(tester, useRealLeftoversSheet: true);

      await tester.tap(find.byKey(const ValueKey('leftovers-pantry')));
      await tester.pumpAndSettle();
      // The pantry sheet's own row, unticked.
      await tester.tap(find.text('Mjöl').last);
      await tester.pump();
      await tester.tap(find.text('Spara').last);
      await tester.pumpAndSettle();

      expect(find.text('Inget dras av'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('leftovers-save')));
      await tester.pumpAndSettle();
      verifyNever(() => pantry.takeCooked(any(), any()));
      verify(() => boxes.add(any())).called(1);
    });
  });
}
