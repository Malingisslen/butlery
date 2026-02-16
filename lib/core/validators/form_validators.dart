/// Form validation system with Swedish localization for all app forms.
/// **Features:** Required/min/max/email/password/URL validation, conditional/combinatorial validators, Swedish errors.
/// ```dart
/// final v = FormValidators.combine([
///   FormValidators.required('Titel'), FormValidators.minLength(3, 'Titel')]);
/// final email = FormValidators.authEmail();
/// final pwd = FormValidators.authPassword(isSignUp: true);
///   // Optional validation for non-required fields
///   final optionalUrlValidator = FormValidators.optional(
///     FormValidators.url(),
///   );
///   // Combined validation with multiple rules
///   final complexValidator = FormValidators.combine([
///     FormValidators.required('Field'),
///     FormValidators.minLength(5, 'Field'),
///     FormValidators.maxLength(50, 'Field'),
///   ]);
/// }
/// ```
/// ## Performance Characteristics
/// - **Validation Efficiency**: Lightweight validation logic with minimal computational overhead
/// - **Memory Management**: Stateless validation functions with no memory leaks or resource retention
/// - **Regex Optimization**: Precompiled regex patterns for improved validation performance
/// - **Error Message Caching**: Efficient string formatting with minimal allocation overhead
/// ## Integration Patterns
/// - **Form Integration**: Direct integration with Flutter TextFormField widgets and form validation
/// - **Localization**: Complete Swedish localization with proper grammar and cultural appropriateness
/// - **Error Handling**: Consistent error message formatting and user guidance across all forms
/// - **Feature Integration**: Specialized validators for recipes, social features, authentication, and shopping
/// This validation system is essential for maintaining consistent, user-friendly, and culturally appropriate
/// form validation throughout the Swedish cooking application while ensuring data integrity and providing
/// helpful user guidance for successful form completion across all application features and interactions.

import 'package:flutter/material.dart';
import 'package:butlery/core/l10n/app_locale.dart';

/// Comprehensive form validation utility class that provides standardized validation patterns for all application forms.
/// This class consolidates validation logic including basic field validation, Swedish-localized error messages,
/// specialized validators for different application domains, and advanced validation patterns. It ensures consistent
/// validation behavior across authentication, recipe management, social features, and collaborative functionality.
/// **Key Features:**
/// - Basic validation patterns with required fields, length constraints, and format validation
/// - Swedish-localized error messages with culturally appropriate tone and guidance
/// - Specialized validators for recipes, user profiles, social interactions, and shopping lists
/// - Advanced validation including password strength, conditional validation, and combinatorial patterns
/// - Unicode support for Swedish characters and international user names
/// - Optional validation patterns for non-required fields with consistent behavior
/// **Integration Points:**
/// - All forms throughout the application use these validators for consistent validation
/// - Authentication flows leverage these for secure user input validation
/// - Recipe creation and editing forms depend on these for data integrity
/// - Social features utilize these for profile and interaction validation
/// **Example Usage:**
/// ```dart
/// // Recipe form validation
/// final titleValidator = FormValidators.combine([
///   FormValidators.required('Recepttitel'),
///   FormValidators.minLength(3, 'Recepttitel'),
/// ]);
/// // Social validation
/// final displayNameValidator = FormValidators.requiredDisplayName();
/// // Authentication validation
/// final passwordValidator = FormValidators.strongPassword();
/// ```
class FormValidators {
  /// Regex patterns
  static final RegExp _urlRegex = RegExp(
    r'^https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)$',
  );

  static final RegExp _displayNameRegex = RegExp(
    r'^[\p{L}\p{N}\s\-_\.]+$',
    unicode: true,
  );

  /// Required field validator.
  static FormFieldValidator<String> required(String fieldName) {
    return (value) {
      if (value == null || value.trim().isEmpty) {
        return AppLocale.current.validationFieldCannotBeEmpty(fieldName);
      }
      return null;
    };
  }

  /// Minimum length validator.
  static FormFieldValidator<String> minLength(int min, String fieldName) {
    return (value) {
      if (value != null && value.trim().length < min) {
        return AppLocale.current.validationFieldTooShort(fieldName, min);
      }
      return null;
    };
  }

  /// Maximum length validator.
  static FormFieldValidator<String> maxLength(int max, String fieldName) {
    return (value) {
      if (value != null && value.length > max) {
        return AppLocale.current.validationFieldTooLong(fieldName, max);
      }
      return null;
    };
  }

  /// Numeric range validator.
  static FormFieldValidator<String> numberRange({
    double? min,
    double? max,
    String? fieldName,
  }) {
    return (value) {
      if (value == null || value.isEmpty) return null;

      final number = double.tryParse(value.replaceAll(',', '.'));
      if (number == null) {
        return AppLocale.current.validationMustBeNumber(
            fieldName ?? AppLocale.current.validationDefaultValueLabel);
      }

      if (min != null && number < min) {
        return AppLocale.current.validationMinValue(
            fieldName ?? AppLocale.current.validationDefaultValueLabel,
            min.toString());
      }

      if (max != null && number > max) {
        return AppLocale.current.validationMaxValue(
            fieldName ?? AppLocale.current.validationDefaultValueLabel,
            max.toString());
      }

      return null;
    };
  }

  /// URL validator
  static FormFieldValidator<String> url() {
    return (value) {
      if (value == null || value.isEmpty) return null;

      if (!_urlRegex.hasMatch(value)) {
        return AppLocale.current.validationInvalidUrlHint;
      }

      return null;
    };
  }

  /// Betyg validator (0-5)
  static FormFieldValidator<String> rating() {
    return numberRange(
        min: 0, max: 5, fieldName: AppLocale.current.validationFieldRating);
  }

  /// Portioner validator (1-100)
  static FormFieldValidator<String> portions() {
    return numberRange(
        min: 1, max: 100, fieldName: AppLocale.current.validationFieldPortions);
  }

  /// Tid validator (1-1440 minuter = 24 timmar)
  static FormFieldValidator<String> cookingTime() {
    return numberRange(
        min: 1,
        max: 1440,
        fieldName: AppLocale.current.validationFieldCookingTime);
  }

  /// Display name validator for user profiles.
  static FormFieldValidator<String> displayName() {
    return (value) {
      if (value == null || value.trim().isEmpty) {
        return AppLocale.current.validationDisplayNameEmpty;
      }

      final trimmed = value.trim();

      if (trimmed.length < 2) {
        return AppLocale.current.validationDisplayNameTooShort;
      }

      if (trimmed.length > 30) {
        return AppLocale.current.validationDisplayNameTooLong;
      }

      if (!_displayNameRegex.hasMatch(trimmed)) {
        return AppLocale.current.validationDisplayNameInvalidChars;
      }

      if (trimmed.replaceAll(RegExp(r'[\s\-_\.]'), '').isEmpty) {
        return AppLocale.current.validationDisplayNameNoLetters;
      }

      if (trimmed != value) {
        return AppLocale.current.validationDisplayNameNoSpaces;
      }

      return null;
    };
  }

  /// Comment validator for recipe comments.
  static FormFieldValidator<String> comment() {
    return (value) {
      if (value == null || value.trim().isEmpty) {
        return AppLocale.current.validationCommentEmpty;
      }

      final trimmed = value.trim();

      if (trimmed.length < 3) {
        return AppLocale.current.validationCommentTooShort;
      }

      if (trimmed.length > 500) {
        return AppLocale.current.validationCommentTooLong;
      }

      return null;
    };
  }

  /// Share message validator.
  static FormFieldValidator<String> shareMessage() {
    return (value) {
      if (value == null || value.isEmpty) {
        return null; // Share message is optional
      }

      if (value.length > 200) {
        return AppLocale.current.validationMessageMaxLength(200);
      }

      return null;
    };
  }

  /// Combines multiple validators.
  static FormFieldValidator<String> combine(
    List<FormFieldValidator<String>> validators,
  ) {
    return (value) {
      for (final validator in validators) {
        final result = validator(value);
        if (result != null) return result;
      }
      return null;
    };
  }

  /// Auth validation - Name field.
  static FormFieldValidator<String> authName() {
    return (value) {
      if (value == null || value.isEmpty) {
        return AppLocale.current.validationNameRequired;
      }
      if (value.length < 2) {
        return AppLocale.current.validationNameTooShort;
      }
      return null;
    };
  }

  /// Auth validation - Email field (from auth_view.dart)
  static FormFieldValidator<String> authEmail() {
    return (value) {
      if (value == null || value.isEmpty) {
        return AppLocale.current.validationEmailRequired;
      }
      // Enkel email-validering - same as auth_view.dart
      if (!value.contains('@') || !value.contains('.')) {
        return AppLocale.current.validationEmailInvalidHint;
      }
      return null;
    };
  }

  /// Auth validation - Password field (from auth_view.dart)
  static FormFieldValidator<String> authPassword({bool isSignUp = false}) {
    return (value) {
      if (value == null || value.isEmpty) {
        return AppLocale.current.validationPasswordRequired;
      }
      if (isSignUp && value.length < 6) {
        return AppLocale.current.validationPasswordTooShort;
      }
      return null;
    };
  }

  /// Shopping item validation - Name field (from input_components.dart)
  static FormFieldValidator<String> shoppingItemName() {
    return (value) {
      if (value == null || value.trim().isEmpty) {
        return AppLocale.current.validationShoppingItemRequired;
      }
      return null;
    };
  }

  /// Shopping item validation - Amount field (from input_components.dart)
  static FormFieldValidator<String> shoppingItemAmount() {
    return (value) {
      if (value == null || value.isEmpty) {
        return AppLocale.current.validationAmountRequired;
      }
      final amount = double.tryParse(value.replaceAll(',', '.'));
      if (amount == null || amount <= 0) {
        return AppLocale.current.validationInvalidAmount;
      }
      return null;
    };
  }

  /// Recipe validation - Tags field (from skriv_sjalv_recept_view.dart)
  static FormFieldValidator<String> recipeTags() {
    return (value) {
      if (value == null || value.isEmpty) return null;

      final tags = value.split(',').map((tag) => tag.trim()).toList();
      for (final tag in tags) {
        if (tag.isEmpty) continue;
        if (tag.length < 2) {
          return AppLocale.current.validationTagMinLength;
        }
        if (tag.length > 20) {
          return AppLocale.current.validationTagMaxLength;
        }
      }
      return null;
    };
  }

  /// Generic text field validation - Non-empty with trim
  static FormFieldValidator<String> nonEmptyText(String fieldName) {
    return (value) {
      if (value == null || value.trim().isEmpty) {
        return AppLocale.current.validationFieldNotEmpty(fieldName);
      }
      return null;
    };
  }

  /// Password strength validation
  static FormFieldValidator<String> strongPassword() {
    return (value) {
      if (value == null || value.isEmpty) {
        return AppLocale.current.validationPasswordRequired;
      }

      if (value.length < 8) {
        return AppLocale.current.validationPasswordMinEight;
      }

      if (!value.contains(RegExp(r'[A-Z]'))) {
        return AppLocale.current.validationPasswordNeedsUppercase;
      }

      if (!value.contains(RegExp(r'[a-z]'))) {
        return AppLocale.current.validationPasswordNeedsLowercase;
      }

      if (!value.contains(RegExp(r'[0-9]'))) {
        return AppLocale.current.validationPasswordNeedsDigit;
      }

      return null;
    };
  }

  /// Conditional validation - only validate if condition is met
  static FormFieldValidator<String> conditional({
    required bool condition,
    required FormFieldValidator<String> validator,
  }) {
    return (value) {
      if (condition) {
        return validator(value);
      }
      return null;
    };
  }

  /// Recipe source URL validation - allows Butlery system URLs or validates as normal URL
  static FormFieldValidator<String> recipeSourceUrl() {
    return (value) {
      if (value == null || value.isEmpty) return null;

      // Allow Butlery system URLs (shared/imported content)
      if (value.startsWith('Delad från') ||
          value.startsWith('Importerad från') ||
          value.contains('Butlery')) {
        return null;
      }

      // For other URLs, validate as normal URL
      return url()(value);
    };
  }

  /// Optional validation - only validate if value is not empty
  static FormFieldValidator<String> optional(
      FormFieldValidator<String> validator) {
    return (value) {
      if (value == null || value.isEmpty) {
        return null;
      }
      return validator(value);
    };
  }

  /// Username validator - combination of required and displayName.
  static FormFieldValidator<String> requiredDisplayName() {
    return combine([
      required(AppLocale.current.validationDisplayNameLabel),
      displayName(),
    ]);
  }

  /// Comment validator - combination for required comments.
  static FormFieldValidator<String> requiredComment() {
    return combine([
      required(AppLocale.current.validationCommentLabel),
      comment(),
    ]);
  }
}
