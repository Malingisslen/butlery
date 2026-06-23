/// Unit tests for SharedRecipe (copy-on-write + V2 denormalized metadata).
///
/// Focused on pure-Dart contracts. Full Firestore round-trip deferred
/// to integration tests because it requires fully-populated RecipeCore.
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/permissions/edit_mode.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/shared_recipe.dart';

Recipe _recipe({
  String id = 'r1',
  String title = 'Pasta',
  String description = '',
  int? portions,
  int? timeMinutes,
  List<String> imageUrls = const [],
}) {
  return Recipe(
    core: RecipeCore(
      id: id,
      title: title,
      description: description,
      ingredients: const [],
      instructions: const [],
      mealType: 'Middag',
      createdAt: DateTime.utc(2025, 1, 1),
      updatedAt: DateTime.utc(2025, 1, 1),
      portions: portions,
      timeMinutes: timeMinutes,
      imageUrls: imageUrls,
    ),
    type: RecipeType.personal,
  );
}

SharedRecipe _shared({
  String id = 'sr-1',
  String sharedByUserId = 'alice',
  String sharedByDisplayName = 'Alice',
  String recipeTitle = 'Pasta',
  bool allowCollaboration = false,
  ShareScope scope = ShareScope.individual,
  Recipe? snapshot,
}) {
  return SharedRecipe(
    id: id,
    sharedByUserId: sharedByUserId,
    sharedByDisplayName: sharedByDisplayName,
    sharedAt: DateTime.utc(2026, 1, 1),
    originalRecipeId: 'orig-1',
    recipeTitle: recipeTitle,
    scope: scope,
    allowCollaboration: allowCollaboration,
    recipeSnapshot: snapshot,
  );
}

void main() {
  group('SharedRecipe.create factory', () {
    test('determinedScope: 1 user → individual', () {
      final s = SharedRecipe.create(
        originalRecipeId: 'orig',
        sharedByUserId: 'alice',
        sharedByDisplayName: 'Alice',
        sharedToUserIds: const ['bob'],
        recipeSnapshot: _recipe(),
      );
      expect(s.scope, ShareScope.individual);
    });

    test('determinedScope: >1 user → multiple', () {
      final s = SharedRecipe.create(
        originalRecipeId: 'orig',
        sharedByUserId: 'alice',
        sharedByDisplayName: 'Alice',
        sharedToUserIds: const ['bob', 'carol'],
        recipeSnapshot: _recipe(),
      );
      expect(s.scope, ShareScope.multiple);
    });

    test('explicit scope param overrides count-based derivation', () {
      final s = SharedRecipe.create(
        originalRecipeId: 'orig',
        sharedByUserId: 'alice',
        sharedByDisplayName: 'Alice',
        sharedToUserIds: const ['bob'], // would be individual
        scope: ShareScope.friends,
        recipeSnapshot: _recipe(),
      );
      expect(s.scope, ShareScope.friends);
    });

    test('denormalizes recipe metadata into V2 fields', () {
      final s = SharedRecipe.create(
        originalRecipeId: 'orig',
        sharedByUserId: 'a',
        sharedByDisplayName: 'A',
        sharedToUserIds: const [],
        recipeSnapshot: _recipe(
          title: 'Lasagna',
          description: 'oven dish',
          portions: 4,
          timeMinutes: 75,
          imageUrls: const ['https://img/1', 'https://img/2'],
        ),
      );
      expect(s.recipeTitle, 'Lasagna');
      expect(s.recipeDescription, 'oven dish');
      expect(s.recipePortions, 4);
      expect(s.recipeTimeMinutes, 75);
      // First image is used as the thumbnail
      expect(s.recipeImageUrl, 'https://img/1');
    });

    test('recipeImageUrl is null when snapshot has no images', () {
      final s = SharedRecipe.create(
        originalRecipeId: 'orig',
        sharedByUserId: 'a',
        sharedByDisplayName: 'A',
        sharedToUserIds: const [],
        recipeSnapshot: _recipe(imageUrls: const []),
      );
      expect(s.recipeImageUrl, isNull);
    });

    test('UUID id + clock-stamped sharedAt', () {
      withClock(Clock.fixed(DateTime.utc(2026, 5, 23, 12)), () {
        final s = SharedRecipe.create(
          originalRecipeId: 'orig',
          sharedByUserId: 'a',
          sharedByDisplayName: 'A',
          sharedToUserIds: const [],
          recipeSnapshot: _recipe(),
        );
        expect(s.id, hasLength(36));
        expect(s.sharedAt, DateTime.utc(2026, 5, 23, 12));
      });
    });
  });

  group('content helpers', () {
    test('contentTypeName is "recipe"', () {
      expect(_shared().contentTypeName, 'recipe');
    });

    test('getContentTitle returns recipeTitle', () {
      expect(_shared(recipeTitle: 'Lasagna').getContentTitle(), 'Lasagna');
    });

    test('contentSnapshot returns the full snapshot when available', () {
      final r = _recipe(title: 'Pasta');
      final s = _shared(snapshot: r);
      expect(s.contentSnapshot.id, r.id);
      expect(s.contentSnapshot.title, r.title);
    });

    test('contentSnapshot synthesizes a minimal Recipe from V2 metadata', () {
      // No snapshot → uses denormalized fields.
      final s = _shared(recipeTitle: 'Lasagna');
      expect(s.contentSnapshot.id, 'orig-1');
      expect(s.contentSnapshot.title, 'Lasagna');
      expect(s.contentSnapshot.type, RecipeType.shared);
    });
  });

  group('snapshot availability', () {
    test('hasFullSnapshot is true when snapshot was provided', () {
      expect(_shared(snapshot: _recipe()).hasFullSnapshot, isTrue);
    });

    test('hasFullSnapshot is false when no snapshot (V2 share)', () {
      expect(_shared().hasFullSnapshot, isFalse);
    });

    test('recipe and recipeSnapshot getters expose the snapshot', () {
      final r = _recipe();
      final s = _shared(snapshot: r);
      expect(s.recipeSnapshot, same(r));
      expect(s.recipe, same(r));
    });
  });

  group('copy-on-write state machine', () {
    test('defaults', () {
      final s = _shared();
      expect(s.isOriginalReference, isTrue);
      expect(s.copyOnWriteTriggered, isFalse);
      expect(s.activeCollaboratorCount, 0);
      expect(s.originalOwnerStaticCopyId, isNull);
    });

    test('non-owner triggerCopyOnWrite flips flags + sets id + count=1', () {
      final s = _shared();
      final after = s.triggerCopyOnWrite(
        editingUserId: 'bob',
        staticCopyId: 'snap-1',
      );
      expect(after.copyOnWriteTriggered, isTrue);
      expect(after.isOriginalReference, isFalse);
      expect(after.originalOwnerStaticCopyId, 'snap-1');
      expect(after.activeCollaboratorCount, 1);
    });

    test('owner triggerCopyOnWrite is a no-op', () {
      final s = _shared();
      final same = s.triggerCopyOnWrite(
        editingUserId: 'alice',
        staticCopyId: 's',
      );
      expect(identical(same, s), isTrue);
    });

    test('already-triggered triggerCopyOnWrite is idempotent', () {
      final s = _shared().triggerCopyOnWrite(
        editingUserId: 'bob',
        staticCopyId: 's1',
      );
      final twice = s.triggerCopyOnWrite(
        editingUserId: 'carol',
        staticCopyId: 's2',
      );
      expect(identical(twice, s), isTrue);
    });

    test('addActiveCollaborator only counts after CoW triggered', () {
      final s = _shared();
      expect(identical(s.addActiveCollaborator('bob'), s), isTrue);

      final triggered = s.triggerCopyOnWrite(
        editingUserId: 'bob',
        staticCopyId: 's',
      );
      expect(
        triggered.addActiveCollaborator('carol').activeCollaboratorCount,
        2,
      );
    });
  });

  group('permission getter', () {
    test('viewer when allowCollaboration=false', () {
      expect(_shared().permission, ResourcePermission.viewer);
    });

    test('editor when allowCollaboration=true', () {
      expect(
        _shared(allowCollaboration: true).permission,
        ResourcePermission.editor,
      );
    });
  });

  group('getEditModeFor', () {
    test('owner gets EditMode.owner regardless of other flags', () {
      expect(_shared().getEditModeFor('alice'), EditMode.owner);
      expect(
        _shared(allowCollaboration: true).getEditModeFor('alice'),
        EditMode.owner,
      );
    });

    test('non-owner with collaboration → collaborative', () {
      expect(
        _shared(allowCollaboration: true).getEditModeFor('bob'),
        EditMode.collaborative,
      );
    });

    test('non-owner without collaboration → readOnlyWithFork', () {
      expect(_shared().getEditModeFor('bob'), EditMode.readOnlyWithFork);
    });

    test('after CoW trigger + active collaborators → collaborative', () {
      final s = _shared(); // allowCollaboration=false
      final triggered = s.triggerCopyOnWrite(
        editingUserId: 'bob',
        staticCopyId: 's',
      );
      expect(triggered.getEditModeFor('bob'), EditMode.collaborative);
    });
  });

  group('importCount + createImportRecipe', () {
    test('importCount mirrors engagementCount', () {
      final s = SharedRecipe(
        id: 'sr',
        sharedByUserId: 'a',
        sharedByDisplayName: 'A',
        originalRecipeId: 'o',
        recipeTitle: 'T',
        engagementCount: 12,
      );
      expect(s.importCount, 12);
    });

    test('createImportRecipe returns null when no full snapshot (V2)', () {
      expect(_shared().createImportRecipe(newOwnerId: 'bob'), isNull);
    });

    test(
      'createImportRecipe sets sourceUrl attribution + clears personal tags',
      () {
        final original = _recipe();
        final s = _shared(snapshot: original);
        final imported = s.createImportRecipe(newOwnerId: 'bob')!;
        // Attribution writes into sourceUrl
        expect(imported.sourceUrl, isNotNull);
        expect(imported.sourceUrl, contains('Alice'));
        // personalTagIds wiped (UUIDs meaningless to recipient)
        expect(imported.personalTagIds, isEmpty);
      },
    );
  });

  group('copyWith', () {
    test('importCount param overrides engagementCount', () {
      final s = SharedRecipe(
        id: 'sr',
        sharedByUserId: 'a',
        sharedByDisplayName: 'A',
        originalRecipeId: 'o',
        recipeTitle: 'T',
        engagementCount: 1,
      );
      expect(s.copyWith(importCount: 99).engagementCount, 99);
    });

    test('preserves untouched fields', () {
      final s = _shared(recipeTitle: 'Lasagna', allowCollaboration: true);
      final copy = s.copyWith(viewCount: 5);
      expect(copy.id, s.id);
      expect(copy.recipeTitle, 'Lasagna');
      expect(copy.allowCollaboration, isTrue);
      expect(copy.viewCount, 5);
    });

    test('allowCollaboration override sticks', () {
      expect(
        _shared().copyWith(allowCollaboration: true).allowCollaboration,
        isTrue,
      );
    });
  });

  group('toFirestore', () {
    test('omits V2 metadata keys when null', () {
      // _shared() leaves recipeImageUrl/Portions/Time/Description null.
      final payload = _shared().toFirestore();
      expect(payload.containsKey('recipeImageUrl'), isFalse);
      expect(payload.containsKey('recipePortions'), isFalse);
      expect(payload.containsKey('recipeTimeMinutes'), isFalse);
      expect(payload.containsKey('recipeDescription'), isFalse);
    });

    test('includes core fields + scope/permissions flags', () {
      final payload = _shared(allowCollaboration: true).toFirestore();
      expect(payload['originalRecipeId'], 'orig-1');
      expect(payload['recipeTitle'], 'Pasta');
      expect(payload['scope'], 'individual');
      expect(payload['allowImport'], isTrue);
      expect(payload['allowCollaboration'], isTrue);
    });
  });
}
