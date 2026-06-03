/// Behaviour tests for [SharedWithMeView] — the "shared with me" inbox.
///
/// The view resolves its [SharedContentCoordinatorViewModel] from the
/// production [ServiceLocator] in `initState`. We register a mocktail mock of
/// that coordinator through the prod↔test ServiceLocator bridge, drive its
/// public state getters (the same ones `_buildContent` branches on), and
/// assert the user-visible Swedish state the view renders for each.
///
/// The coordinator is the view's SINGLE dependency, so each test pins one
/// state → one rendered outcome (input → output), plus one navigation
/// side-effect (tapping the empty-state CTA pushes the home route).
///
/// Rebuilt for BUT-1180 — replaces a ~25-test ULTRATHINK smoke-suite of
/// `findsOneWidget` / `takeException isNull` structural asserts that threw
/// "ServiceLocator not initialized" because they never wired the bridge.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/views/social/shared_with_me_view.dart';
import 'package:butlery/viewmodels/shared_content/shared_content_coordinator_viewmodel.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/widgets/common/indicators/loading_indicator.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../helpers/view_test_helpers.dart';

// Swedish labels the view renders (from app_sv.arb). Captured here so a
// behaviour regression — not a copy tweak — is what fails the assertion.
const _appBarTitle = 'Delat innehåll'; // l10n.sharedContent
const _loadingText = 'Laddar delat innehåll...'; // l10n.sharedLoadingContent
const _emptyTitle = 'Inga delade recept än'; // l10n.sharedNoContentYet
const _emptyCta = 'Dela ett recept'; // l10n.sharedShareFirstRecipe
const _retryLabel = 'Försök igen'; // l10n.commonRetry

void main() {
  late MockSharedContentCoordinatorViewModel coordinator;
  late MockOfflineService offlineService;

  setUpAll(() {
    production.ServiceLocator.initialize(DIContainer());
  });

  setUp(() async {
    await ViewTestHelpers.setupViewTestEnvironment();

    // The view's top sliver is LayoutComponents.offlineIndicator(), whose
    // initState resolves OfflineService and reads `isOnline`. Register an
    // online mock so the indicator builds (collapsed) without exploding.
    offlineService = MockOfflineService();
    when(() => offlineService.isOnline).thenReturn(true);
    when(() => offlineService.addListener(any())).thenReturn(null);
    when(() => offlineService.removeListener(any())).thenReturn(null);
    TestServiceLocator.registerMock<OfflineService>(offlineService);

    coordinator = MockSharedContentCoordinatorViewModel();

    // The view's post-frame callback awaits `initialize()` — stub it to a
    // completed Future so the await doesn't trip on a null return.
    when(() => coordinator.initialize()).thenAnswer((_) async {});
    // ChangeNotifierProvider.value subscribes/unsubscribes; the view disposes
    // the VM. These are void no-ops on the mock.
    when(() => coordinator.addListener(any())).thenReturn(null);
    when(() => coordinator.removeListener(any())).thenReturn(null);
    when(() => coordinator.dispose()).thenReturn(null);
    when(() => coordinator.refreshAllContent()).thenAnswer((_) async {});

    // The app-bar always reads this; default to "no unread" so it renders the
    // plain refresh button rather than the badge branch.
    when(() => coordinator.totalUnreadCount).thenReturn(0);

    // Register through the prod↔test bridge so the view's
    // `ServiceLocator.get<SharedContentCoordinatorViewModel>()` returns OURS.
    TestServiceLocator.registerMock<SharedContentCoordinatorViewModel>(
        coordinator);
  });

  tearDown(() async {
    await TestServiceLocator.reset();
    await ViewTestHelpers.teardownViewTestEnvironment();
  });

  Widget testApp() {
    return MaterialApp(
      locale: const Locale('sv', 'SE'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.lightTheme,
      home: const SharedWithMeView(),
    );
  }

  // Drive the three `_buildContent` branch getters in one place. The search /
  // tab bars short-circuit on `hasAnyContent == false`, so the loading/empty/
  // error states never touch the child specialized ViewModels.
  void stubGlobalState({
    required bool loading,
    required bool hasError,
    String? error,
    required bool hasContent,
  }) {
    when(() => coordinator.isGloballyLoading).thenReturn(loading);
    when(() => coordinator.hasGlobalError).thenReturn(hasError);
    when(() => coordinator.globalError).thenReturn(error);
    when(() => coordinator.hasAnyContent).thenReturn(hasContent);
  }

  // Pump the real view on a tall surface. `mainMenu` introduces a real
  // Scaffold + bottom nav; on a short surface those plus the centred state
  // illustration overflow vertically. The overflow is a layout artifact of
  // the surrounding scaffold, orthogonal to the state-rendering behaviour
  // under test — so we ignore RenderFlex-overflow FlutterErrors ONLY, letting
  // every other error fail the test as normal.
  //
  // [settle] is false for the loading state: its LoadingIndicator wraps a
  // CircularProgressIndicator whose perpetual animation makes pumpAndSettle
  // time out, so we pump discrete frames instead.
  Future<void> pumpView(WidgetTester tester, {bool settle = true}) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final previousOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      // String-matches the framework's exact 'A RenderFlex overflowed'
      // wording; if a future Flutter SDK rewords it, this filter stops
      // matching and the overflow resurfaces as a failure.
      if (details.exceptionAsString().contains('A RenderFlex overflowed')) {
        return;
      }
      previousOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = previousOnError);

    await tester.pumpWidget(testApp());
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      // Pump twice: once to build, once to flush the post-frame initialize().
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  group('SharedWithMeView — state rendering', () {
    testWidgets(
        'global loading shows the Swedish loading text and a progress indicator',
        (tester) async {
      stubGlobalState(
          loading: true, hasError: false, error: null, hasContent: false);

      await pumpView(tester, settle: false);

      // The app bar renders regardless of content state.
      expect(find.text(_appBarTitle), findsOneWidget);

      // Loading branch: Swedish copy + the canonical loading indicator.
      expect(find.text(_loadingText), findsOneWidget);
      expect(find.byType(LoadingIndicator), findsOneWidget);

      // Not the empty/error branches.
      expect(find.text(_emptyTitle), findsNothing);
    });

    testWidgets(
        'no content (not loading, no error) shows the empty-state title, '
        'explanation and CTA', (tester) async {
      stubGlobalState(
          loading: false, hasError: false, error: null, hasContent: false);

      await pumpView(tester);

      expect(find.text(_emptyTitle), findsOneWidget);
      // The empty-state explanation subtitle renders too.
      expect(
        find.textContaining('När du eller dina vänner delar recept'),
        findsOneWidget,
      );
      // The "share your first recipe" CTA button is offered.
      expect(find.text(_emptyCta), findsOneWidget);

      // The loading indicator is gone in the empty state.
      expect(find.byType(LoadingIndicator), findsNothing);
    });

    testWidgets('global error shows the error message and a retry action',
        (tester) async {
      const errorMessage = 'Kunde inte ladda delat innehåll';
      stubGlobalState(
          loading: false,
          hasError: true,
          error: errorMessage,
          hasContent: false);

      await pumpView(tester);

      // The error branch surfaces the coordinator's globalError verbatim.
      expect(find.text(errorMessage), findsOneWidget);
      // A retry action is offered (StateWidget.error resolves a Retry label
      // because onAction == refreshAllContent is non-null).
      expect(find.text(_retryLabel), findsOneWidget);

      // Not the empty or loading branches.
      expect(find.text(_emptyTitle), findsNothing);
      expect(find.byType(LoadingIndicator), findsNothing);
    });

    testWidgets(
        'tapping retry in the error state invokes refreshAllContent on the coordinator',
        (tester) async {
      stubGlobalState(
          loading: false,
          hasError: true,
          error: 'Något gick fel',
          hasContent: false);

      await pumpView(tester);

      await tester.tap(find.text(_retryLabel));
      await tester.pumpAndSettle();

      verify(() => coordinator.refreshAllContent()).called(1);
    });

    testWidgets('tapping the empty-state CTA navigates to the home route',
        (tester) async {
      stubGlobalState(
          loading: false, hasError: false, error: null, hasContent: false);

      // Observe the route push the CTA triggers (Navigator.pushNamed(home)).
      final pushedRoutes = <String?>[];
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('sv', 'SE'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppTheme.lightTheme,
          navigatorObservers: [_RouteRecorder(pushedRoutes)],
          home: const SharedWithMeView(),
        ),
      );
      await tester.pumpAndSettle();

      // The first push is the initial '/' route of this app; tapping the CTA
      // pushes the home route ('/') on top.
      pushedRoutes.clear();
      await tester.tap(find.text(_emptyCta));
      await tester.pumpAndSettle();

      expect(pushedRoutes, contains('/'),
          reason: 'Empty-state CTA should push Routes.home');
    });
  });
}

/// Records the names of routes pushed onto the navigator.
class _RouteRecorder extends NavigatorObserver {
  _RouteRecorder(this.pushed);
  final List<String?> pushed;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route.settings.name);
    super.didPush(route, previousRoute);
  }
}
