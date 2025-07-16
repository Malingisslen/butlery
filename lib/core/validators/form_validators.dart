// lib/core/validators/form_validators.dart

import 'package:flutter/material.dart';

/// Centraliserade validators för formulär - Uppdaterad med social features
class FormValidators {
  /// Regex patterns
  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  static final RegExp _urlRegex = RegExp(
    r'^https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)$',
  );

  // NY: Display name regex - tillåter bokstäver, siffror, mellanslag och vissa tecken
  static final RegExp _displayNameRegex = RegExp(
    r'^[a-zA-ZåäöÅÄÖ0-9\s\-_\.]+$',
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

  // ===== NYA SOCIAL VALIDATORS =====

  /// Display name validator - för användarprofilsn
  static FormFieldValidator<String> displayName() {
    return (value) {
      if (value == null || value.trim().isEmpty) {
        return 'Visningsnamn får inte vara tomt';
      }

      final trimmed = value.trim();

      // Längdvalidering
      if (trimmed.length < 2) {
        return 'Visningsnamn måste vara minst 2 tecken';
      }

      if (trimmed.length > 30) {
        return 'Visningsnamn får vara max 30 tecken';
      }

      // Teckenvalidering
      if (!_displayNameRegex.hasMatch(trimmed)) {
        return 'Visningsnamn får bara innehålla bokstäver, siffror, mellanslag och - _ .';
      }

      // Inte bara mellanslag eller specialtecken
      if (trimmed.replaceAll(RegExp(r'[\s\-_\.]'), '').isEmpty) {
        return 'Visningsnamn måste innehålla minst en bokstav eller siffra';
      }

      // Inte börja/sluta med mellanslag
      if (trimmed != value) {
        return 'Visningsnamn får inte börja eller sluta med mellanslag';
      }

      return null;
    };
  }

  /// Bio validator - för profil beskrivning
  static FormFieldValidator<String> bio() {
    return (value) {
      if (value == null || value.isEmpty) {
        return null; // Bio är valfritt
      }

      if (value.length > 150) {
        return 'Beskrivning får vara max 150 tecken';
      }

      // Kolla för bara whitespace
      if (value.trim().isEmpty) {
        return 'Beskrivning får inte bara innehålla mellanslag';
      }

      return null;
    };
  }

  /// Comment validator - för kommentarer på recept
  static FormFieldValidator<String> comment() {
    return (value) {
      if (value == null || value.trim().isEmpty) {
        return 'Kommentar får inte vara tom';
      }

      final trimmed = value.trim();

      if (trimmed.length < 3) {
        return 'Kommentar måste vara minst 3 tecken';
      }

      if (trimmed.length > 500) {
        return 'Kommentar får vara max 500 tecken';
      }

      return null;
    };
  }

  /// Share message validator - för delningsmeddelanden
  static FormFieldValidator<String> shareMessage() {
    return (value) {
      if (value == null || value.isEmpty) {
        return null; // Delningsmeddelande är valfritt
      }

      if (value.length > 200) {
        return 'Meddelande får vara max 200 tecken';
      }

      return null;
    };
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

  // ===== SPECIFIKA KOMBINATIONER =====

  /// Användarnamn validator - kombination av required och displayName
  static FormFieldValidator<String> requiredDisplayName() {
    return combine([
      required('Visningsnamn'),
      displayName(),
    ]);
  }

  /// Kommentar validator - kombination för required comments
  static FormFieldValidator<String> requiredComment() {
    return combine([
      required('Kommentar'),
      comment(),
    ]);
  }
}
