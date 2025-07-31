/// Centralized permission validation system facade for the Butlery application.
///
/// This module serves as the main entry point for all permission validation functionality,
/// providing a unified interface to the comprehensive permission system while maintaining
/// clean separation of concerns through focused validator modules.
///
/// **Architecture Overview:**
/// The permission system follows a modular, composable design where each validator
/// handles specific domain logic while providing consistent interfaces and error handling.
/// This facade exports all validator components for easy access while maintaining
/// the underlying modular architecture.
///
/// **Permission Validation Components:**
/// - **ValidationResult**: Standardized validation outcomes with detailed feedback
/// - **BaseValidator**: Abstract foundation for all permission validators
/// - **RecipeValidator**: Recipe-specific permission validation logic
/// - **ShoppingListValidator**: Shopping list permission validation
/// - **GroupValidator**: Group membership and role-based validation
/// - **SocialValidator**: Social feature permission validation
/// - **CompositeValidator**: Combines multiple validators for complex scenarios
/// - **ValidatorFactory**: Creates and configures validator instances
///
/// **Usage Examples:**
/// ```dart
/// // Basic permission validation
/// final validator = ValidatorFactory.createRecipeValidator(authService);
/// final result = await validator.canEditRecipe(recipeId, userId);
/// 
/// if (result.isValid) {
///   // Proceed with edit operation
/// } else {
///   // Handle permission denial: result.errorMessage
/// }
/// 
/// // Composite validation for complex operations
/// final compositeValidator = CompositeValidator([
///   recipeValidator,
///   groupValidator,
/// ]);
/// final result = await compositeValidator.validateAll(context);
/// ```
///
/// **Security Features:**
/// - Comprehensive validation coverage for all app operations
/// - Role-based access control with group membership validation
/// - Owner-based permissions with delegation support
/// - Audit logging for security-sensitive operations
/// - Consistent error handling and user feedback
/// - Protection against common security vulnerabilities
///
/// **Design Principles:**
/// - **Single Responsibility**: Each validator handles one domain
/// - **Composability**: Validators can be combined for complex scenarios
/// - **Consistency**: Uniform interfaces and error handling across all validators
/// - **Security-First**: Fail-secure with comprehensive validation coverage
/// - **Maintainability**: Clean separation makes the system easy to extend and test


// Export all validator components for external usage
export 'validators/validation_result.dart';
export 'validators/base_validator.dart';
export 'validators/recipe_validator.dart';
export 'validators/shopping_list_validator.dart';
export 'validators/group_validator.dart';
export 'validators/social_validator.dart';
export 'validators/composite_validator.dart';
export 'validators/validator_factory.dart';