/// P8-U03 · flow 08, a queued recipe edit that meets a newer server version
/// (BUT-2213). The queue, the device database and the recipe module are the
/// ones flow_08_queue_harness.dart builds; the conflict goes through the real
/// RealtimeSyncService and its release gate, which reads the real queue
/// source, onto the real ConflictBanner and ConflictDiffView.
library;

// ignore_for_file: close_sinks

import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/exceptions/repository_exception.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart' as auth;
import 'package:butlery/services/offline/sync_queue_source.dart';
import 'package:butlery/services/realtime_sync_service.dart';
import 'package:butlery/widgets/realtime/conflict_banner.dart';
import 'package:clock/clock.dart';

import '../../infrastructure/di/test_service_locator.dart'
    show TestServiceLocator;
import 'flow_08_queue_harness.dart';

final _sv = AppLocalizationsSv();

class _MockAuthRepository extends Mock implements auth.AuthRepository {}

Widget _recipeScreen(String recipeId) => MaterialApp(
  locale: const Locale('sv'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: Scaffold(body: ConflictBanner(filterDocId: recipeId)),
);

void main() {
  late QueueJourney j;
  late StreamController<User?> authStates;
  late RealtimeSyncService sync;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TestServiceLocator.initialize();
    j = await QueueJourney.open();
    final syncAuth = _MockAuthRepository();
    authStates = StreamController<User?>.broadcast();
    when(() => syncAuth.currentUserId).thenReturn(QueueJourney.uid);
    when(
      () => syncAuth.authStateChanges(),
    ).thenAnswer((_) => authStates.stream);
    sync = RealtimeSyncService(
      firestoreRepository: FirestoreRepository(
        firestore: FakeFirebaseFirestore(),
      ),
      authRepository: syncAuth,
      // As collaboration_module wires it.
      queueSettled: () => SyncQueueSource.resolve().watchSettled(),
      writeOwnRecipe: (recipe) async {
        await j.recipes.updatePersonalRecipe(recipe);
      },
    );
    // As offline_service wires it.
    j.onRecipeConflict = sync.announceQueuedRecipeConflict;
    final container = DIContainer();
    await container.reset();
    container.registerModule(
      JourneyDiModule(
        JourneyAuthService(),
        JourneyProfileViewModel(),
        j.offline,
      ),
    );
    await container.initialize();
    container.container.registerSingleton<RealtimeSyncService>(sync);
    ServiceLocator.initialize(container);
    SyncQueueSource.debugOverride = OfflineSyncQueueSource(
      offlineService: j.offline,
      authRepository: j.auth,
    );
  });

  tearDown(() async {
    SyncQueueSource.debugOverride = null;
    await sync.dispose();
    await authStates.close();
    await j.close();
    await DIContainer().reset();
    await TestServiceLocator.reset();
  });

  Future<T> real<T>(WidgetTester tester, Future<T> Function() body) async =>
      (await tester.runAsync(body)) as T;

  Future<void> settleUi(WidgetTester tester) =>
      withClock(Clock.fixed(QueueJourney.t0), () async {
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 20));
        await tester.pump(const Duration(milliseconds: 20));
      });

  /// Pumps the app, and lets real I/O turn, until [done].
  Future<void> until(WidgetTester tester, bool Function() done) async {
    for (var turn = 0; !done(); turn++) {
      expect(turn, lessThan(500), reason: 'it never happened');
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await settleUi(tester);
    }
    await settleUi(tester);
  }

  /// The connection returns and the queue sends what is due.
  Future<void> reconnect(WidgetTester tester) async {
    var done = false;
    unawaited(
      withClock(
        Clock.fixed(QueueJourney.t0),
        j.offline.reconnect,
      ).whenComplete(() => done = true),
    );
    await until(tester, () => done);
  }

  group('TR::FLOW::08::ko::toms::konfliktbanner', () {
    testWidgets('a queued recipe edit that meets a newer server version '
        'shows the conflict banner when the queue empties, and Behåll min '
        'sends mine', (tester) async {
      final id = await real(tester, () => j.write('Linsgryta'));
      final created = j.lastCreated!;
      await reconnect(tester);
      expect(j.writer.ops, ['create:$id']);
      j.offline.goOffline();

      // Offline, the user edits; meanwhile their other device saved the
      // recipe, so the server is on a newer version.
      await real(
        tester,
        () => j.recipes.updatePersonalRecipe(
          created.copyWith(title: 'Linsgryta med spenat'),
        ),
      );
      final onServer = created.copyWith(title: 'Från min andra enhet', rev: 3);
      j.writer.failWith[id] = RecipeRevisionConflictException(onServer);
      await withClock(
        Clock.fixed(QueueJourney.t0),
        () => tester.pumpWidget(_recipeScreen(id)),
      );
      await settleUi(tester);
      expect(find.text(_sv.conflictBannerTitleRecipe), findsNothing);

      await reconnect(tester);
      await until(
        tester,
        () => tester.any(find.text(_sv.conflictBannerTitleRecipe)),
      );

      expect(await real(tester, j.queued), isEmpty);
      expect(find.text('Två versioner av receptet'), findsOneWidget);
      expect(find.text(_sv.conflictBannerBodyOtherDevice), findsOneWidget);
      expect(j.writer.ops, ['create:$id'], reason: 'mine was not written');

      j.writer.failWith.remove(id);
      await tester.tap(find.text(_sv.commonView));
      await settleUi(tester);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text(_sv.conflictDiffKeepMine));
      await until(tester, () => j.writer.writes.length == 2);

      final sent = j.writer.writes.last;
      expect(sent.$1, 'update');
      expect(sent.$2!.title, 'Linsgryta med spenat');
      expect(sent.$2!.rev, 3, reason: "built on the server's version");
      await until(
        tester,
        () => !tester.any(find.text(_sv.conflictBannerTitleRecipe)),
      );
      expect(await real(tester, j.queued), isEmpty);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 8));
    });
  });
}
