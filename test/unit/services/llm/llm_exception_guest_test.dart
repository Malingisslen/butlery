/// BUT-920: the server's two guest answers, told apart from the generic
/// "overloaded" resource-exhausted.
library;

// FirebaseFunctionsException's constructor is @protected; the server's denial
// can only be built here this way.
// ignore_for_file: invalid_use_of_protected_member

import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/l10n/app_localizations_en.dart';
import 'package:butlery/services/llm/llm_models.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';

FirebaseFunctionsException _denial(String message, String reason) =>
    FirebaseFunctionsException(
      code: 'resource-exhausted',
      message: message,
      details: {'reason': reason},
    );

void main() {
  test('guest-import-limit gets its own code and message', () {
    final ex = LlmException.fromFirebase(
      _denial('guest-import-limit', 'guest-import-limit'),
    );

    expect(ex.code, LlmException.guestImportLimitCode);
    expect(ex.code, 'guest-import-limit');
    expect(ex.isRateLimited, isTrue);
    expect(ex.message, 'Du har använt dina tre importer');
    expect(ex.message, AppLocale.current.llmGuestImportLimit);
    expect(ex.retryAfter, isNull);
  });

  test('guest-capacity gets its own code and message', () {
    final ex = LlmException.fromFirebase(
      _denial('guest-capacity', 'guest-capacity'),
    );

    expect(ex.code, LlmException.guestCapacityCode);
    expect(ex.isRateLimited, isTrue);
    expect(
      ex.message,
      'Gästimporter är tillfälligt slut. Skapa ett gratis konto för att '
      'importera.',
    );
    expect(ex.retryAfter, isNull);
  });

  test('a resource-exhausted without a guest reason is still "overloaded"', () {
    final ex = LlmException.fromFirebase(
      FirebaseFunctionsException(
        code: 'resource-exhausted',
        message: 'slow down',
      ),
    );

    expect(ex.code, 'resource-exhausted');
    expect(ex.retryAfter, const Duration(minutes: 1));
  });

  test('both messages exist in English too', () {
    final en = AppLocalizationsEn();
    expect(en.llmGuestImportLimit, 'You have used your three imports');
    expect(en.llmGuestCapacity, contains('Create a free account'));
  });
}
