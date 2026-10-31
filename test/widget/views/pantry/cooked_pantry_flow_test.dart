/// Kärnflöde steg 9C: read, plan, ask, write, Ångra.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/models/recipe/recipe_ingredient.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/pantry/cooked_pantry_plan.dart';
import 'package:butlery/services/pantry/pantry_service.dart';
import 'package:butlery/views/pantry/cooked_pantry_flow.dart';

import '../../../infrastructure/helpers/base_widget_test.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';

class _MockService extends Mock implements PantryService {}

final _recipe = Recipe(
  core: RecipeCore(
    id: 'r',
    title: 'r',
    description: '',
    ingredients: ['2 dl mjöl'],
    structuredIngredients: [
      RecipeIngredient(amount: 2, unit: 'dl', name: 'mjöl', raw: '2 dl mjöl'),
    ],
    instructions: ['x'],
    mealType: 'Middag',
    portions: 4,
  ),
  type: RecipeType.personal,
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
  });

  late _MockService service;
  var sheets = 0;

  setUp(() {
    service = _MockService();
    sheets = 0;
    when(() => service.getAll(any())).thenAnswer((_) async => [_flour]);
    when(
      () => service.takeCooked(any(), any()),
    ).thenAnswer(
      (i) async => i.positionalArguments[1] as List<CookedPantryTake>,
    );
    when(() => service.undoTakeCooked(any(), any())).thenAnswer((_) async {});
  });

  Future<void> run(
    WidgetTester tester, {
    String? userId = 'u',
    bool choose = true,
  }) async {
    final flow = CookedPantryFlow(
      service: () => service,
      userId: () => userId,
      openSheet: (context, takes, portions) async {
        sheets++;
        return choose ? takes : null;
      },
    );
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => flow.offer(context, _recipe, portions: 4),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
  }

  testWidgets('writes the chosen takes and Ångra writes them back', (
    tester,
  ) async {
    await run(tester);

    verify(() => service.takeCooked('u', any())).called(1);
    expect(find.text('1 vara dragen från skafferiet'), findsOneWidget);

    await tester.tap(find.text('Ångra'));
    await tester.pumpAndSettle();
    verify(() => service.undoTakeCooked('u', any())).called(1);
  });

  testWidgets('signed out: no read, no sheet', (tester) async {
    await run(tester, userId: null);

    verifyNever(() => service.getAll(any()));
    expect(sheets, 0);
  });

  testWidgets('unreadable pantry: no sheet, no snackbar', (tester) async {
    when(() => service.getAll(any())).thenThrow(StateError('offline'));

    await run(tester);

    expect(sheets, 0);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('nothing the pantry holds: no sheet', (tester) async {
    when(() => service.getAll(any())).thenAnswer((_) async => []);

    await run(tester);

    expect(sheets, 0);
  });

  testWidgets('skipped: nothing is written', (tester) async {
    await run(tester, choose: false);

    expect(sheets, 1);
    verifyNever(() => service.takeCooked(any(), any()));
  });

  testWidgets('a refused write shows the error and still offers Ångra', (
    tester,
  ) async {
    final take = CookedPantryTake(item: _flour, amount: 1);
    when(
      () => service.takeCooked(any(), any()),
    ).thenThrow(CookedPantryTakeFailed([take], StateError('refused')));

    await run(tester);

    expect(find.textContaining('Kunde inte dra av allt'), findsOneWidget);
    await tester.tap(find.text('Ångra'));
    await tester.pumpAndSettle();
    verify(() => service.undoTakeCooked('u', [take])).called(1);
  });

  testWidgets('a refusal before anything was written has nothing to Ångra', (
    tester,
  ) async {
    when(
      () => service.takeCooked(any(), any()),
    ).thenThrow(CookedPantryTakeFailed(const [], StateError('refused')));

    await run(tester);

    expect(find.textContaining('Kunde inte dra av allt'), findsOneWidget);
    expect(find.text('Ångra'), findsNothing);
  });

  testWidgets(
    'an unexpected error before any write also has nothing to Ångra',
    (
      tester,
    ) async {
      when(
        () => service.takeCooked(any(), any()),
      ).thenThrow(StateError('boom'));

      await run(tester);

      expect(find.textContaining('Kunde inte dra av allt'), findsOneWidget);
      expect(find.text('Ångra'), findsNothing);
    },
  );

  testWidgets('an Ångra that fails says so', (tester) async {
    when(
      () => service.undoTakeCooked(any(), any()),
    ).thenThrow(StateError('refused'));

    await run(tester);
    await tester.tap(find.text('Ångra'));
    await tester.pumpAndSettle();

    expect(find.text('Kunde inte ångra avdraget i skafferiet'), findsOneWidget);
  });
}
