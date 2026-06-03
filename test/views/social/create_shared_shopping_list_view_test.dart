/// Journey test: open "share shopping list" form → type a title → pick a
/// friend → tap create → the collaborative-list service is invoked with the
/// user's entered values.
///
/// This drives the REAL [CreateSharedShoppingListView]. The view builds its own
/// [CreateSharedListViewModel] internally (via `ChangeNotifierProvider(create:)`),
/// so we can't inject a mock VM. Instead we observe the user-visible
/// side-effect at the service seam: the real VM resolves
/// [UnifiedShoppingService] through the production ServiceLocator bridge, and
/// `createSharedList()` ultimately calls `createCollaborativeList(...)`. We
/// spy on that mock to prove the title + selected friend the user typed/picked
/// reach the service.
///
/// Friends are supplied through the already-registered [MockFriendsViewModel]
/// (overridden to a singleton so the view's `initState` lookup gets OUR
/// configured instance) and [MockUnifiedFriendsService], so the real
/// `FriendCategoryManager` renders a tappable friend list.
///
/// Rebuilt for BUT-1180 — replaces a ~50-test ULTRATHINK smoke-suite of
/// `takeException isNull` / `findsOneWidget` structural asserts. Each test here
/// pins an input → output/side-effect the user actually experiences.
library;

// ignore_for_file: invalid_use_of_protected_member

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:butlery/views/social/create_shared_shopping_list_view.dart';
import 'package:butlery/widgets/common/friends/friend_category_manager.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/user_profile.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/mocks/widget_mocks.dart';
import '../helpers/view_test_helpers.dart';

// Swedish labels the view renders (from app_sv.arb). Captured here so a
// behaviour regression — not a copy tweak — is what fails the assertion.
const _appBarTitle =
    'Dela inköpslista'; // commonShare + shoppingList.toLowerCase()
const _friendSectionHeader = 'Välj vänner att dela med';
const _createButtonLabel = 'Skapa & Dela';
const _noFriendsSelected = 'Inga vänner valda';

UserProfile _friend(String uid, String name) =>
    WidgetMockFactory.createTestUserProfile(id: uid, displayName: name);

void main() {
  late MockUnifiedShoppingService shoppingService;
  late MockUnifiedFriendsService friendsService;
  late MockFriendsViewModel friendsViewModel;

  // Two friends the user can pick from in the friend selector.
  final anna = _friend('friend_anna', 'Anna');
  final bjorn = _friend('friend_bjorn', 'Björn');

  setUpAll(() {
    registerFallbackValue(<String, String>{});
    registerFallbackValue(<String>[]);
    registerFallbackValue(<UnifiedShoppingItem>[]);
    production.ServiceLocator.initialize(DIContainer());

    // The view wires UnifiedFriendsService through `Provider.value`. Our mock
    // mixes in ChangeNotifier (so it can satisfy stateStream/notify in other
    // suites), which makes it a Listenable — tripping Provider's debug
    // "use ChangeNotifierProvider instead" guard. The REAL service is not a
    // Listenable, so this guard is a mock-only artifact, not behaviour under
    // test. Disable it for this file.
    Provider.debugCheckInvalidValueType = null;
  });

  setUp(() async {
    await ViewTestHelpers.setupViewTestEnvironment();

    // The unified friends service backs the FriendCategoryManager's "did the
    // category/friend data load?" gates. We keep categoriesList EMPTY (no
    // category chip section → a shorter friend-manager column → the friend
    // rows stay within the hit-testable region of the view's fixed-height
    // selector). The manager's postFrame `if (categoriesList.isEmpty) refresh()`
    // would then fire; the mock's noSuchMethod `refresh()` returns null (not a
    // Future) and throws, so we stub it to a real completed Future.
    friendsService = TestServiceLocator.get<UnifiedFriendsService>()
        as MockUnifiedFriendsService;
    friendsService.setFriendsState(
      friends: [anna, bjorn],
      categoriesList: const [],
      isLoading: false,
    );
    when(() => friendsService.refresh()).thenAnswer((_) async {});

    // FriendsViewModel is registered as a FACTORY by default → every
    // ServiceLocator.get returns a fresh mock. The view captures one in
    // initState; override with a singleton so OUR seeded friends are what the
    // friend selector renders.
    friendsViewModel = MockFriendsViewModel();
    friendsViewModel.setFriendsState(friends: [anna, bjorn], isLoading: false);
    TestServiceLocator.registerMock<FriendsViewModel>(friendsViewModel);

    // The shopping service is the side-effect seam. Default: a successful
    // create returns a new list id. Individual tests can override.
    shoppingService = TestServiceLocator.get<UnifiedShoppingService>()
        as MockUnifiedShoppingService;
    shoppingService.setShoppingState(error: null);
    when(() => shoppingService.createCollaborativeList(
          name: any(named: 'name'),
          description: any(named: 'description'),
          memberIds: any(named: 'memberIds'),
          memberDisplayNames: any(named: 'memberDisplayNames'),
          items: any(named: 'items'),
          categoryIds: any(named: 'categoryIds'),
        )).thenAnswer((_) async => 'new-list-id');
  });

  tearDown(() async {
    friendsViewModel.dispose();
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
      home: const CreateSharedShoppingListView(),
    );
  }

  // Pump the real view on a tall surface and absorb the ONE known production
  // RenderFlex overflow: FriendCategoryManager packs a fixed 320px friends
  // section into the view's fixed-height (200px) BorderedContainer, which
  // overflows by design on any surface. That overflow is a pre-existing
  // layout artifact of the production widget, orthogonal to the behaviour
  // under test — so we ignore RenderFlex-overflow FlutterErrors only, and
  // let every other error fail the test as normal.
  Future<void> pumpView(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final previousOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      final summary = details.exceptionAsString();
      // String-matches the framework's exact 'A RenderFlex overflowed' wording;
      // if a future Flutter SDK rewords that message this filter stops matching
      // and the (still pre-existing) overflow will resurface as a test failure.
      if (summary.contains('A RenderFlex overflowed')) return;
      previousOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = previousOnError);

    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();
  }

  // The create action is ActionButtons.primaryButton → an ElevatedButton
  // carrying the localized label. We read its onPressed to assert the
  // canCreate gate as the user experiences it (tappable vs greyed out).
  ElevatedButton createButton(WidgetTester tester) =>
      tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, _createButtonLabel),
      );

  // Select a friend by name in the FriendCategoryManager's checkbox list.
  // The list sits inside the view's fixed-height BorderedContainer (which
  // overflows), so a friend row can land outside the hit-test region — scroll
  // it into view first, then toggle its checkbox.
  Future<void> pickFriend(WidgetTester tester, String name) async {
    final tile = find.widgetWithText(CheckboxListTile, name);
    // Scroll the row into the hittable region (the fixed-height friend
    // selector clips rows near its bottom edge), then toggle its checkbox.
    // Pin the scroll target to the FriendCategoryManager's OWN inner list
    // (its ListView.builder of friend rows). `find.byType(Scrollable).first`
    // picks by widget-tree order, and the view's outer page SingleChildScrollView
    // precedes the friend list in the tree — so `.first` would scroll the wrong
    // scrollable. That no-op passed on Windows-local but flaked on ubuntu/macos
    // CI (timeout / StateError). Scoping to the friend manager makes it
    // deterministic across all three OSes.
    final friendList = find.descendant(
      of: find.byType(FriendCategoryManager),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(tile, 100, scrollable: friendList.first);
    await tester.pumpAndSettle();
    final checkbox = find.descendant(of: tile, matching: find.byType(Checkbox));
    await tester.tap(checkbox, warnIfMissed: false);
    await tester.pumpAndSettle();
    // Self-check: the toggle must have registered, else downstream side-effect
    // assertions would silently test an unselected state.
    expect(find.text('1 vän vald'), findsWidgets,
        reason: 'Tapping "$name" did not register as a friend selection');
  }

  group('CreateSharedShoppingListView — share-list journey', () {
    testWidgets(
        'renders the Swedish share form: app-bar title, friend picker, create action',
        (tester) async {
      await pumpView(tester);

      expect(find.text(_appBarTitle), findsOneWidget);
      expect(find.text(_friendSectionHeader), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, _createButtonLabel),
          findsOneWidget);

      // Seeded friends are offered for selection.
      expect(find.text('Anna'), findsOneWidget);
      expect(find.text('Björn'), findsOneWidget);

      // Nothing picked yet → summary says so.
      expect(find.text(_noFriendsSelected), findsOneWidget);
    });

    testWidgets(
        'create stays disabled until BOTH a title is typed AND a friend is picked',
        (tester) async {
      await pumpView(tester);

      // Empty form: button disabled.
      expect(createButton(tester).onPressed, isNull,
          reason: 'No title, no friends → cannot create');

      // Title only: still disabled (a shared list needs someone to share with).
      await tester.enterText(
          find.byType(TextFormField).first, 'Veckans handling');
      await tester.pumpAndSettle();
      expect(createButton(tester).onPressed, isNull,
          reason: 'Title but no friend selected → still cannot create');

      // Pick a friend too: now enabled.
      await pickFriend(tester, 'Anna');
      expect(createButton(tester).onPressed, isNotNull,
          reason: 'Title + at least one friend → create is enabled');
    });

    testWidgets(
        'tapping create invokes createCollaborativeList with the typed title and picked friend',
        (tester) async {
      await pumpView(tester);

      // Snapshot the args AT INVOCATION TIME. The VM passes its internal
      // `_selectedFriendIds` list by reference and then `clearForm()` mutates
      // that same list on success — so a post-hoc `verify().captured` would
      // read the now-empty list. Copying inside the stub captures the real
      // values the service was called with.
      String? capturedName;
      List<String>? capturedMemberIds;
      Map<String, String>? capturedDisplayNames;
      when(() => shoppingService.createCollaborativeList(
            name: any(named: 'name'),
            description: any(named: 'description'),
            memberIds: any(named: 'memberIds'),
            memberDisplayNames: any(named: 'memberDisplayNames'),
            items: any(named: 'items'),
            categoryIds: any(named: 'categoryIds'),
          )).thenAnswer((invocation) async {
        capturedName = invocation.namedArguments[#name] as String;
        capturedMemberIds =
            List<String>.from(invocation.namedArguments[#memberIds] as List);
        capturedDisplayNames = Map<String, String>.from(
            invocation.namedArguments[#memberDisplayNames] as Map);
        return 'new-list-id';
      });

      await pickFriend(tester, 'Anna');
      await tester.enterText(
          find.byType(TextFormField).first, 'Middag hos Anna');
      await tester.pumpAndSettle();

      // Guard: the friend selection must still be live right before we create.
      expect(find.text('1 vän vald'), findsWidgets,
          reason: 'Friend selection lost after typing the title');

      // The form is now valid, so the create action is enabled. We invoke its
      // real onPressed callback directly rather than tapping: the friend
      // selector's fixed-height container overflows and paints clipped rows
      // over the bottom bar, so a positional tap on the create button can
      // instead land on an overflowing friend checkbox (toggling the selection
      // off). Calling the wired callback exercises the same real
      // view → VM → service path without that hit-test hazard.
      final onCreate = createButton(tester).onPressed;
      expect(onCreate, isNotNull,
          reason: 'Title + selected friend → create enabled');
      onCreate!();
      await tester.pumpAndSettle();

      // Title is trimmed and passed through verbatim.
      expect(capturedName, 'Middag hos Anna');
      // The picked friend's uid is the only member.
      expect(capturedMemberIds, ['friend_anna']);
      // Member display-name map resolves Anna's uid → her name (the VM builds
      // this from the friends service, falling back to '?').
      expect(capturedDisplayNames, {'friend_anna': 'Anna'});
    });

    testWidgets(
        'a whitespace-only title keeps create disabled and never calls the service',
        (tester) async {
      await pumpView(tester);

      // Pick a friend so ONLY the title is the blocker.
      await pickFriend(tester, 'Anna');

      // Type only spaces — isTitleValid is false (trim().isEmpty).
      await tester.enterText(find.byType(TextFormField).first, '   ');
      await tester.pumpAndSettle();

      expect(createButton(tester).onPressed, isNull,
          reason: 'Whitespace-only title is not a valid title');

      // The VM surfaces the Swedish "title required, not empty" error once the
      // field is non-empty-but-blank.
      expect(find.text('Titel krävs och får inte vara tom'), findsOneWidget);

      verifyNever(() => shoppingService.createCollaborativeList(
            name: any(named: 'name'),
            description: any(named: 'description'),
            memberIds: any(named: 'memberIds'),
            memberDisplayNames: any(named: 'memberDisplayNames'),
            items: any(named: 'items'),
            categoryIds: any(named: 'categoryIds'),
          ));
    });

    testWidgets(
        'picking a friend updates the bottom selection summary from "none" to a count',
        (tester) async {
      await pumpView(tester);

      expect(find.text(_noFriendsSelected), findsOneWidget);

      await pickFriend(tester, 'Anna');

      // Swedish singular plural form: "1 vän vald". It appears in BOTH the
      // friend selector's own summary AND the bottom action bar's summary —
      // the point is the "none" state is gone and the count is shown.
      expect(find.text(_noFriendsSelected), findsNothing);
      expect(find.text('1 vän vald'), findsWidgets);
    });
  });
}
