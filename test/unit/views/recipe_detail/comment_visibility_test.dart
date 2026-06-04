/// BUT-914: unit tests for `commentVisibilityAudience` — the privacy-correct
/// audience the composer's "visible to" label is built from. The label must
/// neither over- nor under-state who sees a comment, so this pins the exact
/// contract: owner + collaborative members minus the author; empty for
/// non-collaborative recipes (mirrors FirebaseRecipeOwnershipResolver).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/views/recipe_detail/comment_visibility.dart';

import '../../../infrastructure/factories/recipe_factory.dart';

/// Stand-in for the l10n count fallback so the formatter is testable l10n-free.
String _count(int n) => '$n personer';

void main() {
  group('commentVisibilityAudience', () {
    test('a personal (non-collaborative) recipe has no shared audience', () {
      final recipe = RecipeFactory.build(); // type: personal
      expect(commentVisibilityAudience(recipe, 'user1'), isEmpty);
    });

    test('a member sees owner + the other members, never themselves', () {
      // Factory default: owner test_user, members {user1: editor, user2: viewer}.
      final recipe = RecipeFactory.buildCollaborative();
      final audience = commentVisibilityAudience(recipe, 'user1');

      expect(audience, containsAll(<String>['test_user', 'user2']));
      expect(audience, isNot(contains('user1')),
          reason: 'the author is never listed as part of their own audience');
    });

    test('the owner sees the members (and is not in their own audience)', () {
      final recipe = RecipeFactory.buildCollaborative();
      final audience = commentVisibilityAudience(recipe, 'test_user');

      expect(audience, containsAll(<String>['user1', 'user2']));
      expect(audience, isNot(contains('test_user')));
    });

    test('the owner appearing in memberPermissions is not duplicated', () {
      final recipe = RecipeFactory.buildCollaborative(
        permissions: {
          'test_user': ResourcePermission.admin, // owner also a member entry
          'user2': ResourcePermission.viewer,
        },
      );
      // Viewing as a third party who is neither owner nor a member.
      final audience = commentVisibilityAudience(recipe, 'outsider');

      expect(audience.where((id) => id == 'test_user').length, 1,
          reason: 'owner must appear at most once even if also a member');
      expect(audience, containsAll(<String>['test_user', 'user2']));
    });

    test('falls back to createdBy as owner when socialData is absent', () {
      // Legacy collaborative recipe: type is collaborative but no socialData —
      // mirrors the resolver's `_resolveOwnerId` createdBy branch. The owner
      // must still appear, or the label silently under-states the audience.
      final recipe = RecipeFactory.build(
        type: RecipeType.collaborative,
        createdBy: 'legacy_owner',
      );
      expect(commentVisibilityAudience(recipe, 'someone_else'),
          contains('legacy_owner'));
    });
  });

  group('formatCommentAudience — never under-states', () {
    test('returns null only for an empty audience (caller hides the line)', () {
      expect(formatCommentAudience(const [], 0, countLabel: _count), isNull);
    });

    test('lists every name when the audience fits in 3', () {
      expect(
        formatCommentAudience(const ['Anna', 'Per'], 2, countLabel: _count),
        'Anna, Per',
      );
    });

    test('counts the +N against the TRUE total, not the resolved subset', () {
      // 5 share; only 2 names resolved. The label must imply 5, not 2 — so
      // "+3" (the other 3, named-or-not) is disclosed, never dropped.
      expect(
        formatCommentAudience(const ['Anna', 'Per'], 5, countLabel: _count),
        'Anna, Per +3',
      );
    });

    test('overflows beyond 3 resolved names against the true total', () {
      expect(
        formatCommentAudience(const ['A', 'B', 'C', 'D'], 6,
            countLabel: _count),
        'A, B, C +3',
      );
    });

    test('falls back to a count when NO name resolves — never hides', () {
      // The privacy bug this guards: a recipe shared with 3 non-friends whose
      // names don't resolve must NOT render an empty/hidden label.
      expect(
          formatCommentAudience(const [], 3, countLabel: _count), '3 personer');
    });
  });
}
