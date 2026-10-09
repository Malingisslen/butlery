/// BUT-2221: a dish on a shared menu gets its creator's name only when every
/// condition holds; every other path shows nothing rather than an error.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/profile_lookup.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/viewmodels/shared_content/menu_dish_credit_viewmodel.dart';

/// Answers `getUserProfiles` the way UserService does: a failed read is a
/// returned lookup with `unavailableIds`, never a throw.
class _RecordingUserService extends Fake implements UserService {
  _RecordingUserService({
    this.profiles = const [],
    this.unavailableIds = const {},
  });

  final List<UserProfile> profiles;
  final Set<String> unavailableIds;
  final List<List<String>> calls = [];

  @override
  Future<ProfileBatchLookup> getUserProfiles(List<String> userIds) async {
    calls.add(List.of(userIds));
    final unavailable = userIds.where(unavailableIds.contains).toSet();
    final found = profiles
        .where((p) => userIds.contains(p.uid) && !unavailable.contains(p.uid))
        .toList();
    final foundIds = found.map((p) => p.uid).toSet();
    return ProfileBatchLookup(
      profiles: found,
      missingIds: userIds
          .where((id) => !foundIds.contains(id) && !unavailable.contains(id))
          .toSet(),
      unavailableIds: unavailable,
    );
  }
}

const _sharer = 'sharer-uid';
const _viewer = 'viewer-uid';

UserProfile _profile(
  String uid, {
  String name = 'Anna',
  bool optedIn = true,
  bool isHidden = false,
}) => UserProfile(
  uid: uid,
  displayName: name,
  email: '$uid@example.com',
  joinedAt: DateTime(2025, 1, 1),
  lastActiveAt: DateTime(2025, 1, 1),
  showNameOnSharedDishes: optedIn,
  isHidden: isHidden,
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

SharedMenu _menu(List<Recipe> dishes) => SharedMenu(
  id: 'menu-1',
  sharedByUserId: _sharer,
  sharedByDisplayName: 'Sharer',
  menuTitle: 'Veckomeny',
  menuSnapshot: {'Middag': dishes},
);

Future<MenuDishCreditViewModel> _load(
  List<Recipe> dishes,
  _RecordingUserService service, {
  DishCreditScope scope = DishCreditScope.sharerOnly,
  Set<String> blocked = const {},
  String viewerId = _viewer,
}) async {
  final vm = MenuDishCreditViewModel(
    menu: _menu(dishes),
    scope: scope,
    userService: service,
    blockedUserIds: () => blocked,
    viewerId: viewerId,
  );
  addTearDown(vm.dispose);
  await vm.load();
  return vm;
}

void main() {
  group('MenuDishCreditViewModel', () {
    test('credits a dish whose sharer opted in', () async {
      final dish = _dish('a', createdBy: _sharer);
      final vm = await _load([
        dish,
      ], _RecordingUserService(profiles: [_profile(_sharer, name: ' Anna ')]));

      final credit = vm.creditFor(dish);
      expect(credit, isNotNull);
      expect(credit!.userId, _sharer);
      expect(credit.displayName, 'Anna');
    });

    test('notifies listeners when a credit arrives', () async {
      final dish = _dish('a', createdBy: _sharer);
      final vm = MenuDishCreditViewModel(
        menu: _menu([dish]),
        userService: _RecordingUserService(profiles: [_profile(_sharer)]),
        blockedUserIds: () => const {},
        viewerId: _viewer,
      );
      addTearDown(vm.dispose);
      var notifications = 0;
      vm.addListener(() => notifications++);

      await vm.load();

      expect(notifications, 1);
    });

    test('no credit when the creator has not opted in', () async {
      final dish = _dish('a', createdBy: _sharer);
      final vm = await _load([
        dish,
      ], _RecordingUserService(profiles: [_profile(_sharer, optedIn: false)]));

      expect(vm.creditFor(dish), isNull);
    });

    test('no credit when the profile does not exist', () async {
      final dish = _dish('a', createdBy: _sharer);
      final service = _RecordingUserService();
      final vm = await _load([dish], service);

      expect(service.calls, hasLength(1));
      expect(vm.creditFor(dish), isNull);
    });

    test('no credit when the profile read is reported unavailable', () async {
      final dish = _dish('a', createdBy: _sharer);
      final vm = await _load([
        dish,
      ], _RecordingUserService(unavailableIds: {_sharer}));

      expect(vm.creditFor(dish), isNull);
      expect(vm.hasError, isFalse);
    });

    test('no credit when the profile is hidden by moderation', () async {
      final dish = _dish('a', createdBy: _sharer);
      final vm = await _load([
        dish,
      ], _RecordingUserService(profiles: [_profile(_sharer, isHidden: true)]));

      expect(vm.creditFor(dish), isNull);
    });

    test('no credit when the display name is blank', () async {
      final dish = _dish('a', createdBy: _sharer);
      final vm = await _load([
        dish,
      ], _RecordingUserService(profiles: [_profile(_sharer, name: '   ')]));

      expect(vm.creditFor(dish), isNull);
    });

    test('no credit and no read when the creator is blocked', () async {
      final dish = _dish('a', createdBy: _sharer);
      final service = _RecordingUserService(profiles: [_profile(_sharer)]);
      final vm = await _load([dish], service, blocked: {_sharer});

      expect(vm.creditFor(dish), isNull);
      expect(service.calls, isEmpty);
    });

    test('a block on someone else does not remove the credit', () async {
      final dish = _dish('a', createdBy: _sharer);
      final vm = await _load(
        [dish],
        _RecordingUserService(profiles: [_profile(_sharer)]),
        blocked: {'somebody-else'},
      );

      expect(vm.creditFor(dish), isNotNull);
    });

    for (final id in <String?>[null, '', 'deleted', 'users/other']) {
      test(
        'createdBy ${id == null ? 'null' : "'$id'"} is not a creator',
        () async {
          final dish = _dish('a', createdBy: id);
          final service = _RecordingUserService(
            profiles: [_profile(id ?? 'x'), _profile('deleted')],
          );
          final vm = await _load(
            [dish],
            service,
            scope: DishCreditScope.everyCreator,
          );

          expect(vm.creditFor(dish), isNull);
          expect(service.calls, isEmpty);
        },
      );
    }

    test('the viewer is never credited on their own dish', () async {
      final dish = _dish('a', createdBy: _viewer);
      final service = _RecordingUserService(profiles: [_profile(_viewer)]);
      final vm = await _load(
        [dish],
        service,
        scope: DishCreditScope.everyCreator,
      );

      expect(vm.creditFor(dish), isNull);
      expect(service.calls, isEmpty);
    });

    test(
      'more than ten distinct creators: no credit for anyone, no read',
      () async {
        final ids = [for (var i = 0; i < 11; i++) 'creator-$i'];
        final dishes = [for (final id in ids) _dish(id, createdBy: id)];
        final service = _RecordingUserService(
          profiles: [for (final id in ids) _profile(id)],
        );
        final vm = await _load(
          dishes,
          service,
          scope: DishCreditScope.everyCreator,
        );

        expect(service.calls, isEmpty);
        for (final dish in dishes) {
          expect(vm.creditFor(dish), isNull);
        }
      },
    );

    test('exactly ten distinct creators are all credited', () async {
      final ids = [for (var i = 0; i < 10; i++) 'creator-$i'];
      final dishes = [for (final id in ids) _dish(id, createdBy: id)];
      final service = _RecordingUserService(
        profiles: [for (final id in ids) _profile(id, name: 'N-$id')],
      );
      final vm = await _load(
        dishes,
        service,
        scope: DishCreditScope.everyCreator,
      );

      expect(service.calls, hasLength(1));
      for (final dish in dishes) {
        expect(vm.creditFor(dish)?.displayName, 'N-${dish.createdBy}');
      }
    });

    test('sharerOnly ignores another creator even if they opted in', () async {
      final theirs = _dish('a', createdBy: 'other-creator');
      final mine = _dish('b', createdBy: _sharer);
      final service = _RecordingUserService(
        profiles: [
          _profile('other-creator', name: 'Bo'),
          _profile(_sharer),
        ],
      );
      final vm = await _load([theirs, mine], service);

      expect(vm.creditFor(theirs), isNull);
      expect(vm.creditFor(mine), isNotNull);
      expect(service.calls.single, [_sharer]);
    });

    test('everyCreator credits a forwarded dish by another creator', () async {
      final theirs = _dish('a', createdBy: 'other-creator');
      final vm = await _load(
        [theirs],
        _RecordingUserService(
          profiles: [_profile('other-creator', name: 'Bo')],
        ),
        scope: DishCreditScope.everyCreator,
      );

      expect(vm.creditFor(theirs)?.displayName, 'Bo');
    });

    test('three dishes by one creator cost one read of one id', () async {
      final dishes = [
        for (final id in ['a', 'b', 'c']) _dish(id, createdBy: _sharer),
      ];
      final service = _RecordingUserService(profiles: [_profile(_sharer)]);
      final vm = await _load(dishes, service);

      expect(service.calls, [
        [_sharer],
      ]);
      for (final dish in dishes) {
        expect(vm.creditFor(dish)?.userId, _sharer);
      }
    });
  });
}
