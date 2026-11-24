// Intention: "Fasta dagar" lists the saved rules, a rule is added from the
// editor or the day sheet, paused with its switch and removed by a swipe, all
// through UserService, in light and dark.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/menu/recurring_day_rule.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/user_service/user_service_roles.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/recurring_day_rules_viewmodel.dart';
import 'package:butlery/views/recurring_day_rules/recurring_day_rule_editor_view.dart';
import 'package:butlery/views/recurring_day_rules/recurring_day_rule_sheet.dart';
import 'package:butlery/views/recurring_day_rules/recurring_day_rules_view.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';

import '../../../helpers/user_profile_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';

class _FakeUserService extends MockUserService {
  _FakeUserService(List<RecurringDayRule> rules)
    : profile = testUserProfile().copyWith(recurringDayRules: rules);

  UserProfile profile;
  bool failWrites = false;
  final _listeners = <VoidCallback>{};

  @override
  UserProfile? get currentUserProfile => profile;

  @override
  void addListener(VoidCallback listener) => _listeners.add(listener);

  @override
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  @override
  Future<bool> setRecurringDayRules(List<RecurringDayRule> rules) async {
    if (failWrites) return false;
    profile = profile.copyWith(recurringDayRules: rules);
    for (final listener in _listeners.toList()) {
      listener();
    }
    return true;
  }
}

RecurringDayRule _rule(
  DayOfWeek day, {
  RecurringFood? food,
  bool quick = false,
  MealSlot meal = MealSlot.middag,
}) => RecurringDayRule.create(day: day, meal: meal, food: food, quick: quick);

void main() {
  final sv = AppLocalizationsSv();
  late _FakeUserService users;

  Future<void> setUpUsers(List<RecurringDayRule> rules) async {
    await GetIt.instance.reset();
    users = _FakeUserService(rules);
    GetIt.instance.registerSingleton<UserService>(users);
    GetIt.instance.registerSingleton<OwnProfileReader>(users);
    GetIt.instance.registerSingleton<OwnProfileEditor>(users);
    prod.ServiceLocator.initialize(DIContainer());
  }

  tearDown(() async {
    prod.ServiceLocator.reset();
    await GetIt.instance.reset();
  });

  Future<void> pump(
    WidgetTester tester,
    Widget home, {
    bool dark = false,
  }) async {
    tester.view.physicalSize = const Size(600, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
        locale: const Locale('sv', 'SE'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: home,
      ),
    );
    await tester.pumpAndSettle();
  }

  group('the list', () {
    final seed = [
      _rule(DayOfWeek.mon, food: RecurringFood.fisk),
      _rule(DayOfWeek.tue, quick: true),
    ];

    for (final dark in [false, true]) {
      testWidgets(
        'shows each rule with its sort (${dark ? 'dark' : 'light'})',
        (
          tester,
        ) async {
          await setUpUsers(seed);
          await pump(tester, const RecurringDayRulesView(), dark: dark);

          expect(find.text(sv.recurringRulesTitle), findsWidgets);
          expect(find.text('Måndag · middag'), findsOneWidget);
          expect(find.text('Fisk'), findsOneWidget);
          expect(find.text('Tisdag · middag'), findsOneWidget);
          expect(find.text(sv.recurringRuleQuickLabel), findsOneWidget);
          expect(find.text(sv.recurringRulesNew), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('the switch pauses a rule without deleting it', (
      tester,
    ) async {
      await setUpUsers(seed);
      await pump(tester, const RecurringDayRulesView());

      await tester.tap(find.text('Måndag · middag'));
      await tester.pumpAndSettle();

      expect(users.profile.recurringDayRules, hasLength(2));
      expect(users.profile.recurringDayRules.first.paused, isTrue);
      expect(find.text('Måndag · middag'), findsOneWidget);
    });

    testWidgets('a swipe deletes the rule and Ångra puts it back', (
      tester,
    ) async {
      await setUpUsers(seed);
      await pump(tester, const RecurringDayRulesView());

      await tester.drag(find.text('Måndag · middag'), const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(users.profile.recurringDayRules.map((r) => r.id), [
        RecurringDayRule.idFor(DayOfWeek.tue, MealSlot.middag),
      ]);
      expect(find.text('Måndag · middag'), findsNothing);
      expect(find.text(sv.recurringRuleDeleted), findsOneWidget);

      await tester.tap(find.text(sv.commonUndo));
      await tester.pumpAndSettle();
      expect(users.profile.recurringDayRules, hasLength(2));
      expect(find.text('Måndag · middag'), findsOneWidget);
    });

    testWidgets('with no rules it says so and offers Ny fast dag', (
      tester,
    ) async {
      await setUpUsers(const []);
      await pump(tester, const RecurringDayRulesView());

      expect(find.text(sv.recurringRulesEmptyTitle), findsOneWidget);
      expect(find.text(sv.recurringRulesNew), findsOneWidget);
      expect(find.byType(ButleryListRow), findsNothing);
    });
  });

  group('the editor', () {
    testWidgets('saves a new rule for the preselected day', (tester) async {
      await setUpUsers(const []);
      await pump(
        tester,
        const RecurringDayRuleEditorView(initialDay: DayOfWeek.wed),
      );

      await tester.tap(find.text(sv.recurringRuleFoodLabel('kyckling')));
      await tester.tap(find.text(sv.recurringRuleQuickLabel));
      await tester.pump();
      await tester.tap(find.text(sv.commonSave));
      await tester.pumpAndSettle();

      final saved = users.profile.recurringDayRules.single;
      expect(saved.day, DayOfWeek.wed);
      expect(saved.meal, MealSlot.middag);
      expect(saved.food, RecurringFood.kyckling);
      expect(saved.quick, isTrue);
    });

    testWidgets('refuses to save with neither a food nor Snabbt', (
      tester,
    ) async {
      await setUpUsers(const []);
      await pump(tester, const RecurringDayRuleEditorView());

      await tester.tap(find.text(sv.commonSave));
      await tester.pumpAndSettle();

      expect(users.profile.recurringDayRules, isEmpty);
      expect(find.text(sv.recurringRuleNeedChoice), findsOneWidget);
    });

    testWidgets('a day and meal with a rule edits that rule', (tester) async {
      await setUpUsers([_rule(DayOfWeek.fri, food: RecurringFood.tacos)]);
      await pump(
        tester,
        const RecurringDayRuleEditorView(initialDay: DayOfWeek.fri),
      );

      await tester.tap(find.text(sv.recurringRuleFoodLabel('soppa')));
      await tester.pump();
      await tester.tap(find.text(sv.commonSave));
      await tester.pumpAndSettle();

      final rules = users.profile.recurringDayRules;
      expect(rules, hasLength(1));
      expect(rules.single.food, RecurringFood.soppa);
    });

    testWidgets('says so when the save fails', (tester) async {
      await setUpUsers(const []);
      users.failWrites = true;
      await pump(
        tester,
        const RecurringDayRuleEditorView(initialDay: DayOfWeek.mon),
      );

      await tester.tap(find.text(sv.recurringRuleFoodLabel('fisk')));
      await tester.pump();
      await tester.tap(find.text(sv.commonSave));
      await tester.pumpAndSettle();

      expect(find.text(sv.recurringRuleSaveFailed), findsOneWidget);
    });
  });

  group('the day sheet', () {
    testWidgets('names the day and opens the editor on it', (tester) async {
      await setUpUsers(const []);
      await pump(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showRecurringDayRuleSheet(context, DayOfWeek.thu),
            child: const Text('open'),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Torsdag middag'), findsOneWidget);

      await tester.tap(find.text(sv.recurringRuleMakeFixed));
      await tester.pumpAndSettle();
      expect(find.byType(RecurringDayRuleEditorView), findsOneWidget);
      final chip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, sv.recurringRuleDayShort('thu')),
      );
      expect(chip.selected, isTrue);
    });
  });

  group('the view model', () {
    test('pausing a rule that is gone from a full list reports a failed save '
        'instead of throwing, and writes nothing', () async {
      final full = [
        for (final day in DayOfWeek.values)
          for (final meal in [MealSlot.lunch, MealSlot.middag])
            _rule(day, food: RecurringFood.fisk, meal: meal),
      ];
      expect(full, hasLength(RecurringDayRules.maxRules));
      await setUpUsers(full);
      final vm = RecurringDayRulesViewModel(reader: users, editor: users);
      addTearDown(vm.dispose);
      final missing = _rule(
        DayOfWeek.mon,
        food: RecurringFood.fisk,
        meal: MealSlot.ovrigt,
      );

      final ok = await vm.setPaused(missing, true);

      expect(ok, isFalse);
      expect(vm.error, sv.recurringRuleSaveFailed);
      expect(users.profile.recurringDayRules, full);
    });
  });
}
