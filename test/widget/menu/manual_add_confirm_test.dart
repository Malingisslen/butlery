// Adding recipes to the menu by hand asks first when they conflict with the
// household, and never blocks the add because the check itself broke.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/viewmodels/menu/manual_add_check.dart';
import 'package:butlery/widgets/menu/manual_add_confirm.dart';

import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/helpers/widget_test_app.dart';
import '../../test_support/base_unit_test.dart';

void main() {
  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  final bread = RecipeFactory.build(id: 'bread', title: 'Bröd');

  ManualAddFinding containsGluten() => ManualAddFinding(
    recipe: bread,
    containsAllergens: const ['gluten'],
    uncheckedAllergens: const [],
    disliked: false,
  );

  Future<bool?> run(
    WidgetTester tester,
    Future<List<ManualAddFinding>> Function(List<Recipe>) findings,
  ) async {
    bool? result;
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await confirmManualAdd(
              context,
              [bread],
              findingsFor: findings,
            ),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('goes ahead without a question when nothing conflicts', (
    tester,
  ) async {
    final result = await run(tester, (_) async => const []);

    expect(result, isTrue);
    expect(find.text('Lägg till ändå?'), findsNothing);
  });

  testWidgets('asks, and cancelling stops the add', (tester) async {
    bool? result;
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await confirmManualAdd(
              context,
              [bread],
              findingsFor: (_) async => [containsGluten()],
            ),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(find.text('Lägg till ändå?'), findsOneWidget);
    expect(find.textContaining('Bröd innehåller gluten.'), findsOneWidget);

    await tester.tap(find.text('Avbryt'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
  });

  testWidgets('confirming lets the add through', (tester) async {
    bool? result;
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await confirmManualAdd(
              context,
              [bread],
              findingsFor: (_) async => [containsGluten()],
            ),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lägg till ändå'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
  });

  testWidgets('a failing check does not block the add', (tester) async {
    final result = await run(tester, (_) async => throw StateError('offline'));

    expect(result, isTrue);
    expect(find.text('Lägg till ändå?'), findsNothing);
  });
}
