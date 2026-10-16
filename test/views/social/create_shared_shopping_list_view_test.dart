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
/// configured instance) and [MockUnifiedFriendsService].
///
/// Rebuilt for BUT-1180 — replaces a ~50-test ULTRATHINK smoke-suite of
/// `takeException isNull` / `findsOneWidget` structural asserts. Each test here
/// pins an input → output/side-effect the user actually experiences.
library;

// ignore_for_file: invalid_use_of_protected_member

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/feedback/inline_error.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:butlery/views/social/create_shared_shopping_list_view.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/services/unified/operations/collaborative_shopping_operations.dart';
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
const _appBarTitle = 'Ny delad lista';
const _friendSectionHeader = 'DELA MED';
const _createButtonLabel = 'Skapa och dela';

class _MockCollaborativeOps extends Mock
    implements CollaborativeShoppingOperations {}

UserProfile _friend(String uid, String name) =>
    WidgetMockFactory.createTestUserProfile(id: uid, displayName: name);

void main() {
  late MockUnifiedShoppingService shoppingService;
  late _MockCollaborativeOps collabOps;
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

    friendsService =
        TestServiceLocator.get<UnifiedFriendsService>()
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
    shoppingService =
        TestServiceLocator.get<UnifiedShoppingService>()
            as MockUnifiedShoppingService;
    shoppingService.setShoppingState(error: null);
    collabOps = _MockCollaborativeOps();
    when(() => shoppingService.collaborative).thenReturn(collabOps);
    when(
      () => collabOps.createListAndInvite(
        name: any(named: 'name'),
        description: any(named: 'description'),
        memberIds: any(named: 'memberIds'),
        items: any(named: 'items'),
        categoryIds: any(named: 'categoryIds'),
        allowGuestEditing: any(named: 'allowGuestEditing'),
      ),
    ).thenAnswer(
      (_) async => (listId: 'new-list-id', notInvited: const <String>[]),
    );
  });

  tearDown(() async {
    friendsViewModel.dispose();
    await TestServiceLocator.reset();
    await ViewTestHelpers.teardownViewTestEnvironment();
  });

  Widget testApp({ThemeData? theme, bool pushed = false}) {
    return MaterialApp(
      locale: const Locale('sv', 'SE'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: theme ?? AppTheme.lightTheme,
      home: pushed
          ? Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CreateSharedShoppingListView(),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            )
          : const CreateSharedShoppingListView(),
    );
  }

  // Pump the real view on a tall surface.
  Future<void> pumpView(
    WidgetTester tester, {
    ThemeData? theme,
    bool pushed = false,
  }) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(testApp(theme: theme, pushed: pushed));
    await tester.pumpAndSettle();
    if (pushed) {
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }
  }

  // The create action is the view's saffron HeroButton (P4-U13) → a
  // FilledButton carrying the localized label. We read its onPressed to
  // assert the canCreate gate as the user experiences it (tappable vs the
  // disabled surface).
  FilledButton createButton(WidgetTester tester) => tester.widget<FilledButton>(
    find.widgetWithText(FilledButton, _createButtonLabel),
  );

  // Select a friend by tapping their row; the row's box draws the tick.
  Future<void> pickFriend(WidgetTester tester, String uid) async {
    final row = find.byKey(ValueKey('createSharedList.friend.$uid'));
    await tester.tap(row);
    await tester.pumpAndSettle();
    // Self-check: the toggle must have registered, else downstream side-effect
    // assertions would silently test an unselected state.
    expect(
      tester
          .widget<Checkbox>(
            find.descendant(of: row, matching: find.byType(Checkbox)),
          )
          .value,
      isTrue,
      reason: 'Tapping "$uid" did not register as a friend selection',
    );
  }

  group('CreateSharedShoppingListView — share-list journey', () {
    testWidgets(
      'renders the Swedish share form: app-bar title, friend picker, create action',
      (tester) async {
        await pumpView(tester);

        expect(find.text(_appBarTitle), findsOneWidget);
        expect(find.text(_friendSectionHeader), findsOneWidget);
        expect(
          find.widgetWithText(FilledButton, _createButtonLabel),
          findsOneWidget,
        );

        // Seeded friends are offered for selection.
        expect(find.text('Anna'), findsOneWidget);
        expect(find.text('Björn'), findsOneWidget);

        // Both permission choices are offered.
        expect(find.text('Kan redigera'), findsOneWidget);
        expect(find.text('Bara läsning'), findsOneWidget);
      },
    );

    testWidgets(
      'create stays disabled until BOTH a title is typed AND a friend is picked',
      (tester) async {
        await pumpView(tester);

        // Empty form: button disabled.
        expect(
          createButton(tester).onPressed,
          isNull,
          reason: 'No title, no friends → cannot create',
        );

        // Title only: still disabled (a shared list needs someone to share with).
        await tester.enterText(
          find.byType(TextField).first,
          'Veckans handling',
        );
        await tester.pumpAndSettle();
        expect(
          createButton(tester).onPressed,
          isNull,
          reason: 'Title but no friend selected → still cannot create',
        );

        // Pick a friend too: now enabled.
        await pickFriend(tester, 'friend_anna');
        expect(
          createButton(tester).onPressed,
          isNotNull,
          reason: 'Title + at least one friend → create is enabled',
        );
      },
    );

    testWidgets(
      'tapping create creates the list with the typed title and invites the picked friend',
      (tester) async {
        await pumpView(tester);

        // Snapshot the args AT INVOCATION TIME, inside the stub.
        String? capturedName;
        List<String>? capturedMemberIds;
        when(
          () => collabOps.createListAndInvite(
            name: any(named: 'name'),
            description: any(named: 'description'),
            memberIds: any(named: 'memberIds'),
            items: any(named: 'items'),
            categoryIds: any(named: 'categoryIds'),
            allowGuestEditing: any(named: 'allowGuestEditing'),
          ),
        ).thenAnswer((invocation) async {
          capturedName = invocation.namedArguments[#name] as String;
          capturedMemberIds = List<String>.from(
            invocation.namedArguments[#memberIds] as List,
          );
          return (listId: 'new-list-id', notInvited: const <String>[]);
        });

        await pickFriend(tester, 'friend_anna');
        await tester.enterText(
          find.byType(TextField).first,
          'Middag hos Anna',
        );
        await tester.pumpAndSettle();

        // The form is now valid, so the create action is enabled.
        final onCreate = createButton(tester).onPressed;
        expect(
          onCreate,
          isNotNull,
          reason: 'Title + selected friend → create enabled',
        );
        onCreate!();
        await tester.pumpAndSettle();

        // Title is trimmed and passed through verbatim.
        expect(capturedName, 'Middag hos Anna');
        // The picked friend's uid is handed over to be INVITED; the create
        // call itself seats nobody but the creator (BUT-2089).
        expect(capturedMemberIds, ['friend_anna']);
      },
    );

    testWidgets(
      'a friend the invitation did not reach is named in one line and the list '
      'is kept',
      (tester) async {
        when(
          () => collabOps.createListAndInvite(
            name: any(named: 'name'),
            description: any(named: 'description'),
            memberIds: any(named: 'memberIds'),
            items: any(named: 'items'),
            categoryIds: any(named: 'categoryIds'),
            allowGuestEditing: any(named: 'allowGuestEditing'),
          ),
        ).thenAnswer(
          (_) async => (listId: 'new-list-id', notInvited: ['friend_anna']),
        );
        // Pushed over a host page, as in the app: the notice outlives the pop.
        await pumpView(tester, pushed: true);
        final l10n = AppLocalizations.of(
          tester.element(find.byType(CreateSharedShoppingListView)),
        );

        await pickFriend(tester, 'friend_anna');
        await tester.enterText(find.byType(TextField).first, 'Middag');
        await tester.pumpAndSettle();
        createButton(tester).onPressed!();
        await tester.pumpAndSettle();

        expect(
          find.text(l10n.listInviteConvertedSomeNotInvited('Anna')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'when everyone was invited the create closes without a notice',
      (
        tester,
      ) async {
        when(
          () => collabOps.createListAndInvite(
            name: any(named: 'name'),
            description: any(named: 'description'),
            memberIds: any(named: 'memberIds'),
            items: any(named: 'items'),
            categoryIds: any(named: 'categoryIds'),
            allowGuestEditing: any(named: 'allowGuestEditing'),
          ),
        ).thenAnswer(
          (_) async => (listId: 'new-list-id', notInvited: const <String>[]),
        );
        await pumpView(tester, pushed: true);

        await pickFriend(tester, 'friend_anna');
        await tester.enterText(find.byType(TextField).first, 'Middag');
        await tester.pumpAndSettle();
        createButton(tester).onPressed!();
        await tester.pumpAndSettle();

        expect(find.byType(CreateSharedShoppingListView), findsNothing);
        expect(find.byType(SnackBar), findsNothing);
      },
    );

    testWidgets(
      'a whitespace-only title keeps create disabled and never calls the service',
      (tester) async {
        await pumpView(tester);

        // Pick a friend so ONLY the title is the blocker.
        await pickFriend(tester, 'friend_anna');

        // Type only spaces — isTitleValid is false (trim().isEmpty).
        await tester.enterText(find.byType(TextField).first, '   ');
        await tester.pumpAndSettle();

        expect(
          createButton(tester).onPressed,
          isNull,
          reason: 'Whitespace-only title is not a valid title',
        );

        // The VM surfaces the Swedish "title required, not empty" error once the
        // field is non-empty-but-blank.
        expect(find.text('Titel krävs och får inte vara tom'), findsOneWidget);

        verifyNever(
          () => collabOps.createListAndInvite(
            name: any(named: 'name'),
            description: any(named: 'description'),
            memberIds: any(named: 'memberIds'),
            items: any(named: 'items'),
            categoryIds: any(named: 'categoryIds'),
            allowGuestEditing: any(named: 'allowGuestEditing'),
          ),
        );
      },
    );

    testWidgets('picking a friend twice takes the friend off again', (
      tester,
    ) async {
      await pumpView(tester);

      await pickFriend(tester, 'friend_anna');
      await tester.tap(
        find.byKey(const ValueKey('createSharedList.friend.friend_anna')),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Checkbox>(
              find.descendant(
                of: find.byKey(
                  const ValueKey('createSharedList.friend.friend_anna'),
                ),
                matching: find.byType(Checkbox),
              ),
            )
            .value,
        isFalse,
      );
    });

    testWidgets('read only is passed on as no editing for the invited', (
      tester,
    ) async {
      await pumpView(tester);
      bool? capturedAllowEditing;
      when(
        () => collabOps.createListAndInvite(
          name: any(named: 'name'),
          description: any(named: 'description'),
          memberIds: any(named: 'memberIds'),
          items: any(named: 'items'),
          categoryIds: any(named: 'categoryIds'),
          allowGuestEditing: any(named: 'allowGuestEditing'),
        ),
      ).thenAnswer((invocation) async {
        capturedAllowEditing =
            invocation.namedArguments[#allowGuestEditing] as bool;
        return (listId: 'new-list-id', notInvited: const <String>[]);
      });

      await pickFriend(tester, 'friend_anna');
      await tester.tap(find.text('Bara läsning'));
      await tester.pumpAndSettle();
      expect(
        find.text('De du delar med kan se listan men inte ändra den.'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField).first, 'Middag');
      await tester.pumpAndSettle();
      createButton(tester).onPressed!();
      await tester.pumpAndSettle();

      expect(capturedAllowEditing, isFalse);
    });
  });

  // A refused create is the shared InlineError.
  group('CreateSharedShoppingListView — notice box (BUT-2183)', () {
    for (final (name, theme) in [
      ('light', AppTheme.lightTheme),
      ('dark', AppTheme.darkTheme),
    ]) {
      // A refused create (the service answers null) shows the error box. The
      // dark run carries the text assertion: in light, the old static error
      // colour and onErrorContainer are the same value.
      testWidgets('$name: a refused create shows an InlineError', (
        tester,
      ) async {
        when(
          () => collabOps.createListAndInvite(
            name: any(named: 'name'),
            description: any(named: 'description'),
            memberIds: any(named: 'memberIds'),
            items: any(named: 'items'),
            categoryIds: any(named: 'categoryIds'),
            allowGuestEditing: any(named: 'allowGuestEditing'),
          ),
        ).thenAnswer((_) async => (listId: null, notInvited: const <String>[]));
        await pumpView(tester, theme: theme);

        await pickFriend(tester, 'friend_anna');
        await tester.enterText(
          find.byType(TextField).first,
          'Middag hos Anna',
        );
        await tester.pumpAndSettle();
        createButton(tester).onPressed!();
        await tester.pumpAndSettle();

        final context = tester.element(
          find.byType(CreateSharedShoppingListView),
        );
        expect(
          find.text(AppLocalizations.of(context).errorUnknown),
          findsOneWidget,
        );
        expect(find.byKey(InlineError.boxKey), findsOneWidget);
        final box = tester.widget<Material>(find.byKey(InlineError.boxKey));
        final shape = box.shape! as RoundedRectangleBorder;
        expect(shape.side.color, Theme.of(context).colorScheme.error);
        expect(box.color, Theme.of(context).colorScheme.surface);
      });
    }
  });
}
