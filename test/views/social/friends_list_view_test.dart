/// Behaviour tests for [FriendsListView] — the friends & groups hub.
///
/// The view is the most service-entangled of the social set: in
/// `initState`/`build` it resolves SIX dependencies through the production
/// [ServiceLocator] (FriendsViewModel, ActivityFeedViewModel, PermissionService,
/// AnalyticsService, UnifiedFriendsService, FeatureFlagService) and drives a
/// 3-tab TabController (Feed / Vänner / Grupper); finding friends is a sheet
/// opened from the top bar.
///
/// We wire every dependency through the prod↔test ServiceLocator bridge, drive
/// the FriendsViewModel into a known empty state, and assert the user-visible
/// Swedish behaviour: the three localized tab labels, the branded Friends-empty
/// state, tab switching changing the visible content, and the feature-flag gate
/// rendering the "social disabled" fallback when off.
///
/// Rebuilt for BUT-1180 — replaces a ~50-test ULTRATHINK smoke-suite of
/// `find.byType(MultiProvider)` / `takeException isNull` structural asserts that
/// threw "ServiceLocator not initialized" because they never wired the bridge.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/widgets/social/groups/create_group_dialog.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';

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
const _findFriends = 'Hitta vänner'; // l10n.socialFindFriends
const _requestsRow = 'Vänförfrågningar'; // l10n.socialFriendRequestsTitle
const _createGroup = 'Skapa grupp'; // l10n.groupCreateGroup
String _myGroupsHeader(int count) =>
    'MINA GRUPPER ($count)'; // groupMyGroupsCount, drawn uppercase
String _invitationsHeader(int count) =>
    'GRUPPINBJUDNINGAR ($count)'; // groupInvitationsCount, drawn uppercase
const _copyLink = 'Kopiera länk'; // l10n.commonCopyLink
const _linkCopied = 'Länk kopierad'; // l10n.commonLinkCopied
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
    when(() => friendsViewModel.isSearching).thenReturn(false);
    when(() => friendsViewModel.searchDegraded).thenReturn(false);
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

  Widget testApp({ThemeData? theme, RouteFactory? onGenerateRoute}) {
    return MaterialApp(
      onGenerateRoute: onGenerateRoute,
      locale: const Locale('sv', 'SE'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: theme ?? AppTheme.lightTheme,
      home: const FriendsListView(),
    );
  }

  // Pump the real view on a tall surface. The view nests LayoutComponents
  // .mainMenu (Scaffold + bottom nav) with a centred branded empty state and a
  // tab bar; on a short surface those overflow vertically. That overflow is a
  // layout artifact of the surrounding scaffold, orthogonal to the
  // tab/state behaviour under test — so we ignore RenderFlex-overflow
  // FlutterErrors ONLY, letting every other error fail the test as normal.
  Future<void> pumpView(WidgetTester tester, {ThemeData? theme}) async {
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

    await tester.pumpWidget(testApp(theme: theme));
    await tester.pumpAndSettle();
  }

  group('FriendsListView — tab hub', () {
    testWidgets('renders the three Swedish tab labels', (tester) async {
      await pumpView(tester);

      Finder tabLabel(String text) =>
          find.descendant(of: find.byType(TabBar), matching: find.text(text));
      expect(tabLabel(_tabFeed), findsOneWidget);
      expect(tabLabel(_tabFriends), findsOneWidget);
      expect(tabLabel(_tabGroups), findsOneWidget);
      expect(tabLabel(_findFriends), findsNothing);

      final tabBar = tester.widget<TabBar>(find.byType(TabBar));
      expect(tabBar.controller?.length, 3);
    });

    testWidgets('has no floating action button on any tab', (tester) async {
      await pumpView(tester);
      for (final tab in [_tabFriends, _tabGroups, _tabFeed]) {
        await tester.tap(
          find.descendant(of: find.byType(TabBar), matching: find.text(tab)),
        );
        await tester.pumpAndSettle();
        expect(find.byType(FloatingActionButton), findsNothing);
      }
    });

    testWidgets(
      'Friends tab with no friends shows the branded empty state, not the feed',
      (tester) async {
        await pumpView(tester);

        await tester.tap(find.text(_tabFriends));
        await tester.pumpAndSettle();

        expect(find.text(_friendsEmptyHeadline), findsOneWidget);
        expect(find.text(_friendsEmptyFindByUsername), findsOneWidget);
      },
    );

    testWidgets(
      'Friends tab leads with the Vänförfrågningar row and its pending count',
      (tester) async {
        when(() => friendsViewModel.incomingRequests).thenReturn([
          FriendRequest(
            id: 'r1',
            fromUserId: 'erik',
            toUserId: 'me',
            sentAt: DateTime.utc(2026, 10, 5),
          ),
          FriendRequest(
            id: 'r2',
            fromUserId: 'anna',
            toUserId: 'me',
            sentAt: DateTime.utc(2026, 10, 5),
          ),
        ]);
        await pumpView(tester);
        await tester.tap(find.text(_tabFriends));
        await tester.pumpAndSettle();

        expect(find.text(_requestsRow), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(ButleryListRow),
            matching: find.text('2'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'tapping the Friends-empty "find by username" CTA opens the Hitta vänner sheet',
      (tester) async {
        await pumpView(tester);

        await tester.tap(find.text(_tabFriends));
        await tester.pumpAndSettle();
        await tester.tap(find.text(_friendsEmptyFindByUsername));
        await tester.pumpAndSettle();

        expect(find.text('Namn eller e-postadress'), findsOneWidget);
        expect(find.text('Dela din profillänk'), findsOneWidget);
        final tabBar = tester.widget<TabBar>(find.byType(TabBar));
        expect(tabBar.controller?.index, 1);
      },
    );

    testWidgets('the top-bar search action opens the Hitta vänner sheet and '
        'runs the friend search', (tester) async {
      await pumpView(tester);

      await tester.tap(find.byTooltip(_findFriends));
      await tester.pumpAndSettle();

      expect(find.text('Dela din profillänk'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'erik');
      await tester.pump();
      verify(() => friendsViewModel.updateSearch('erik')).called(1);
    });

    testWidgets('tapping the Vänförfrågningar row opens the friend requests '
        'page', (tester) async {
      final pushed = <String?>[];
      tester.view.physicalSize = const Size(1200, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        testApp(
          onGenerateRoute: (settings) {
            pushed.add(settings.name);
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const SizedBox(),
            );
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(_tabFriends));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ButleryListRow, _requestsRow));
      await tester.pumpAndSettle();

      expect(pushed, [Routes.friendRequests]);
    });

    testWidgets('a friend row shows the bio or nothing, never Online, and '
        'opens that friend\'s profile', (tester) async {
      final now = DateTime.utc(2026, 1, 1);
      final withBio = UserProfile(
        uid: 'a',
        displayName: 'Anna',
        email: 'a@x.se',
        bio: 'Bakar surdeg',
        joinedAt: now,
        lastActiveAt: now,
      );
      final online = UserProfile(
        uid: 'b',
        displayName: 'Bo',
        email: 'b@x.se',
        bio: '',
        isOnline: true,
        joinedAt: now,
        lastActiveAt: now,
      );
      friendsViewModel.setFriendsState(
        friends: [withBio, online],
        isLoading: false,
      );
      final pushed = <RouteSettings>[];
      tester.view.physicalSize = const Size(1200, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        testApp(
          onGenerateRoute: (settings) {
            pushed.add(settings);
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const SizedBox(),
            );
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(_tabFriends));
      await tester.pumpAndSettle();

      final annaTile = tester.widget<ListTile>(
        find.widgetWithText(ListTile, 'Anna'),
      );
      expect((annaTile.subtitle! as Text).data, 'Bakar surdeg');
      final boTile = tester.widget<ListTile>(
        find.widgetWithText(ListTile, 'Bo'),
      );
      expect(boTile.subtitle, isNull);
      expect(find.text('Online'), findsNothing);

      await tester.tap(find.text('Bo'));
      await tester.pumpAndSettle();
      expect(pushed.map((s) => s.name), [Routes.friendProfile]);
      expect(pushed.single.arguments, same(online));
    });

    testWidgets('closing the Hitta vänner sheet clears the search query left '
        'in the view model', (tester) async {
      await pumpView(tester);
      await tester.tap(find.byTooltip(_findFriends));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'erik');
      await tester.pump();
      verifyNever(() => friendsViewModel.updateSearch(''));

      // The barrier sits above the 85%-high sheet.
      await tester.tapAt(const Offset(600, 10));
      await tester.pumpAndSettle();

      expect(find.text('Dela din profillänk'), findsNothing);
      verify(() => friendsViewModel.updateSearch('')).called(1);
    });

    testWidgets('Kopiera länk in the sheet puts a link on the clipboard and '
        'confirms it', (tester) async {
      when(() => friendsViewModel.currentUserId).thenReturn('me');
      final copied = <String?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String?);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await pumpView(tester);
      await tester.tap(find.byTooltip(_findFriends));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ButleryListRow, _copyLink));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(copied, hasLength(1));
      expect(Uri.parse(copied.single!).queryParameters['from'], 'me');
      expect(find.text(_linkCopied), findsOneWidget);
    });

    testWidgets('a Groups tab with only a pending invitation shows the '
        'invitations section and exactly one Skapa grupp row', (tester) async {
      when(() => invitationsOps.isLoading).thenReturn(false);
      when(() => invitationsOps.pendingReceivedInvitations).thenReturn([
        GroupInvitation(
          id: 'i1',
          groupId: 'g9',
          groupName: 'Söndagsmiddag',
          groupEmoji: '🍲',
          fromUserId: 'erik',
          fromUserName: 'Erik',
          toUserId: 'me',
        ),
      ]);
      await pumpView(tester);
      await tester.tap(find.text(_tabGroups));
      await tester.pumpAndSettle();

      expect(find.text(_invitationsHeader(1)), findsOneWidget);
      expect(find.text('Söndagsmiddag'), findsOneWidget);
      expect(find.widgetWithText(ButleryListRow, _createGroup), findsOneWidget);
      expect(find.text(_createGroup), findsOneWidget);
    });

    testWidgets('an empty Groups tab has no Skapa grupp row; the empty state '
        'keeps its own button', (tester) async {
      await pumpView(tester);
      await tester.tap(find.text(_tabGroups));
      await tester.pumpAndSettle();

      // Empty list: exactly one create control (the empty-state button).
      expect(find.text(_createGroup), findsOneWidget);
      expect(find.widgetWithText(ButleryListRow, _createGroup), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('Groups tab with a group ends with exactly one Skapa grupp row '
        'that opens the create-group dialog', (tester) async {
      final categoriesOps = MockFriendsCategoriesOperations()
        ..setCategoriesState(
          categories: [FriendCategory(id: 'g1', ownerId: 'me', name: 'Middag')],
        );
      friendsService.setFriendsState(
        friends: const [],
        categoriesList: const [],
        categories: categoriesOps,
        invitations: invitationsOps,
        isLoading: false,
      );

      await pumpView(tester);
      await tester.tap(find.text(_tabGroups));
      await tester.pumpAndSettle();

      expect(find.text('Middag'), findsOneWidget);
      expect(find.text(_myGroupsHeader(1)), findsOneWidget);
      final row = find.widgetWithText(ButleryListRow, _createGroup);
      expect(row, findsOneWidget);
      expect(find.text(_createGroup), findsOneWidget);

      await tester.tap(row);
      await tester.pumpAndSettle();

      expect(find.byType(CreateGroupDialog), findsOneWidget);
    });

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

  // BUT-2183: the error box is a surface.tint.danger notice with no border
  // (B83-2).
  group('FriendsListView — tokens (BUT-2183)', () {
    for (final (name, theme) in [
      ('light', AppTheme.lightTheme),
      ('dark', AppTheme.darkTheme),
    ]) {
      testWidgets('$name: the error box is a surface.tint.danger fill with no '
          'border', (tester) async {
        friendsViewModel.setFriendsState(error: 'Något gick fel');
        when(() => friendsViewModel.error).thenReturn('Något gick fel');
        await pumpView(tester, theme: theme);

        final context = tester.element(find.byType(FriendsListView));
        final message = find.text('Något gick fel');
        expect(message, findsOneWidget);
        final box = tester.widget<Container>(
          find.ancestor(of: message, matching: find.byType(Container)).first,
        );
        final decoration = box.decoration! as BoxDecoration;
        expect(decoration.color, context.modeColors.surfaceTintDanger);
        expect(decoration.border, isNull);
        expect(
          tester.widget<Text>(message).style?.color,
          Theme.of(context).colorScheme.onErrorContainer,
        );
      });
    }
  });
}
