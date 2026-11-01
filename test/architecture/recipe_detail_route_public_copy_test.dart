/// A public copy opened from a profile must reach the detail view as a public
/// copy, or the owner-only rows (ratings, comments, sharing) come back on
/// someone else's recipe.
library;

import 'package:flutter_test/flutter_test.dart';

import '../helpers/decision_guard_support.dart';

void main() {
  test('the recipeDetail route hands publicCopy on to RecipeDetailView', () {
    final source = guardSource('lib/core/router/app_router.dart');

    final start = source.indexOf('case Routes.recipeDetail:');
    expect(start, isNonNegative, reason: 'the recipeDetail case is gone');
    final end = source.indexOf('case Routes.', start + 1);
    final branch = source.substring(start, end < 0 ? source.length : end);

    expect(
      RegExp(
        r'RecipeDetailView\([^;]*publicCopy:\s*args\.publicCopy\b',
      ).hasMatch(branch),
      isTrue,
    );
  });
}
