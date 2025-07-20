// lib/core/permissions/validators/validator_factory.dart

import 'recipe_validator.dart';
import 'shopping_list_validator.dart';
import 'group_validator.dart';
import 'social_validator.dart';
import 'composite_validator.dart';

/// Permission validator factory
class PermissionValidatorFactory {
  static RecipePermissionValidator createRecipeValidator() => RecipePermissionValidator();
  static ShoppingListPermissionValidator createShoppingListValidator() => ShoppingListPermissionValidator();
  static GroupPermissionValidator createGroupValidator() => GroupPermissionValidator();
  static SocialPermissionValidator createSocialValidator() => SocialPermissionValidator();
  static CompositePermissionValidator createCompositeValidator() => CompositePermissionValidator();
}