/// Unit tests for SharedMenu (copy-on-write menu sharing model).
///
/// Focused on the pure-Dart contracts: factory + derived fields,
/// content helpers, the CoW state machine (triggerCopyOnWrite +
/// addActiveCollaborator), createImportMenu transformation, and
/// computed getters (menuSummary / mostPopularCategory / conversionRate
/// / allowImport / hasContent). Full toFirestore round-trip is left to
/// integration tests because it requires a fully-populated RecipeCore.
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/shared_menu.dart';

Recipe _recipe({String id = 'r1', String title = 'Pasta'}) {
  return Recipe(
    core: RecipeCore(
      id: id,
      title: title,
      description: '',
      ingredients: const [],
      instructions: const [],
      mealType: 'Middag',
      createdAt: DateTime.utc(2025, 1, 1),
      updatedAt: DateTime.utc(2025, 1, 1),
    ),
    type: RecipeType.personal,
  );
}

SharedMenu _menu({
  String id = 'sm-1',
  String sharedByUserId = 'alice',
  String sharedByDisplayName = 'Alice',
  Map<String, List<Recipe>>? menuSnapshot,
  int viewCount = 0,
  int engagementCount = 0,
  bool allowCollaboration = false,
}) {
  return SharedMenu(
    id: id,
    sharedByUserId: sharedByUserId,
    sharedByDisplayName: sharedByDisplayName,
    sharedAt: DateTime.utc(2026, 1, 1),
    menuTitle: 'Veckomeny',
    menuSnapshot:
        menuSnapshot ??
        {
          'Måndag': [_recipe(id: 'r1')],
          'Tisdag': [_recipe(id: 'r2'), _recipe(id: 'r3')],
        },
    viewCount: viewCount,
    engagementCount: engagementCount,
    allowCollaboration: allowCollaboration,
  );
}

void main() {
  group('constructor derived fields', () {
    test('totalRecipeCount = sum of recipes across all categories', () {
      expect(_menu().totalRecipeCount, 3);
    });

    test('categories = menuSnapshot.keys preserves insertion order', () {
      expect(_menu().categories, ['Måndag', 'Tisdag']);
    });

    test('empty menu has 0 totalRecipeCount and empty categories', () {
      final empty = _menu(menuSnapshot: const {});
      expect(empty.totalRecipeCount, 0);
      expect(empty.categories, isEmpty);
    });
  });

  group('SharedMenu.create factory', () {
    test('generates a UUID id', () {
      final m = SharedMenu.create(
        sharedByUserId: 'a',
        sharedByDisplayName: 'A',
        sharedToUserIds: const [],
        menuSnapshot: const {},
      );
      expect(m.id, isNotEmpty);
      expect(m.id, hasLength(36));
    });

    test('uses provided menuTitle when given', () {
      final m = SharedMenu.create(
        sharedByUserId: 'a',
        sharedByDisplayName: 'A',
        sharedToUserIds: const [],
        menuSnapshot: const {},
        menuTitle: 'Helgmenyn',
      );
      expect(m.menuTitle, 'Helgmenyn');
    });

    test('sharedAt stamps via clock.now()', () {
      withClock(Clock.fixed(DateTime.utc(2026, 5, 23, 12)), () {
        final m = SharedMenu.create(
          sharedByUserId: 'a',
          sharedByDisplayName: 'A',
          sharedToUserIds: const [],
          menuSnapshot: const {},
        );
        expect(m.sharedAt, DateTime.utc(2026, 5, 23, 12));
      });
    });
  });

  group('content helpers', () {
    test('contentTypeName is "menu"', () {
      expect(_menu().contentTypeName, 'menu');
    });

    test('contentSnapshot exposes menuSnapshot', () {
      final m = _menu();
      expect(m.contentSnapshot, m.menuSnapshot);
    });

    test('getContentTitle returns menuTitle', () {
      expect(_menu().getContentTitle(), 'Veckomeny');
    });

    test('getContentDescription returns menuSummary', () {
      // 1 + 2 across the two days → "1 måndag, 2 tisdag"
      expect(_menu().getContentDescription(), '1 måndag, 2 tisdag');
    });
  });

  group('menuSummary', () {
    test('lowercases category names + drops empty buckets', () {
      final m = _menu(
        menuSnapshot: {
          'MÅNDAG': [_recipe(id: 'r1')],
          'EMPTY': const [],
          'TISDAG': [_recipe(id: 'r2'), _recipe(id: 'r3')],
        },
      );
      expect(m.menuSummary, '1 måndag, 2 tisdag');
    });

    test('empty menu → empty string', () {
      expect(_menu(menuSnapshot: const {}).menuSummary, '');
    });
  });

  group('mostPopularCategory', () {
    test('returns the category with the most recipes', () {
      expect(_menu().mostPopularCategory, 'Tisdag');
    });

    test('returns null when menu is empty', () {
      expect(_menu(menuSnapshot: const {}).mostPopularCategory, isNull);
    });
  });

  group('hasContent / allowImport', () {
    test('true when there are recipes', () {
      expect(_menu().hasContent, isTrue);
      expect(_menu().allowImport, isTrue);
    });

    test('false on empty menu', () {
      final empty = _menu(menuSnapshot: const {});
      expect(empty.hasContent, isFalse);
      expect(empty.allowImport, isFalse);
    });
  });

  group('conversionRate', () {
    test('returns 0.0 when viewCount is 0 (no division-by-zero)', () {
      expect(_menu().conversionRate, 0.0);
    });

    test('returns importCount / viewCount * 100', () {
      final m = _menu(viewCount: 10, engagementCount: 3);
      // 3 imports out of 10 views → 30%
      expect(m.conversionRate, 30.0);
    });
  });

  group('importCount alias', () {
    test('mirrors engagementCount', () {
      expect(_menu(engagementCount: 7).importCount, 7);
    });
  });

  group('copy-on-write state machine', () {
    test('defaults: isOriginalReference=true, copyOnWriteTriggered=false', () {
      final m = _menu();
      expect(m.isOriginalReference, isTrue);
      expect(m.copyOnWriteTriggered, isFalse);
      expect(m.activeCollaboratorCount, 0);
      expect(m.originalOwnerStaticCopyId, isNull);
    });

    test(
      'triggerCopyOnWrite by non-owner flips the flags + sets static copy id',
      () {
        final m = _menu();
        final copied = m.triggerCopyOnWrite(
          editingUserId: 'bob',
          staticCopyId: 'snap-1',
        );
        expect(copied.isOriginalReference, isFalse);
        expect(copied.copyOnWriteTriggered, isTrue);
        expect(copied.originalOwnerStaticCopyId, 'snap-1');
        expect(copied.activeCollaboratorCount, 1);
      },
    );

    test('triggerCopyOnWrite by owner is a no-op (returns same instance)', () {
      final m = _menu();
      final same = m.triggerCopyOnWrite(
        editingUserId: 'alice',
        staticCopyId: 's',
      );
      expect(identical(same, m), isTrue);
    });

    test('triggerCopyOnWrite twice is idempotent (second call no-ops)', () {
      final m = _menu();
      final first = m.triggerCopyOnWrite(
        editingUserId: 'bob',
        staticCopyId: 'snap-1',
      );
      final second = first.triggerCopyOnWrite(
        editingUserId: 'carol',
        staticCopyId: 'snap-2',
      );
      expect(identical(second, first), isTrue);
    });

    test('addActiveCollaborator only counts when CoW already triggered', () {
      final m = _menu();
      final preCow = m.addActiveCollaborator('bob');
      expect(identical(preCow, m), isTrue);

      final triggered = m.triggerCopyOnWrite(
        editingUserId: 'bob',
        staticCopyId: 'snap-1',
      );
      final added = triggered.addActiveCollaborator('carol');
      expect(added.activeCollaboratorCount, 2);
    });
  });

  group('copyWith', () {
    test('importCount param updates engagementCount', () {
      final m = _menu(engagementCount: 1);
      expect(m.copyWith(importCount: 99).engagementCount, 99);
    });

    test('allowCollaboration override sticks', () {
      expect(
        _menu(
          allowCollaboration: false,
        ).copyWith(allowCollaboration: true).allowCollaboration,
        isTrue,
      );
    });

    test('preserves untouched fields', () {
      final base = _menu();
      final copy = base.copyWith(viewCount: 99);
      expect(copy.id, base.id);
      expect(copy.menuTitle, base.menuTitle);
      expect(copy.totalRecipeCount, base.totalRecipeCount);
      expect(copy.viewCount, 99);
    });
  });

  group('createImportMenu', () {
    test('produces a same-shape map with all recipes attributed', () {
      final m = _menu();
      final imported = m.createImportMenu(newOwnerId: 'bob');

      expect(imported.keys.toList(), ['Måndag', 'Tisdag']);
      expect(imported['Måndag'], hasLength(1));
      expect(imported['Tisdag'], hasLength(2));

      // Each recipe description is appended with the import attribution.
      for (final recipes in imported.values) {
        for (final r in recipes) {
          expect(r.description, contains('📋'));
          expect(r.description, contains('Alice'));
        }
      }
    });

    test('clears lastCookedAt on imported recipes', () {
      final cooked = Recipe(
        core: RecipeCore(
          id: 'r1',
          title: 'Pasta',
          description: 'orig',
          ingredients: const [],
          instructions: const [],
          mealType: 'Middag',
          createdAt: DateTime.utc(2025, 1, 1),
          updatedAt: DateTime.utc(2025, 1, 1),
          lastCookedAt: DateTime.utc(2025, 1, 10),
        ),
        type: RecipeType.personal,
      );
      final m = _menu(
        menuSnapshot: {
          'Måndag': [cooked],
        },
      );
      final imported = m.createImportMenu(newOwnerId: 'bob');
      expect(imported['Måndag']!.single.lastCookedAt, isNull);
    });
  });
}
