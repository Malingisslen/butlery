/// P5-U25 and P5-U26a on the week menu.
///
/// U25 (produktregler.md:206, :893, :905-909): a generation with fewer dishes
/// than asked says "Vi hittade n av m rätter" in the partial-outcome form and
/// names each short meal type.
///
/// U26a (produktregler.md:104; ux-beslut.json D-04): the week menu mounts
/// P3-U08's conflict snackbar. It listens to the sync service's conflict
/// stream while the week menu is open; the snackbar itself decides that only
/// a week-menu conflict the user's edit lost is shown.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/realtime/realtime_resource.dart';
import 'package:butlery/services/realtime/realtime_types.dart';
import 'package:butlery/services/realtime_sync_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/menu_viewmodel.dart';
import 'package:butlery/views/veckomeny_view.dart';
import 'package:butlery/widgets/common/feedback/partial_outcome.dart';
import 'package:butlery/widgets/realtime/conflict_snackbar.dart';

class _MockSync extends Mock implements RealtimeSyncService {}

class _FakeResource extends Fake implements RealtimeResource {
  _FakeResource(this.lastEditedByDisplayName);

  @override
  final String lastEditedByDisplayName;
}

ConflictEvent _event({
  ConflictResolutionStrategy strategy = ConflictResolutionStrategy.remoteWon,
  ConflictEntity entity = ConflictEntity.weekMenu,
}) => ConflictEvent(
  collectionPath: 'realtime_resources',
  docId: 'menu-1',
  localValue: _FakeResource('Malin'),
  remoteValue: _FakeResource('Johan'),
  chosenStrategy: strategy,
  entity: entity,
  occurredAt: DateTime(2026, 9, 23),
);

Widget _app(ThemeData theme, Widget child) => MaterialApp(
  theme: theme,
  locale: const Locale('sv'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: Scaffold(body: child),
);

const _outcome = MenuPartialOutcome(
  found: 2,
  requested: 5,
  missing: [MenuMissingMeal(mealType: 'middag', found: 2, requested: 5)],
);

void main() {
  group('P5-U25: the partial generation', () {
    for (final (mode, theme, raised) in [
      ('light', AppTheme.lightTheme, const Color(0xFFE6EAD9)),
      ('dark', AppTheme.darkTheme, const Color(0xFF2F4437)),
    ]) {
      testWidgets('says n av m and names what is missing ($mode)', (
        tester,
      ) async {
        await tester.pumpWidget(
          _app(theme, const VeckomenyPartialResult(outcome: _outcome)),
        );

        expect(find.byType(PartialOutcome), findsOneWidget);
        expect(find.text('Vi hittade 2 av 5 rätter'), findsOneWidget);
        final row = find.byKey(PartialOutcome.itemKey('meal-middag'));
        expect(
          find.descendant(of: row, matching: find.text('Middag')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: row, matching: find.text('2 av 5, 3 saknas')),
          findsOneWidget,
        );
        final box = tester.widget<DecoratedBox>(
          find.byKey(PartialOutcome.surfaceKey),
        );
        expect((box.decoration as BoxDecoration).color, raised);
      });
    }
  });

  group('P5-U26a: the week conflict snackbar is mounted', () {
    late StreamController<ConflictEvent> conflicts;

    setUp(() async {
      await GetIt.instance.reset();
      conflicts = StreamController<ConflictEvent>.broadcast();
      final sync = _MockSync();
      when(() => sync.conflictStream).thenAnswer((_) => conflicts.stream);
      GetIt.instance.registerSingleton<RealtimeSyncService>(sync);
      prod.ServiceLocator.initialize(DIContainer());
    });

    tearDown(() async {
      await conflicts.close();
      prod.ServiceLocator.reset();
      await GetIt.instance.reset();
    });

    testWidgets('someone else saving the week shows "{namn} sparade veckan"', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          AppTheme.lightTheme,
          const VeckomenyConflictNotice(child: Text('veckan')),
        ),
      );

      conflicts.add(_event());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Johan sparade veckan'), findsOneWidget);
      final bar = tester.widget<SnackBar>(find.byType(SnackBar));
      // D-04: its own 30 s window, never the 7 s undo.
      expect(bar.duration, kConflictNoticeWindow);
    });

    testWidgets('an edit that won, or another entity, shows nothing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          AppTheme.lightTheme,
          const VeckomenyConflictNotice(child: Text('veckan')),
        ),
      );

      conflicts
        ..add(_event(strategy: ConflictResolutionStrategy.localWon))
        ..add(_event(entity: ConflictEntity.recipeOwn));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('it stops listening when the week menu closes', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          AppTheme.lightTheme,
          const VeckomenyConflictNotice(child: Text('veckan')),
        ),
      );
      expect(conflicts.hasListener, isTrue);

      await tester.pumpWidget(_app(AppTheme.lightTheme, const Text('annat')));

      expect(conflicts.hasListener, isFalse);
    });
  });
}
