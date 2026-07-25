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

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
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
import 'package:butlery/services/account/export/export_pagination_helper.dart';

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
  int? capturedMaxLists;

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

  // Sentinel default (NOT the real 1000), same reasoning as
  // `_FakePantryRepository`: shopping lists is the ONE migrated section whose
  // fetch parameter is named `maxLists` rather than `maxDocuments`, so it is
  // the likeliest place for the cap to stop being forwarded. A realistic
  // default would let that regression pass.
  @override
  Future<List<Map<String, dynamic>>> exportPersonalShoppingLists(
    String userId, {
    int maxLists = -1,
    int maxItemsPerList = 500,
  }) async {
    capturedMaxLists = maxLists;
    return shoppingLists;
  }
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
  int? capturedMaxDocuments;

  // Sentinel default (NOT the real 1000): Dart fills in the callee's default
  // when the caller omits a named arg, so if production ever stops passing
  // `maxDocuments`, capturedMaxDocuments becomes -1 and the forwarding test
  // fails. A 1000 default here would make that test pass either way (the
  // computed limit is also 1000) — the exact false-green BUT-1440 guards.
  @override
  Future<List<Map<String, dynamic>>> exportAllByUser(
    String userId, {
    int maxDocuments = -1,
  }) async {
    capturedMaxDocuments = maxDocuments;
    return rows;
  }
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

Map<String, dynamic> _recipeRow(String prefix, int i) => {
  'id': '$prefix$i',
  'data': {'title': 'r$i'},
};

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

    test(
      'forwards the N+1 probe size to the repo\'s maxLists parameter '
      '(BUT-1662)',
      () async {
        // Shopping lists is the only section whose fetch parameter is named
        // `maxLists`, not `maxDocuments` — a rename-shaped slip here would
        // silently drop the cap to the repo default and break the truncation
        // probe. Paired with the sentinel default on the fake, this fails if
        // production stops forwarding.
        final exports = _FakeDataExportRepository();
        final manager = _manager(exports: exports);

        await manager.exportShoppingLists('user-uid');

        expect(
          exports.capturedMaxLists,
          ExportPaginationHelper.getLimitForType('shopping_lists') + 1,
        );
      },
    );

    // A Timestamp on the list document used to reach the encoder untouched.
    // `jsonEncode` in DataExportService is NOT inside a try/catch, so one such
    // field threw JsonUnsupportedObjectError out of the WHOLE GDPR export,
    // not just this section.
    test(
      'sanitizes list_info so a Timestamp cannot break jsonEncode',
      () async {
        final manager = _manager(
          exports: _FakeDataExportRepository(
            shoppingLists: [
              {
                'id': 'list1',
                'data': {
                  'name': 'Groceries',
                  'createdAt': Timestamp.fromDate(DateTime.utc(2026, 7, 25)),
                },
                'items': const <Map<String, dynamic>>[],
              },
            ],
          ),
        );

        final result = await manager.exportShoppingLists('user-uid');

        final list = (result['shopping_lists'] as List).single as Map;
        final info = list['list_info'] as Map;
        expect(info['name'], 'Groceries');
        expect(info['createdAt'], isNot(isA<Timestamp>()));
        expect(() => jsonEncode(result), returnsNormally);
      },
    );
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

    test(
      'exportPantryItems forwards its computed limit to the repo (BUT-1440)',
      () async {
        // Regression guard: pantry was the lone export method that computed
        // its limit (for the `truncated` flag) but did not pass it to the
        // repo, so the repo silently fell back to its own default. The two
        // values coincide today (both 1000) but could diverge.
        //
        // BUT-1662: the forwarded value is now cap + 1 — the N+1 truncation
        // probe fetches one past the cap so a complete export of exactly `cap`
        // rows stays distinguishable from a clipped one.
        final pantryRepo = _FakePantryRepository(const []);
        final manager = ContentExportManager(
          recipeRepository: _FakeRecipeRepository(),
          dataExportRepository: _FakeDataExportRepository(),
          personalTagRepository: _FakePersonalTagRepository(const []),
          personalTagGroupRepository: _FakePersonalTagGroupRepository(const []),
          cookSnapRepository: _FakeCookSnapRepository(const []),
          cookEventRepository: _FakeCookEventRepository(const []),
          pantryRepository: pantryRepo,
          activityEventRepository: _FakeActivityEventRepository(const []),
          weeklyMenuPlanRepository: _FakeWeeklyMenuPlanRepository(const []),
          groupWeeklyMenuPlanRepository: _FakeGroupWeeklyMenuPlanRepository(
            const [],
          ),
        );

        await manager.exportPantryItems('user-uid');

        expect(
          pantryRepo.capturedMaxDocuments,
          ExportPaginationHelper.getLimitForType('pantry_items') + 1,
        );
      },
    );

    test(
      'exportPantryItems flags truncated only when rows were actually '
      'omitted (BUT-1662)',
      () async {
        // Boundary contract: below the cap and EXACTLY at the cap the export
        // is complete, so `truncated` must be absent — the pre-BUT-1662
        // `length >= cap` test stamped a complete cap-sized export as
        // truncated, a false incompleteness claim on a GDPR bundle. Only when
        // the source holds more than the cap (the N+1 probe returns cap + 1)
        // may the flag appear, and the payload is trimmed back to the cap.
        // The fake echoes whatever rows it is given, so we can drive all three
        // sides of the boundary directly. The cap is DERIVED: re-tuning it is a
        // config change, not a behaviour regression, and must not fail here.
        final cap = ExportPaginationHelper.getLimitForType('pantry_items');
        Map<String, dynamic> row(int i) => {
          'id': 'p$i',
          'data': {'name': 'item$i'},
        };

        final belowCap = _manager(
          pantry: List.generate(3, row),
        );
        final belowResult = await belowCap.exportPantryItems('user-uid');
        expect(belowResult.containsKey('truncated'), isFalse);
        expect(belowResult['total_count'], 3);

        final atCap = _manager(
          pantry: List.generate(cap, row),
        );
        final atResult = await atCap.exportPantryItems('user-uid');
        expect(atResult.containsKey('truncated'), isFalse);
        expect(atResult['total_count'], cap);

        final overCap = _manager(
          pantry: List.generate(cap + 1, row),
        );
        final overResult = await overCap.exportPantryItems('user-uid');
        expect(overResult['truncated'], isTrue);
        expect(overResult['total_count'], cap);
      },
    );

    test(
      'exportRecipes does not stamp truncated when two complete sub-queries '
      'happen to sum past the cap (BUT-1662)',
      () async {
        // The recipe cap applies PER sub-query — personal and top-level are
        // separate Firestore reads. Comparing the MERGED length to one cap
        // stamped a fully complete export as truncated as soon as the two
        // halves added up past it. Each leg here holds three quarters of the
        // cap: neither is clipped, but together they exceed it.
        final cap = ExportPaginationHelper.getLimitForType('recipes');
        final perLeg = (cap * 3) ~/ 4;
        expect(perLeg, lessThanOrEqualTo(cap), reason: 'fixture premise');
        expect(perLeg * 2, greaterThan(cap), reason: 'fixture premise');

        final manager = _manager(
          recipes: _FakeRecipeRepository(
            personal: List.generate(perLeg, (i) => _recipeRow('p', i)),
            unified: List.generate(perLeg, (i) => _recipeRow('u', i)),
          ),
        );

        final result = await manager.exportRecipes('user-uid');

        expect(result['total_count'], perLeg * 2);
        expect(result.containsKey('truncated'), isFalse);
      },
    );

    test(
      'exportRecipes stamps truncated when the personal-recipe leg clipped '
      '(BUT-1662)',
      () async {
        // Positive control for the OR: without it the "sum past the cap"
        // test above passes even if the flag were dropped from exportRecipes
        // entirely — and a clipped bundle silently claiming completeness is
        // the dangerous direction for Art. 15.
        final cap = ExportPaginationHelper.getLimitForType('recipes');

        final manager = _manager(
          recipes: _FakeRecipeRepository(
            personal: List.generate(cap + 1, (i) => _recipeRow('p', i)),
            unified: [_recipeRow('u', 0)],
          ),
        );

        final result = await manager.exportRecipes('user-uid');

        expect(result['truncated'], isTrue);
        // Personal trimmed back to the cap; the intact unified leg still lands.
        expect(result['total_count'], cap + 1);
        expect((result['recipes'] as List).last, {
          'recipe_id': 'u0',
          'type': 'unified',
          'data': {'title': 'r0'},
        });
      },
    );

    test(
      'exportRecipes stamps truncated when only the top-level leg clipped '
      '(BUT-1662)',
      () async {
        // The second half of the OR: a regression keeping only
        // `personal.truncated` would leave the test above green.
        final cap = ExportPaginationHelper.getLimitForType('recipes');

        final manager = _manager(
          recipes: _FakeRecipeRepository(
            personal: [_recipeRow('p', 0)],
            unified: List.generate(cap + 1, (i) => _recipeRow('u', i)),
          ),
        );

        final result = await manager.exportRecipes('user-uid');

        expect(result['truncated'], isTrue);
        expect(result['total_count'], cap + 1);
      },
    );

    test(
      'exportMenus stamps truncated when only the personal-menu leg clipped '
      '(BUT-1662)',
      () async {
        // First half of the menus OR. Without it, an expression collapsed to
        // `shared.truncated` alone stays green — covering only the LAST leg
        // catches collapse-to-first but never collapse-to-last.
        final cap = ExportPaginationHelper.getLimitForType('menus');

        final manager = _manager(
          exports: _FakeDataExportRepository(
            personalMenus: List.generate(
              cap + 1,
              (i) => {
                'id': 'p$i',
                'data': {'name': 'Personal$i'},
              },
            ),
            sharedMenus: [
              {
                'id': 's1',
                'data': {'name': 'Shared'},
              },
            ],
          ),
        );

        final result = await manager.exportMenus('user-uid');

        expect(result['truncated'], isTrue);
        // Personal trimmed back to the cap; the intact shared leg still lands.
        expect(result['total_count'], cap + 1);
        expect((result['menus'] as List).last, {
          'menu_id': 's1',
          'type': 'shared',
          'data': {'name': 'Shared'},
        });
      },
    );

    test(
      'exportMenus stamps truncated when only the shared-menu leg clipped '
      '(BUT-1662)',
      () async {
        // Second half of the menus OR: a regression keeping only
        // `personal.truncated` would leave the test above green.
        final cap = ExportPaginationHelper.getLimitForType('menus');

        final manager = _manager(
          exports: _FakeDataExportRepository(
            personalMenus: [
              {
                'id': 'm1',
                'data': {'name': 'Personal'},
              },
            ],
            sharedMenus: List.generate(
              cap + 1,
              (i) => {
                'id': 's$i',
                'data': {'name': 'Shared$i'},
              },
            ),
          ),
        );

        final result = await manager.exportMenus('user-uid');

        expect(result['truncated'], isTrue);
        expect(result['total_count'], cap + 1);
      },
    );

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
