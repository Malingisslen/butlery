/// P3-U08: the week menu's conflict snackbar (produktregler.md:104,
/// ux-beslut.json D-04, block288-uxfrysning.json
/// TR::FLOW::01::vecka-sparad-av-annan::konfliktsnackbar).
///
/// Pins: it fires only when the user's week edit lost; it stays exactly
/// kConflictNoticeWindow (30 s), apart from the 7 s undo window; "Behåll min"
/// (Skarmar v12 etapp 11 breda vyer.dc.html:221, produktregler.md:1119)
/// re-applies the lost version once; and it persists under assistive
/// navigation, as the undo primitive does until PQ-05.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/utils/undo_window.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/models/realtime/realtime_resource.dart';
import 'package:butlery/services/realtime/realtime_types.dart';
import 'package:butlery/services/realtime_sync_service.dart';
import 'package:butlery/widgets/realtime/conflict_snackbar.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

class _MockRealtimeSyncService extends Mock implements RealtimeSyncService {}

class _FakeResource extends Fake implements RealtimeResource {
  _FakeResource([this.lastEditedByDisplayName = 'Johan']);

  @override
  final String lastEditedByDisplayName;
}

ConflictEvent _event({
  ConflictResolutionStrategy strategy = ConflictResolutionStrategy.remoteWon,
  ConflictEntity entity = ConflictEntity.weekMenu,
  RealtimeResource? local,
  String editor = 'Johan',
}) => ConflictEvent(
  collectionPath: 'realtime_resources',
  docId: 'menu-1',
  localValue: local ?? _FakeResource('Malin'),
  remoteValue: _FakeResource(editor),
  chosenStrategy: strategy,
  entity: entity,
  occurredAt: DateTime(2026, 9, 23),
);

void main() {
  late _MockRealtimeSyncService service;

  setUpAll(() {
    registerFallbackValue(_FakeResource());
  });

  setUp(() async {
    await GetIt.instance.reset();
    service = _MockRealtimeSyncService();
    when(
      () => service.recoverLocalVersion<RealtimeResource>(any()),
    ).thenAnswer((_) async {});
    GetIt.instance.registerSingleton<RealtimeSyncService>(service);
    prod.ServiceLocator.initialize(DIContainer());
  });

  tearDown(() async {
    prod.ServiceLocator.reset();
    await GetIt.instance.reset();
  });

  late String saved;
  late String keepMine;

  Widget harness(ConflictEvent event, {bool accessibleNavigation = false}) {
    return createLocalizedTestApp(
      child: Builder(
        builder: (outer) => MediaQuery(
          data: MediaQuery.of(
            outer,
          ).copyWith(accessibleNavigation: accessibleNavigation),
          child: Builder(
            builder: (context) {
              saved = context.l10n.conflictWeekSaved('Johan');
              keepMine = context.l10n.conflictWeekKeepMine;
              return TextButton(
                onPressed: () => ConflictSnackBar.showWeekSaved(context, event),
                child: const Text('show'),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> show(WidgetTester tester) async {
    await tester.tap(find.text('show'));
    await tester.pumpAndSettle();
  }

  test('the window is 30 s and is not the undo window (D-04)', () {
    expect(kConflictNoticeWindow, const Duration(seconds: 30));
    expect(kConflictNoticeWindow, isNot(kUndoWindow));
  });

  testWidgets('a lost week edit shows "{namn} sparade veckan" + Behåll min', (
    tester,
  ) async {
    await tester.pumpWidget(harness(_event()));
    await show(tester);

    expect(saved, 'Johan sparade veckan');
    // The drawn label (Skarmar v12 etapp 11 #vmbkonflikt :221), not the
    // column header "Ångra" (produktregler.md:99), which is a category.
    expect(keepMine, 'Behåll min');
    expect(find.text(saved), findsOneWidget);
    expect(find.widgetWithText(SnackBarAction, keepMine), findsOneWidget);
    expect(find.text('Ångra'), findsNothing);
  });

  testWidgets('a localWon shows nothing', (tester) async {
    await tester.pumpWidget(
      harness(_event(strategy: ConflictResolutionStrategy.localWon)),
    );
    await show(tester);

    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a recipe conflict shows nothing', (tester) async {
    await tester.pumpWidget(harness(_event(entity: ConflictEntity.recipeOwn)));
    await show(tester);

    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('an unknown editor name gets the nameless message', (
    tester,
  ) async {
    late String unnamed;
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) {
            unnamed = context.l10n.conflictWeekSavedUnnamed;
            return TextButton(
              onPressed: () =>
                  ConflictSnackBar.showWeekSaved(context, _event(editor: '')),
              child: const Text('show'),
            );
          },
        ),
      ),
    );
    await show(tester);

    expect(find.text(unnamed), findsOneWidget);
  });

  testWidgets('visible at 29.9 s, gone at 30 s', (tester) async {
    await tester.pumpWidget(harness(_event()));
    await show(tester);

    await tester.pump(const Duration(milliseconds: 29900));
    expect(find.text(saved), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.text(saved), findsNothing);
  });

  testWidgets('Behåll min re-applies the lost version exactly once', (
    tester,
  ) async {
    final local = _FakeResource('Malin');
    await tester.pumpWidget(harness(_event(local: local)));
    await show(tester);

    await tester.tap(find.text(keepMine));
    await tester.pumpAndSettle();

    final captured = verify(
      () => service.recoverLocalVersion<RealtimeResource>(captureAny()),
    ).captured;
    expect(captured, hasLength(1));
    expect(identical(captured.single, local), isTrue);
  });

  testWidgets('it stays until acted on under accessible navigation', (
    tester,
  ) async {
    await tester.pumpWidget(harness(_event(), accessibleNavigation: true));
    await show(tester);

    await tester.pump(const Duration(seconds: 60));
    await tester.pumpAndSettle();
    expect(find.text(saved), findsOneWidget);
  });
}
