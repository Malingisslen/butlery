/// BUT-941: IncomingShareHandler decision-logic tests.
///
/// The handler is the piece that decides WHEN a shared photo reaches the user:
/// it must auth-gate (never route an unauthenticated user into import), hold a
/// share that can't route yet, and never let share wiring break startup. Those
/// are unit-testable via the injectable seams (auth resolver, navigate, and an
/// injected share service) without a device or a widget tree.

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/bootstrap/handlers/incoming_share_handler.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/router/shared_import_route.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/services/import/incoming_share_service.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockShareService extends Mock implements IncomingShareService {}

class _FakeUser extends Fake implements User {}

void main() {
  late IncomingShareHandler handler;
  late _MockAuthRepository auth;
  late _MockShareService service;
  late List<List<String>> routed;
  late List<SharedImportRoute> routedText;

  setUp(() {
    handler = IncomingShareHandler()..reset();
    auth = _MockAuthRepository();
    service = _MockShareService();
    routed = [];
    routedText = [];
    handler.authResolver = () => auth;
    handler.navigate = (paths) {
      routed.add(paths);
      return true;
    };
    handler.navigateText = (route) {
      routedText.add(route);
      return true;
    };
    when(() => service.mediaStream).thenAnswer((_) => const Stream.empty());
    when(() => service.textStream).thenAnswer((_) => const Stream.empty());
    when(() => service.getInitialSharedImages()).thenAnswer((_) async => []);
    when(() => service.getInitialSharedText()).thenAnswer((_) async => null);
  });

  tearDown(() => handler.reset());

  test(
    'unauthenticated share is held, not routed; routes once authed',
    () async {
      when(
        () => service.getInitialSharedImages(),
      ).thenAnswer((_) async => ['/a.jpg']);
      when(() => auth.currentUser).thenReturn(null);

      await handler.initialize(service: service);
      await handler.processPendingShare();
      expect(routed, isEmpty, reason: 'must not route an unauthenticated user');

      // Auth transition: the held share now routes with its paths intact.
      when(() => auth.currentUser).thenReturn(_FakeUser());
      await handler.processPendingShare();
      expect(routed, [
        ['/a.jpg'],
      ]);

      // Drained: a subsequent call does nothing (no double-route).
      routed.clear();
      await handler.processPendingShare();
      expect(routed, isEmpty);
    },
  );

  test(
    'initialize survives a throwing service (startup never breaks)',
    () async {
      when(
        () => service.getInitialSharedImages(),
      ).thenThrow(Exception('firestore boom'));

      await handler.initialize(service: service);

      expect(handler.isInitialized, isTrue);
    },
  );

  test(
    'warm-start with no live navigator holds, then routes on drain',
    () async {
      final controller = StreamController<List<String>>();
      addTearDown(controller.close);
      when(() => service.mediaStream).thenAnswer((_) => controller.stream);
      when(() => auth.currentUser).thenReturn(_FakeUser());

      var navigatorReady = false;
      handler.navigate = (paths) {
        if (!navigatorReady) return false; // simulate no live navigator
        routed.add(paths);
        return true;
      };

      await handler.initialize(service: service);

      controller.add(['/warm.jpg']);
      await pumpEventQueue();
      expect(routed, isEmpty, reason: 'no navigator yet → held');

      navigatorReady = true;
      await handler.processPendingShare();
      expect(routed, [
        ['/warm.jpg'],
      ]);
    },
  );

  test('empty pending share is a no-op', () async {
    when(() => auth.currentUser).thenReturn(_FakeUser());
    await handler.initialize(service: service); // getInitial → []
    await handler.processPendingShare();
    expect(routed, isEmpty);
  });

  group('shared text (BUT-2241)', () {
    const link = 'https://www.ica.se/recept/pannkakor-1/';

    test('a cold-start link starts Smart import once signed in', () async {
      when(() => service.getInitialSharedText()).thenAnswer((_) async => link);
      when(() => auth.currentUser).thenReturn(null);

      await handler.initialize(service: service);
      await handler.processPendingShare();
      expect(routedText, isEmpty, reason: 'must not route a signed-out user');

      when(() => auth.currentUser).thenReturn(_FakeUser());
      await handler.processPendingShare();
      expect(routedText.single.route, Routes.smartImport);
      final args = routedText.single.arguments as SmartImportRouteArgs;
      expect(args.url, link);
      expect(args.autoStart, isTrue);

      routedText.clear();
      await handler.processPendingShare();
      expect(routedText, isEmpty, reason: 'drained, no double import');
    });

    test('a warm-start text without a link opens the text import', () async {
      final controller = StreamController<String>();
      addTearDown(controller.close);
      when(() => service.textStream).thenAnswer((_) => controller.stream);
      when(() => auth.currentUser).thenReturn(_FakeUser());

      await handler.initialize(service: service);
      controller.add('2 dl mjölk\n3 ägg');
      await pumpEventQueue();

      expect(routedText.single.route, Routes.fromSocialMedia);
      expect(routedText.single.arguments, '2 dl mjölk\n3 ägg');
      expect(routed, isEmpty, reason: 'a text share is not a photo share');
    });

    test(
      'a warm-start text with no navigator yet is held, the newest wins',
      () async {
        final controller = StreamController<String>();
        addTearDown(controller.close);
        when(() => service.textStream).thenAnswer((_) => controller.stream);
        when(() => auth.currentUser).thenReturn(_FakeUser());
        var navigatorReady = false;
        handler.navigateText = (route) {
          if (!navigatorReady) return false;
          routedText.add(route);
          return true;
        };

        await handler.initialize(service: service);
        controller
          ..add('https://first.example/r')
          ..add(link);
        await pumpEventQueue();
        expect(routedText, isEmpty);

        navigatorReady = true;
        await handler.processPendingShare();
        expect(
          (routedText.single.arguments as SmartImportRouteArgs).url,
          link,
        );
      },
    );

    test('a held text is dropped once a newer share routes', () async {
      final controller = StreamController<String>();
      addTearDown(controller.close);
      when(() => service.textStream).thenAnswer((_) => controller.stream);
      when(() => auth.currentUser).thenReturn(_FakeUser());
      var navigatorReady = false;
      handler.navigateText = (route) {
        if (!navigatorReady) return false;
        routedText.add(route);
        return true;
      };

      await handler.initialize(service: service);
      controller.add('https://first.example/r');
      await pumpEventQueue();
      navigatorReady = true;
      controller.add(link);
      await pumpEventQueue();
      await handler.processPendingShare();

      expect(
        (routedText.single.arguments as SmartImportRouteArgs).url,
        link,
        reason: 'the older share must not start a second import',
      );
    });
  });
}
