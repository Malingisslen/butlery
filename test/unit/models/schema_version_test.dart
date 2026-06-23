/// BUT-648: Round-trip tests for schemaVersion field on the 6 core models.
///
/// Three assertions per model:
///   (a) Constructor default → schemaVersion == 1.
///   (b) toFirestore → fromFirestore/fromMap round-trip preserves schemaVersion.
///   (c) fromFirestore/fromMap on a map WITHOUT schemaVersion key → defaults to 1
///       (old-doc backward-compat — the lazy-default-1 contract).

library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/models/shared_menu.dart';

void main() {
  // ---------------------------------------------------------------------------
  // 1. UserProfile
  // ---------------------------------------------------------------------------
  group('UserProfile schemaVersion', () {
    final baseDate = DateTime(2024, 6, 1);

    UserProfile makeProfile() => UserProfile(
      uid: 'uid-1',
      displayName: 'Test User',
      email: 'test@example.com',
      joinedAt: baseDate,
      lastActiveAt: baseDate,
    );

    test('(a) defaults to 1 when not specified', () {
      expect(makeProfile().schemaVersion, 1);
    });

    test('(b) round-trip toFirestore → fromMap preserves schemaVersion', () {
      final profile = makeProfile();
      final map = profile.toFirestore();
      // toFirestore writes to public_profiles shape; fromMap reads it back.
      final restored = UserProfile.fromMap('uid-1', map);
      expect(restored.schemaVersion, 1);
    });

    test('(c) fromMap on legacy doc missing schemaVersion defaults to 1', () {
      final legacyMap = <String, dynamic>{
        'displayName': 'Old User',
        'email': 'old@example.com',
        'joinedAt': Timestamp.fromDate(baseDate),
        'lastActiveAt': Timestamp.fromDate(baseDate),
        // schemaVersion deliberately absent
      };
      final profile = UserProfile.fromMap('uid-old', legacyMap);
      expect(profile.schemaVersion, 1);
    });
  });

  // ---------------------------------------------------------------------------
  // 2. RecipeCore
  // ---------------------------------------------------------------------------
  group('RecipeCore schemaVersion', () {
    RecipeCore makeCore() => RecipeCore(
      title: 'Pasta',
      description: 'Simple pasta',
      ingredients: ['pasta', 'salt'],
      instructions: ['Boil water', 'Cook pasta'],
      mealType: 'Middag',
    );

    test('(a) defaults to 1 when not specified', () {
      expect(makeCore().schemaVersion, 1);
    });

    test(
      '(b) round-trip toFirestore map → fromMap preserves schemaVersion',
      () {
        final core = makeCore();
        final map = core.toFirestore();
        // fromMap uses the id from the Firestore doc ID
        final restored = RecipeCore.fromMap(core.id, map);
        expect(restored.schemaVersion, 1);
      },
    );

    test('(c) fromMap on legacy map missing schemaVersion defaults to 1', () {
      final legacyMap = <String, dynamic>{
        'title': 'Old Recipe',
        'description': '',
        'ingredients': <String>[],
        'instructions': <String>[],
        'mealType': 'Middag',
        // schemaVersion deliberately absent
      };
      final core = RecipeCore.fromMap('old-id', legacyMap);
      expect(core.schemaVersion, 1);
    });
  });

  // ---------------------------------------------------------------------------
  // 3. WeeklyMenuPlan
  // ---------------------------------------------------------------------------
  group('WeeklyMenuPlan schemaVersion', () {
    final weekStart = DateTime(2024, 6, 3);
    final now = DateTime(2024, 6, 3, 12);

    WeeklyMenuPlan makePlan() => WeeklyMenuPlan(
      id: 'uid-1_2024-W23',
      userId: 'uid-1',
      weekStartDate: weekStart,
      entries: const [],
      createdAt: now,
      updatedAt: now,
    );

    test('(a) defaults to 1 when not specified', () {
      expect(makePlan().schemaVersion, 1);
    });

    test('(b) round-trip toFirestore → fromMap preserves schemaVersion', () {
      final plan = makePlan();
      final map = plan.toFirestore();
      final restored = WeeklyMenuPlan.fromMap(plan.id, map);
      expect(restored.schemaVersion, 1);
    });

    test('(c) fromMap on legacy map missing schemaVersion defaults to 1', () {
      final legacyMap = <String, dynamic>{
        'userId': 'uid-old',
        'weekStartDate': Timestamp.fromDate(weekStart),
        'entries': <dynamic>[],
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        // schemaVersion deliberately absent
      };
      final plan = WeeklyMenuPlan.fromMap('uid-old_2024-W23', legacyMap);
      expect(plan.schemaVersion, 1);
    });
  });

  // ---------------------------------------------------------------------------
  // 4. UnifiedShoppingList
  // ---------------------------------------------------------------------------
  group('UnifiedShoppingList schemaVersion', () {
    UnifiedShoppingList makeList() => UnifiedShoppingList(
      name: 'Veckohandling',
      ownerId: 'uid-1',
      ownerDisplayName: 'Test User',
    );

    test('(a) defaults to 1 when not specified', () {
      expect(makeList().schemaVersion, 1);
    });

    test(
      '(b) round-trip toFirestore map → fromMap preserves schemaVersion',
      () {
        final list = makeList();
        final map = list.toFirestore();
        final restored = UnifiedShoppingList.fromMap(list.id, map);
        expect(restored.schemaVersion, 1);
      },
    );

    test('(c) fromMap on legacy map missing schemaVersion defaults to 1', () {
      final legacyMap = <String, dynamic>{
        'name': 'Old List',
        'ownerId': 'uid-old',
        'ownerDisplayName': 'Old User',
        'items': <dynamic>[],
        'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1)),
        'updatedAt': Timestamp.fromDate(DateTime(2024, 1, 1)),
        'type': 'personal',
        'memberPermissions': <String, dynamic>{},
        'settings': <String, dynamic>{},
        'categoryIds': <String>[],
        // schemaVersion deliberately absent
      };
      final list = UnifiedShoppingList.fromMap('list-old', legacyMap);
      expect(list.schemaVersion, 1);
    });
  });

  // ---------------------------------------------------------------------------
  // 5. PersonalTag
  // ---------------------------------------------------------------------------
  group('PersonalTag schemaVersion', () {
    final now = DateTime(2024, 6, 1);

    PersonalTag makeTag() => PersonalTag(
      id: 'tag-1',
      name: 'Familjerecept',
      createdAt: now,
      updatedAt: now,
    );

    test('(a) defaults to 1 when not specified', () {
      expect(makeTag().schemaVersion, 1);
    });

    test('(b) round-trip toFirestore → fromMap preserves schemaVersion', () {
      final tag = makeTag();
      final map = tag.toFirestore();
      final restored = PersonalTag.fromMap(tag.id, map);
      expect(restored.schemaVersion, 1);
    });

    test('(c) fromMap on legacy map missing schemaVersion defaults to 1', () {
      final legacyMap = <String, dynamic>{
        'name': 'Old Tag',
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'sortOrder': 0,
        // schemaVersion deliberately absent
      };
      final tag = PersonalTag.fromMap('tag-old', legacyMap);
      expect(tag.schemaVersion, 1);
    });
  });

  // ---------------------------------------------------------------------------
  // 6. SharedMenu
  // ---------------------------------------------------------------------------
  group('SharedMenu schemaVersion', () {
    final now = DateTime(2024, 6, 1);

    SharedMenu makeMenu() => SharedMenu(
      id: 'menu-1',
      sharedByUserId: 'uid-1',
      sharedByDisplayName: 'Test User',
      sharedAt: now,
      menuTitle: 'Veckans meny',
      menuSnapshot: const {},
    );

    test('(a) defaults to 1 when not specified', () {
      expect(makeMenu().schemaVersion, 1);
    });

    test('(b) round-trip toFirestore → fromMap preserves schemaVersion', () {
      final menu = makeMenu();
      final map = menu.toFirestore();
      final restored = SharedMenu.fromMap(menu.id, map);
      expect(restored.schemaVersion, 1);
    });

    test('(c) fromMap on legacy map missing schemaVersion defaults to 1', () {
      final legacyMap = <String, dynamic>{
        'sharedByUserId': 'uid-old',
        'sharedByDisplayName': 'Old User',
        'sharedAt': Timestamp.fromDate(now),
        'menuTitle': 'Old Menu',
        'menuSnapshot': <String, dynamic>{},
        'totalRecipeCount': 0,
        'categories': <String>[],
        'allowCollaboration': false,
        'viewCount': 0,
        'engagementCount': 0,
        'dismissalCount': 0,
        'isOriginalReference': true,
        'copyOnWriteTriggered': false,
        'activeCollaboratorCount': 0,
        // schemaVersion deliberately absent
      };
      final menu = SharedMenu.fromMap('menu-old', legacyMap);
      expect(menu.schemaVersion, 1);
    });
  });
}
