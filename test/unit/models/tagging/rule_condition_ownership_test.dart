/// BUT-2107: the "mine" ownership condition resolves the owner with
/// `Recipe.ownerUid`, so a recipe whose `socialData.ownerId` is '' and whose
/// `createdBy` is the signed-in user is still theirs. This only touches the
/// owner filter; allergen and dietary conditions do not read the owner.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/condition_operator.dart';
import 'package:butlery/models/tagging/condition_type.dart';
import 'package:butlery/models/tagging/rule_condition.dart';

const _me = 'user_me';

Recipe _recipe({String? createdBy = _me, String ownerId = ''}) => Recipe(
  core: RecipeCore(
    id: 'r1',
    title: 'Gryta',
    description: 'd',
    ingredients: const ['i'],
    instructions: const ['s'],
    mealType: 'Middag',
    createdBy: createdBy,
    createdAt: DateTime(2026, 10, 8),
    updatedAt: DateTime(2026, 10, 8),
  ),
  type: RecipeType.personal,
  socialData: RecipeSocialData(ownerId: ownerId),
);

const _mine = RuleCondition(
  type: ConditionType.ownership,
  operator: ConditionOperator.equals,
  value: 'mine',
);

void main() {
  group('ownership "mine"', () {
    test('matches the creator when ownerId is empty', () {
      expect(_mine.evaluate(_recipe(), null, currentUserId: _me), isTrue);
    });

    test('closing: someone else created it', () {
      expect(
        _mine.evaluate(
          _recipe(createdBy: 'stranger'),
          null,
          currentUserId: _me,
        ),
        isFalse,
      );
    });

    test('closing: both fields are empty', () {
      expect(
        _mine.evaluate(_recipe(createdBy: ''), null, currentUserId: _me),
        isFalse,
      );
    });

    test('closing: an empty current user does not own an unowned recipe', () {
      expect(
        _mine.evaluate(_recipe(createdBy: ''), null, currentUserId: ''),
        isFalse,
      );
    });
  });
}
