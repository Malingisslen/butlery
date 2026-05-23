/// Widget tests for FeedbackFAB.
///
/// The FAB resolves its AuthService via the production ServiceLocator at
/// `initState`. When the locator is uninitialized it returns null and the
/// FAB renders `SizedBox.shrink()`. For the authenticated path we register
/// a configured `MockAuthService` into GetIt and initialize a bare
/// DIContainer (both share the same GetIt instance).
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/feedback_fab.dart';

import '../../infrastructure/factories/mock_factory.dart';

Widget _wrap(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('sv'),
      // The FAB is a Positioned that expects an ancestor Stack.
      home: Scaffold(body: Stack(children: [child])),
    );

void _unregisterAuth() {
  final g = GetIt.instance;
  if (g.isRegistered<AuthService>()) {
    g.unregister<AuthService>();
  }
}

Future<void> _bindAuth({required bool isAuthenticated}) async {
  await GetIt.instance.reset();
  final mock = MockFactory.createAuthService(isAuthenticated: isAuthenticated);
  GetIt.instance.registerSingleton<AuthService>(mock);
  prod.ServiceLocator.initialize(DIContainer());
}

void main() {
  tearDown(() async {
    prod.ServiceLocator.reset();
    _unregisterAuth();
    await GetIt.instance.reset();
  });

  group('FeedbackFAB — unauthenticated / no service', () {
    testWidgets('renders SizedBox.shrink when ServiceLocator is uninitialized',
        (tester) async {
      // No ServiceLocator.initialize call → tryGet returns null.
      prod.ServiceLocator.reset();
      await tester.pumpWidget(_wrap(const FeedbackFAB()));

      // Nothing visible (no Positioned, no '!' Text).
      expect(find.text('!'), findsNothing);
      expect(
          find.descendant(
            of: find.byType(FeedbackFAB),
            matching: find.byType(Positioned),
          ),
          findsNothing);
    });

    testWidgets('renders nothing when AuthService.isAuthenticated is false',
        (tester) async {
      await _bindAuth(isAuthenticated: false);
      await tester.pumpWidget(_wrap(const FeedbackFAB()));
      await tester.pump();

      expect(find.text('!'), findsNothing);
      expect(
          find.descendant(
            of: find.byType(FeedbackFAB),
            matching: find.byType(GestureDetector),
          ),
          findsNothing);
    });
  });

  group('FeedbackFAB — authenticated rendering', () {
    setUp(() async {
      await _bindAuth(isAuthenticated: true);
    });

    testWidgets('renders the "!" glyph when authenticated', (tester) async {
      await tester.pumpWidget(_wrap(const FeedbackFAB()));
      await tester.pump();

      expect(
          find.descendant(
            of: find.byType(FeedbackFAB),
            matching: find.text('!'),
          ),
          findsOneWidget);
    });

    testWidgets('positions at right: 16 and bottom: feedbackFabBottomOffset',
        (tester) async {
      await tester.pumpWidget(_wrap(const FeedbackFAB()));
      await tester.pump();

      final positioned = tester.widget<Positioned>(find.descendant(
        of: find.byType(FeedbackFAB),
        matching: find.byType(Positioned),
      ));
      expect(positioned.right, 16);
      expect(positioned.bottom, AppDimensions.feedbackFabBottomOffset);
    });

    testWidgets('container is square at minTouchTarget size', (tester) async {
      await tester.pumpWidget(_wrap(const FeedbackFAB()));
      await tester.pump();

      final container = tester.widget<Container>(find.descendant(
        of: find.byType(FeedbackFAB),
        matching: find.byType(Container),
      ));
      expect(container.constraints?.maxWidth, AppDimensions.minTouchTarget);
      expect(container.constraints?.maxHeight, AppDimensions.minTouchTarget);
    });

    testWidgets('uses opaque hit-test on the GestureDetector', (tester) async {
      await tester.pumpWidget(_wrap(const FeedbackFAB()));
      await tester.pump();

      final detector = tester.widget<GestureDetector>(find.descendant(
        of: find.byType(FeedbackFAB),
        matching: find.byType(GestureDetector),
      ));
      expect(detector.behavior, HitTestBehavior.opaque);
      expect(detector.onTap, isNotNull);
    });

    testWidgets('"!" glyph color uses theme primary', (tester) async {
      await tester.pumpWidget(_wrap(const FeedbackFAB()));
      await tester.pump();

      // Resolve the theme from the live element tree so we compare against
      // whatever MaterialApp applied.
      final cs = Theme.of(tester.element(find.byType(FeedbackFAB))).colorScheme;
      final text = tester.widget<Text>(find.descendant(
        of: find.byType(FeedbackFAB),
        matching: find.text('!'),
      ));
      expect(text.style?.color, cs.primary);
      expect(text.style?.fontSize, 24);
    });

    testWidgets('wraps tap target in Semantics(label, button: true)',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(const FeedbackFAB()));
      await tester.pump();

      // Swedish label: "Skicka feedback". Use a regex-tolerant lookup
      // (semantic strings can be normalized by the engine).
      expect(
        find.bySemanticsLabel(RegExp('Skicka feedback')),
        findsAtLeastNWidgets(1),
      );
      handle.dispose();
    });
  });

  group('FeedbackFAB — auth state reactivity', () {
    testWidgets('hides itself when AuthService notifies sign-out',
        (tester) async {
      await _bindAuth(isAuthenticated: true);
      final auth = GetIt.instance<AuthService>();

      await tester.pumpWidget(_wrap(const FeedbackFAB()));
      await tester.pump();
      expect(find.text('!'), findsOneWidget);

      // Flip the mock to unauthenticated and notify. ListenableBuilder
      // should rebuild and the FAB should collapse.
      (auth as dynamic).setAuthState(isAuthenticated: false);
      (auth as dynamic).notifyListeners();
      await tester.pump();

      expect(find.text('!'), findsNothing);
    });
  });

  group('FeedbackFAB — tap handler', () {
    testWidgets(
        'tapping does not throw when appNavigatorKey is unwired '
        '(test environment)', (tester) async {
      // appNavigatorKey.currentState is null in this test (the FAB is not
      // mounted under the real app's MaterialApp(navigatorKey:)). _onTap
      // early-returns without opening the dialog — we just assert the tap
      // surface is reachable and does not crash.
      // SKIP: full dialog-opens path requires wiring appNavigatorKey to a
      // real MaterialApp instance and stubbing FeedbackService — out of
      // scope for this widget test.
      await _bindAuth(isAuthenticated: true);
      await tester.pumpWidget(_wrap(const FeedbackFAB()));
      await tester.pump();

      await tester.tap(find.descendant(
        of: find.byType(FeedbackFAB),
        matching: find.byType(GestureDetector),
      ));
      await tester.pump();

      // Still rendered, no exception bubbled up.
      expect(find.text('!'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('FeedbackFAB — global keys', () {
    test('feedbackRepaintBoundaryKey is a GlobalKey', () {
      expect(feedbackRepaintBoundaryKey, isA<GlobalKey>());
    });

    test('appNavigatorKey is a GlobalKey<NavigatorState>', () {
      expect(appNavigatorKey, isA<GlobalKey<NavigatorState>>());
    });

    testWidgets(
        'wrapping a subtree under feedbackRepaintBoundaryKey allows '
        'RenderRepaintBoundary lookup', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: RepaintBoundary(
          key: feedbackRepaintBoundaryKey,
          child: const SizedBox(width: 10, height: 10),
        ),
      ));
      final ro = feedbackRepaintBoundaryKey.currentContext?.findRenderObject();
      expect(ro, isA<RenderRepaintBoundary>());
    });
  });
}
