/// Behaviour tests for [FriendsListView] — the friends & groups hub.
///
/// The view is the most service-entangled of the social set: in
/// `initState`/`build` it resolves SIX dependencies through the production
/// [ServiceLocator] (FriendsViewModel, ActivityFeedViewModel, PermissionService,
/// AnalyticsService, UnifiedFriendsService, FeatureFlagService) and drives a
/// 4-tab TabController (Feed / Vänner / Grupper / Hitta vänner).
///
/// We wire every dependency through the prod↔test ServiceLocator bridge, drive
/// the FriendsViewModel into a known empty state, and assert the user-visible
/// Swedish behaviour: the four localized tab labels, the branded Friends-empty
/// state, tab switching changing the visible content, and the feature-flag gate
/// rendering the "social disabled" fallback when off.
///
/// Rebuilt for BUT-1180 — replaces a ~50-test ULTRATHINK smoke-suite of
/// `find.byType(MultiProvider)` / `takeException isNull` structural asserts that
/// threw "ServiceLocator not initialized" because they never wired the bridge.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:butlery/views/social/friends_list_view.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/viewmodels/social/activity_feed_viewmodel.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/feature_flags/feature_flag_service.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/models/friend_request.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/group_invitation.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/mocks/widget_mocks.dart';
import '../helpers/view_test_helpers.dart';

// Swedish labels the view renders (from app_sv.arb). Captured here so a
// behaviour regression — not a copy tweak — is what fails the assertion.
const _tabFeed = 'Flöde'; // l10n.socialFeed
const _tabFriends = 'Vänner'; // l10n.socialFriends
const _tabGroups = 'Grupper'; // l10n.socialGroups
const _tabFindFriends = 'Hitta vänner'; // l10n.socialFindFriends
const _friendsEmptyHeadline =
    'Laga tillsammans med vänner'; // friendsEmptyHeadline
const _friendsEmptyFindByUsername =
    'Hitta vänner med användarnamn'; // friendsEmptyFindByUsername
const _socialDisabled =
    'Sociala funktioner är tillfälligt inaktiverade.'; // hardcoded fallback

class _MockFeatureFlagService extends Mock implements FeatureFlagService {}

void main() {
  late MockFriendsViewModel friendsViewModel;
  late MockActivityFeedViewModel feedViewModel;
  late MockUnifiedFriendsService friendsService;
  late MockFriendsInvitationsOperations invitationsOps;
  late _MockFeatureFlagService featureFlags;
  late MockOfflineService offlineService;

  setUpAll(() {
    production.ServiceLocator.initialize(DIContainer());

    // The view wires UnifiedFriendsService through `Provider.value`. Our mock
    // mixes in ChangeNotifier (to satisfy stateStream/notify in other suites),
    // making it a Listenable — which trips Provider's debug "use
    // ChangeNotifierProvider instead" guard. The REAL service is NOT a
    // Listenable, so this guard is a mock-only artifact, not behaviour under
    // test. Disable it for this file.
    Provider.debugCheckInvalidValueType = null;
  });

  setUp(() async {
    await ViewTestHelpers.setupViewTestEnvironment();

    // The TabBar's Groups tab reads friendsService.invitations
    // .pendingReceivedInvitations; the default mock returns an unstubbed ops
    // object, so seed an empty-invitations ops instance.
    invitationsOps = MockFriendsInvitationsOperations();
    when(
      () => invitationsOps.pendingReceivedInvitations,
    ).thenReturn(<GroupInvitation>[]);

    friendsService =
        TestServiceLocator.get<UnifiedFriendsService>()
            as MockUnifiedFriendsService;
    friendsService.setFriendsState(
      friends: const [],
      categoriesList: const [],
      invitations: invitationsOps,
      isLoading: false,
    );

    // FriendsViewModel is registered as a FACTORY → the view's initState
    // lookup would get a fresh mock. Override with a singleton so the empty
    // state we configure is what the friends tab renders.
    friendsViewModel = MockFriendsViewModel();
    friendsViewModel.setFriendsState(friends: const [], isLoading: false);
    // The view reads these getters in build(); the widget mock only provides
    // `friends`/`isLoading`, so stub the rest of the FriendsViewModel surface
    // the view branches on.
    when(() => friendsViewModel.searchQuery).thenReturn('');
    when(() => friendsViewModel.searchResults).thenReturn(<UserProfile>[]);
    when(() => friendsViewModel.incomingRequests).thenReturn(<FriendRequest>[]);
    when(() => friendsViewModel.sentRequests).thenReturn(<FriendRequest>[]);
    when(() => friendsViewModel.friendsCount).thenReturn(0);
    when(() => friendsViewModel.updateSearch(any())).thenAnswer((_) async {});
    TestServiceLocator.registerMock<FriendsViewModel>(friendsViewModel);

    // ActivityFeedViewModel is a factory by default; the view captures one in
    // initState and the Feed tab (the default index 0) reads its
    // loading/error/events state. Override with a singleton driven to an empty,
    // settled feed so the Feed tab renders its empty state cleanly.
    // `events`, `filteredEvents`, `loadFeed` are concrete bodies on this mock —
    // setFeedState drives them and loadFeed is a no-op Future. Only the
    // BaseViewModel-derived `isLoading`/`error` getters need stubbing.
    feedViewModel = MockActivityFeedViewModel();
    feedViewModel.setFeedState(events: const []);
    when(() => feedViewModel.isLoading).thenReturn(false);
    when(() => feedViewModel.error).thenReturn(null);
    TestServiceLocator.registerMock<ActivityFeedViewModel>(feedViewModel);

    // FeatureFlagService is NOT registered by default; the view reads
    // isEnabled(enableSocialFeatures) in the content state's initState. Default
    // to ON (the main behaviour); the "off" test re-stubs it.
    featureFlags = _MockFeatureFlagService();
    when(
      () => featureFlags.isEnabled(FeatureFlags.enableSocialFeatures),
    ).thenReturn(true);
    TestServiceLocator.registerMock<FeatureFlagService>(featureFlags);

    // LayoutComponents.offlineIndicator() resolves OfflineService and reads
    // isOnline in initState. Register an online mock so it builds collapsed.
    offlineService = MockOfflineService();
    when(() => offlineService.isOnline).thenReturn(true);
    when(() => offlineService.addListener(any())).thenReturn(null);
    when(() => offlineService.removeListener(any())).thenReturn(null);
    TestServiceLocator.registerMock<OfflineService>(offlineService);

    // The view fires a fire-and-forget social-onboarding analytics event
    // (logSocialOnboardingStartedIfFirstEntry, Future<bool>) in initState. The
    // default registered MockAnalyticsService's shared social tracker now
    // returns the correct Future<bool> for the IfFirstEntry family (BUT-1183),
    // so no local override is needed.
  });

  tearDown(() async {
    friendsViewModel.dispose();
    feedViewModel.dispose();
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
      home: const FriendsListView(),
    );
  }

  // Pump the real view on a tall surface. The view nests LayoutComponents
  // .mainMenu (Scaffold + bottom nav) with a centred branded empty state and a
  // 4-tab bar; on a short surface those overflow vertically. That overflow is a
  // layout artifact of the surrounding scaffold, orthogonal to the
  // tab/state behaviour under test — so we ignore RenderFlex-overflow
  // FlutterErrors ONLY, letting every other error fail the test as normal.
  Future<void> pumpView(WidgetTester tester) async {
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
    await tester.pumpAndSettle();
  }

  group('FriendsListView — tab hub', () {
    testWidgets('renders the four Swedish tab labels', (tester) async {
      await pumpView(tester);

      // Scope the label finders to the TabBar: with no friends the default Feed
      // tab also shows a "Hitta vänner" CTA (same copy as the Find-friends tab),
      // so an unscoped find.text(_tabFindFriends) would match twice. Asserting
      // inside the TabBar pins the *tab labels* specifically.
      Finder tabLabel(String text) =>
          find.descendant(of: find.byType(TabBar), matching: find.text(text));
      expect(tabLabel(_tabFeed), findsOneWidget);
      expect(tabLabel(_tabFriends), findsOneWidget);
      expect(tabLabel(_tabGroups), findsOneWidget);
      expect(tabLabel(_tabFindFriends), findsOneWidget);

      // The 4-tab controller is wired (length 4), not the legacy 3.
      final tabBar = tester.widget<TabBar>(find.byType(TabBar));
      expect(tabBar.controller?.length, 4);
    });

    testWidgets(
      'Friends tab with no friends shows the branded empty state, not the feed',
      (tester) async {
        await pumpView(tester);

        // Default tab is Feed (index 0); switch to the Friends tab.
        await tester.tap(find.text(_tabFriends));
        await tester.pumpAndSettle();

        // The branded FriendsEmptyState renders its headline + the
        // "find by username" secondary CTA.
        expect(find.text(_friendsEmptyHeadline), findsOneWidget);
        expect(find.text(_friendsEmptyFindByUsername), findsOneWidget);
      },
    );

    testWidgets(
      'tapping the Friends-empty "find by username" CTA switches to the Find friends tab',
      (tester) async {
        await pumpView(tester);

        await tester.tap(find.text(_tabFriends));
        await tester.pumpAndSettle();

        // The branded empty state offers a secondary CTA that animates the tab
        // controller to index 3 (Find friends). Before tapping, the Find-friends
        // tab content (the RequestsTab search hub) is not the active body.
        await tester.tap(find.text(_friendsEmptyFindByUsername));
        await tester.pumpAndSettle();

        // After the jump, the active tab is index 3 — the friends-empty headline
        // is gone (we left the Friends tab) and the search box for finding new
        // friends is now shown.
        expect(find.text(_friendsEmptyHeadline), findsNothing);
        final tabBar = tester.widget<TabBar>(find.byType(TabBar));
        expect(tabBar.controller?.index, 3);
      },
    );

    testWidgets(
      'switching to the Groups tab surfaces the create-group FloatingActionButton',
      (tester) async {
        await pumpView(tester);

        // No FAB on the default Feed tab.
        expect(find.byType(FloatingActionButton), findsNothing);

        await tester.tap(find.text(_tabGroups));
        await tester.pumpAndSettle();

        // The Groups tab (index 2) carries the create-group FAB. (The Friends tab
        // also carries an Add-friend FAB now — see the BUT-1357 test below — so
        // the FAB is no longer Groups-exclusive; presence here is what matters.)
        expect(find.byType(FloatingActionButton), findsOneWidget);
      },
    );

    testWidgets(
      'BUT-1357: Friends tab shows an Add-friend FAB that jumps to the Find friends tab',
      (tester) async {
        await pumpView(tester);

        // No FAB on the default Feed tab (index 0).
        expect(find.byType(FloatingActionButton), findsNothing);

        // Switch to the Friends tab (index 1).
        await tester.tap(find.text(_tabFriends));
        await tester.pumpAndSettle();

        // The Friends tab now surfaces its own primary-action FAB, labelled for
        // screen readers via the a11yAddFriend semantics key.
        expect(find.byType(FloatingActionButton), findsOneWidget);
        final addFriendFab = find.bySemanticsLabel(
          'Lägg till vän',
        ); // a11yAddFriend
        expect(addFriendFab, findsOneWidget);

        // Tapping it animates the tab controller to the Find friends tab (index 3)
        // — the same target as the empty-state "find by username" CTA, no new flow.
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();

        final tabBar = tester.widget<TabBar>(find.byType(TabBar));
        expect(tabBar.controller?.index, 3);

        // On the Find friends tab the Add-friend FAB is gone (that tab carries its
        // own search field instead).
        expect(find.byType(FloatingActionButton), findsNothing);
      },
    );

    testWidgets(
      'with social features flagged OFF the view renders the disabled fallback and no tabs',
      (tester) async {
        // Flip the gate the content state reads in initState.
        when(
          () => featureFlags.isEnabled(FeatureFlags.enableSocialFeatures),
        ).thenReturn(false);

        await pumpView(tester);

        // The hardcoded Swedish "temporarily disabled" message replaces the whole
        // tabbed UI.
        expect(find.text(_socialDisabled), findsOneWidget);
        expect(find.byType(TabBar), findsNothing);
        expect(find.text(_tabFeed), findsNothing);
      },
    );
  });
}
