// Intention: a group's fixed days show in the group week as a band, a mark on
// the day and "Fast dag: <kind>" in the empty place - for everyone - and only
// whoever may edit the week gets a tappable place. With rules the grid is
// shown even in an empty week; without a chat group or with the flag off the
// week looks as before.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/menu/group_weekly_menu_plan.dart';
import 'package:butlery/models/menu/recurring_day_rule.dart';
import 'package:butlery/models/messaging/chat_group.dart';
import 'package:butlery/models/profile_lookup.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart'
    show SharedListPermission;
import 'package:butlery/services/menu/group_weekly_menu_plan_service.dart';
import 'package:butlery/services/unified/operations/realtime_group_menu/realtime_group_menu_module.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/menu/group_weekly_menu_viewmodel.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/widgets/menu/calendar/calendar_week_grid.dart';
import 'package:butlery/widgets/menu/group_fixed_day_widgets.dart';
import 'package:butlery/widgets/menu/group_weekly_menu_widget.dart';

import '../../infrastructure/mocks/service_mocks.dart';

class _MockService extends Mock implements GroupWeeklyMenuPlanService {}

class _MockRealtime extends Mock implements RealtimeGroupMenuModule {}

class _MockUsers extends Mock implements UserService {}

const _me = 'user-me';
final _week = DateTime.utc(2026, 9, 2);
final _sv = AppLocalizationsSv();

RecurringDayRule _tacosFriday() => RecurringDayRule.create(
  day: DayOfWeek.fri,
  meal: MealSlot.middag,
  food: RecurringFood.tacos,
);

ChatGroup _group(List<RecurringDayRule> rules, {required bool meAdmin}) =>
    ChatGroup(
      id: 'cg1',
      name: 'Familjen',
      memberIds: const [_me, 'other'],
      adminIds: meAdmin ? const [_me] : const ['other'],
      memberDisplayNames: const {},
      memberAvatarUrls: const {},
      conversationId: 'conv-1',
      createdBy: 'other',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
      recurringDayRules: rules,
    );

GroupWeeklyMenuPlan _plan(SharedListPermission permission) =>
    GroupWeeklyMenuPlan.empty(
      groupId: 'conv-1',
      creatorId: _me,
      date: _week,
      initialParticipants: [
        GroupMenuParticipant(
          userId: _me,
          permission: permission,
          addedAt: DateTime.utc(2026, 1, 1),
        ),
      ],
    );

void main() {
  late StreamController<ChatGroup?> groupStream;
  late GroupWeeklyMenuViewModel vm;

  setUp(() => groupStream = StreamController<ChatGroup?>.broadcast());
  tearDown(() async {
    vm.dispose();
    await groupStream.close();
  });

  Future<void> pump(
    WidgetTester tester, {
    required ChatGroup? group,
    GroupWeeklyMenuPlan? plan,
    bool enabled = true,
    String? chatGroupId = 'cg1',
    double textScale = 1.0,
  }) async {
    final service = _MockService();
    when(
      () => service.readWeek(
        groupId: any(named: 'groupId'),
        date: any(named: 'date'),
      ),
    ).thenAnswer(
      (_) async => GroupWeeklyMenuPlanRead(plan: plan, readFailed: false),
    );
    final realtime = _MockRealtime();
    when(
      () => realtime.subscribe(
        groupId: any(named: 'groupId'),
        date: any(named: 'date'),
        onUpdate: any(named: 'onUpdate'),
        onError: any(named: 'onError'),
      ),
    ).thenAnswer(
      (_) => const Stream<GroupWeeklyMenuPlan?>.empty().listen(null),
    );
    final users = _MockUsers();
    when(() => users.getUserProfiles(any())).thenAnswer(
      (_) async => const ProfileBatchLookup(
        profiles: [],
        missingIds: {},
        unavailableIds: {},
      ),
    );
    final groups = MockChatGroupRepository();
    when(() => groups.watchGroup('cg1')).thenAnswer((_) => groupStream.stream);
    vm = GroupWeeklyMenuViewModel(
      service: service,
      realtime: realtime,
      userService: users,
      groupId: 'conv-1',
      currentUserId: _me,
      chatGroupId: chatGroupId,
      participantIds: const [_me, 'other'],
      chatGroupRepository: groups,
      rulesEnabled: enabled,
    );
    await vm.loadWeek(_week);

    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('sv'),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: ChangeNotifierProvider<GroupWeeklyMenuViewModel>.value(
          value: vm,
          child: GroupWeeklyMenuWidget(
            groupName: 'Familjen',
            chatGroupId: chatGroupId,
          ),
        ),
      ),
    );
    if (group != null) groupStream.add(group);
    await tester.pumpAndSettle();
  }

  final cell = find.text(_sv.groupMenuFixedDayCell('Tacos'));
  // The action label is read together with the cell's visible text.
  Finder pickAction() =>
      find.bySemanticsLabel(RegExp('^${_sv.a11yGroupMenuPickFixedDay}'));

  int bandCount(WidgetTester tester) =>
      tester.widget<ButleryListRow>(find.byType(ButleryListRow)).count;

  testWidgets('a rule shows the band, the day mark and "Fast dag: Tacos" '
      'in an EMPTY week, tappable for an editor', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(
      tester,
      group: _group([_tacosFriday()], meAdmin: false),
      plan: _plan(SharedListPermission.edit),
    );

    expect(find.byType(CalendarWeekGrid), findsOneWidget);
    expect(find.text(_sv.recurringRulesTitle), findsOneWidget);
    expect(bandCount(tester), 1);
    expect(find.bySemanticsLabel(_sv.recurringRuleMarkLabel), findsOneWidget);
    expect(cell, findsOneWidget);
    expect(pickAction(), findsOneWidget);
    expect(tester.takeException(), isNull);
    handle.dispose();
  });

  testWidgets('a viewer sees the same text, inert', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(
      tester,
      group: _group([_tacosFriday()], meAdmin: false),
      plan: _plan(SharedListPermission.view),
    );

    expect(cell, findsOneWidget);
    expect(pickAction(), findsNothing);
    handle.dispose();
  });

  testWidgets('a week nobody has planned is tappable for any member', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester, group: _group([_tacosFriday()], meAdmin: false));

    expect(cell, findsOneWidget);
    expect(pickAction(), findsOneWidget);
    handle.dispose();
  });

  testWidgets(
    'a place somebody already planned shows the dish, not the rule',
    (tester) async {
      final planned = _plan(SharedListPermission.edit).copyWith(
        entries: [
          WeeklyMenuPlanEntry.create(
            day: DayOfWeek.fri,
            slot: MealSlot.middag,
            recipeId: 'r-soup',
            recipeTitle: 'Gulaschsoppa',
          ),
        ],
      );
      await pump(
        tester,
        group: _group([_tacosFriday()], meAdmin: false),
        plan: planned,
      );

      expect(find.text('Gulaschsoppa'), findsOneWidget);
      expect(find.byType(GroupFixedDayCell), findsNothing);
    },
  );

  testWidgets(
    'a paused rule shows no cell while an active one beside it does',
    (
      tester,
    ) async {
      await pump(
        tester,
        group: _group([
          _tacosFriday().copyWith(paused: true),
          RecurringDayRule.create(
            day: DayOfWeek.wed,
            meal: MealSlot.middag,
            food: RecurringFood.soppa,
          ),
        ], meAdmin: false),
        plan: _plan(SharedListPermission.edit),
      );

      expect(find.byType(CalendarWeekGrid), findsOneWidget);
      expect(find.text(_sv.groupMenuFixedDayCell('Soppa')), findsOneWidget);
      expect(cell, findsNothing);
      // The band still counts both rules the admin has saved.
      expect(bandCount(tester), 2);
    },
  );

  testWidgets('no rules: an admin sees the band to add the first, a member '
      'does not, and the empty week keeps its empty state', (tester) async {
    await pump(
      tester,
      group: _group(const [], meAdmin: true),
      plan: _plan(SharedListPermission.edit),
    );
    expect(find.text(_sv.recurringRulesTitle), findsOneWidget);
    expect(bandCount(tester), 0);
    expect(find.text(_sv.groupMenuEmptyTitle), findsOneWidget);
    expect(find.byType(CalendarWeekGrid), findsNothing);
  });

  testWidgets('no rules: a member sees no band', (tester) async {
    await pump(
      tester,
      group: _group(const [], meAdmin: false),
      plan: _plan(SharedListPermission.edit),
    );
    expect(find.text(_sv.recurringRulesTitle), findsNothing);
  });

  testWidgets('a conversation without a chat group has no band and no cell', (
    tester,
  ) async {
    await pump(
      tester,
      group: null,
      chatGroupId: null,
      plan: _plan(SharedListPermission.edit),
    );
    expect(find.text(_sv.recurringRulesTitle), findsNothing);
    expect(find.byType(GroupFixedDayCell), findsNothing);
  });

  testWidgets('flag off: the rule is not shown', (tester) async {
    await pump(
      tester,
      group: _group([_tacosFriday()], meAdmin: true),
      enabled: false,
      plan: _plan(SharedListPermission.edit),
    );
    expect(find.text(_sv.recurringRulesTitle), findsNothing);
    expect(find.byType(GroupFixedDayCell), findsNothing);
  });

  testWidgets('the cell survives 2x text on a narrow screen', (tester) async {
    await pump(
      tester,
      group: _group([_tacosFriday()], meAdmin: false),
      plan: _plan(SharedListPermission.edit),
      textScale: 2.0,
    );
    expect(find.byType(GroupFixedDayCell), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
