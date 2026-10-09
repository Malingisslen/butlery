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
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/views/settings/trash_view.dart';

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
    expect(find.text('Markera alla'), findsNothing);
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

  testWidgets('lists rows with time left, amber under 3 days', (tester) async {
    await open(tester);
    await push(tester, [pannkakor, soppa]);
    expect(find.text('Pannkakor'), findsOneWidget);
    expect(find.text('30 dagar kvar'), findsOneWidget);
    expect(find.text('2 dagar kvar'), findsOneWidget);
    expect(find.text('Töm papperskorgen'), findsOneWidget);

    final fills = tester
        .widgetList<ColoredBox>(find.byKey(const ValueKey('timeLeftFill')))
        .toList();
    expect(fills, hasLength(2));
    final ctx = tester.element(find.text('Pannkakor'));
    final cs = Theme.of(ctx).colorScheme;
    expect(fills[0].color, cs.primary);
    expect(fills[1].color, ctx.modeColors.warning);
    // The warning token is for borders and bars; text gets the dark variant.
    expect(
      tester.widget<Text>(find.text('2 dagar kvar')).style?.color,
      AppModeColors.textWarning(cs.brightness),
    );
    expect(
      tester.widget<Text>(find.text('30 dagar kvar')).style?.color,
      cs.onSurfaceVariant,
    );
  });

  testWidgets('amber starts below 3 days left, not at 3', (tester) async {
    await open(tester);
    await push(tester, [
      trashItemFor('c', now: now, age: const Duration(days: 27)),
      trashItemFor('d', now: now, age: const Duration(days: 28)),
    ]);
    expect(find.text('3 dagar kvar'), findsOneWidget);
    expect(find.text('2 dagar kvar'), findsOneWidget);

    final fills = tester
        .widgetList<ColoredBox>(find.byKey(const ValueKey('timeLeftFill')))
        .toList();
    final ctx = tester.element(find.text('3 dagar kvar'));
    expect(fills[0].color, Theme.of(ctx).colorScheme.primary);
    expect(fills[1].color, ctx.modeColors.warning);
  });

  testWidgets('tapping a row selects it and swaps the footer', (tester) async {
    await open(tester);
    await push(tester, [pannkakor, soppa]);

    await tester.tap(find.text('Pannkakor'));
    await tester.pump();

    expect(find.text('1 vald'), findsOneWidget);
    expect(find.text('Återställ 1 recept'), findsOneWidget);
    expect(find.text('Radera 1 recept'), findsOneWidget);
    expect(find.text('Töm papperskorgen'), findsNothing);
  });

  testWidgets('Markera alla selects every row, again clears them', (
    tester,
  ) async {
    await open(tester);
    await push(tester, [pannkakor, soppa]);

    await tester.tap(find.text('Markera alla'));
    await tester.pump();
    expect(find.text('2 valda'), findsOneWidget);
    expect(find.text('Avmarkera alla'), findsOneWidget);

    await tester.tap(find.text('Avmarkera alla'));
    await tester.pump();
    expect(find.text('Töm papperskorgen'), findsOneWidget);
  });

  testWidgets('restore needs no dialog and says the recipe is private', (
    tester,
  ) async {
    await open(tester);
    await push(tester, [pannkakor, soppa]);
    await tester.tap(find.text('Pannkakor'));
    await tester.pump();

    await tester.tap(find.text('Återställ 1 recept'));
    await tester.pump();
    await tester.pump();

    expect(service.restored.single, ['a']);
    expect(find.text('Återställt som privat'), findsOneWidget);
  });

  testWidgets('delete for good asks first and can be cancelled', (
    tester,
  ) async {
    await open(tester);
    await push(tester, [pannkakor, soppa]);
    await tester.tap(find.text('Pannkakor'));
    await tester.pump();

    await tester.tap(find.text('Radera 1 recept'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Receptet raderas för alltid. Det går inte att ångra.',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(service.deleted, isEmpty);

    await tester.tap(find.text('Avbryt'));
    await tester.pumpAndSettle();
    expect(service.deleted, isEmpty);

    await tester.tap(find.text('Radera 1 recept'));
    await tester.pumpAndSettle();
    await tester.tap(button('Radera för gott'));
    await tester.pumpAndSettle();

    expect(service.deleted.single, ['a']);
    expect(find.text('Receptet raderades för alltid'), findsOneWidget);
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
    expect(find.text('Töm papperskorgen'), findsOneWidget);
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
    await tester.tap(find.text('Markera alla'));
    await tester.pump();

    await tester.tap(find.text('Återställ 2 recept'));
    await tester.pump();
    await tester.pump();

    expect(
      find.text('1 av 2 klara. 1 recept hade redan gått ut.'),
      findsOneWidget,
    );
  });

  testWidgets('offline says nothing was changed', (tester) async {
    await open(tester);
    await push(tester, [pannkakor]);
    service.next = TrashOutcome.notRun(['a'], TrashFailure.offline);
    await tester.tap(find.text('Pannkakor'));
    await tester.pump();

    await tester.tap(find.text('Återställ 1 recept'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Du är offline. Inget ändrades.'), findsOneWidget);
  });
}
