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
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/feedback_fab.dart';

import '../../infrastructure/factories/mock_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart' show MockAuthService;

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('sv'),
  // The FAB is a Positioned that expects an ancestor Stack.
  home: Scaffold(body: Stack(children: [child])),
);

/// Mirrors the real mount point: `butlery_app.dart` builds the FAB into a
/// `Stack` beside the whole navigator subtree, inside the `MaterialApp`
/// builder. `_wrap` above is deliberately thinner and does NOT reproduce
/// BUT-1837.
Widget _appLike(Widget page) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('sv'),
  home: page,
  builder: (context, child) => SafeArea(
    top: false,
    child: Stack(
      children: [
        RepaintBoundary(key: feedbackRepaintBoundaryKey, child: child!),
        const FeedbackFAB(),
      ],
    ),
  ),
);

SemanticsNode _rootNode(WidgetTester tester) {
  var node = tester.getSemantics(find.byType(FeedbackFAB));
  while (node.parent != null) {
    node = node.parent!;
  }
  return node;
}

/// [root] and every node below it, root first.
List<SemanticsNode> _allNodes(SemanticsNode root) {
  final out = <SemanticsNode>[root];
  root.visitChildren((child) {
    out.addAll(_allNodes(child));
    return true;
  });
  return out;
}

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
    testWidgets(
      'renders SizedBox.shrink when ServiceLocator is uninitialized',
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
          findsNothing,
        );
      },
    );

    testWidgets('renders nothing when AuthService.isAuthenticated is false', (
      tester,
    ) async {
      await _bindAuth(isAuthenticated: false);
      await tester.pumpWidget(_wrap(const FeedbackFAB()));
      await tester.pump();

      expect(find.text('!'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(FeedbackFAB),
          matching: find.byType(GestureDetector),
        ),
        findsNothing,
      );
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
        findsOneWidget,
      );
    });

    testWidgets('positions at right: 16 and bottom: feedbackFabBottomOffset', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const FeedbackFAB()));
      await tester.pump();

      final positioned = tester.widget<Positioned>(
        find.descendant(
          of: find.byType(FeedbackFAB),
          matching: find.byType(Positioned),
        ),
      );
      expect(positioned.right, 16);
      expect(positioned.bottom, AppDimensions.feedbackFabBottomOffset);
    });

    testWidgets('can be dragged off content and snaps to the nearest edge', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const FeedbackFAB()));
      await tester.pump();

      final before = tester.getTopLeft(find.text('!'));
      await tester.drag(find.text('!'), const Offset(-500, -120));
      await tester.pumpAndSettle();

      final after = tester.getTopLeft(find.text('!'));
      expect(after.dx, lessThan(before.dx - 200));
      expect(after.dy, lessThan(before.dy));
      expect(after.dx, lessThan(AppDimensions.minTouchTarget + 32));
    });

    testWidgets('stays inside the screen however far it is dragged', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const FeedbackFAB()));
      await tester.pump();

      await tester.drag(find.text('!'), const Offset(-3000, -3000));
      await tester.pumpAndSettle();

      final screen = tester.getRect(find.byType(Scaffold));
      final rect = tester.getRect(find.byType(InkWell));
      expect(screen.contains(rect.topLeft), isTrue);
      expect(screen.contains(rect.bottomRight - const Offset(1, 1)), isTrue);
    });

    testWidgets('snaps back to the right edge when dropped on the right half', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const FeedbackFAB()));
      await tester.pump();

      final before = tester.getTopLeft(find.byType(InkWell));
      await tester.drag(find.text('!'), const Offset(-60, -120));
      await tester.pumpAndSettle();

      final after = tester.getTopLeft(find.byType(InkWell));
      expect(after.dx, before.dx);
      expect(after.dy, lessThan(before.dy));
    });

    testWidgets('the tap surface is square at minTouchTarget size', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const FeedbackFAB()));
      await tester.pump();

      final size = tester.getSize(
        find.descendant(
          of: find.byType(FeedbackFAB),
          matching: find.byType(InkWell),
        ),
      );
      expect(size, const Size.square(AppDimensions.minTouchTarget));
    });

    testWidgets('the tap surface has a handler', (tester) async {
      await tester.pumpWidget(_wrap(const FeedbackFAB()));
      await tester.pump();

      final ink = tester.widget<InkWell>(
        find.descendant(
          of: find.byType(FeedbackFAB),
          matching: find.byType(InkWell),
        ),
      );
      expect(ink.onTap, isNotNull);
    });

    testWidgets('"!" glyph color is text.primary (onSurface)', (tester) async {
      await tester.pumpWidget(_wrap(const FeedbackFAB()));
      await tester.pump();

      // Resolve the theme from the live element tree so we compare against
      // whatever MaterialApp applied.
      final cs = Theme.of(tester.element(find.byType(FeedbackFAB))).colorScheme;
      final text = tester.widget<Text>(
        find.descendant(
          of: find.byType(FeedbackFAB),
          matching: find.text('!'),
        ),
      );
      // text.primary on the page; primary is ink in both modes (P4-T7).
      expect(text.style?.color, cs.onSurface);
      // The title role, 22/700 (tokens.json typography.roles.title).
      expect(text.style?.fontSize, AppTextStyles.headlineSmall.fontSize);
    });

    testWidgets('exposes a semantics node labelled "Skicka feedback"', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(_wrap(const FeedbackFAB()));
        await tester.pump();

        // Swedish label: "Skicka feedback". Use a regex-tolerant lookup
        // (semantic strings can be normalized by the engine).
        expect(
          find.bySemanticsLabel(RegExp('Skicka feedback')),
          findsAtLeastNWidgets(1),
        );
      } finally {
        handle.dispose();
      }
    });
  });

  group('FeedbackFAB — auth state reactivity', () {
    testWidgets('hides itself when AuthService notifies sign-out', (
      tester,
    ) async {
      await _bindAuth(isAuthenticated: true);
      final auth = GetIt.instance<AuthService>() as MockAuthService;

      await tester.pumpWidget(_wrap(const FeedbackFAB()));
      await tester.pump();
      expect(find.text('!'), findsOneWidget);

      // Flip the mock to unauthenticated and notify. ListenableBuilder
      // should rebuild and the FAB should collapse.
      auth.setAuthState(isAuthenticated: false);
      auth.notifyListeners();
      await tester.pump();

      expect(find.text('!'), findsNothing);
    });
  });

  group('FeedbackFAB — tap handler', () {
    testWidgets('tapping does not throw when appNavigatorKey is unwired '
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

      await tester.tap(
        find.descendant(
          of: find.byType(FeedbackFAB),
          matching: find.byType(InkWell),
        ),
      );
      await tester.pump();

      // Still rendered, no exception bubbled up.
      expect(find.text('!'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('FeedbackFAB — semantics node boundary (BUT-1837)', () {
    /// The page the FAB shares its `Stack` with.
    Widget page() => Scaffold(
      body: Column(
        children: [
          TextButton(onPressed: () {}, child: const Text('Spara recept')),
          const TextField(),
        ],
      ),
    );

    setUp(() async {
      await _bindAuth(isAuthenticated: true);
    });

    testWidgets('the node carrying the feedback label is the button, not the '
        'screen', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(_appLike(page()));
        await tester.pump();

        final root = _rootNode(tester);
        final labelled = _allNodes(
          root,
        ).where((n) => n.label.contains('Skicka feedback')).toList();

        expect(labelled, hasLength(1));
        // The measured symptom: this rect used to be the whole viewport.
        expect(labelled.single.rect.width, AppDimensions.minTouchTarget);
        expect(labelled.single.rect.height, AppDimensions.minTouchTarget);
        expect(labelled.single.rect.width, lessThan(root.rect.width));
      } finally {
        handle.dispose();
      }
    });

    testWidgets('the feedback node adopts no other control on the screen', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(_appLike(page()));
        await tester.pump();

        final root = _rootNode(tester);
        final feedback = _allNodes(
          root,
        ).firstWhere((n) => n.label.contains('Skicka feedback'));

        // The page's button must be reachable WITHOUT descending through the
        // FAB. Nesting is what let a tap anywhere reach the feedback handler.
        final underneath = _allNodes(feedback);
        expect(
          underneath.any((n) => n.label.contains('Spara recept')),
          isFalse,
          reason: 'the page is nested inside the feedback FAB node',
        );
        expect(
          _allNodes(root).any((n) => n.label.contains('Spara recept')),
          isTrue,
          reason: 'guards the assertion above from passing vacuously',
        );
      } finally {
        handle.dispose();
      }
    });
  });

  group('FeedbackFAB — text style at the app mount point', () {
    setUp(() async {
      await _bindAuth(isAuthenticated: true);
    });

    testWidgets('the "!" draws without the fallback underline', (
      tester,
    ) async {
      await tester.pumpWidget(_appLike(const Scaffold(body: SizedBox())));
      await tester.pump();

      final glyph = tester.widget<RichText>(
        find.descendant(
          of: find.byType(FeedbackFAB),
          matching: find.byType(RichText),
        ),
      );
      final decoration = glyph.text.style?.decoration;
      expect(
        decoration == null || decoration == TextDecoration.none,
        isTrue,
        reason: 'got $decoration',
      );
    });
  });

  group('FeedbackFAB — steps aside for a snackbar', () {
    late BuildContext pageContext;

    /// Mounted as `butlery_app.dart` does: the messenger and the FAB share a
    /// `Stack` in the `MaterialApp` builder, above the navigator.
    Widget app() => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('sv'),
      home: Scaffold(
        body: Builder(
          builder: (context) {
            pageContext = context;
            return const SizedBox();
          },
        ),
      ),
      builder: (context, child) => FeedbackAwareScaffoldMessenger(
        child: Stack(children: [child!, const FeedbackFAB()]),
      ),
    );

    ScaffoldFeatureController<SnackBar, SnackBarClosedReason> show(
      String text,
    ) => ScaffoldMessenger.of(
      pageContext,
    ).showSnackBar(SnackBar(content: Text(text)));

    setUp(() async {
      await _bindAuth(isAuthenticated: true);
    });

    testWidgets('the "!" hides while a snackbar is up and returns when it is '
        'hidden', (tester) async {
      await tester.pumpWidget(app());
      await tester.pump();
      expect(find.text('!'), findsOneWidget);

      show('Sparat');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));
      expect(find.text('Sparat'), findsOneWidget);
      expect(find.text('!'), findsNothing);

      ScaffoldMessenger.of(pageContext).hideCurrentSnackBar();
      await tester.pumpAndSettle();
      expect(find.text('Sparat'), findsNothing);
      expect(find.text('!'), findsOneWidget);
    });

    testWidgets('the "!" returns when the snackbar times out', (tester) async {
      await tester.pumpWidget(app());
      show('Sparat');
      await tester.pump();
      expect(find.text('!'), findsNothing);

      // Slide in, then outlast the display duration, then slide out.
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();

      expect(find.text('!'), findsOneWidget);
    });

    testWidgets('the "!" stays hidden until every queued snackbar is gone', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      show('Första');
      show('Andra');
      await tester.pump();

      ScaffoldMessenger.of(pageContext).hideCurrentSnackBar();
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.text('Andra'), findsOneWidget);
      expect(find.text('!'), findsNothing);

      ScaffoldMessenger.of(pageContext).hideCurrentSnackBar();
      await tester.pumpAndSettle();
      expect(find.text('!'), findsOneWidget);
    });

    testWidgets('the "!" returns after clearSnackBars drops a queue', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      show('Första');
      show('Andra');
      show('Tredje');
      await tester.pump();
      expect(find.text('!'), findsNothing);

      ScaffoldMessenger.of(pageContext).clearSnackBars();
      await tester.pumpAndSettle();

      expect(find.text('Andra'), findsNothing);
      expect(find.text('!'), findsOneWidget);
    });
  });
}
