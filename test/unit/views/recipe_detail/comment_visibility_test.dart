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
      expect(
        audience,
        isNot(contains('user1')),
        reason: 'the author is never listed as part of their own audience',
      );
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

      expect(
        audience.where((id) => id == 'test_user').length,
        1,
        reason: 'owner must appear at most once even if also a member',
      );
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
      expect(
        commentVisibilityAudience(recipe, 'someone_else'),
        contains('legacy_owner'),
      );
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
        formatCommentAudience(
          const ['A', 'B', 'C', 'D'],
          6,
          countLabel: _count,
        ),
        'A, B, C +3',
      );
    });

    test('falls back to a count when NO name resolves — never hides', () {
      // The privacy bug this guards: a recipe shared with 3 non-friends whose
      // names don't resolve must NOT render an empty/hidden label.
      expect(
        formatCommentAudience(const [], 3, countLabel: _count),
        '3 personer',
      );
    });
  });

  group('resolveCommentAudienceNames — never under-states (BUT-1211)', () {
    test('empty audience yields no names and zero total', () {
      final r = resolveCommentAudienceNames(const [], const {});
      expect(r.resolved, isEmpty);
      expect(r.total, 0);
    });

    test('total is the full audience size, not the resolved subset', () {
      // 3 people see the comment; only one name is known. total must stay 3 so
      // the dialog/label disclose the other two as a count — never drop them.
      final r = resolveCommentAudienceNames(
        const ['owner', 'friendA', 'stranger'],
        const {'friendA': 'Anna'},
      );
      expect(r.resolved, const ['Anna']);
      expect(r.total, 3);
    });

    test(
      'owner name resolves via the fallback when the friends map is empty',
      () {
        // Friends list unavailable (the try/catch path in the widget): the
        // recipe's denormalized owner name must still resolve, or a collaborator
        // sees an audience they cannot identify at all.
        final r = resolveCommentAudienceNames(
          const ['ownerId'],
          const {},
          ownerId: 'ownerId',
          ownerName: 'Per',
        );
        expect(r.resolved, const ['Per']);
        expect(r.total, 1);
      },
    );

    test('an empty owner name does not register as a resolution', () {
      final r = resolveCommentAudienceNames(
        const ['ownerId'],
        const {},
        ownerId: 'ownerId',
        ownerName: '',
      );
      expect(r.resolved, isEmpty, reason: 'blank name must not resolve');
      expect(r.total, 1);
    });

    test('the friends map wins over the owner fallback for the same uid', () {
      // putIfAbsent semantics: a friend-resolved name is authoritative; the
      // denormalized owner name is only a fallback, never an override.
      final r = resolveCommentAudienceNames(
        const ['ownerId'],
        const {'ownerId': 'Fresh Name'},
        ownerId: 'ownerId',
        ownerName: 'Stale Denormalized Name',
      );
      expect(r.resolved, const ['Fresh Name']);
    });

    test('resolution preserves audience order', () {
      final r = resolveCommentAudienceNames(
        const ['c', 'a', 'b'],
        const {'a': 'Anna', 'b': 'Bo', 'c': 'Cilla'},
      );
      expect(r.resolved, const ['Cilla', 'Anna', 'Bo']);
    });

    test('drives the dialog unresolved-count arithmetic correctly', () {
      // The dialog computes `unresolved = total - resolved.length`; this is the
      // value behind the trailing "+N others" line. Pin it on the record so a
      // refactor of resolved/total can't silently desync that count.
      final r = resolveCommentAudienceNames(
        const ['owner', 'x', 'y', 'z'],
        const {'owner': 'Owner'},
      );
      expect(r.total - r.resolved.length, 3);
    });
  });
}
