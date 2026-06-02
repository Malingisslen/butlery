/// BUT-1178 (BUT-972 follow-up): pins the ownership-conditional fork
/// ("Skapa kopia" / Create copy) placement invariant on recipe-detail.
///
/// These assert the REAL production predicates from
/// `lib/views/recipe_detail/fork_placement.dart` — the same functions the view
/// calls — so a regression in the placement logic fails here (not a re-stated
/// copy of the condition). The invariant: across every ownership case the fork
/// shows in EXACTLY ONE of {app-bar, overflow}. Each case asserts both the
/// present and the absent side.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/views/recipe_detail/fork_placement.dart';

void main() {
  const me = 'user_me';
  const someoneElse = 'user_other';

  group('fork placement — mutual exclusion (BUT-1178)', () {
    test('shared & not owned → app-bar button, overflow item hidden', () {
      // recipe.createdBy is a non-empty author that differs from the viewer.
      expect(showForkInAppBar(someoneElse, me), isTrue);
      expect(showForkInOverflow(someoneElse, me), isFalse);
    });

    test('owned (createdBy == currentUser) → overflow item, no app-bar button',
        () {
      expect(showForkInAppBar(me, me), isFalse);
      expect(showForkInOverflow(me, me), isTrue);
    });

    test('local recipe (empty createdBy) → overflow item, no app-bar button',
        () {
      // Negative control: a local recipe with no author is the owned-side path.
      expect(showForkInAppBar('', me), isFalse);
      expect(showForkInOverflow('', me), isTrue);

      // null createdBy is treated the same as empty.
      expect(showForkInAppBar(null, me), isFalse);
      expect(showForkInOverflow(null, me), isTrue);
    });

    test(
        'the two placements are exhaustive complements for every '
        'ownership combination', () {
      // The invariant itself: showInAppBar == !showInOverflow, always.
      const cases = <(String?, String?)>[
        (someoneElse, me), // shared, not owned
        (me, me), // owned
        ('', me), // local (empty)
        (null, me), // local (null)
        (someoneElse, null), // shared, viewer not signed in
        ('', null), // local, viewer not signed in
      ];
      for (final (createdBy, currentUserId) in cases) {
        expect(
          showForkInAppBar(createdBy, currentUserId),
          isNot(showForkInOverflow(createdBy, currentUserId)),
          reason: 'fork must show in exactly one place for '
              '(createdBy: $createdBy, currentUserId: $currentUserId)',
        );
      }
    });
  });
}
