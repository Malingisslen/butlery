/// BUT-907: the trash view shows what the view model holds in each state, and
/// every change goes through the service after the confirmation it needs.
library;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/trash/trash_service.dart';
import 'package:butlery/views/settings/trash_view.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';

import '../../../infrastructure/fakes/scripted_trash_service.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';

void main() {
  late ScriptedTrashService service;

  setUp(() async {
    await GetIt.instance.reset();
    ServiceLocator.reset();
    service = ScriptedTrashService();
    final container = DIContainer();
    container.container.registerSingleton<TrashService>(service);
    ServiceLocator.initialize(container);
  });

  tearDown(() async {
    ServiceLocator.reset();
    await GetIt.instance.reset();
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScaffold: false,
        child: const TrashView(),
      ),
    );
  }

  Future<void> push(WidgetTester tester, List items) async {
    service.list.add(List.of(items.cast()));
    await tester.pump();
    await tester.pump();
  }

  final now = clock.now();
  final pannkakor = trashItemFor('a', title: 'Pannkakor', now: now);
  final soppa = trashItemFor(
    'b',
    title: 'Soppa',
    now: now,
    age: const Duration(days: 28),
  );

  Finder button(String label) =>
      find.descendant(of: find.byType(Dialog), matching: find.text(label));

  testWidgets('shows loading until the first list arrives', (tester) async {
    await open(tester);
    expect(find.text('Laddar papperskorgen …'), findsOneWidget);
    expect(find.text('Återställ alla'), findsNothing);
    expect(find.text('Töm papperskorgen'), findsNothing);
  });

  testWidgets('empty trash says so and that recipes are kept 30 days', (
    tester,
  ) async {
    await open(tester);
    await push(tester, []);
    expect(find.text('Papperskorgen är tom'), findsOneWidget);
    expect(
      find.text('Raderade recept ligger kvar här i 30 dagar.'),
      findsOneWidget,
    );
  });

  testWidgets('a stream error shows the error with a retry', (tester) async {
    await open(tester);
    service.list.addError(StateError('boom'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Papperskorgen kunde inte laddas.'), findsOneWidget);

    await tester.tap(find.text('Försök igen'));
    await tester.pump();
    expect(service.watched, 2);
  });

  testWidgets('lists rows with time left, marked under 3 days', (
    tester,
  ) async {
    await open(tester);
    await push(tester, [pannkakor, soppa]);
    expect(
      find.text('Recept raderas för gott efter 30 dagar.'),
      findsOneWidget,
    );
    expect(find.text('Pannkakor'), findsOneWidget);
    expect(find.text('Raderad i dag · 30 dagar kvar'), findsOneWidget);
    expect(find.textContaining('2 dagar kvar'), findsOneWidget);
    expect(find.textContaining('raderas för gott på'), findsOneWidget);
    // Only the 2-day row carries the warning mark.
    expect(find.byKey(const ValueKey('trashUrgentMark')), findsOneWidget);
    expect(find.text('Markera alla'), findsNothing);
  });

  testWidgets('the subtitle names the date it was deleted, the weekday it '
      'goes for good, and "today" on the last day', (tester) async {
    final fixed = DateTime(2026, 10, 12, 12);
    await withClock(Clock.fixed(fixed), () async {
      await open(tester);
      await push(tester, [
        trashItemFor(
          'e',
          title: 'Tre kvar',
          now: fixed,
          age: const Duration(days: 27),
        ),
        trashItemFor(
          'f',
          title: 'Två kvar',
          now: fixed,
          age: const Duration(days: 28),
        ),
        trashItemFor(
          'g',
          title: 'Sista dagen',
          now: fixed,
          age: const Duration(days: 30),
        ),
      ]);

      String subtitleOf(String title) => tester
          .widgetList<Text>(
            find.descendant(
              of: find.ancestor(
                of: find.text(title),
                matching: find.byType(ButleryListRow),
              ),
              matching: find.byType(Text),
            ),
          )
          .map((t) => t.data)
          .whereType<String>()
          .firstWhere((t) => t != title);

      expect(subtitleOf('Tre kvar'), 'Raderad 15 sep. · 3 dagar kvar');
      expect(
        subtitleOf('Två kvar'),
        '2 dagar kvar — raderas för gott på onsdag',
      );
      expect(
        subtitleOf('Sista dagen'),
        contains('raderas för gott i dag'),
      );
    });
  });

  testWidgets('the mark starts below 3 days left, not at 3', (tester) async {
    await open(tester);
    await push(tester, [
      trashItemFor('c', now: now, age: const Duration(days: 27)),
      trashItemFor('d', now: now, age: const Duration(days: 28)),
    ]);
    expect(find.textContaining('3 dagar kvar'), findsOneWidget);
    expect(find.textContaining('2 dagar kvar'), findsOneWidget);
    final mark = find.byKey(const ValueKey('trashUrgentMark'));
    expect(mark, findsOneWidget);
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.textContaining('2 dagar kvar'),
          matching: find.byType(ButleryListRow),
        ),
        matching: mark,
      ),
      findsOneWidget,
    );
  });

  Future<void> openRecipeSheet(WidgetTester tester, String title) async {
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
  }

  testWidgets('a row opens a sheet titled with the recipe name', (
    tester,
  ) async {
    await open(tester);
    await push(tester, [pannkakor, soppa]);
    await openRecipeSheet(tester, 'Pannkakor');

    expect(find.text('Återställ receptet'), findsOneWidget);
    expect(find.text('Radera för gott'), findsOneWidget);
    expect(service.restored, isEmpty);
  });

  testWidgets('restore needs no dialog and says the recipe is private', (
    tester,
  ) async {
    await open(tester);
    await push(tester, [pannkakor, soppa]);
    await openRecipeSheet(tester, 'Pannkakor');

    await tester.tap(find.text('Återställ receptet'));
    await tester.pumpAndSettle();

    expect(service.restored.single, ['a']);
    expect(find.text('Återställt som privat'), findsOneWidget);
  });

  testWidgets('delete for good names the recipe, asks, and can be cancelled', (
    tester,
  ) async {
    await open(tester);
    await push(tester, [pannkakor, soppa]);
    await openRecipeSheet(tester, 'Pannkakor');

    await tester.tap(find.text('Radera för gott'));
    await tester.pumpAndSettle();
    expect(find.text('Radera Pannkakor för gott?'), findsOneWidget);
    expect(
      find.text('Det går inte att ångra.', findRichText: true),
      findsOneWidget,
    );
    expect(service.deleted, isEmpty);

    await tester.tap(find.text('Avbryt'));
    await tester.pumpAndSettle();
    expect(service.deleted, isEmpty);

    await openRecipeSheet(tester, 'Pannkakor');
    await tester.tap(find.text('Radera för gott'));
    await tester.pumpAndSettle();
    await tester.tap(button('Radera för gott'));
    await tester.pumpAndSettle();

    expect(service.deleted.single, ['a']);
    expect(find.text('Receptet raderades för alltid'), findsOneWidget);
  });

  testWidgets('Återställ alla restores every recipe', (tester) async {
    await open(tester);
    await push(tester, [pannkakor, soppa]);

    await tester.tap(find.text('Återställ alla'));
    await tester.pumpAndSettle();

    expect(service.restored.single, ['a', 'b']);
    expect(find.text('2 recept återställda som privat'), findsOneWidget);
  });

  testWidgets('empty trash asks first, then empties it', (tester) async {
    await open(tester);
    await push(tester, [pannkakor, soppa]);

    await tester.tap(find.text('Töm papperskorgen'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Alla recept i papperskorgen raderas för alltid. '
        'Det går inte att ångra.',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(service.emptied, 0);

    await tester.tap(button('Töm papperskorgen'));
    await tester.pumpAndSettle();

    expect(service.emptied, 1);
    expect(find.text('Papperskorgen är tömd'), findsOneWidget);
  });

  testWidgets('cancelling the empty dialog keeps every recipe', (
    tester,
  ) async {
    await open(tester);
    await push(tester, [pannkakor, soppa]);

    await tester.tap(find.text('Töm papperskorgen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Avbryt'));
    await tester.pumpAndSettle();

    expect(service.emptied, 0);
    expect(find.text('Papperskorgen är tömd'), findsNothing);
    expect(find.text('Pannkakor'), findsOneWidget);
  });

  testWidgets('a partly done restore names what did not happen', (
    tester,
  ) async {
    await open(tester);
    await push(tester, [pannkakor, soppa]);
    service.next = const TrashOutcome(
      doneIds: ['a'],
      failures: {'b': TrashFailure.expired},
    );

    await tester.tap(find.text('Återställ alla'));
    await tester.pumpAndSettle();

    expect(
      find.text('1 av 2 klara. 1 recept hade redan gått ut.'),
      findsOneWidget,
    );
  });

  testWidgets('offline says nothing was changed', (tester) async {
    await open(tester);
    await push(tester, [pannkakor]);
    service.next = TrashOutcome.notRun(['a'], TrashFailure.offline);
    await openRecipeSheet(tester, 'Pannkakor');

    await tester.tap(find.text('Återställ receptet'));
    await tester.pumpAndSettle();

    expect(find.text('Du är offline. Inget ändrades.'), findsOneWidget);
  });
}
