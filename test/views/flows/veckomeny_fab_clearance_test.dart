/// BUT-2275 finding 2: on the generated list, the floating "Till inköpslista"
/// button covered "Jag placerar själv", the second placement button.
library;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/services/pantry/pantry_service.dart';

import '../../infrastructure/di/test_service_locator.dart';
import 'veckomeny_flow_harness.dart';

class _Pantry extends Mock implements PantryService {
  @override
  Stream<List<PantryItem>> watchAll(String userId) =>
      Stream.value(const <PantryItem>[]);
}

void main() {
  late VeckomenyFlowHarness h;

  setUp(() async {
    h = VeckomenyFlowHarness();
    await h.setUp();
    h.menu.next = {
      'Middag': [flowDinner(1), flowDinner(2)],
    };
    TestServiceLocator.registerMock<PantryService>(_Pantry());
  });

  tearDown(() => h.tearDown());

  testWidgets('the shopping button leaves both placement buttons free', (
    tester,
  ) async {
    await withClock(Clock.fixed(flowMonday), () async {
      await h.pump(tester);
      await h.generate(tester, 'två middagar');
      await tester.pumpAndSettle();

      final fab = tester.getRect(
        find.ancestor(
          of: find.text('Till inköpslista'),
          matching: find.byType(ElevatedButton),
        ),
      );
      for (final label in [
        'Placera automatiskt i kalendern',
        'Jag placerar själv',
      ]) {
        final button = find.ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate(
            (w) => w is ElevatedButton || w is OutlinedButton,
          ),
        );
        expect(button, findsOneWidget, reason: 'premise: $label is shown');
        expect(
          tester.getRect(button).overlaps(fab),
          isFalse,
          reason: '"Till inköpslista" lies over "$label"',
        );
        expect(find.text(label).hitTestable(), findsOneWidget);
      }
    });
  });
}
