/// 🛡️ PERMISSION VALIDATORS - Facade for permission validation modules
/// File: lib/core/permissions/permission_validators.dart
/// Purpose: Provides backward compatibility while using focused validator modules
/// Migration: All validator logic has been moved to focused modules for better SRP adherence


// Export all validator components for external usage
export 'validators/validation_result.dart';
export 'validators/base_validator.dart';
export 'validators/recipe_validator.dart';
export 'validators/shopping_list_validator.dart';
export 'validators/group_validator.dart';
export 'validators/social_validator.dart';
export 'validators/composite_validator.dart';
export 'validators/validator_factory.dart';