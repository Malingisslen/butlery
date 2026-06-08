/// BUT-901: unit tests for `cookSnapAudience` — the classifier behind the
/// "who will see this photo?" disclosure shown before a cook snap uploads. A
/// snap has no visibility field of its own; it inherits the parent recipe's.
/// The disclosure must never under-state that audience, so this pins the exact
/// scope mapping (public / shared / private) and the reuse of BUT-914's
/// privacy-correct collaborative audience.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/views/recipe_detail/cook_snap_visibility.dart';

import '../../../infrastructure/factories/recipe_factory.dart';

void main() {
  group('cookSnapAudience', () {
    test('a public recipe makes the snap public (no per-name audience)', () {
      final recipe = RecipeFactory.build(isPublic: true);
      final a = cookSnapAudience(recipe, 'me', const {});

      expect(a.scope, CookSnapVisibilityScope.public);
      expect(a.resolvedNames, isEmpty);
      expect(a.total, 0);
    });

    test('public is checked before collaborative (public wins)', () {
      // A recipe that is BOTH public and collaborative discloses "public" — the
      // strongest, most surprising audience — not the member list.
      final recipe = RecipeFactory.build(
        type: RecipeType.collaborative,
        isPublic: true,
      );
      expect(cookSnapAudience(recipe, 'test_user', const {}).scope,
          CookSnapVisibilityScope.public);
    });

    test('a personal recipe keeps the snap private (no warning)', () {
      final recipe = RecipeFactory.build(); // personal, not public
      final a = cookSnapAudience(recipe, 'me', const {});

      expect(a.scope, CookSnapVisibilityScope.private);
      expect(a.total, 0);
    });

    test('a collaborative recipe with other members is shared', () {
      // Factory default: owner test_user, members {user1: editor, user2: viewer}.
      // Viewing as user1, the audience is owner + the OTHER member (minus self).
      final recipe = RecipeFactory.buildCollaborative();
      final a = cookSnapAudience(
        recipe,
        'user1',
        const {'test_user': 'Owner', 'user2': 'Bob'},
      );

      expect(a.scope, CookSnapVisibilityScope.shared);
      expect(a.total, 2, reason: 'owner + user2, never the author user1');
      expect(a.resolvedNames, containsAll(<String>['Owner', 'Bob']));
    });

    test('shared total counts unresolved members — never under-states', () {
      // Only one of the two audience members has a known name; total must stay
      // 2 so the disclosure discloses the unnamed one as a count, not drop it.
      final recipe = RecipeFactory.buildCollaborative();
      final a = cookSnapAudience(recipe, 'user1', const {'test_user': 'Owner'});

      expect(a.scope, CookSnapVisibilityScope.shared);
      expect(a.total, 2);
      expect(a.resolvedNames, const ['Owner']);
    });

    test('a collaborative recipe with no OTHER members is private', () {
      // Owner-only collaborative recipe viewed by the owner: nobody else can see
      // the snap, so there is nothing to warn about.
      final recipe = RecipeFactory.buildCollaborative(permissions: const {});
      final a = cookSnapAudience(recipe, 'test_user', const {});

      expect(a.scope, CookSnapVisibilityScope.private,
          reason: 'self-only collaborative recipe → no audience → private');
    });
  });
}
