// lib/core/validators/form_validators.dart

import 'package:flutter/material.dart';

/// Centraliserade validators för formulär
class FormValidators {
  /// Regex patterns
  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  static final RegExp _urlRegex = RegExp(
    r'^https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)$',
  );

  /// Obligatoriskt fält
  static FormFieldValidator<String> required(String fieldName) {
    return (value) {
      if (value == null || value.trim().isEmpty) {
        return '$fieldName får inte vara tom';
      }
      return null;
    };
  }

  /// Min längd
  static FormFieldValidator<String> minLength(int min, String fieldName) {
    return (value) {
      if (value != null && value.trim().length < min) {
        return '$fieldName måste vara minst $min tecken';
      }
      return null;
    };
  }

  /// Max längd
  static FormFieldValidator<String> maxLength(int max, String fieldName) {
    return (value) {
      if (value != null && value.length > max) {
        return '$fieldName får vara max $max tecken';
      }
      return null;
    };
  }

  /// Numeriskt värde inom intervall
  static FormFieldValidator<String> numberRange({
    double? min,
    double? max,
    String? fieldName,
  }) {
    return (value) {
      if (value == null || value.isEmpty) return null;

      final number = double.tryParse(value.replaceAll(',', '.'));
      if (number == null) {
        return '${fieldName ?? 'Värdet'} måste vara ett nummer';
      }

      if (min != null && number < min) {
        return '${fieldName ?? 'Värdet'} måste vara minst $min';
      }

      if (max != null && number > max) {
        return '${fieldName ?? 'Värdet'} får vara max $max';
      }

      return null;
    };
  }

  /// Email validator
  static FormFieldValidator<String> email() {
    return (value) {
      if (value == null || value.isEmpty) return null;

      if (!_emailRegex.hasMatch(value)) {
        return 'Ange en giltig e-postadress';
      }

      return null;
    };
  }

  /// URL validator
  static FormFieldValidator<String> url() {
    return (value) {
      if (value == null || value.isEmpty) return null;

      if (!_urlRegex.hasMatch(value)) {
        return 'Ange en giltig URL (börja med http:// eller https://)';
      }

      return null;
    };
  }

  /// Betyg validator (0-5)
  static FormFieldValidator<String> rating() {
    return numberRange(min: 0, max: 5, fieldName: 'Betyg');
  }

  /// Portioner validator (1-100)
  static FormFieldValidator<String> portions() {
    return numberRange(min: 1, max: 100, fieldName: 'Antal portioner');
  }

  /// Tid validator (1-1440 minuter = 24 timmar)
  static FormFieldValidator<String> cookingTime() {
    return numberRange(min: 1, max: 1440, fieldName: 'Tillagningstid');
  }

  /// Kombinerar flera validators
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
}
