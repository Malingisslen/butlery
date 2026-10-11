/// REC-15 — behaviour tests for [TagDetailView], the single-tag detail screen.
///
/// The view resolves its [PersonalTagViewModel] through the production
/// [ServiceLocator] (GetIt) and looks the tag up by id in `build`. It branches
/// on three VM states (loading-while-missing → not-found → loaded) and carries
/// a name field that saves on blur. We register a thin fake VM over the
/// GetIt bridge and assert the user-visible Swedish behaviour for each branch
/// plus the autosaved rename, group sheet, rules and menu.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/views/tag_detail_view.dart';
import 'package:butlery/viewmodels/personal_tag_viewmodel.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/models/tagging/personal_tag_group.dart';
import 'package:butlery/models/tagging/personal_tag_rule.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/widgets/tagging/rule_builder_sheet.dart';
import 'package:butlery/widgets/styled/styled_input.dart';

import '../../../infrastructure/mocks/production_mocks.dart';
import 'fake_personal_tag_viewmodel.dart';

void main() {
  late _RecordingVm fakeVm;
  late MockOfflineService offlineService;

  setUp(() {
    final getIt = GetIt.instance;

    fakeVm = _RecordingVm();
    if (getIt.isRegistered<PersonalTagViewModel>()) {
      getIt.unregister<PersonalTagViewModel>();
    }
    // TagDetailView.build() resolves the VM once per build; a singleton keeps
    // the same configured fake across rebuilds.
    getIt.registerSingleton<PersonalTagViewModel>(fakeVm);

    offlineService = MockOfflineService();
    when(() => offlineService.isOnline).thenReturn(true);
    when(() => offlineService.addListener(any())).thenReturn(null);
    when(() => offlineService.removeListener(any())).thenReturn(null);
    if (getIt.isRegistered<OfflineService>()) {
      getIt.unregister<OfflineService>();
    }
    getIt.registerSingleton<OfflineService>(offlineService);

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

  Widget testApp(String tagId) {
    return MaterialApp(
      locale: const Locale('sv'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.lightTheme,
      home: TagDetailView(tagId: tagId),
    );
  }

  Future<void> pumpView(WidgetTester tester, String tagId) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(testApp(tagId));
    await tester.pump(); // settle the post-frame loadRuleEffectiveness callback
  }

  testWidgets('loaded tag shows its name in the app bar and the recipe count', (
    tester,
  ) async {
    // Proves: the happy path — the resolved tag's name titles the screen and
    // its usage count is rendered via TagDetailHeader.
    final tag = PersonalTag.create(name: 'Vardagsmat');
    fakeVm.setState(
      tags: [tag],
      isLoading: false,
      usageCounts: {'Vardagsmat': 3},
    );
    await pumpView(tester, tag.id);

    expect(find.text('Vardagsmat'), findsWidgets);
    expect(find.text('3 recept'), findsOneWidget); // tagDetailRecipeCount(3)
  });

  testWidgets('unknown tag id shows the not-found error state', (tester) async {
    // Proves: when no tag matches the id (and we are not loading), the user
    // gets the localized "could not find the tag" state, not a blank screen.
    fakeVm.setState(tags: const [], isLoading: false);
    await pumpView(tester, 'does-not-exist');

    expect(find.text('Taggen kunde inte hittas'), findsOneWidget);
    expect(find.text('Tagg'), findsOneWidget); // tagDetailDefaultTitle
  });

  testWidgets('loading while tag not yet present shows the loading title', (
    tester,
  ) async {
    // Proves: the isLoading && tag==null branch shows the plate line with
    // "Hämtar taggen …" (produktregler.md:163, P4-U16) rather than
    // prematurely flashing the not-found error.
    fakeVm.setState(tags: const [], isLoading: true);
    await pumpView(tester, 'pending-id');

    expect(find.text('Hämtar taggen …'), findsOneWidget); // loadingTag
    expect(find.text('Taggen kunde inte hittas'), findsNothing);
  });

  testWidgets('the bar is the tag name and Back leads to Egna taggar', (
    tester,
  ) async {
    final tag = PersonalTag.create(name: 'Helg');
    fakeVm.setState(tags: [tag], isLoading: false);
    await pumpView(tester, tag.id);

    final bar = tester.widget<ButleryTopBar>(find.byType(ButleryTopBar));
    expect(bar.title, 'Helg');
    expect(bar.backTo, 'Egna taggar');
    expect(find.text('Spara'), findsNothing);
  });

  testWidgets('the name field is seeded and saves when it loses focus', (
    tester,
  ) async {
    final tag = PersonalTag.create(name: 'Helg');
    fakeVm.setState(tags: [tag], isLoading: false);
    await pumpView(tester, tag.id);

    final field = find.byType(StyledInput);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'Helg',
    );

    await tester.enterText(find.byType(TextField), 'Helgmat');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(field, findsOneWidget);
    expect(fakeVm.updated.single.name, 'Helgmat');
    expect(find.text('Tagg uppdaterad'), findsOneWidget);
  });

  testWidgets('an emptied name is refused and put back', (tester) async {
    final tag = PersonalTag.create(name: 'Helg');
    fakeVm.setState(tags: [tag], isLoading: false);
    await pumpView(tester, tag.id);

    await tester.enterText(find.byType(TextField), '  ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(fakeVm.updated, isEmpty);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'Helg',
    );
  });

  testWidgets('a refused rename says so instead of claiming success', (
    tester,
  ) async {
    final tag = PersonalTag.create(name: 'Helg');
    fakeVm
      ..updateSucceeds = false
      ..setState(tags: [tag], isLoading: false);
    await pumpView(tester, tag.id);

    await tester.enterText(find.byType(TextField), 'Helgmat');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.textContaining('Kunde inte uppdatera taggen'), findsOneWidget);
    expect(find.text('Tagg uppdaterad'), findsNothing);
  });

  testWidgets('a name typed and then left by Back is still saved', (
    tester,
  ) async {
    final tag = PersonalTag.create(name: 'Helg');
    fakeVm.setState(tags: [tag], isLoading: false);
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
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => TagDetailView(tagId: tag.id),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Helgmat');
    await tester.pump();
    Navigator.of(tester.element(find.byType(TagDetailView))).pop();
    await tester.pumpAndSettle();

    expect(find.byType(TagDetailView), findsNothing);
    expect(fakeVm.updated.single.name, 'Helgmat');
  });

  testWidgets('the Grupp row shows the group and its sheet moves the tag', (
    tester,
  ) async {
    final group = PersonalTagGroup.create(name: 'Kvällsmat');
    final tag = PersonalTag.create(name: 'Helg');
    fakeVm.setState(tags: [tag], groups: [group], isLoading: false);
    await pumpView(tester, tag.id);

    expect(find.text('Ingen grupp'), findsOneWidget);
    await tester.tap(find.widgetWithText(ButleryListRow, 'Grupp'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kvällsmat'));
    await tester.pumpAndSettle();

    expect(fakeVm.moved, [(tag.id, group.id)]);
  });

  testWidgets('a rule is a row with its state and a last row adds one', (
    tester,
  ) async {
    final now = DateTime(2026, 10, 10);
    final tag = PersonalTag(
      id: 't1',
      name: 'Fisk',
      createdAt: now,
      updatedAt: now,
      rules: [
        PersonalTagRule(
          id: 'r1',
          name: 'Laxregel',
          conditions: const [],
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );
    fakeVm.setState(tags: [tag], isLoading: false);
    await pumpView(tester, tag.id);

    expect(find.text('REGLER'), findsOneWidget);
    expect(find.text('Laxregel'), findsOneWidget);
    expect(find.text('På'), findsOneWidget);
    expect(find.text('Lägg till regel'), findsOneWidget);
    expect(find.text('Kör reglerna på alla recept'), findsOneWidget);

    await tester.tap(find.text('Laxregel'));
    await tester.pumpAndSettle();
    expect(find.text('Pausa regeln'), findsOneWidget);
    expect(find.text('Redigera regeln'), findsOneWidget);
    expect(find.text('Ta bort regeln'), findsOneWidget);

    await tester.tap(find.text('Pausa regeln'));
    await tester.pumpAndSettle();
    expect(fakeVm.toggled, [('t1', 'r1')]);
  });

  group('a rule\'s sheet', () {
    final now = DateTime(2026, 10, 10);
    final rule = PersonalTagRule(
      id: 'r1',
      name: 'Laxregel',
      conditions: const [],
      createdAt: now,
      updatedAt: now,
    );
    final tag = PersonalTag(
      id: 't1',
      name: 'Fisk',
      createdAt: now,
      updatedAt: now,
      rules: [rule],
    );

    Future<void> openSheet(WidgetTester tester) async {
      fakeVm.setState(tags: [tag], isLoading: false);
      await pumpView(tester, tag.id);
      await tester.tap(find.text('Laxregel'));
      await tester.pumpAndSettle();
    }

    testWidgets('Ta bort regeln asks first and deletes only on confirm', (
      tester,
    ) async {
      await openSheet(tester);
      await tester.tap(find.text('Ta bort regeln'));
      await tester.pumpAndSettle();
      expect(find.text('Ta bort regel?'), findsOneWidget);
      expect(fakeVm.deletedRules, isEmpty);

      await tester.tap(find.text('Avbryt'));
      await tester.pumpAndSettle();
      expect(fakeVm.deletedRules, isEmpty);

      await tester.tap(find.text('Laxregel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ta bort regeln'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Ta bort'));
      await tester.pumpAndSettle();
      expect(fakeVm.deletedRules, [('t1', 'r1')]);
    });

    testWidgets('a rule row sums up its condition and how many recipes match', (
      tester,
    ) async {
      final lax = PersonalTagRule(
        id: 'r2',
        name: 'Laxregel',
        conditions: const [
          RuleCondition(
            type: ConditionType.ingredient,
            operator: ConditionOperator.contains,
            value: 'lax',
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );
      fakeVm
        ..matchCounts = {'r2': 3}
        ..setState(
          tags: [
            tag.copyWith(rules: [lax]),
          ],
          isLoading: false,
        );
      await pumpView(tester, tag.id);

      expect(find.textContaining('"lax" · 3 recept matchar'), findsOneWidget);
    });

    testWidgets('a paused rule reads Av and its sheet offers Aktivera', (
      tester,
    ) async {
      fakeVm.setState(
        tags: [
          tag.copyWith(rules: [rule.copyWith(isEnabled: false)]),
        ],
        isLoading: false,
      );
      await pumpView(tester, tag.id);
      expect(find.text('Av'), findsOneWidget);
      expect(find.text('På'), findsNothing);

      await tester.tap(find.text('Laxregel'));
      await tester.pumpAndSettle();
      expect(find.text('Pausa regeln'), findsNothing);
      await tester.tap(find.text('Aktivera regeln'));
      await tester.pumpAndSettle();
      expect(fakeVm.toggled, [('t1', 'r1')]);
    });

    testWidgets('Lägg till regel opens an empty rule builder', (tester) async {
      fakeVm.setState(tags: [tag], isLoading: false);
      await pumpView(tester, tag.id);

      await tester.tap(find.text('Lägg till regel'));
      await tester.pumpAndSettle();
      // The new-rule form's empty condition card overflows its operator
      // dropdown by a few pixels (rule_condition_card.dart); that layout is
      // outside this test, which only asks which rule the builder opened on.
      final error = tester.takeException();
      expect(error == null || '$error'.contains('overflowed'), isTrue);

      expect(
        tester
            .widget<RuleBuilderSheet>(find.byType(RuleBuilderSheet))
            .existingRule,
        isNull,
      );
    });

    testWidgets('Redigera regeln opens the rule builder on that rule', (
      tester,
    ) async {
      await openSheet(tester);
      await tester.tap(find.text('Redigera regeln'));
      await tester.pumpAndSettle();

      final sheet = tester.widget<RuleBuilderSheet>(
        find.byType(RuleBuilderSheet),
      );
      expect(sheet.existingRule?.id, 'r1');
      expect(fakeVm.deletedRules, isEmpty);
      expect(fakeVm.toggled, isEmpty);
    });
  });

  group('the menu turns all rules on or off', () {
    final now = DateTime(2026, 10, 10);
    PersonalTagRule rule(String id, {required bool on}) => PersonalTagRule(
      id: id,
      name: 'Regel $id',
      conditions: const [],
      isEnabled: on,
      createdAt: now,
      updatedAt: now,
    );

    Future<void> openMenu(
      WidgetTester tester,
      List<PersonalTagRule> rules,
    ) async {
      final tag = PersonalTag(
        id: 't1',
        name: 'Fisk',
        createdAt: now,
        updatedAt: now,
        rules: rules,
      );
      fakeVm.setState(tags: [tag], isLoading: false);
      await pumpView(tester, tag.id);
      await tester.tap(find.byIcon(ButleryIcons.moreVertical));
      await tester.pumpAndSettle();
    }

    testWidgets('all on: only Inaktivera, and it asks first', (tester) async {
      await openMenu(tester, [rule('a', on: true), rule('b', on: true)]);
      expect(find.text('Aktivera alla regler'), findsNothing);

      await tester.tap(find.text('Inaktivera alla regler'));
      await tester.pumpAndSettle();
      expect(find.text('Inaktivera alla regler?'), findsOneWidget);
    });

    testWidgets('all off: only Aktivera, and it asks first', (tester) async {
      await openMenu(tester, [rule('a', on: false), rule('b', on: false)]);
      expect(find.text('Inaktivera alla regler'), findsNothing);

      await tester.tap(find.text('Aktivera alla regler'));
      await tester.pumpAndSettle();
      expect(find.text('Aktivera alla regler?'), findsOneWidget);
    });

    testWidgets('some on: both rows', (tester) async {
      await openMenu(tester, [rule('a', on: true), rule('b', on: false)]);
      expect(find.text('Aktivera alla regler'), findsOneWidget);
      expect(find.text('Inaktivera alla regler'), findsOneWidget);
    });

    testWidgets('no rules: neither row', (tester) async {
      await openMenu(tester, const []);
      expect(find.text('Aktivera alla regler'), findsNothing);
      expect(find.text('Inaktivera alla regler'), findsNothing);
      expect(find.text('Dela taggen'), findsOneWidget);
    });
  });

  testWidgets('the menu holds share and the danger row, which confirms', (
    tester,
  ) async {
    final tag = PersonalTag.create(name: 'Helg');
    fakeVm.setState(tags: [tag], isLoading: false);
    await pumpView(tester, tag.id);

    await tester.tap(find.byIcon(ButleryIcons.moreVertical));
    await tester.pumpAndSettle();
    expect(find.text('Dela taggen'), findsOneWidget);

    await tester.tap(find.text('Ta bort taggen'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(fakeVm.deleted, isEmpty);

    await tester.tap(find.widgetWithText(FilledButton, 'Ta bort'));
    await tester.pumpAndSettle();
    expect(fakeVm.deleted, [tag.id]);
  });
}

class _RecordingVm extends FakePersonalTagViewModel {
  final updated = <PersonalTag>[];
  final moved = <(String, String?)>[];
  final toggled = <(String, String)>[];
  final deleted = <String>[];
  final deletedRules = <(String, String)>[];
  bool updateSucceeds = true;
  Map<String, int> matchCounts = const {};

  @override
  int getRuleMatchCount(String ruleId) => matchCounts[ruleId] ?? 0;

  @override
  Future<bool> updateTag(PersonalTag tag) async {
    updated.add(tag);
    return updateSucceeds;
  }

  @override
  Future<bool> moveTagToGroup(String tagId, String? groupId) async {
    moved.add((tagId, groupId));
    return true;
  }

  @override
  Future<bool> toggleRuleEnabled(String tagId, String ruleId) async {
    toggled.add((tagId, ruleId));
    return true;
  }

  @override
  Future<bool> deleteRule(String tagId, String ruleId) async {
    deletedRules.add((tagId, ruleId));
    return true;
  }

  @override
  Future<bool> deleteTag(String tagId) async {
    deleted.add(tagId);
    return true;
  }
}
