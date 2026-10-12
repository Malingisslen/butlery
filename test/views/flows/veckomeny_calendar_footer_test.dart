/// The week menu in Kalender: "Till inköpslista" is the way from a planned
/// week to the shopping list, and the prompt is a single field until there is
/// text to generate from (approved picture 21-veckomeny-v2-1).
library;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/services/pantry/pantry_service.dart';
import 'package:butlery/services/persistence_service.dart';
import 'package:butlery/widgets/styled/styled_input.dart';

import '../../infrastructure/di/test_service_locator.dart';
import 'veckomeny_flow_harness.dart';

class _Pantry extends Mock implements PantryService {
  @override
  Stream<List<PantryItem>> watchAll(String userId) =>
      Stream.value(const <PantryItem>[]);
}

final _sv = AppLocalizationsSv();
const generateKey = ValueKey('test-veckomeny-generate');

void main() {
  late VeckomenyFlowHarness h;

  setUp(() async {
    h = VeckomenyFlowHarness();
    await h.setUp();
    TestServiceLocator.registerMock<PantryService>(_Pantry());
  });

  tearDown(() => h.tearDown());

  Future<void> openOnMonday(WidgetTester tester) =>
      withClock(Clock.fixed(flowMonday), () async {
        await h.pump(tester);
        await tester.pumpAndSettle();
      });

  // The saved dishes name recipes the generator cannot resolve, so the flow
  // ends in its "nothing to generate" notice: what this pins is that the
  // calendar's button starts the flow, not the sheet's own content.
  testWidgets('a planned week offers Till inköpslista, and it starts the '
      'shopping flow', (tester) async {
    h.seedWeek(3);
    await openOnMonday(tester);

    expect(find.text(_sv.menuToShoppingList), findsOneWidget);

    await tester.tap(find.text(_sv.menuToShoppingList));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text(_sv.menuShoppingListGenerationEmpty), findsOneWidget);
  });

  testWidgets('an empty week offers no Till inköpslista', (tester) async {
    await PersistenceService().setVeckomenyViewMode('kalender');
    await openOnMonday(tester);

    // Premise: Kalender is the open view and shows its empty week.
    expect(find.text('Ingen planering än'), findsOneWidget);
    expect(find.text(_sv.menuToShoppingList), findsNothing);
  });

  testWidgets('over a planned week the prompt is the field alone until there '
      'is text', (tester) async {
    h.seedWeek(3);
    await openOnMonday(tester);

    expect(find.byType(StyledInput), findsOneWidget);
    expect(find.byKey(generateKey), findsNothing);

    await tester.enterText(find.byType(StyledInput), 'pasta');
    await tester.pump();

    expect(find.byKey(generateKey), findsOneWidget);
  });

  testWidgets('over an empty week the prompt has its button from the start', (
    tester,
  ) async {
    await PersistenceService().setVeckomenyViewMode('kalender');
    await openOnMonday(tester);

    expect(find.text('Ingen planering än'), findsOneWidget);

    expect(find.byKey(generateKey), findsOneWidget);
  });
}
