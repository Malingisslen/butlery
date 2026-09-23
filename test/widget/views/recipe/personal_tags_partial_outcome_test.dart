/// P5-U33: bulk tag delete reports a partial outcome.
///
/// produktregler.md:905-909 (§ 17.6, I-29): a partial result is a third
/// outcome. It names what went, what did not and why, and the ones that did
/// not go stay selected, with selection mode still on (produktregler.md:878).
/// The delete runs in atomic chunks of 100, so a later chunk can fail after
/// an earlier one landed; the result says per tag id which.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/models/tagging/personal_tag_bulk_delete_result.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/personal_tag_viewmodel.dart';
import 'package:butlery/views/personal_tags_view.dart';
import 'package:butlery/widgets/common/feedback/partial_outcome.dart';

import '../../../infrastructure/mocks/production_mocks.dart';
import 'fake_personal_tag_viewmodel.dart';

/// Deletes the ids in [deletes] and keeps the rest, as a chunk that failed
/// would. Tags that went leave the list, as the live list does.
class _BulkDeleteVm extends FakePersonalTagViewModel {
  Set<String> deletes = {};
  final List<List<String>> calls = [];

  @override
  Future<PersonalTagBulkDeleteResult> bulkDeleteTags(
    List<String> tagIds,
  ) async {
    calls.add(List.of(tagIds));
    final gone = tagIds.where(deletes.contains).toList();
    final left = tagIds.where((id) => !deletes.contains(id)).toList();
    setState(
      tags: tags.where((t) => !gone.contains(t.id)).toList(),
      usageCounts: const {'Snabbt': 1, 'Vardag': 1, 'Fest': 1},
    );
    return PersonalTagBulkDeleteResult(deletedIds: gone, failedIds: left);
  }
}

void main() {
  late _BulkDeleteVm vm;
  final snabbt = PersonalTag.create(name: 'Snabbt');
  final vardag = PersonalTag.create(name: 'Vardag');
  final fest = PersonalTag.create(name: 'Fest');

  setUp(() {
    final getIt = GetIt.instance;
    vm = _BulkDeleteVm()
      ..setState(
        tags: [snabbt, vardag, fest],
        usageCounts: const {'Snabbt': 1, 'Vardag': 1, 'Fest': 1},
      );
    if (getIt.isRegistered<PersonalTagViewModel>()) {
      getIt.unregister<PersonalTagViewModel>();
    }
    getIt.registerFactory<PersonalTagViewModel>(() => vm);

    final offline = MockOfflineService();
    when(() => offline.isOnline).thenReturn(true);
    when(() => offline.addListener(any())).thenReturn(null);
    when(() => offline.removeListener(any())).thenReturn(null);
    if (getIt.isRegistered<OfflineService>()) {
      getIt.unregister<OfflineService>();
    }
    getIt.registerSingleton<OfflineService>(offline);

    production.ServiceLocator.reset();
    production.ServiceLocator.initialize(DIContainer());
  });

  tearDown(() {
    production.ServiceLocator.reset();
    final getIt = GetIt.instance;
    if (getIt.isRegistered<PersonalTagViewModel>()) {
      getIt.unregister<PersonalTagViewModel>();
    }
    if (getIt.isRegistered<OfflineService>()) {
      getIt.unregister<OfflineService>();
    }
  });

  Future<void> pumpView(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('sv'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.lightTheme,
        home: const PersonalTagsView(),
      ),
    );
    await tester.pump();
  }

  Future<void> selectAllThreeAndDelete(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('personal-tags-select-enter')));
    await tester.pump();
    for (final name in ['Snabbt', 'Vardag', 'Fest']) {
      await tester.tap(find.widgetWithText(ListTile, name));
      await tester.pump();
    }
    expect(find.text('3 valda'), findsOneWidget);
    await tester.tap(find.widgetWithIcon(IconButton, Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Ta bort'));
    await tester.pumpAndSettle();
  }

  final outcome = find.byKey(const ValueKey('personal-tags-partial-outcome'));

  testWidgets('one of three went: the outcome counts it, names the two left '
      'with their reason, and they stay selected', (tester) async {
    vm.deletes = {snabbt.id};
    await pumpView(tester);
    await selectAllThreeAndDelete(tester);

    expect(outcome, findsOneWidget);
    expect(find.text('1 av 3 taggar togs bort'), findsOneWidget);
    for (final tag in [vardag, fest]) {
      final row = find.byKey(PartialOutcome.itemKey(tag.id));
      expect(row, findsOneWidget);
      expect(
        find.descendant(
          of: row,
          matching: find.text(
            'Kunde inte tas bort — borttagningen sparades inte',
          ),
        ),
        findsOneWidget,
      );
    }
    expect(find.byKey(PartialOutcome.itemKey(snabbt.id)), findsNothing);
    // Still in selection mode with exactly the two left selected.
    expect(find.text('2 valda'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('personal-tags-selection-cancel')),
      findsOneWidget,
    );
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('"Försök igen" asks again for the two left only', (
    tester,
  ) async {
    vm.deletes = {snabbt.id};
    await pumpView(tester);
    await selectAllThreeAndDelete(tester);

    vm.deletes = {vardag.id, fest.id};
    await tester.tap(find.byKey(const ValueKey('personal-tags-partial-retry')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Ta bort'));
    await tester.pumpAndSettle();

    expect(vm.calls.last, unorderedEquals([vardag.id, fest.id]));
    expect(outcome, findsNothing);
    expect(find.textContaining('valda'), findsNothing);
  });

  testWidgets('"Klart" closes the outcome and leaves selection mode', (
    tester,
  ) async {
    vm.deletes = {snabbt.id};
    await pumpView(tester);
    await selectAllThreeAndDelete(tester);

    await tester.tap(find.byKey(const ValueKey('personal-tags-partial-done')));
    await tester.pump();

    expect(outcome, findsNothing);
    expect(find.textContaining('valda'), findsNothing);
  });

  testWidgets('none went: a failure says so and all three stay selected', (
    tester,
  ) async {
    vm.deletes = {};
    await pumpView(tester);
    await selectAllThreeAndDelete(tester);

    expect(outcome, findsNothing);
    expect(
      find.text('Taggarna kunde inte tas bort. De ligger kvar valda.'),
      findsOneWidget,
    );
    expect(find.text('3 valda'), findsOneWidget);
  });

  testWidgets('all went: selection mode closes with the success count', (
    tester,
  ) async {
    vm.deletes = {snabbt.id, vardag.id, fest.id};
    await pumpView(tester);
    await selectAllThreeAndDelete(tester);

    expect(outcome, findsNothing);
    expect(find.text('3 taggar borttagna'), findsOneWidget);
  });
}
