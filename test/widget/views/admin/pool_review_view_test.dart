// BUT-1517: the "Betyg" tab shows a pool's numbers and switches it off/on.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/admin/pool_inspection.dart';
import 'package:butlery/services/moderation/pool_moderation_service.dart';
import 'package:butlery/viewmodels/admin/pool_review_viewmodel.dart';
import 'package:butlery/views/admin/pool_review_view.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

class _MockService extends Mock implements PoolModerationService {}

const _key = 'v1:0123456789abcdef';

PoolInspection _pool({bool quarantined = false}) => PoolInspection(
  poolKey: _key,
  quarantined: quarantined,
  reason: quarantined ? QuarantineReason.badMerge : null,
  count: 42,
  average: 4.25,
  distribution: const [1, 2, 3, 4, 32],
  votes24h: 7,
  votes7d: 19,
  sampled: 40,
  youngAccountShare: 0.375,
  unverifiedShare: 0.5,
);

void main() {
  late _MockService service;

  setUp(() => service = _MockService());

  Future<void> pump(WidgetTester tester, {String? initialKey}) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: PoolReviewView(
          initialPoolKey: initialKey,
          viewModel: PoolReviewViewModel(service: service),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a key from a warning is looked up at once and shown', (
    tester,
  ) async {
    when(() => service.inspect(_key)).thenAnswer((_) async => _pool());

    await pump(tester, initialKey: _key);

    expect(find.text('Betyget visas'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('4.25'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('19'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('pool-stars-5')),
        matching: find.text('32'),
      ),
      findsOneWidget,
    );
    expect(
      find.text('38 % nya konton (under 7 dagar) av de 40 senaste rösterna'),
      findsOneWidget,
    );
    expect(
      find.text('50 % overifierade konton av de 40 senaste rösterna'),
      findsOneWidget,
    );
    expect(find.text('Stäng av betyget'), findsOneWidget);
  });

  testWidgets('a key typed by hand is checked before any call', (tester) async {
    await pump(tester);

    await tester.enterText(find.byType(TextField), 'nonsense');
    await tester.tap(find.text('Visa'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Nyckeln ska se ut som v1:'), findsOneWidget);
    verifyNever(() => service.inspect(any()));
  });

  testWidgets('a refused read says so', (tester) async {
    when(() => service.inspect(_key)).thenThrow(
      const PoolModerationException(PoolModerationFailure.notAllowed),
    );

    await pump(tester, initialKey: _key);

    expect(
      find.text('Du har inte behörighet att se eller ändra betyg.'),
      findsOneWidget,
    );
  });

  testWidgets('switching off asks for a reason, then confirms, then reloads', (
    tester,
  ) async {
    var off = false;
    when(
      () => service.inspect(_key),
    ).thenAnswer((_) async => _pool(quarantined: off));
    when(
      () => service.setQuarantine(
        poolKey: _key,
        quarantined: true,
        reason: QuarantineReason.badMerge,
      ),
    ).thenAnswer((_) async => off = true);
    await pump(tester, initialKey: _key);

    await tester.tap(find.text('Stäng av betyget'));
    await tester.pumpAndSettle();
    expect(find.text('Fusk'), findsOneWidget);
    expect(find.text('Annat'), findsOneWidget);
    await tester.tap(find.text('Felaktig sammanslagning'));
    await tester.pumpAndSettle();

    expect(find.text('Stänga av betyget?'), findsOneWidget);
    expect(find.textContaining('Rösterna finns kvar'), findsOneWidget);
    verifyNever(
      () => service.setQuarantine(
        poolKey: any(named: 'poolKey'),
        quarantined: any(named: 'quarantined'),
        reason: any(named: 'reason'),
      ),
    );
    await tester.tap(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.text('Stäng av betyget'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Betyget är avstängt'), findsOneWidget);
    expect(find.text('Orsak: Felaktig sammanslagning'), findsOneWidget);
    expect(find.text('Slå på betyget igen'), findsOneWidget);
    verify(() => service.inspect(_key)).called(2);
  });

  testWidgets('cancelling the confirmation changes nothing', (tester) async {
    when(() => service.inspect(_key)).thenAnswer((_) async => _pool());
    await pump(tester, initialKey: _key);

    await tester.tap(find.text('Stäng av betyget'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fusk'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Avbryt'));
    await tester.pumpAndSettle();

    verifyNever(
      () => service.setQuarantine(
        poolKey: any(named: 'poolKey'),
        quarantined: any(named: 'quarantined'),
        reason: any(named: 'reason'),
      ),
    );
    expect(find.text('Betyget visas'), findsOneWidget);
  });

  testWidgets('switching a quarantined rating back on confirms first', (
    tester,
  ) async {
    var off = true;
    when(
      () => service.inspect(_key),
    ).thenAnswer((_) async => _pool(quarantined: off));
    when(
      () => service.setQuarantine(poolKey: _key, quarantined: false),
    ).thenAnswer((_) async => off = false);
    await pump(tester, initialKey: _key);

    await tester.tap(find.text('Slå på betyget igen'));
    await tester.pumpAndSettle();
    expect(find.text('Slå på betyget igen?'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.text('Slå på betyget igen'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Betyget visas'), findsOneWidget);
    verify(
      () => service.setQuarantine(poolKey: _key, quarantined: false),
    ).called(1);
  });
}
