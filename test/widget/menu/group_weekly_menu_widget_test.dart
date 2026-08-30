/// Widget tests for [GroupWeeklyMenuWidget] (BUT-1971).
///
/// The product condition the design round bound this screen to: a permission
/// refusal and a transient outage must not look the same, and the refusal must
/// carry NO retry control — a button on something that can never succeed
/// teaches the user that buttons do nothing.
///
/// Drives a real `GroupWeeklyMenuViewModel` with mocked collaborators, so the
/// widget is exercised through the state transitions it will really see.
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/menu/group_weekly_menu_plan.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart'
    show SharedListPermission;
import 'package:butlery/services/menu/group_weekly_menu_plan_service.dart';
import 'package:butlery/services/unified/operations/realtime_group_menu/realtime_group_menu_module.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/menu/group_weekly_menu_viewmodel.dart';
import 'package:butlery/widgets/menu/group_weekly_menu_widget.dart';

class _MockService extends Mock implements GroupWeeklyMenuPlanService {}

class _MockRealtime extends Mock implements RealtimeGroupMenuModule {}

class _MockUserService extends Mock implements UserService {}

class _FakePlan extends Fake implements GroupWeeklyMenuPlan {}

const _groupId = 'group-1';
const _alice = 'user-alice';
final _week = DateTime.utc(2026, 9, 2);

GroupWeeklyMenuPlan _plan({
  List<WeeklyMenuPlanEntry> entries = const [],
  SharedListPermission permission = SharedListPermission.edit,
}) {
  return GroupWeeklyMenuPlan.empty(
    groupId: _groupId,
    creatorId: _alice,
    date: _week,
    initialParticipants: [
      GroupMenuParticipant(
        userId: _alice,
        permission: permission,
        addedAt: DateTime.utc(2026, 1, 1),
      ),
    ],
  ).copyWith(entries: entries);
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakePlan());
    registerFallbackValue(
      const WeeklyMenuPlanEntry(
        id: 'fallback',
        day: DayOfWeek.mon,
        slot: MealSlot.middag,
        recipeId: 'r',
        recipeTitle: 't',
      ),
    );
  });

  late _MockService service;
  late _MockRealtime realtime;
  late _MockUserService userService;
  late StreamController<GroupWeeklyMenuPlan?> stream;
  late GroupWeeklyMenuViewModel vm;

  setUp(() {
    service = _MockService();
    realtime = _MockRealtime();
    userService = _MockUserService();
    stream = StreamController<GroupWeeklyMenuPlan?>.broadcast();

    // Answers only what it is ASKED for. A stub that returns its fixtures
    // regardless makes `_resolveNames`' id set unobservable, so widening it
    // to proposers and voters could be reverted with every suite green.
    when(() => userService.getUserProfiles(any())).thenAnswer((_) async => []);
    // `undoLastRemoval` goes through the service now (BUT-1971), so the trail
    // records an undo. Mirrors the real mutator: idempotent, appends the dish.
    when(
      () => service.restoreEntry(
        plan: any(named: 'plan'),
        actorId: any(named: 'actorId'),
        entry: any(named: 'entry'),
      ),
    ).thenAnswer((invocation) {
      final plan = invocation.namedArguments[#plan] as GroupWeeklyMenuPlan;
      final restored = invocation.namedArguments[#entry] as WeeklyMenuPlanEntry;
      if (plan.entries.any((e) => e.id == restored.id)) return plan;
      return plan.copyWith(entries: [...plan.entries, restored]);
    });

    when(
      () => realtime.subscribe(
        groupId: any(named: 'groupId'),
        date: any(named: 'date'),
        onUpdate: any(named: 'onUpdate'),
        onError: any(named: 'onError'),
      ),
    ).thenAnswer((invocation) {
      final onUpdate =
          invocation.namedArguments[#onUpdate]
              as void Function(GroupWeeklyMenuPlan?);
      final onError =
          invocation.namedArguments[#onError] as void Function(Object)?;
      return stream.stream.listen(onUpdate, onError: onError);
    });

    vm = GroupWeeklyMenuViewModel(
      service: service,
      realtime: realtime,
      userService: userService,
      groupId: _groupId,
      currentUserId: _alice,
    );
  });

  tearDown(() async {
    vm.dispose();
    await stream.close();
  });

  void stubRead(GroupWeeklyMenuPlan? plan, {bool readFailed = false}) {
    when(
      () => service.readWeek(
        groupId: any(named: 'groupId'),
        date: any(named: 'date'),
      ),
    ).thenAnswer(
      (_) async => GroupWeeklyMenuPlanRead(plan: plan, readFailed: readFailed),
    );
  }

  Future<void> pump(
    WidgetTester tester, {
    VoidCallback? onStartPoll,
    double width = 375,
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = Size(width, 812);
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
            groupName: 'Torsdagsklubben',
            onStartPoll: onStartPoll,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  WeeklyMenuPlanEntry entry(
    String id, {
    MealSlot slot = MealSlot.middag,
    String title = 'Linsgryta med spetskål',
  }) => WeeklyMenuPlanEntry(
    id: id,
    day: DayOfWeek.mon,
    slot: slot,
    recipeId: 'r-$id',
    recipeTitle: title,
  );

  group('a refusal and an outage are different screens', () {
    testWidgets('a refusal offers NO retry', (tester) async {
      stubRead(_plan());
      await vm.loadWeek(_week);
      stream.addError(
        FirebaseException(plugin: 'x', code: 'permission-denied'),
      );
      await pump(tester);

      expect(
        find.text('Du har inte åtkomst till den här veckans meny.'),
        findsOne,
      );
      expect(
        find.text('Försök igen'),
        findsNothing,
        reason: 'there is nothing to retry — the refusal will not change',
      );
    });

    // The discriminating control: same widget, same delivery path, differing
    // only in which failure the viewmodel is holding. Without it the assertion
    // above would pass on a screen that never renders a retry at all.
    testWidgets('a transient outage DOES offer a retry', (tester) async {
      stubRead(null, readFailed: true);
      await vm.loadWeek(_week);
      await pump(tester);

      expect(find.text('Kunde inte läsa in veckan.'), findsOne);
      expect(find.text('Försök igen'), findsOne);
    });
  });

  // The seven-row layout is the direction Malin picked, and a dense fixed-slice
  // version of it clips SILENTLY in release — the BUT-1895/1911 bug class.
  //
  // These do NOT assert the week fits on screen: the rows live in a
  // `SingleChildScrollView`, so their height is unbounded and a too-tall week
  // scrolls instead of overflowing. Measured, it already scrolls by 210px at 2x
  // text. What they hold is that nothing overflows at these sizes — probed by
  // replacing the scroll view with `Expanded` rows, which reddens this group.
  group('no overflow at small sizes', () {
    testWidgets('320dp at 1x with two meals on one day', (tester) async {
      stubRead(
        _plan(
          entries: [
            entry('lunch', slot: MealSlot.lunch, title: 'Ugnsbakad lax'),
            entry('middag'),
          ],
        ),
      );
      await vm.loadWeek(_week);
      await pump(tester, width: 320);

      expect(tester.takeException(), isNull);
      // `takeException` alone is equally happy with an error screen.
      expect(find.text('Ugnsbakad lax'), findsOne);
    });

    testWidgets('360dp at 2x text', (tester) async {
      stubRead(_plan(entries: [entry('e1')]));
      await vm.loadWeek(_week);
      await pump(tester, width: 360, textScale: 2.0);

      expect(tester.takeException(), isNull);
      expect(find.text('Linsgryta med spetskål'), findsOne);
    });

    // The narrowest supported phone at Large text — the case that squeezes the
    // week arrows sideways rather than the day rows downwards.
    testWidgets('320dp at 2x text', (tester) async {
      stubRead(_plan(entries: [entry('e1')]));
      await vm.loadWeek(_week);
      await pump(tester, width: 320, textScale: 2.0);

      expect(tester.takeException(), isNull);
      expect(find.text('Linsgryta med spetskål'), findsOne);
    });
  });

  group('an outage and a refusal say different things', () {
    Future<void> loadAndStub(WidgetTester tester, Object saveError) async {
      final loaded = _plan(entries: [entry('e1')]);
      stubRead(loaded);
      await vm.loadWeek(_week);
      when(
        () => service.removeEntry(
          plan: any(named: 'plan'),
          actorId: any(named: 'actorId'),
          entryId: any(named: 'entryId'),
        ),
      ).thenReturn(loaded.copyWith(entries: const []));
      when(
        () => service.save(
          plan: any(named: 'plan'),
          actorId: any(named: 'actorId'),
        ),
      ).thenThrow(saveError);
      await pump(tester);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
    }

    testWidgets('a plain failure blames the save, not the person', (
      tester,
    ) async {
      await loadAndStub(tester, Exception('offline'));
      expect(find.text('Kunde inte spara ändringen. Försök igen.'), findsOne);
      // A failed REMOVAL leaves the dish on screen, so there is nothing an
      // action could recover — only a failed UNDO earns one. `commonRetry` is
      // its own widget; the sentence above merely ends with the same words.
      expect(find.text('Försök igen'), findsNothing);
    });

    // The discriminating control: same tap, same path, different exception.
    testWidgets('a refusal says you may not edit', (tester) async {
      await loadAndStub(tester, PermissionDeniedException('view only'));
      expect(
        find.text('Du kan se gruppens meny men inte ändra i den.'),
        findsOne,
      );
    });
  });

  group('a viewer', () {
    // The product bar this screen was built to: a control that can only fail
    // teaches the user that controls do nothing. It was enforced on the refusal
    // SCREEN and, until this test, not on the viewer state.
    testWidgets('is offered no delete control, and is told why', (
      tester,
    ) async {
      stubRead(
        _plan(
          entries: [entry('e1')],
          permission: SharedListPermission.view,
        ),
      );
      await vm.loadWeek(_week);
      await pump(tester);

      expect(find.text('Linsgryta med spetskål'), findsOne);
      expect(find.byIcon(Icons.close), findsNothing);
      expect(
        find.text('Du kan se gruppens meny men inte ändra i den.'),
        findsOne,
      );
    });
  });

  group('a week nobody has planned', () {
    // `plan == null` (never planned) and an empty plan (planned, then cleared)
    // are different shapes. The banner gate's `vm.plan != null` half exists for
    // the first, and only the second had a fixture.
    testWidgets('shows no viewer banner, only the poll prompt', (tester) async {
      stubRead(null);
      await vm.loadWeek(_week);
      await pump(tester, onStartPoll: () {});

      expect(find.text('Ingen rätt är framröstad än'), findsOne);
      expect(
        find.text('Du kan se gruppens meny men inte ändra i den.'),
        findsNothing,
        reason:
            'nobody may edit a week that does not exist yet, so saying so '
            'is noise, not information',
      );
    });
  });

  group('removing a dish', () {
    testWidgets('a day with two meals can remove EITHER of them', (
      tester,
    ) async {
      final loaded = _plan(
        entries: [
          entry('lunch', slot: MealSlot.lunch, title: 'Ugnsbakad lax'),
          entry('middag'),
        ],
      );
      stubRead(loaded);
      await vm.loadWeek(_week);

      when(
        () => service.removeEntry(
          plan: any(named: 'plan'),
          actorId: any(named: 'actorId'),
          entryId: any(named: 'entryId'),
        ),
      ).thenAnswer((invocation) {
        final id = invocation.namedArguments[#entryId] as String;
        return loaded.copyWith(
          entries: loaded.entries.where((e) => e.id != id).toList(),
        );
      });
      when(
        () => service.save(
          plan: any(named: 'plan'),
          actorId: any(named: 'actorId'),
        ),
      ).thenAnswer((_) async {});

      await pump(tester);

      // The SECOND dish's control. A single per-day control could only ever
      // reach the first, which left the other meal unremovable.
      final buttons = find.byIcon(Icons.close);
      expect(buttons, findsNWidgets(2));
      await tester.tap(buttons.last);
      await tester.pumpAndSettle();

      final captured = verify(
        () => service.removeEntry(
          plan: any(named: 'plan'),
          actorId: any(named: 'actorId'),
          entryId: captureAny(named: 'entryId'),
        ),
      ).captured;
      expect(captured.single, 'middag');
    });

    testWidgets('offers an undo that puts the dish back', (tester) async {
      final loaded = _plan(entries: [entry('e1')]);
      stubRead(loaded);
      await vm.loadWeek(_week);

      when(
        () => service.removeEntry(
          plan: any(named: 'plan'),
          actorId: any(named: 'actorId'),
          entryId: any(named: 'entryId'),
        ),
      ).thenReturn(loaded.copyWith(entries: const []));
      when(
        () => service.save(
          plan: any(named: 'plan'),
          actorId: any(named: 'actorId'),
        ),
      ).thenAnswer((_) async {});

      await pump(tester);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('Linsgryta med spetskål'), findsNothing);
      expect(find.text('Ångra'), findsOne);

      await tester.tap(find.text('Ångra'));
      await tester.pumpAndSettle();

      expect(find.text('Linsgryta med spetskål'), findsOne);
    });
  });

  // The dish survives a failed undo in memory, but the snackbar that offered
  // "Ångra" is gone by then. Without an action on the failure notice the user
  // has a rescued dish and no control that reaches it.
  group('a failed undo', () {
    /// Removes the only dish, then taps "Ångra". The removal's save succeeds;
    /// every later save throws [undoError] until [stopFailing] is called.
    Future<void Function()> removeThenFailUndo(
      WidgetTester tester,
      Object undoError,
    ) async {
      final loaded = _plan(entries: [entry('e1')]);
      stubRead(loaded);
      await vm.loadWeek(_week);

      when(
        () => service.removeEntry(
          plan: any(named: 'plan'),
          actorId: any(named: 'actorId'),
          entryId: any(named: 'entryId'),
        ),
      ).thenReturn(loaded.copyWith(entries: const []));

      var failing = false;
      when(
        () => service.save(
          plan: any(named: 'plan'),
          actorId: any(named: 'actorId'),
        ),
      ).thenAnswer((_) async {
        if (failing) throw undoError;
      });

      await pump(tester);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      failing = true;
      await tester.tap(find.text('Ångra'));
      await tester.pumpAndSettle();
      return () => failing = false;
    }

    testWidgets('offers a retry, and the retry puts the dish back', (
      tester,
    ) async {
      final stopFailing = await removeThenFailUndo(
        tester,
        Exception('offline'),
      );

      // Its own sentence: the save's text already ends in "Försök igen", and
      // this is the notice that puts a BUTTON with those words beside it.
      expect(find.text('Kunde inte ångra borttagningen.'), findsOne);
      expect(
        find.text('Kunde inte spara ändringen. Försök igen.'),
        findsNothing,
      );
      expect(find.text('Linsgryta med spetskål'), findsNothing);
      expect(find.text('Försök igen'), findsOne);

      stopFailing();
      await tester.tap(find.text('Försök igen'));
      await tester.pumpAndSettle();

      expect(find.text('Linsgryta med spetskål'), findsOne);
    });

    // The discriminating control: same tap, same path, different exception. A
    // refusal will not change on a second attempt, and a control that can only
    // fail is what this screen was built to avoid.
    testWidgets('a REFUSED undo offers none', (tester) async {
      await removeThenFailUndo(tester, PermissionDeniedException('view only'));

      expect(
        find.text('Du kan se gruppens meny men inte ändra i den.'),
        findsOne,
      );
      expect(find.text('Försök igen'), findsNothing);
    });
  });

  // The enum value is asserted elsewhere; the MAPPING from it to a sentence was
  // not, so the arm could be pointed at any other string silently.
  group('an undo that is no longer possible', () {
    testWidgets('says so, and offers no retry', (tester) async {
      final loaded = _plan(entries: [entry('e1')]);
      stubRead(loaded);
      await vm.loadWeek(_week);
      await pump(tester);

      // Nothing was removed, so nothing is armed.
      await vm.undoLastRemoval();
      await tester.pumpAndSettle();

      expect(find.text('Det går inte att ångra det här längre.'), findsOne);
      expect(find.text('Försök igen'), findsNothing);
    });
  });

  // BUT-1971. The row exists to answer "whose dish is this" — and to answer
  // NOTHING when the app does not know, rather than guess.
  group('the provenance row', () {
    testWidgets('names the proposer and counts the voters', (tester) async {
      // The proposer is NEITHER a participant nor a voter, so his name can
      // only appear if `_resolveNames` really widened its id set to proposers.
      // With an on-roster proposer that half is deletable-green.
      final profiles = [
        UserProfile(
          uid: 'user-dan',
          email: 'd@b.se',
          displayName: 'Dan',
          joinedAt: DateTime.utc(2026, 1, 1),
          lastActiveAt: DateTime.utc(2026, 1, 1),
        ),
      ];
      when(() => userService.getUserProfiles(any())).thenAnswer((
        invocation,
      ) async {
        final asked = invocation.positionalArguments.first as List<String>;
        return profiles.where((p) => asked.contains(p.uid)).toList();
      });
      stubRead(
        _plan(
          entries: [
            WeeklyMenuPlanEntry(
              id: 'e1',
              day: DayOfWeek.mon,
              slot: MealSlot.middag,
              recipeId: 'r1',
              recipeTitle: 'Linsgryta med spetskål',
              proposedBy: 'user-dan',
              votedInBy: const [_alice, 'user-bob', 'user-cara'],
            ),
          ],
        ),
      );
      await vm.loadWeek(_week);
      await pump(tester);

      expect(find.text('Föreslagen av Dan · framröstad av 3'), findsOne);
    });

    // The row is a tap target, so it owes the tap-target Semantics rule. The
    // label names the ACTION only: the framework CONCATENATES the child text
    // onto it, so restating the sentence would make a screen reader say it
    // twice.
    testWidgets('the row announces its action once, and is a button', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      stubRead(
        _plan(
          entries: [
            WeeklyMenuPlanEntry(
              id: 'e1',
              day: DayOfWeek.mon,
              slot: MealSlot.middag,
              recipeId: 'r1',
              recipeTitle: 'Linsgryta med spetskål',
              votedInBy: const ['user-bob'],
            ),
          ],
        ),
      );
      await vm.loadWeek(_week);
      await pump(tester);

      final node = tester.getSemantics(find.text('framröstad av 1'));
      expect(node.label, contains('Visa vilka som röstade'));
      // Count the ROW's own sentence, not the label's: the framework
      // concatenates the child text onto the label, so a label that restates
      // it makes a screen reader say it twice. Counting the label's words
      // instead would stay green under exactly that mutation.
      expect(
        'framröstad av 1'.allMatches(node.label).length,
        1,
        reason:
            'the label names the ACTION; the row text is added by the '
            'framework, so restating it announces the sentence twice',
      );
      expect(node.flagsCollection.isButton, isTrue);
      handle.dispose();
    });

    // The row is the only way to the sheet, and the sheet is what the Art. 15
    // keep decision rests on. A hit region the size of one line of `bodySmall`
    // is the same failure one layer down.
    testWidgets('the tap target meets the minimum height', (tester) async {
      stubRead(
        _plan(
          entries: [
            WeeklyMenuPlanEntry(
              id: 'e1',
              day: DayOfWeek.mon,
              slot: MealSlot.middag,
              recipeId: 'r1',
              recipeTitle: 'Linsgryta med spetskål',
              votedInBy: const ['user-bob'],
            ),
          ],
        ),
      );
      await vm.loadWeek(_week);
      await pump(tester);

      final region = tester.getRect(
        find.ancestor(
          of: find.text('framröstad av 1'),
          matching: find.byType(InkWell),
        ),
      );
      expect(region.height, greaterThanOrEqualTo(AppDimensions.minTouchTarget));
    });

    // The sheet is a separate route, so it does not repaint on the
    // viewmodel's notify unless something listens. Every other sheet test
    // resolves its names during `loadWeek`, before the tap — so without this
    // one the `ListenableBuilder` can be deleted with the group green, and a
    // name arriving late would read "Okänd medlem" for the life of the sheet.
    testWidgets('a name that resolves after the sheet opens reaches it', (
      tester,
    ) async {
      final gate = Completer<List<UserProfile>>();
      when(
        () => userService.getUserProfiles(any()),
      ).thenAnswer((_) => gate.future);
      stubRead(
        _plan(
          entries: [
            WeeklyMenuPlanEntry(
              id: 'e1',
              day: DayOfWeek.mon,
              slot: MealSlot.middag,
              recipeId: 'r1',
              recipeTitle: 'Linsgryta med spetskål',
              votedInBy: const ['user-bob'],
            ),
          ],
        ),
      );
      await vm.loadWeek(_week);
      await pump(tester);

      await tester.tap(find.text('framröstad av 1'));
      await tester.pumpAndSettle();
      expect(find.text('Okänd medlem'), findsOne);

      gate.complete([
        UserProfile(
          uid: 'user-bob',
          email: 'b@b.se',
          displayName: 'Bosse',
          joinedAt: DateTime.utc(2026, 1, 1),
          lastActiveAt: DateTime.utc(2026, 1, 1),
        ),
      ]);
      await tester.pumpAndSettle();

      expect(find.text('Bosse'), findsOne);
      expect(find.text('Okänd medlem'), findsNothing);
    });

    // A profile that resolves to a blank name must fall back the same way an
    // unresolved one does, in the row AND in the sheet.
    testWidgets('a blank display name falls back rather than rendering empty', (
      tester,
    ) async {
      when(() => userService.getUserProfiles(any())).thenAnswer(
        (_) async => [
          UserProfile(
            uid: 'user-bob',
            email: 'b@b.se',
            displayName: '   ',
            joinedAt: DateTime.utc(2026, 1, 1),
            lastActiveAt: DateTime.utc(2026, 1, 1),
          ),
        ],
      );
      stubRead(
        _plan(
          entries: [
            WeeklyMenuPlanEntry(
              id: 'e1',
              day: DayOfWeek.mon,
              slot: MealSlot.middag,
              recipeId: 'r1',
              recipeTitle: 'Linsgryta med spetskål',
              proposedBy: 'user-bob',
              votedInBy: const ['user-bob'],
            ),
          ],
        ),
      );
      await vm.loadWeek(_week);
      await pump(tester);

      // The row drops the proposer half rather than printing an empty name.
      expect(find.text('framröstad av 1'), findsOne);

      await tester.tap(find.text('framröstad av 1'));
      await tester.pumpAndSettle();
      expect(find.text('Okänd medlem'), findsOne);
    });

    // The sheet's own comment says the scroll is what stops a big group losing
    // voters off the bottom. Nothing measured that until here.
    testWidgets('a long voter list reaches its last name', (tester) async {
      final voters = List.generate(20, (i) => 'user-$i');
      when(() => userService.getUserProfiles(any())).thenAnswer((
        invocation,
      ) async {
        final asked = invocation.positionalArguments.first as List<String>;
        return [
          for (final uid in asked)
            if (uid.startsWith('user-') && uid != _alice)
              UserProfile(
                uid: uid,
                email: '$uid@b.se',
                displayName: 'Röstare ${uid.substring(5)}',
                joinedAt: DateTime.utc(2026, 1, 1),
                lastActiveAt: DateTime.utc(2026, 1, 1),
              ),
        ];
      });
      stubRead(
        _plan(
          entries: [
            WeeklyMenuPlanEntry(
              id: 'e1',
              day: DayOfWeek.mon,
              slot: MealSlot.middag,
              recipeId: 'r1',
              recipeTitle: 'Linsgryta med spetskål',
              votedInBy: voters,
            ),
          ],
        ),
      );
      await vm.loadWeek(_week);
      await pump(tester);

      await tester.tap(find.text('framröstad av 20'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // The sheet's own list, not the week's: two scrollables are in the tree
      // and `scrollUntilVisible` refuses an ambiguous one.
      await tester.scrollUntilVisible(
        find.text('Röstare 19'),
        200,
        scrollable: find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.text('Röstare 19'), findsOne);
    });

    // Malin's decision: the export ships other members' voter uids
    // on the basis that the app shows them. Until this sheet the app showed a
    // COUNT, and the justification was refuted by measurement. This test is
    // what keeps it true.
    testWidgets('tapping the row shows who voted', (tester) async {
      // Filtered by what was ASKED for: `user-bob` is a VOTER and not a
      // participant, so it only resolves if `_resolveNames` really widened its
      // id set beyond the roster. A stub that ignores its argument would let
      // that widening be reverted with every suite green.
      final profiles = [
        UserProfile(
          uid: _alice,
          email: 'a@b.se',
          displayName: 'Malin',
          joinedAt: DateTime.utc(2026, 1, 1),
          lastActiveAt: DateTime.utc(2026, 1, 1),
        ),
        UserProfile(
          uid: 'user-bob',
          email: 'b@b.se',
          displayName: 'Bosse',
          joinedAt: DateTime.utc(2026, 1, 1),
          lastActiveAt: DateTime.utc(2026, 1, 1),
        ),
      ];
      when(() => userService.getUserProfiles(any())).thenAnswer((
        invocation,
      ) async {
        final asked = invocation.positionalArguments.first as List<String>;
        return profiles.where((p) => asked.contains(p.uid)).toList();
      });
      stubRead(
        _plan(
          entries: [
            WeeklyMenuPlanEntry(
              id: 'e1',
              day: DayOfWeek.mon,
              slot: MealSlot.middag,
              recipeId: 'r1',
              recipeTitle: 'Linsgryta med spetskål',
              proposedBy: _alice,
              votedInBy: const [_alice, 'user-bob', 'user-ghost'],
            ),
          ],
        ),
      );
      await vm.loadWeek(_week);
      await pump(tester);

      await tester.tap(find.text('Föreslagen av Malin · framröstad av 3'));
      await tester.pumpAndSettle();

      expect(find.text('Röstade på den här rätten'), findsOne);
      expect(find.text('Malin'), findsOne);
      expect(find.text('Bosse'), findsOne);
      // A uid is never rendered, in the sheet either.
      expect(find.text('Okänd medlem'), findsOne);
      expect(find.textContaining('user-ghost'), findsNothing);
    });

    // The discriminating control. Every dish that predates the feature is in
    // this state, and a guessed name is worse than a missing one.
    testWidgets('draws nothing for a dish with no provenance', (tester) async {
      stubRead(_plan(entries: [entry('e1')]));
      await vm.loadWeek(_week);
      await pump(tester);

      expect(find.text('Linsgryta med spetskål'), findsOne);
      expect(find.textContaining('Föreslagen av'), findsNothing);
      expect(find.textContaining('framröstad av'), findsNothing);
    });

    // A uid is never rendered. An unresolved profile costs the half it names,
    // not the whole row — the count is still true.
    testWidgets('keeps the vote count when the name will not resolve', (
      tester,
    ) async {
      stubRead(
        _plan(
          entries: [
            WeeklyMenuPlanEntry(
              id: 'e1',
              day: DayOfWeek.mon,
              slot: MealSlot.middag,
              recipeId: 'r1',
              recipeTitle: 'Linsgryta med spetskål',
              proposedBy: 'user-ghost',
              votedInBy: const ['user-bob'],
            ),
          ],
        ),
      );
      await vm.loadWeek(_week);
      await pump(tester);

      expect(find.text('framröstad av 1'), findsOne);
      expect(find.textContaining('user-ghost'), findsNothing);
    });
  });

  group('the week', () {
    testWidgets('renders all seven days, empty ones as empty', (tester) async {
      stubRead(
        _plan(
          entries: [
            WeeklyMenuPlanEntry(
              id: 'e1',
              day: DayOfWeek.mon,
              slot: MealSlot.middag,
              recipeId: 'r1',
              recipeTitle: 'Linsgryta med spetskål',
            ),
          ],
        ),
      );
      await vm.loadWeek(_week);
      await pump(tester);

      for (final day in DayOfWeek.values) {
        expect(
          find.text(day.displayLabel.toUpperCase()),
          findsOne,
          reason: '${day.name} must have a row even with nothing in it',
        );
      }
      expect(find.text('Linsgryta med spetskål'), findsOne);
      expect(find.text('Ingen rätt vald'), findsNWidgets(6));
    });

    testWidgets('an empty week asks for a poll, not seven blank rows', (
      tester,
    ) async {
      stubRead(_plan());
      await vm.loadWeek(_week);
      var started = false;
      await pump(tester, onStartPoll: () => started = true);

      expect(find.text('Ingen rätt är framröstad än'), findsOne);
      expect(find.text('Ingen rätt vald'), findsNothing);

      await tester.tap(find.text('Starta en omröstning'));
      await tester.pumpAndSettle();
      expect(started, isTrue);
    });
  });
}
