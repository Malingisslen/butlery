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
import 'package:butlery/services/account/export/shared_shopping_list_export.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';

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
    this.sharedOwned = const [],
    this.sharedMember = const [],
    this.sharedContributor = const [],
    this.contributorProbeError,
  });
  final List<Map<String, dynamic>> personalMenus;
  final List<Map<String, dynamic>> sharedMenus;
  final List<Map<String, dynamic>> shoppingLists;
  // BUT-1732: the three shared-list probes, mirroring the deletion cascade's.
  final List<Map<String, dynamic>> sharedOwned;
  final List<Map<String, dynamic>> sharedMember;
  final List<Map<String, dynamic>> sharedContributor;

  /// The exact failure the contributor probe raises, not a bool. The section
  /// branches on WHICH error arrived — a rules refusal is a documented,
  /// expected gap ("you have left these lists"), anything else is an unproven
  /// completeness claim that has to reach `export_metadata.warnings`. A boolean
  /// flag can only ever stage one of those two, which is how the refusal
  /// predicate came to be deletable with the suite green.
  final Object? contributorProbeError;
  int? capturedMaxLists;

  @override
  Future<List<Map<String, dynamic>>> exportSharedShoppingListsOwned(
    String userId, {
    int maxDocuments = 500,
  }) async => sharedOwned;

  @override
  Future<List<Map<String, dynamic>>> exportSharedShoppingListsAsMember(
    String userId, {
    int maxDocuments = 500,
  }) async => sharedMember;

  @override
  Future<List<Map<String, dynamic>>> exportSharedShoppingListsAsContributor(
    String userId, {
    int maxDocuments = 500,
  }) async {
    if (contributorProbeError != null) {
      throw contributorProbeError!;
    }
    return sharedContributor;
  }

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

  // BUT-1732. `exportShoppingLists` only ever read the PERSONAL subcollection,
  // so a household that shops from a shared list had its entire shopping
  // history missing from the Article-15 bundle — while the deletion cascade
  // scrubs exactly those documents under Article 17.
  group('exportSharedShoppingLists', () {
    Map<String, dynamic> sharedDoc({
      required String id,
      required String ownerId,
    }) => {
      'id': id,
      'data': {
        'name': 'Veckans handla',
        'ownerId': ownerId,
        'ownerDisplayName': 'Alice A',
        'memberPermissions': {'alice': 'admin', 'bob': 'edit'},
        'contributorUserIds': ['alice', 'bob'],
        'lastActivityByUserId': 'bob',
        'lastActivityByDisplayName': 'Bob B',
        'items': [
          {
            'id': 'i1',
            'name': 'Mjölk',
            'addedByUserId': 'alice',
            'addedByDisplayName': 'Alice A',
          },
          {
            'id': 'i2',
            'name': 'Bröd',
            'addedByUserId': 'bob',
            'addedByDisplayName': 'Bob B',
            'assignedToUserId': 'bob',
            'assignedToDisplayName': 'Bob B',
            // BUT-1732 review: the two fields the first minimisation map
            // MISSED. They are stamped on every tick of a shared list
            // (`markAsBought`), which makes them the most frequently populated
            // attribution fields on the collection — and the bundle's own
            // data_minimisation line claimed they were dropped.
            'purchasedByUserId': 'bob',
            'purchasedByDisplayName': 'Bob B',
            'lastModifiedByUserId': 'bob',
            'lastModifiedByDisplayName': 'Bob B',
          },
        ],
      },
    };

    test('merges the three probes and records every role', () async {
      final manager = _manager(
        exports: _FakeDataExportRepository(
          sharedOwned: [sharedDoc(id: 'l1', ownerId: 'alice')],
          sharedMember: [
            sharedDoc(id: 'l1', ownerId: 'alice'),
            sharedDoc(id: 'l2', ownerId: 'bob'),
          ],
          sharedContributor: [sharedDoc(id: 'l2', ownerId: 'bob')],
        ),
      );

      final result = await manager.exportSharedShoppingLists('alice');

      expect(result['total_count'], 2, reason: 'l1 appears in two probes');
      final byId = {
        for (final list in result['shared_shopping_lists'] as List)
          (list as Map)['list_id']: list,
      };
      expect(byId['l1']!['your_roles'], ['member', 'owner']);
      expect(byId['l2']!['your_roles'], ['contributor', 'member']);
    });

    // The minimisation contract, asserted as ABSENCE of the other member's
    // name and PRESENCE of their uid — the BUT-1450 balance. Asserting the row
    // is merely non-null would pass against a manager that copied the document
    // through untouched.
    test('drops other members\' names and keeps their ids', () async {
      final manager = _manager(
        exports: _FakeDataExportRepository(
          sharedOwned: [sharedDoc(id: 'l1', ownerId: 'alice')],
        ),
      );

      final result = await manager.exportSharedShoppingLists('alice');
      final list = (result['shared_shopping_lists'] as List).single as Map;
      final info = list['list_info'] as Map;
      final items = {
        for (final row in list['items'] as List)
          (row as Map)['item_id']: (row['data'] as Map),
      };

      // Alice's own cached name is her own record, so it stays.
      expect(info['ownerDisplayName'], 'Alice A');
      expect(items['i1']!['addedByDisplayName'], 'Alice A');

      // Bob's is another data subject's profile.
      expect(info.containsKey('lastActivityByDisplayName'), isFalse);
      expect(info['lastActivityByUserId'], 'bob');
      expect(items['i2']!.containsKey('addedByDisplayName'), isFalse);
      expect(items['i2']!.containsKey('assignedToDisplayName'), isFalse);
      expect(items['i2']!.containsKey('purchasedByDisplayName'), isFalse);
      expect(items['i2']!.containsKey('lastModifiedByDisplayName'), isFalse);
      expect(items['i2']!['addedByUserId'], 'bob');
      expect(items['i2']!['purchasedByUserId'], 'bob');
      expect(items['i2']!['lastModifiedByUserId'], 'bob');
      expect(items['i2']!['name'], 'Bröd', reason: 'the row itself stays');

      // Access control is the requester's own record too.
      expect((info['memberPermissions'] as Map).keys, contains('bob'));
      expect(result['data_minimisation'], isNotNull);
      expect(info.containsKey('items'), isFalse);
    });

    // BUT-1732 review: the map enumerated FOUR of the six persisted
    // `*DisplayName` fields, so the two most frequently written ones shipped
    // raw while the bundle claimed otherwise. Enumeration by hand is the
    // defect; this reads the models' own key sets, so a new attribution field
    // cannot be added without either appearing in the map or reddening here.
    test('every persisted *DisplayName field is covered by the map', () {
      Set<String> persistedKeys() => {
        ...UnifiedShoppingList.collaborative(
          name: 'x',
          ownerId: 'alice',
          ownerDisplayName: 'Alice',
          memberPermissions: const {'alice': SharedListPermission.admin},
        ).toFirestore().keys,
        ...UnifiedShoppingItem(
          id: 'i',
          name: 'x',
          amount: 1,
        ).toFirestore().keys,
      };

      final allKeys = persistedKeys();
      final nameKeys = allKeys
          .where((key) => key.endsWith('DisplayName'))
          .toSet();
      final map = SharedShoppingListExport.nameKeysByOwnerIdKey;

      expect(nameKeys, isNotEmpty, reason: 'the key scan must find something');
      expect(
        nameKeys.difference(map.keys.toSet()),
        isEmpty,
        reason:
            'an unlisted *DisplayName field ships another household '
            'member name into a GDPR bundle that says it was dropped',
      );

      // And every paired id key must itself be persisted, or the "keep it when
      // it is yours" branch silently becomes "drop it always".
      for (final idKey in map.values) {
        expect(allKeys, contains(idKey), reason: '$idKey is not persisted');
      }
    });

    // A list the user has LEFT is exactly what `contributorUserIds` finds and
    // exactly what `firestore.rules` refuses the client. That must degrade to a
    // documented gap, never to a failed export section.
    //
    // BUT-1732 review: these two tests are a PAIR, and the pairing is the
    // point. Both branch strings contain the word "left", so an assertion on
    // that substring alone matched either arm — the whole
    // `e is FirebaseException && e.code == 'permission-denied'` predicate was
    // deletable with the suite green. Each test therefore asserts the phrase
    // UNIQUE to its arm plus the flag the arm sets, because the flag is the
    // half that reaches `export_metadata.warnings` and so the half a data
    // subject can act on.
    test('a rules refusal is worded as a documented gap, with no '
        'warning flag', () async {
      final manager = _manager(
        exports: _FakeDataExportRepository(
          sharedOwned: [sharedDoc(id: 'l1', ownerId: 'alice')],
          contributorProbeError: FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          ),
        ),
      );

      final result = await manager.exportSharedShoppingLists('alice');

      expect(result['error'], isNull);
      expect(result['total_count'], 1);
      expect(
        result['note'],
        contains('could not be included'),
        reason:
            'the phrase unique to the refusal arm — "left" appears in BOTH '
            'branches and cannot tell them apart',
      );
      expect(
        result.containsKey('contributor_probe_failed'),
        isFalse,
        reason:
            'an expected, documented gap is not a warning; flagging it would '
            'tell every departed-list user their export is unreliable',
      );
      expect(result.containsKey('error_code'), isFalse);
    });

    test('a non-permission failure is worded neutrally and raises the '
        'warning flag', () async {
      // A network drop, a deadline or a missing index lands in the same catch.
      // The bundle may say it is incomplete but must not invent WHY — and
      // unlike the refusal, this one is genuinely unproven, so it has to carry
      // an `error_code`: `DataExportService` keys `export_metadata.warnings` on
      // that field ALONE, and without it the metadata reads complete while a
      // probe silently did not run.
      final manager = _manager(
        exports: _FakeDataExportRepository(
          sharedOwned: [sharedDoc(id: 'l1', ownerId: 'alice')],
          contributorProbeError: FirebaseException(
            plugin: 'cloud_firestore',
            code: 'unavailable',
          ),
        ),
      );

      final result = await manager.exportSharedShoppingLists('alice');

      expect(result['error'], isNull, reason: 'still not a failed section');
      expect(result['total_count'], 1);
      expect(
        result['note'],
        contains('did not complete'),
        reason: 'the phrase unique to the neutral arm',
      );
      expect(
        result['note'],
        isNot(contains('could not be included')),
        reason:
            'asserting an expected cause the data is silent about is its own '
            'defect — the user has not left anything',
      );
      expect(result['contributor_probe_failed'], isTrue);
      expect(
        result['error_code'],
        'shared-shopping-lists-contributor-probe-failed',
        reason:
            'the only field DataExportService lifts into '
            'export_metadata.warnings',
      );
    });

    // BUT-1732 review round 2: the section's `truncated` flag is a THREE-way
    // OR and it shipped with no truncation test at all, while the CONTRIBUTOR
    // leg's flag was being discarded outright — a clipped bundle silently
    // claiming completeness, which is the dangerous direction for Art. 15.
    // One test per probe, each clipping only its own leg, so a collapse to any
    // single term reddens (the same per-leg shape the recipes and menus
    // sections already carry).
    Map<String, dynamic> lightDoc(String id) => {
      'id': id,
      'data': {
        'name': 'Lista $id',
        'ownerId': 'alice',
        'items': const <Map<String, dynamic>>[],
      },
    };

    for (final leg in ['owned', 'member', 'contributor']) {
      test('stamps truncated when only the $leg probe clipped', () async {
        // Derived, not literal: re-tuning the cap is a config change, not a
        // behaviour regression, and must not fail here.
        final cap = ExportPaginationHelper.getLimitForType(
          'shared_shopping_lists',
        );
        // The N+1 probe: cap + 1 rows means rows were omitted. Ids are
        // leg-unique so the merge cannot dedupe the fixture away.
        final clipped = List.generate(cap + 1, (i) => lightDoc('$leg-$i'));

        final manager = _manager(
          exports: _FakeDataExportRepository(
            sharedOwned: leg == 'owned' ? clipped : const [],
            sharedMember: leg == 'member' ? clipped : const [],
            sharedContributor: leg == 'contributor' ? clipped : const [],
          ),
        );

        final result = await manager.exportSharedShoppingLists('alice');

        expect(result['truncated'], isTrue);
        expect(
          result['total_count'],
          cap,
          reason: 'the payload is trimmed back to the declared cap',
        );
      });
    }

    // The recall control for all three above: a section that fits must NOT
    // claim to be incomplete. Exactly AT the cap is the flip point — the
    // pre-BUT-1662 `length >= cap` shape stamped a complete export as
    // truncated, a false incompleteness claim on a GDPR bundle.
    test('a complete section at exactly the cap is not flagged', () async {
      final cap = ExportPaginationHelper.getLimitForType(
        'shared_shopping_lists',
      );
      final manager = _manager(
        exports: _FakeDataExportRepository(
          sharedOwned: List.generate(cap, (i) => lightDoc('o-$i')),
        ),
      );

      final result = await manager.exportSharedShoppingLists('alice');

      expect(result.containsKey('truncated'), isFalse);
      expect(result['total_count'], cap);
    });

    // Empty-safe. A user with no shared lists must get an empty SECTION, not
    // an `error` key: `DataExportService` renders one per record type, and an
    // error there reads to the data subject as "we could not give you this",
    // which is a different Art. 15 answer from "there is nothing".
    test('no shared lists yields an empty, error-free section', () async {
      final manager = _manager(exports: _FakeDataExportRepository());

      final result = await manager.exportSharedShoppingLists('alice');

      expect(result['total_count'], 0);
      expect(result['shared_shopping_lists'], isEmpty);
      expect(result.containsKey('error'), isFalse);
      expect(result.containsKey('truncated'), isFalse);
      expect(
        result.containsKey('note'),
        isFalse,
        reason:
            'the left-lists note belongs to a REFUSED probe, not an empty '
            'one — stamping it here would tell every user data was withheld',
      );
    });

    // The twin of the personal-list test above, and the one this group was
    // missing. EVERY real document in this collection carries Timestamps —
    // `createdAt`/`updatedAt` on the list, `addedAt`/`purchasedAt`/
    // `lastModifiedAt`/`assignedAt` on the rows — while every other fixture
    // here is Strings and Maps. So both `sanitizeForJson` calls in
    // `_minimiseList` were deletable with this whole group green.
    //
    // `jsonEncode` in DataExportService is NOT inside a try/catch, so one
    // surviving Timestamp throws JsonUnsupportedObjectError out of the ENTIRE
    // GDPR bundle — every section, for the first user who owns a shared list
    // and asks for their data. That is the normal path, not a corner case.
    test(
      'sanitizes list_info AND item rows so a Timestamp cannot break jsonEncode',
      () async {
        final manager = _manager(
          exports: _FakeDataExportRepository(
            sharedOwned: [
              {
                'id': 'list1',
                'data': {
                  'name': 'Delad lista',
                  'ownerId': 'alice',
                  'createdAt': Timestamp.fromDate(DateTime.utc(2026, 7, 25)),
                  'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 7, 29)),
                  'items': [
                    {
                      'id': 'item1',
                      'name': 'Mjölk',
                      'addedByUserId': 'alice',
                      'addedAt': Timestamp.fromDate(DateTime.utc(2026, 7, 26)),
                    },
                  ],
                },
              },
            ],
          ),
        );

        final result = await manager.exportSharedShoppingLists('alice');

        final list = (result['shared_shopping_lists'] as List).single as Map;
        final info = list['list_info'] as Map;
        expect(info['name'], 'Delad lista');
        expect(info['createdAt'], isNot(isA<Timestamp>()));
        expect(info['updatedAt'], isNot(isA<Timestamp>()));

        // The row leg is a SEPARATE sanitizeForJson call, so assert it
        // separately — sanitising only the list would still pass above.
        final row = (list['items'] as List).single as Map;
        expect(row['item_id'], 'item1');
        expect((row['data'] as Map)['addedAt'], isNot(isA<Timestamp>()));

        expect(() => jsonEncode(result), returnsNormally);
      },
    );

    // The position fallback in `_itemId`. Without it a legacy row written
    // without an id exports as `"item_id": null`, and several such rows in one
    // list are mutually indistinguishable in a bundle whose whole purpose is
    // to show the subject their own records.
    test('an item with no usable id still gets a distinct identifier', () async {
      final manager = _manager(
        exports: _FakeDataExportRepository(
          sharedOwned: [
            {
              'id': 'list1',
              'data': {
                'name': 'Delad lista',
                'ownerId': 'alice',
                'items': [
                  {'name': 'Utan id'},
                  {'id': '   ', 'name': 'Blankt id'},
                  {'id': 'real-id', 'name': 'Med id'},
                ],
              },
            },
          ],
        ),
      );

      final result = await manager.exportSharedShoppingLists('alice');

      final rows =
          ((result['shared_shopping_lists'] as List).single as Map)['items']
              as List;
      final ids = rows.map((r) => (r as Map)['item_id']).toList();

      expect(ids, ['row_0', 'row_1', 'real-id']);
      expect(
        ids.toSet(),
        hasLength(3),
        reason:
            'two id-less rows must not collapse to the same identifier — that '
            'is the whole point of the position fallback',
      );
    });
  });
}
