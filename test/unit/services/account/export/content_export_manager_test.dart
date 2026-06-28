/// Direct unit tests for [ContentExportManager] (BUT-1438, BUT-1401 follow-up).
///
/// Proves the GDPR Article-15/20 *content* export contract across every
/// record type this manager owns: recipes (personal + unified), menus
/// (personal + shared), shopping lists with items, personal tags, personal
/// tag groups, cook snaps, cook events, pantry items, activity events,
/// weekly menu plans, and group weekly menu plans. Each method must surface
/// its record-type key with rows reshaped (source `id` → typed id key,
/// payload under `data`) and a `total_count`. A dropped type would fail a
/// key assertion here while the assembled bundle stayed green.
///
/// Mocking: every dependency is a constructor seam, so we inject `Fake`
/// repos returning canned rows — no emulator, no ServiceLocator. The recipe
/// repo fake must `implement FirebaseRecipeRepository` because the manager
/// gates recipe export on an `is FirebaseRecipeRepository` check.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/repositories/firebase/firebase_data_export_repository.dart';
import 'package:butlery/repositories/firebase/firebase_personal_tag_group_repository.dart';
import 'package:butlery/repositories/firebase/firebase_personal_tag_repository.dart';
import 'package:butlery/repositories/firebase/firebase_recipe_repository.dart';
import 'package:butlery/repositories/interfaces/activity_event_repository.dart';
import 'package:butlery/repositories/interfaces/cook_event_repository.dart';
import 'package:butlery/repositories/interfaces/cook_snap_repository.dart';
import 'package:butlery/repositories/interfaces/group_weekly_menu_plan_repository.dart';
import 'package:butlery/repositories/interfaces/pantry_repository.dart';
import 'package:butlery/repositories/interfaces/weekly_menu_plan_repository.dart';
import 'package:butlery/services/account/export/content_export_manager.dart';

class _FakeRecipeRepository extends Fake implements FirebaseRecipeRepository {
  _FakeRecipeRepository({this.personal = const [], this.unified = const []});
  final List<Map<String, dynamic>> personal;
  final List<Map<String, dynamic>> unified;

  @override
  Future<List<Map<String, dynamic>>> exportPersonalRecipesByUser(
    String userId, {
    int maxDocuments = 1000,
  }) async => personal;

  @override
  Future<List<Map<String, dynamic>>> exportTopLevelRecipesByOwner(
    String userId, {
    int maxDocuments = 1000,
  }) async => unified;
}

class _FakeDataExportRepository extends Fake
    implements FirebaseDataExportRepository {
  _FakeDataExportRepository({
    this.personalMenus = const [],
    this.sharedMenus = const [],
    this.shoppingLists = const [],
  });
  final List<Map<String, dynamic>> personalMenus;
  final List<Map<String, dynamic>> sharedMenus;
  final List<Map<String, dynamic>> shoppingLists;

  @override
  Future<List<Map<String, dynamic>>> exportPersonalMenus(
    String userId, {
    int maxDocuments = 1000,
  }) async => personalMenus;

  @override
  Future<List<Map<String, dynamic>>> exportSharedMenusByOwner(
    String userId, {
    int maxDocuments = 1000,
  }) async => sharedMenus;

  @override
  Future<List<Map<String, dynamic>>> exportPersonalShoppingLists(
    String userId, {
    int maxLists = 1000,
    int maxItemsPerList = 500,
  }) async => shoppingLists;
}

class _FakePersonalTagRepository extends Fake
    implements FirebasePersonalTagRepository {
  _FakePersonalTagRepository(this.rows);
  final List<Map<String, dynamic>> rows;

  @override
  Future<List<Map<String, dynamic>>> exportAllByUser(
    String userId, {
    int maxDocuments = 1000,
  }) async => rows;
}

class _FakePersonalTagGroupRepository extends Fake
    implements FirebasePersonalTagGroupRepository {
  _FakePersonalTagGroupRepository(this.rows);
  final List<Map<String, dynamic>> rows;

  @override
  Future<List<Map<String, dynamic>>> exportAllByUser(
    String userId, {
    int maxDocuments = 1000,
  }) async => rows;
}

class _FakeCookSnapRepository extends Fake implements CookSnapRepository {
  _FakeCookSnapRepository(this.rows);
  final List<Map<String, dynamic>> rows;

  @override
  Future<List<Map<String, dynamic>>> exportCookSnapsByUser(
    String userId, {
    int maxDocuments = 1000,
  }) async => rows;
}

class _FakeCookEventRepository extends Fake implements CookEventRepository {
  _FakeCookEventRepository(this.rows);
  final List<Map<String, dynamic>> rows;

  @override
  Future<List<Map<String, dynamic>>> exportCookEventsByUser(
    String userId, {
    int? limit,
  }) async => rows;
}

class _FakePantryRepository extends Fake implements PantryRepository {
  _FakePantryRepository(this.rows);
  final List<Map<String, dynamic>> rows;

  @override
  Future<List<Map<String, dynamic>>> exportAllByUser(
    String userId, {
    int maxDocuments = 1000,
  }) async => rows;
}

class _FakeActivityEventRepository extends Fake
    implements ActivityEventRepository {
  _FakeActivityEventRepository(this.rows);
  final List<Map<String, dynamic>> rows;

  @override
  Future<List<Map<String, dynamic>>> exportEventsByUser(
    String userId, {
    int maxDocuments = 1000,
  }) async => rows;
}

class _FakeWeeklyMenuPlanRepository extends Fake
    implements WeeklyMenuPlanRepository {
  _FakeWeeklyMenuPlanRepository(this.rows);
  final List<Map<String, dynamic>> rows;

  @override
  Future<List<Map<String, dynamic>>> exportAllByUser(
    String userId, {
    int maxDocuments = 260,
  }) async => rows;
}

class _FakeGroupWeeklyMenuPlanRepository extends Fake
    implements GroupWeeklyMenuPlanRepository {
  _FakeGroupWeeklyMenuPlanRepository(this.rows);
  final List<Map<String, dynamic>> rows;

  @override
  Future<List<Map<String, dynamic>>> exportPlansForParticipant(
    String userId, {
    int maxDocuments = 260,
  }) async => rows;
}

ContentExportManager _manager({
  _FakeRecipeRepository? recipes,
  _FakeDataExportRepository? exports,
  List<Map<String, dynamic>> personalTags = const [],
  List<Map<String, dynamic>> personalTagGroups = const [],
  List<Map<String, dynamic>> cookSnaps = const [],
  List<Map<String, dynamic>> cookEvents = const [],
  List<Map<String, dynamic>> pantry = const [],
  List<Map<String, dynamic>> activityEvents = const [],
  List<Map<String, dynamic>> weeklyMenus = const [],
  List<Map<String, dynamic>> groupMenus = const [],
}) {
  return ContentExportManager(
    recipeRepository: recipes ?? _FakeRecipeRepository(),
    dataExportRepository: exports ?? _FakeDataExportRepository(),
    personalTagRepository: _FakePersonalTagRepository(personalTags),
    personalTagGroupRepository: _FakePersonalTagGroupRepository(
      personalTagGroups,
    ),
    cookSnapRepository: _FakeCookSnapRepository(cookSnaps),
    cookEventRepository: _FakeCookEventRepository(cookEvents),
    pantryRepository: _FakePantryRepository(pantry),
    activityEventRepository: _FakeActivityEventRepository(activityEvents),
    weeklyMenuPlanRepository: _FakeWeeklyMenuPlanRepository(weeklyMenus),
    groupWeeklyMenuPlanRepository: _FakeGroupWeeklyMenuPlanRepository(
      groupMenus,
    ),
  );
}

void main() {
  group('ContentExportManager.exportRecipes (BUT-1438)', () {
    test('includes personal and unified recipes, each typed', () async {
      final manager = _manager(
        recipes: _FakeRecipeRepository(
          personal: [
            {
              'id': 'rp1',
              'data': {'title': 'Soup'},
            },
          ],
          unified: [
            {
              'id': 'ru1',
              'data': {'title': 'Stew'},
            },
          ],
        ),
      );

      final result = await manager.exportRecipes('user-uid');

      // Guard the runtime `is FirebaseRecipeRepository` branch (production
      // line ~93): if the fake ever stopped satisfying that check, the export
      // branch would be skipped silently and `recipes` would be empty — a
      // false green. A non-empty recipes list proves the branch ran.
      expect(
        result['recipes'],
        isNotEmpty,
        reason: 'the is-FirebaseRecipeRepository export branch must have run',
      );
      // Order is deterministic: personal recipes are appended before unified.
      expect(result['recipes'], [
        {
          'recipe_id': 'rp1',
          'type': 'personal',
          'data': {'title': 'Soup'},
        },
        {
          'recipe_id': 'ru1',
          'type': 'unified',
          'data': {'title': 'Stew'},
        },
      ]);
      expect(result['total_count'], 2);
    });
  });

  group('ContentExportManager.exportMenus (BUT-1438)', () {
    test('includes personal and shared-by-owner menus', () async {
      final manager = _manager(
        exports: _FakeDataExportRepository(
          personalMenus: [
            {
              'id': 'm1',
              'data': {'name': 'Personal'},
            },
          ],
          sharedMenus: [
            {
              'id': 'm2',
              'data': {'name': 'Shared'},
            },
          ],
        ),
      );

      final result = await manager.exportMenus('user-uid');

      // Order is deterministic: personal menus are appended before shared.
      expect(result['menus'], [
        {
          'menu_id': 'm1',
          'data': {'name': 'Personal'},
        },
        {
          'menu_id': 'm2',
          'type': 'shared',
          'data': {'name': 'Shared'},
        },
      ]);
      expect(result['total_count'], 2);
    });
  });

  group('ContentExportManager.exportShoppingLists (BUT-1438)', () {
    test('includes lists with their nested items reshaped', () async {
      final manager = _manager(
        exports: _FakeDataExportRepository(
          shoppingLists: [
            {
              'id': 'list1',
              'data': {'name': 'Groceries'},
              'items': [
                {
                  'id': 'item1',
                  'data': {'name': 'Milk'},
                },
              ],
            },
          ],
        ),
      );

      final result = await manager.exportShoppingLists('user-uid');

      final lists = result['shopping_lists'] as List;
      expect(lists, hasLength(1));
      final list = lists.single as Map<String, dynamic>;
      expect(list['list_id'], 'list1');
      expect(list['list_info'], {'name': 'Groceries'});
      expect(list['items'], [
        {
          'item_id': 'item1',
          'data': {'name': 'Milk'},
        },
      ]);
      expect(result['total_count'], 1);
    });
  });

  group('ContentExportManager — single-collection record types (BUT-1438)', () {
    test(
      'exportPersonalTags includes tag records under personal_tags',
      () async {
        final manager = _manager(
          personalTags: [
            {
              'id': 't1',
              'data': {'name': 'Quick'},
            },
          ],
        );

        final result = await manager.exportPersonalTags('user-uid');

        expect(result['personal_tags'], [
          {
            'tag_id': 't1',
            'data': {'name': 'Quick'},
          },
        ]);
        expect(result['total_count'], 1);
      },
    );

    test('exportPersonalTagGroups includes group records', () async {
      final manager = _manager(
        personalTagGroups: [
          {
            'id': 'g1',
            'data': {'name': 'Cuisine'},
          },
        ],
      );

      final result = await manager.exportPersonalTagGroups('user-uid');

      expect(result['personal_tag_groups'], [
        {
          'group_id': 'g1',
          'data': {'name': 'Cuisine'},
        },
      ]);
      expect(result['total_count'], 1);
    });

    test('exportCookSnaps includes snap records', () async {
      final manager = _manager(
        cookSnaps: [
          {
            'id': 's1',
            'data': {'photo': 'url'},
          },
        ],
      );

      final result = await manager.exportCookSnaps('user-uid');

      expect(result['cook_snaps'], [
        {
          'snap_id': 's1',
          'data': {'photo': 'url'},
        },
      ]);
      expect(result['total_count'], 1);
    });

    test('exportCookEvents includes cook-event records', () async {
      final manager = _manager(
        cookEvents: [
          {
            'id': 'e1',
            'data': {'recipeId': 'r1'},
          },
        ],
      );

      final result = await manager.exportCookEvents('user-uid');

      expect(result['recipe_cook_events'], [
        {
          'event_id': 'e1',
          'data': {'recipeId': 'r1'},
        },
      ]);
      expect(result['total_count'], 1);
    });

    test('exportPantryItems includes pantry records', () async {
      final manager = _manager(
        pantry: [
          {
            'id': 'p1',
            'data': {'name': 'Flour'},
          },
        ],
      );

      final result = await manager.exportPantryItems('user-uid');

      expect(result['pantry_items'], [
        {
          'item_id': 'p1',
          'data': {'name': 'Flour'},
        },
      ]);
      expect(result['total_count'], 1);
    });

    test('exportActivityEvents includes activity-event records', () async {
      final manager = _manager(
        activityEvents: [
          {
            'id': 'a1',
            'data': {'kind': 'view'},
          },
        ],
      );

      final result = await manager.exportActivityEvents('user-uid');

      expect(result['activity_events'], [
        {
          'event_id': 'a1',
          'data': {'kind': 'view'},
        },
      ]);
      expect(result['total_count'], 1);
    });

    test('exportWeeklyMenuPlans includes plan records', () async {
      final manager = _manager(
        weeklyMenus: [
          {
            'id': 'w1',
            'data': {'week': 22},
          },
        ],
      );

      final result = await manager.exportWeeklyMenuPlans('user-uid');

      expect(result['weekly_menu_plans'], [
        {
          'plan_id': 'w1',
          'data': {'week': 22},
        },
      ]);
      expect(result['total_count'], 1);
    });

    test(
      'exportGroupWeeklyMenuPlans includes participant plan records',
      () async {
        final manager = _manager(
          groupMenus: [
            {
              'id': 'gw1',
              'data': {'groupId': 'grp1'},
            },
          ],
        );

        final result = await manager.exportGroupWeeklyMenuPlans('user-uid');

        expect(result['group_weekly_menu_plans'], [
          {
            'plan_id': 'gw1',
            'data': {'groupId': 'grp1'},
          },
        ]);
        expect(result['total_count'], 1);
      },
    );
  });
}
