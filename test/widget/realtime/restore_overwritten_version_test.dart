/// P5-U26b: "Återställ" for an overwritten week or own recipe, within 30 days
/// (produktregler.md:104, :109; flows-roles-budget.md:36; PQ-01 = A).
///
/// Pins the flow: one kept version goes straight to the confirmation, more
/// than one are picked by their own id; the confirmation names what is
/// replaced; confirming restores and offers Ångra for the undo window
/// (BUT-954 class 2); Ångra puts the other version back and keeps mine kept;
/// a closed window forgets the kept row; cancelling changes nothing; a failed
/// restore says what happened and what is kept. Also the time wording
/// (content-style-guide.md:20-36) and where the two surfaces mount the entry.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/core/utils/undo_window.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/realtime/overwritten_version.dart';
import 'package:butlery/models/realtime/realtime_resource.dart';
import 'package:butlery/services/realtime/overwritten_version_service.dart';
import 'package:butlery/widgets/realtime/restore_overwritten_version.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

class _MockService extends Mock implements OverwrittenVersionService {}

class _FakeResource extends Fake implements RealtimeResource {}

OverwrittenVersion _version(
  String id,
  DateTime at, {
  ConflictEntity entity = ConflictEntity.weekMenu,
  String by = 'Per',
}) => OverwrittenVersion(
  id: id,
  ownerId: 'me',
  entity: entity,
  resourceType: entity == ConflictEntity.weekMenu
      ? RealtimeResourceType.menu
      : RealtimeResourceType.recipe,
  resourceId: 'res-1',
  version: const {},
  overwrittenBy: 'per-uid',
  overwrittenByName: by,
  overwrittenAt: at,
  expiresAt: at.add(OverwrittenVersion.keptFor),
);

void main() {
  late _MockService service;
  late AppLocalizations l;
  late OverwrittenVersionRestore receipt;

  setUpAll(() {
    registerFallbackValue(_version('fallback', DateTime(2026)));
    registerFallbackValue(
      OverwrittenVersionRestore(
        version: _version('fallback', DateTime(2026)),
        replaced: _FakeResource(),
      ),
    );
  });

  setUp(() async {
    await GetIt.instance.reset();
    service = _MockService();
    when(() => service.restore(any())).thenAnswer((inv) async {
      receipt = OverwrittenVersionRestore(
        version: inv.positionalArguments.single as OverwrittenVersion,
        replaced: _FakeResource(),
      );
      return receipt;
    });
    when(() => service.undo(any())).thenAnswer((_) async {});
    when(() => service.settle(any())).thenAnswer((_) async {});
    GetIt.instance.registerSingleton<OverwrittenVersionService>(service);
    prod.ServiceLocator.initialize(DIContainer());
  });

  tearDown(() async {
    prod.ServiceLocator.reset();
    await GetIt.instance.reset();
  });

  Future<void> pumpStart(
    WidgetTester tester,
    List<OverwrittenVersion> versions,
  ) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) {
            l = context.l10n;
            return TextButton(
              onPressed: () =>
                  RestoreOverwrittenVersion.start(context, versions),
              child: const Text('start'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('start'));
    await tester.pumpAndSettle();
  }

  // Kept "today" relative to the real clock, so the wording is stable.
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day, 0, 5);

  group('the flow', () {
    testWidgets('one version: confirm, restore, Ångra puts theirs back', (
      tester,
    ) async {
      final v = _version('v1', today);
      await pumpStart(tester, [v]);

      final when = RestoreOverwrittenVersion.whenLabel(
        l,
        today,
        DateTime.now(),
      );
      expect(find.text(l.overwrittenConfirmTitleWeek), findsOneWidget);
      expect(find.text(l.overwrittenConfirmBodyWeek(when)), findsOneWidget);
      verifyNever(() => service.restore(any()));

      await tester.tap(find.text(l.overwrittenRestoreAction));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      verify(() => service.restore(v)).called(1);
      expect(find.text(l.overwrittenRestored), findsOneWidget);

      await tester.tap(find.text(l.commonUndo));
      await tester.pumpAndSettle();

      verify(() => service.undo(receipt)).called(1);
      verifyNever(() => service.settle(any()));
    });

    testWidgets('the undo window closing forgets the kept row', (
      tester,
    ) async {
      await pumpStart(tester, [_version('v1', today)]);
      await tester.tap(find.text(l.overwrittenRestoreAction));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.pump(kUndoWindow + const Duration(seconds: 1));
      await tester.pumpAndSettle();

      verify(() => service.settle(receipt)).called(1);
      verifyNever(() => service.undo(any()));
    });

    testWidgets('cancelling changes nothing', (tester) async {
      await pumpStart(tester, [_version('v1', today)]);

      await tester.tap(find.text(l.commonCancel));
      await tester.pumpAndSettle();

      verifyNever(() => service.restore(any()));
    });

    testWidgets('an own recipe is named as a recipe', (tester) async {
      await pumpStart(tester, [
        _version('r1', today, entity: ConflictEntity.recipeOwn),
      ]);

      expect(find.text(l.overwrittenConfirmTitleRecipe), findsOneWidget);
    });

    testWidgets('two versions are picked by their id, not their position', (
      tester,
    ) async {
      final newer = _version('newer', today);
      final older = _version(
        'older',
        today.subtract(const Duration(days: 5)),
        by: 'Lisa',
      );
      await pumpStart(tester, [newer, older]);

      expect(find.text(l.overwrittenPickTitle), findsOneWidget);
      expect(
        find.byKey(RestoreOverwrittenVersion.pickerRowKey('newer')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(RestoreOverwrittenVersion.pickerRowKey('older')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.overwrittenRestoreAction));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      verify(() => service.restore(older)).called(1);
    });

    testWidgets('a failed restore says what happened and what is kept', (
      tester,
    ) async {
      final v = _version('v1', today);
      when(() => service.restore(any())).thenThrow(StateError('offline'));
      await pumpStart(tester, [v]);

      await tester.tap(find.text(l.overwrittenRestoreAction));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final until = RestoreOverwrittenVersion.dateLabel(
        l,
        v.expiresAt,
        DateTime.now(),
      );
      expect(
        find.textContaining(l.overwrittenRestoreFailed),
        findsOneWidget,
      );
      expect(
        find.textContaining(l.overwrittenKeptUntil(until)),
        findsOneWidget,
      );
      expect(find.text(l.commonRetry), findsOneWidget);
      expect(find.textContaining('offline'), findsNothing);
    });
  });

  group('the time, as content-style-guide.md:20-36 writes it', () {
    testWidgets('today, yesterday, a date, another year', (tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (context) {
              l = context.l10n;
              return const SizedBox();
            },
          ),
        ),
      );
      final ref = DateTime(2026, 9, 23, 18);
      expect(
        RestoreOverwrittenVersion.whenLabel(
          l,
          DateTime(2026, 9, 23, 14, 2),
          ref,
        ),
        'i dag 14:02',
      );
      expect(
        RestoreOverwrittenVersion.whenLabel(l, DateTime(2026, 9, 22, 9), ref),
        'i går',
      );
      expect(
        RestoreOverwrittenVersion.whenLabel(l, DateTime(2026, 7, 9, 9), ref),
        '9 juli',
      );
      expect(
        RestoreOverwrittenVersion.whenLabel(l, DateTime(2025, 7, 9, 9), ref),
        '9 juli 2025',
      );
    });
  });

  group('where the entry is mounted', () {
    String code(String path) => File(path).readAsStringSync();

    test('the week menu offers the row only while a week is kept', () {
      final week = code('lib/views/veckomeny_view.dart');
      expect(week, contains('entity: ConflictEntity.weekMenu'));
      expect(
        RegExp(
          r'if \(_restorable\.versions\.isNotEmpty\)\s*_rootItem\(\s*'
          r'_VeckomenyRootAction\.restore',
        ).hasMatch(week),
        isTrue,
      );
      expect(week, contains('_restorable.dispose()'));
    });

    test("recipe detail offers it only on the owner's recipe, by its id", () {
      final detail = code('lib/views/recipe_detail_view.dart');
      expect(detail, contains('entity: ConflictEntity.recipeOwn'));
      expect(detail, contains('resourceId: widget.recipe.id'));
      expect(
        RegExp(
          r'if \(!widget\.readOnly &&\s*_restorable\.versions\.isNotEmpty\)',
        ).hasMatch(detail),
        isTrue,
      );
      expect(detail, contains('_restorable.dispose()'));
    });
  });
}
