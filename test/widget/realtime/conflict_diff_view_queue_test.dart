/// BUT-2213 (TR::FLOW::08::ko::toms::konfliktbanner): "Behåll min version" on
/// a queue conflict. The user's own recipe lives on the recipe document, not
/// in realtime_resources (BUT-2151), so the choice goes to the service's
/// queued-recipe path and never to the live-resource recovery.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/models/realtime/realtime_resource.dart';
import 'package:butlery/services/realtime/realtime_types.dart';
import 'package:butlery/services/realtime_sync_service.dart';
import 'package:butlery/views/realtime/conflict_diff_view.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

class _MockRealtimeSyncService extends Mock implements RealtimeSyncService {}

class _FakeResource extends Fake implements RealtimeResource {
  _FakeResource(this._map);
  final Map<String, dynamic> _map;

  @override
  String get lastEditedByDisplayName => 'Malin';

  @override
  Map<String, dynamic> toFirestore() => _map;
}

ConflictEvent _queueEvent() => ConflictEvent(
  collectionPath: 'recipes',
  docId: 'r1',
  localValue: _FakeResource({'title': 'Min ändring'}),
  remoteValue: _FakeResource({'title': 'Från min andra enhet'}),
  chosenStrategy: ConflictResolutionStrategy.remoteWon,
  entity: ConflictEntity.recipeOwn,
  occurredAt: DateTime(2026, 10, 8),
  origin: ConflictOrigin.queue,
);

void main() {
  late _MockRealtimeSyncService service;

  setUpAll(() {
    registerFallbackValue(_FakeResource(const {}));
    registerFallbackValue(_queueEvent());
  });

  setUp(() async {
    await GetIt.instance.reset();
    service = _MockRealtimeSyncService();
    GetIt.instance.registerSingleton<RealtimeSyncService>(service);
    prod.ServiceLocator.initialize(DIContainer());
  });

  tearDown(() async {
    prod.ServiceLocator.reset();
    await GetIt.instance.reset();
  });

  late String keepMine;
  late String keepFailed;

  Future<void> open(WidgetTester tester, ConflictEvent event) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) {
            keepMine = context.l10n.conflictDiffKeepMine;
            keepFailed = context.l10n.conflictDiffKeepFailed;
            return ElevatedButton(
              onPressed: () => ConflictDiffView.show(context, event),
              child: const Text('open'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('"Behåll min version" hands the notice to the queued-recipe '
      'path and closes the view', (tester) async {
    final event = _queueEvent();
    when(() => service.keepQueuedRecipe(any())).thenAnswer((_) async {});
    await open(tester, event);

    await tester.tap(find.widgetWithText(FilledButton, keepMine));
    await tester.pumpAndSettle();

    expect(
      verify(() => service.keepQueuedRecipe(captureAny())).captured.single,
      same(event),
    );
    verifyNever(() => service.recoverLocalVersion<RealtimeResource>(any()));
    expect(find.text('open'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, keepMine), findsNothing);
  });

  testWidgets('a failed save stays open and says so', (tester) async {
    when(
      () => service.keepQueuedRecipe(any()),
    ).thenAnswer((_) async => throw StateError('offline'));
    await open(tester, _queueEvent());

    await tester.tap(find.widgetWithText(FilledButton, keepMine));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, keepMine), findsOneWidget);
    expect(find.textContaining(keepFailed), findsOneWidget);
  });
}
