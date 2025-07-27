// lib/core/permissions/validators/validator_factory.dart

import 'package:butlery/core/permissions/validators/recipe_validator.dart';
import 'package:butlery/core/permissions/validators/shopping_list_validator.dart';
import 'package:butlery/core/permissions/validators/group_validator.dart';
import 'package:butlery/core/permissions/validators/social_validator.dart';
import 'package:butlery/core/permissions/validators/composite_validator.dart';

/// Permission validator factory
class PermissionValidatorFactory {
  static RecipePermissionValidator createRecipeValidator() => RecipePermissionValidator();
  static ShoppingListPermissionValidator createShoppingListValidator() => ShoppingListPermissionValidator();
  static GroupPermissionValidator createGroupValidator() => GroupPermissionValidator();
  static SocialPermissionValidator createSocialValidator() => SocialPermissionValidator();
  static CompositePermissionValidator createCompositeValidator() => CompositePermissionValidator();
}