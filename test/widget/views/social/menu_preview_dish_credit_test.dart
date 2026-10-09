/// BUT-2221: the creator line under a dish on a shared menu.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/models/profile_lookup.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/viewmodels/shared_content/menu_dish_credit_viewmodel.dart';
import 'package:butlery/views/social/menu_preview/menu_preview_dishes.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';
import '../../../infrastructure/mocks/production_mocks.dart';

class _UserService extends Fake implements UserService {
  _UserService(this.profiles);
  final List<UserProfile> profiles;

  @override
  Future<ProfileBatchLookup> getUserProfiles(List<String> userIds) async =>
      ProfileBatchLookup(
        profiles: profiles.where((p) => userIds.contains(p.uid)).toList(),
        missingIds: const {},
        unavailableIds: const {},
      );
}

class _FriendsService extends Fake implements UnifiedFriendsService {
  _FriendsService(this.blockedUsers);

  @override
  final Set<String> blockedUsers;
}

const _creatorUid = 'creator-uid';

UserProfile _optedIn(String uid, String name) => UserProfile(
  uid: uid,
  displayName: name,
  email: '$uid@example.com',
  joinedAt: DateTime(2025, 1, 1),
  lastActiveAt: DateTime(2025, 1, 1),
  showNameOnSharedDishes: true,
);

Recipe _dish(String id, {String? createdBy}) => Recipe(
  core: RecipeCore(
    id: id,
    title: 'Rätt $id',
    description: '',
    ingredients: const [],
    instructions: const [],
    imageUrls: const [],
    mealType: 'Middag',
    createdBy: createdBy,
  ),
  type: RecipeType.personal,
);

SharedMenu _menu(List<Recipe> dishes, {String sharedBy = _creatorUid}) =>
    SharedMenu(
      id: 'menu-1',
      sharedByUserId: sharedBy,
      sharedByDisplayName: 'Sharer',
      menuTitle: 'Veckomeny',
      menuSnapshot: {'Middag': dishes},
    );

Future<MenuDishCreditViewModel> _loadedVm(SharedMenu menu) async {
  final vm = MenuDishCreditViewModel(
    menu: menu,
    userService: _UserService([
      UserProfile(
        uid: _creatorUid,
        displayName: 'Anna',
        email: 'a@example.com',
        joinedAt: DateTime(2025, 1, 1),
        lastActiveAt: DateTime(2025, 1, 1),
        showNameOnSharedDishes: true,
      ),
    ]),
    blockedUserIds: () => const {},
    viewerId: 'viewer-uid',
  );
  await vm.load();
  return vm;
}

Future<List<Object?>> _pump(
  WidgetTester tester,
  SharedMenu menu,
  MenuDishCreditViewModel vm,
) async {
  final pushed = <Object?>[];
  await tester.pumpWidget(
    createLocalizedTestApp(
      wrapInScaffold: false,
      child: Scaffold(
        body: CustomScrollView(
          slivers: [MenuPreviewDishes(sharedMenu: menu, credits: vm)],
        ),
      ),
      onGenerateRoute: (settings) {
        if (settings.name == Routes.publicProfile) {
          pushed.add(settings.arguments);
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const Scaffold(body: Text('PROFIL-SIDA')),
          );
        }
        return null;
      },
    ),
  );
  await tester.pump();
  return pushed;
}

void main() {
  setUp(() async {
    await GetIt.instance.reset();
  });

  tearDown(() async {
    prod.ServiceLocator.reset();
    await GetIt.instance.reset();
  });

  // The widget builds and loads its own view model here, so the real default
  // collaborators are resolved from the locator.
  Future<void> pumpWithLocator(
    WidgetTester tester,
    SharedMenu menu, {
    required Set<String> blocked,
  }) async {
    GetIt.instance.registerSingleton<UserService>(
      _UserService([
        _optedIn(_creatorUid, 'Anna'),
        _optedIn('bertil-uid', 'Bertil'),
        _optedIn('cecilia-uid', 'Cecilia'),
      ]),
    );
    GetIt.instance.registerSingleton<PermissionService>(
      FakePermissionService()..setPermissionState(currentUserId: 'viewer-uid'),
    );
    GetIt.instance.registerSingleton<UnifiedFriendsService>(
      _FriendsService(blocked),
    );
    prod.ServiceLocator.initialize(DIContainer());

    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScaffold: false,
        child: Scaffold(
          body: CustomScrollView(
            slivers: [MenuPreviewDishes(sharedMenu: menu)],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('without an injected view model it loads the sharer\'s credit '
      'and no one else\'s', (tester) async {
    final menu = _menu([
      _dish('a', createdBy: _creatorUid),
      _dish('b', createdBy: 'bertil-uid'),
      _dish('c', createdBy: 'cecilia-uid'),
    ]);
    await pumpWithLocator(tester, menu, blocked: {'cecilia-uid'});

    expect(find.text('Rätt a'), findsOneWidget);
    expect(find.text('Rätt b'), findsOneWidget);
    expect(find.text('Rätt c'), findsOneWidget);
    expect(find.text('Recept av Anna'), findsOneWidget);
    expect(find.text('Recept av Bertil'), findsNothing);
    expect(find.text('Recept av Cecilia'), findsNothing);
  });

  testWidgets('a blocked sharer gets no credit line', (tester) async {
    final menu = _menu([
      _dish('a', createdBy: 'cecilia-uid'),
    ], sharedBy: 'cecilia-uid');
    await pumpWithLocator(tester, menu, blocked: {'cecilia-uid'});

    expect(find.text('Rätt a'), findsOneWidget);
    expect(find.textContaining('Recept av'), findsNothing);
  });

  testWidgets('the credit line shows under the credited dish only', (
    tester,
  ) async {
    final menu = _menu([
      _dish('a', createdBy: _creatorUid),
      _dish('b', createdBy: 'unknown-creator'),
    ]);
    final vm = await _loadedVm(menu);
    addTearDown(vm.dispose);
    await _pump(tester, menu, vm);

    expect(find.text('Recept av Anna'), findsOneWidget);
    // Directly after the first dish's card, not after the second.
    final credit = tester.getTopLeft(find.text('Recept av Anna')).dy;
    expect(credit, greaterThan(tester.getTopLeft(find.text('Rätt a')).dy));
    expect(credit, lessThan(tester.getTopLeft(find.text('Rätt b')).dy));
  });

  testWidgets('a menu with no credited dish renders no credit line', (
    tester,
  ) async {
    final menu = _menu([_dish('a', createdBy: 'unknown-creator')]);
    final vm = await _loadedVm(menu);
    addTearDown(vm.dispose);
    await _pump(tester, menu, vm);

    expect(find.textContaining('Recept av'), findsNothing);
    expect(find.text('Rätt a'), findsOneWidget);
  });

  testWidgets('tapping the line opens that creator\'s public profile', (
    tester,
  ) async {
    final menu = _menu([_dish('a', createdBy: _creatorUid)]);
    final vm = await _loadedVm(menu);
    addTearDown(vm.dispose);
    final pushed = await _pump(tester, menu, vm);

    await tester.tap(find.text('Recept av Anna'));
    await tester.pumpAndSettle();

    expect(pushed, [_creatorUid]);
    expect(find.text('PROFIL-SIDA'), findsOneWidget);
  });

  testWidgets('the line is announced once, as a button', (tester) async {
    final handle = tester.ensureSemantics();
    try {
      final menu = _menu([_dish('a', createdBy: _creatorUid)]);
      final vm = await _loadedVm(menu);
      addTearDown(vm.dispose);
      await _pump(tester, menu, vm);

      final finder = find.bySemanticsLabel(RegExp('Öppna profilen'));
      expect(finder, findsOneWidget);
      final data = tester.getSemantics(finder).getSemanticsData();
      expect(data.flagsCollection.isButton, isTrue);
    } finally {
      handle.dispose();
    }
  });
}
