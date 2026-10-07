/// P8-U03 · flow 08, the offline queue as a user meets it (BUT-2162).
///
/// Every journey starts at the write a screen makes: `PersonalRecipeModule`
/// (create, update, delete) or `OfflineService.queueRecipeImage`, over a real
/// database, user storage and sync manager (flow_08_queue_harness.dart). What
/// the user sees is the real top bar counter, "Väntar på synk" and the
/// sign-out dialog, reading that database through the real queue source.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/services/auth/sign_out_guard.dart';
import 'package:butlery/services/offline/sync_queue_source.dart';
import 'package:butlery/views/sync/sync_queue_view.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/widgets/common/profile/handlers/auth_action_handler.dart';
import 'package:butlery/widgets/common/sync/sync_queue_indicator.dart';
import 'package:clock/clock.dart';

import '../../infrastructure/di/test_service_locator.dart'
    show TestServiceLocator;
import '../../unit/services/offline/queue_harness.dart' show firestoreError;
import 'flow_08_queue_harness.dart';

final _sv = AppLocalizationsSv();

Widget _app() => MaterialApp(
  locale: const Locale('sv'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  routes: {
    Routes.syncQueue: (_) => const SyncQueueView(),
    Routes.auth: (_) => const Scaffold(body: Text('sign-in screen')),
  },
  home: Scaffold(
    appBar: const ButleryTopBar.rot(title: 'Hem'),
    body: Builder(
      builder: (context) => TextButton(
        onPressed: () => AuthActionHandler.handleLogout(context),
        child: const Text('Logga ut'),
      ),
    ),
  ),
);

void main() {
  late QueueJourney j;
  late JourneyAuthService auth;
  late JourneyProfileViewModel profile;
  late SignOutGuard Function() originalGuard;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TestServiceLocator.initialize();
    j = await QueueJourney.open();
    auth = JourneyAuthService();
    profile = JourneyProfileViewModel();
    final container = DIContainer();
    await container.reset();
    container.registerModule(JourneyDiModule(auth, profile, j.offline));
    await container.initialize();
    ServiceLocator.initialize(container);
    SyncQueueSource.debugOverride = OfflineSyncQueueSource(
      offlineService: j.offline,
      authRepository: j.auth,
    );
    originalGuard = AuthActionHandler.guardFactory;
    AuthActionHandler.guardFactory = () => SignOutGuard(authService: auth);
  });

  tearDown(() async {
    AuthActionHandler.guardFactory = originalGuard;
    SyncQueueSource.debugOverride = null;
    await j.close();
    await DIContainer().reset();
    await TestServiceLocator.reset();
  });

  Future<T> real<T>(WidgetTester tester, Future<T> Function() body) async =>
      (await tester.runAsync(body)) as T;

  /// The app at [at], with the database streams delivered.
  Future<void> pumpApp(WidgetTester tester, {DateTime? at}) async {
    await withClock(Clock.fixed(at ?? QueueJourney.t0), () async {
      await tester.pumpWidget(_app());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
    });
  }

  Future<void> settleUi(WidgetTester tester, {DateTime? at}) =>
      withClock(Clock.fixed(at ?? QueueJourney.t0), () async {
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 20));
        await tester.pump(const Duration(milliseconds: 20));
      });

  Future<void> openQueue(WidgetTester tester, {DateTime? at}) async {
    await withClock(Clock.fixed(at ?? QueueJourney.t0), () async {
      unawaited(
        Navigator.of(
          tester.element(find.text('Logga ut')),
        ).pushNamed(Routes.syncQueue),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 20));
    });
  }

  /// Pumps the app, and lets real I/O turn, until [done]. The database
  /// serves the screen's live queries from this zone's clock, so a queue
  /// pass or a tap that reads it needs a pump to finish.
  Future<void> until(
    WidgetTester tester,
    bool Function() done, {
    DateTime? at,
  }) async {
    for (var turn = 0; !done(); turn++) {
      expect(turn, lessThan(500), reason: 'it never happened');
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await settleUi(tester, at: at);
    }
    await settleUi(tester, at: at);
  }

  /// The connection returns at [at] and the queue sends what is due.
  Future<void> reconnectAt(WidgetTester tester, DateTime at) async {
    var done = false;
    unawaited(
      withClock(Clock.fixed(at), j.offline.reconnect).whenComplete(
        () => done = true,
      ),
    );
    await until(tester, () => done, at: at);
  }

  Future<void> closeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  group('TR::FLOW::08::skrivning::koas', () {
    testWidgets('a recipe created, edited and deleted offline stays on the '
        'phone, is queued in order and is not sent', (tester) async {
      final stored = await real(tester, () async {
        final keptId = await j.write('Linsgryta');
        final kept = j.lastCreated!;
        final goneId = await j.write('Fiskpinnar');
        await j.recipes.updatePersonalRecipe(
          kept.copyWith(title: 'Linsgryta med spenat'),
        );
        await j.recipes.deletePersonalRecipe(goneId);
        return (
          keptId: keptId,
          goneId: goneId,
          rows: await j.queued(),
          unsent: await j.offline.hasUnsentRecipeWrite(
            keptId,
            QueueJourney.uid,
          ),
          counts: await j.offline.database
              .watchQueueCounts(QueueJourney.uid)
              .first,
          onPhone: await j.db.recipeDao.getRecipe(keptId, QueueJourney.uid),
          deletedFromPhone: await j.db.recipeDao.getRecipe(
            goneId,
            QueueJourney.uid,
          ),
        );
      });

      expect(j.errors, isEmpty);
      expect(
        stored.rows.map((r) => '${r.operation}:${r.recipeId}'),
        [
          'create:${stored.keptId}',
          'create:${stored.goneId}',
          'update:${stored.keptId}',
          'delete:${stored.goneId}',
        ],
        reason: 'one entry per write, in the order the user made them',
      );
      expect(stored.counts.waiting, 4);
      expect(stored.unsent, isTrue);
      expect(
        stored.onPhone,
        isNotNull,
        reason: 'the edit is kept on the phone',
      );
      expect(stored.deletedFromPhone, isNull);
      expect(j.writer.writes, isEmpty, reason: 'offline: nothing is sent');
    });
  });

  group('TR::FLOW::08::kovy::vantar-pa-synk', () {
    testWidgets('"Väntar på synk" lists what the user wrote offline, with '
        'count, what and age, and is empty once it is sent', (tester) async {
      await real(tester, () async {
        await j.write('Linsgryta');
        await j.write(
          'Fiskpinnar',
          at: QueueJourney.t0.add(const Duration(minutes: 1)),
        );
      });
      final later = QueueJourney.t0.add(const Duration(minutes: 5));
      await pumpApp(tester, at: later);
      await openQueue(tester, at: later);

      expect(find.text(_sv.syncQueueTitle), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(SyncQueueView.countKey)).data,
        '2',
      );
      expect(find.text(_sv.syncQueueQueuedHeader(2).toUpperCase()), findsOne);
      expect(find.text(_sv.syncQueueRecipeCreated('Linsgryta')), findsOne);
      expect(find.text(_sv.syncQueueRecipeCreated('Fiskpinnar')), findsOne);
      expect(find.text(_sv.syncQueueAgeMinutes(5)), findsOneWidget);
      expect(find.text(_sv.syncQueueAgeMinutes(4)), findsOneWidget);

      await reconnectAt(tester, later);
      await settleUi(tester, at: later);
      await settleUi(tester, at: later);

      expect(find.byKey(SyncQueueView.emptyKey), findsOneWidget);
      expect(find.text(_sv.syncQueueEmpty), findsOneWidget);
      expect(j.writer.writes, hasLength(2));
      await closeApp(tester);
    });
  });

  group('TR::FLOW::08::ko::koindikator-i-toppfaltet', () {
    testWidgets('the counter stays away while the queue drains by itself, '
        'shows when a write is refused, and goes when the user has dealt '
        'with it', (tester) async {
      final id = await real(tester, () => j.write('Linsgryta'));
      final counts = OfflineSyncQueueSource(
        offlineService: j.offline,
        authRepository: j.auth,
      ).watchCounts();
      expect((await real(tester, () => counts.first)).waiting, 1);
      await pumpApp(tester);

      expect(find.byKey(SyncQueueIndicator.buttonKey), findsNothing);

      j.writer.failWith[id] = firestoreError('permission-denied');
      await reconnectAt(tester, QueueJourney.t0);

      final counter = find.byKey(SyncQueueIndicator.buttonKey);
      expect(counter, findsOneWidget);
      expect(
        find.descendant(of: counter, matching: find.text('1')),
        findsOneWidget,
      );

      await tester.tap(counter);
      await until(tester, () => tester.any(find.text(_sv.syncQueueTitle)));
      await tester.tap(find.text(_sv.syncQueueSaveAsCopy));
      await until(tester, () => j.writer.writes.isNotEmpty);
      await until(tester, () => tester.any(find.byKey(SyncQueueView.emptyKey)));

      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await settleUi(tester);
      await settleUi(tester);
      expect(find.byKey(SyncQueueIndicator.buttonKey), findsNothing);
      await closeApp(tester);
    });
  });

  group('TR::FLOW::08::ko::omforsok-backoff', () {
    testWidgets('a write the network drops is tried again on the schedule, '
        'not before; the screen says when', (tester) async {
      final id = await real(tester, () => j.write('Linsgryta'));
      j.writer.failWith[id] = firestoreError('unavailable');
      await pumpApp(tester);
      await openQueue(tester);

      await reconnectAt(tester, QueueJourney.t0);
      expect(find.text(_sv.syncQueueNextAttemptSeconds(2)), findsOneWidget);

      // The network flaps: a reconnect pass before the time sends nothing.
      j.writer.failWith.remove(id);
      await reconnectAt(
        tester,
        QueueJourney.t0.add(const Duration(seconds: 1)),
      );
      expect(j.writer.writes, isEmpty);
      expect(find.byKey(SyncQueueView.countKey), findsOneWidget);

      // At its time it is sent; this one fails again and the next step is 4 s.
      j.writer.failWith[id] = firestoreError('deadline-exceeded');
      final second = QueueJourney.t0.add(const Duration(seconds: 3));
      await reconnectAt(tester, second);
      expect(find.text(_sv.syncQueueNextAttemptSeconds(4)), findsOneWidget);
      expect(j.writer.writes, isEmpty);

      j.writer.failWith.remove(id);
      await reconnectAt(tester, second.add(const Duration(seconds: 4)));
      expect(j.writer.ops, ['create:$id']);
      expect(find.byKey(SyncQueueView.emptyKey), findsOneWidget);
      await closeApp(tester);
    });
  });

  group('TR::FLOW::08::ko::permanent-fel', () {
    testWidgets('a refused write waits for the user with its cause, is not '
        'sent again by itself, and "Spara som kopia" saves it as a new '
        'recipe', (tester) async {
      final id = await real(tester, () => j.write('Linsgryta'));
      j.writer.failWith[id] = firestoreError('permission-denied');
      await pumpApp(tester);
      await openQueue(tester);

      await reconnectAt(tester, QueueJourney.t0);

      expect(
        find.text(_sv.syncQueueNeedsYouHeader(1).toUpperCase()),
        findsOneWidget,
      );
      expect(find.text(_sv.syncQueueReasonPermission), findsOneWidget);
      expect(find.text(_sv.syncQueueSaveAsCopy), findsOneWidget);
      expect((await real(tester, j.queued)).single.failed, isTrue);

      // Never again by itself, whatever the clock and the network do.
      j.writer.failWith.remove(id);
      await reconnectAt(tester, QueueJourney.t0.add(const Duration(hours: 1)));
      expect(j.writer.writes, isEmpty);
      expect(find.text(_sv.syncQueueReasonPermission), findsOneWidget);

      await tester.tap(find.text(_sv.syncQueueSaveAsCopy));
      await until(tester, () => j.writer.writes.isNotEmpty);
      await until(tester, () => tester.any(find.byKey(SyncQueueView.emptyKey)));

      final sent = j.writer.writes.single;
      expect(sent.$1, 'create');
      expect(sent.$3, isNot(id), reason: 'a new recipe, not the refused one');
      expect(sent.$2!.title, 'Linsgryta (kopia)');
      expect(await real(tester, j.queued), isEmpty);
      await closeApp(tester);
    });
  });

  group('TR::FLOW::08::ko::beroendekedja-misslyckas', () {
    testWidgets('when the recipe is refused for good, its later edit and its '
        'image fail with it and are never sent', (tester) async {
      final id = await real(tester, () async {
        final id = await j.write('Linsgryta');
        await j.recipes.updatePersonalRecipe(
          j.lastCreated!.copyWith(title: 'Linsgryta med spenat'),
        );
        final picked = j.pickedImage('flow08-chain');
        addTearDown(() {
          if (picked.existsSync()) picked.deleteSync();
        });
        await j.offline.queueRecipeImage(picked.path, id, QueueJourney.uid);
        return id;
      });
      j.writer.failWith[id] = firestoreError('permission-denied');
      await pumpApp(tester);
      await openQueue(tester);

      await reconnectAt(tester, QueueJourney.t0);

      expect(
        find.text(_sv.syncQueueNeedsYouHeader(3).toUpperCase()),
        findsOneWidget,
        reason: 'the whole chain, not the first link only',
      );
      expect(find.text(_sv.syncQueueReasonPermission), findsOneWidget);
      expect(find.text(_sv.syncQueueReasonDependency), findsNWidgets(2));
      expect(
        find.text(_sv.syncQueueQueuedHeader(0).toUpperCase()),
        findsNothing,
      );
      expect(j.writer.writes, isEmpty);
      expect(j.uploaded, isEmpty);
      await closeApp(tester);
    });
  });

  group('TR::FLOW::08::utloggning-med-ko::blockeras', () {
    testWidgets('signing out with writes in the queue is blocked and says '
        'what is lost; once the queue is sent it asks the ordinary '
        'question', (tester) async {
      await real(tester, () async {
        final id = await j.write('Linsgryta');
        final picked = j.pickedImage('flow08-signout');
        addTearDown(() {
          if (picked.existsSync()) picked.deleteSync();
        });
        await j.offline.queueRecipeImage(picked.path, id, QueueJourney.uid);
      });
      await pumpApp(tester);

      await tester.tap(find.text('Logga ut'));
      await until(
        tester,
        () => tester.any(find.byKey(const ValueKey('signOut.pendingChanges'))),
      );

      expect(find.text(_sv.signOutPendingTitle(2)), findsOneWidget);
      expect(find.text(_sv.signOutPendingRecipes(1)), findsOneWidget);
      expect(find.text(_sv.signOutPendingImages(1)), findsOneWidget);
      await tester.tap(find.text(_sv.signOutPendingWait));
      await settleUi(tester);
      await settleUi(tester);
      expect(profile.logouts, 0);
      expect((await real(tester, j.queued)), hasLength(1));

      await reconnectAt(tester, QueueJourney.t0);
      await tester.tap(find.text('Logga ut'));
      await until(tester, () => tester.any(find.byType(AlertDialog)));
      expect(
        find.byKey(const ValueKey('signOut.pendingChanges')),
        findsNothing,
      );
      await closeApp(tester);
    });
  });
}
