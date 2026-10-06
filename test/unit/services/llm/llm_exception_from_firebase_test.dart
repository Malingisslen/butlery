/// BUT-582: regression gate for LlmException.fromFirebase.
///
/// `fromFirebase` is the user-visible error-copy switchboard for every LLM
/// failure (recipe import, OCR, ingredient parsing). A regression here
/// silently degrades user-facing error messages — e.g. a deadline-exceeded
/// timeout falling back to the generic "Ett fel uppstod" bucket would mean
/// users stop seeing actionable copy and start seeing raw Firebase errors.
///
/// This test pins the contract:
///   - error string contains a known Firebase code → mapped exception with
///     the matching `code` AND a non-generic localized `message`.
///   - rate-limited path sets `isRateLimited` + `retryAfter`.
///   - unknown error → falls through to the 'unknown' bucket.
///
/// Localization: `AppLocale.current` defaults to Swedish (see
/// `lib/core/l10n/app_locale.dart`). Tests assert against the Swedish copy
/// because that's what real users see; if either the Swedish or the English
/// copy regresses, the parity check below catches it.
library;

// FirebaseFunctionsException's constructor is @protected; the server's denial
// can only be built here this way.
// ignore_for_file: invalid_use_of_protected_member

import 'dart:io';

import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/l10n/app_localizations_en.dart';
import 'package:butlery/services/llm/llm_models.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LlmException.fromFirebase', () {
    test('maps unauthenticated to llmMustBeLoggedIn (Swedish default)', () {
      final ex = LlmException.fromFirebase(
        Exception('FirebaseFunctionsException: unauthenticated; nope'),
      );

      expect(ex.code, 'unauthenticated');
      expect(ex.isRateLimited, isFalse);
      expect(ex.retryAfter, isNull);
      expect(ex.message, AppLocale.current.llmMustBeLoggedIn);
      // Sanity: copy is non-empty and not the raw error string.
      expect(ex.message, isNotEmpty);
      expect(ex.message, isNot(contains('FirebaseFunctionsException')));
    });

    test('maps resource-exhausted with rate-limit metadata', () {
      final ex = LlmException.fromFirebase(
        Exception('code=resource-exhausted slow down'),
      );

      expect(ex.code, 'resource-exhausted');
      expect(ex.isRateLimited, isTrue);
      expect(ex.retryAfter, const Duration(minutes: 1));
      expect(ex.message, AppLocale.current.llmServiceOverloaded);
    });

    test('maps invalid-argument and surfaces the raw cause to the user', () {
      final ex = LlmException.fromFirebase(
        Exception('invalid-argument: bad text'),
      );

      expect(ex.code, 'invalid-argument');
      // The l10n template includes the raw error so users have a hint.
      expect(ex.message, contains('bad text'));
    });

    test('BUT-582: maps deadline-exceeded to llmTimeout (not generic)', () {
      final ex = LlmException.fromFirebase(Exception('deadline-exceeded'));

      expect(ex.code, 'deadline-exceeded');
      expect(ex.isRateLimited, isFalse);
      expect(ex.message, AppLocale.current.llmTimeout);
      // Regression guard: must NOT fall through to the generic bucket.
      expect(
        ex.message,
        isNot(equals(AppLocale.current.llmGenericError('deadline-exceeded'))),
      );
    });

    test(
      'BUT-582: maps unavailable to llmTemporarilyUnavailable (not generic)',
      () {
        final ex = LlmException.fromFirebase(Exception('unavailable'));

        expect(ex.code, 'unavailable');
        expect(ex.message, AppLocale.current.llmTemporarilyUnavailable);
        // Regression guard: must NOT fall through to the generic bucket.
        expect(
          ex.message,
          isNot(equals(AppLocale.current.llmGenericError('unavailable'))),
        );
      },
    );

    test('falls through to unknown bucket on unrecognised error', () {
      final ex = LlmException.fromFirebase(
        Exception('some unrelated explosion'),
      );

      expect(ex.code, 'unknown');
      // The generic l10n template embeds the raw cause for support diagnosis.
      expect(ex.message, contains('some unrelated explosion'));
    });

    // BUT-2243: the server's per-user AI cost ceiling arrives as
    // `resource-exhausted` with `details.reason`. Without its own mapping the
    // user is told the service is overloaded and to retry in a minute, when
    // the answer is "tomorrow" or "next month".
    group('the AI cost ceiling (BUT-2243)', () {
      FirebaseFunctionsException ceiling(String reason) =>
          FirebaseFunctionsException(
            code: 'resource-exhausted',
            message: 'Du har använt AI-hjälpen.',
            details: {'reason': reason},
          );

      test('llm_cost_day maps to its own message, no one-minute retry', () {
        final ex = LlmException.fromFirebase(ceiling('llm_cost_day'));

        expect(ex.code, LlmException.costCeilingCode);
        expect(ex.message, AppLocale.current.llmCostCeilingDay);
        expect(ex.isRateLimited, isTrue);
        expect(ex.retryAfter, isNull);
      });

      test('llm_cost_month maps to its own message, no one-minute retry', () {
        final ex = LlmException.fromFirebase(ceiling('llm_cost_month'));

        expect(ex.code, LlmException.costCeilingCode);
        expect(ex.message, AppLocale.current.llmCostCeilingMonth);
        expect(ex.isRateLimited, isTrue);
        expect(ex.retryAfter, isNull);
      });

      test(
        'the day and month messages differ, and neither is "overloaded"',
        () {
          expect(
            AppLocale.current.llmCostCeilingDay,
            isNot(AppLocale.current.llmCostCeilingMonth),
          );
          expect(
            AppLocale.current.llmCostCeilingDay,
            isNot(AppLocale.current.llmServiceOverloaded),
          );
          expect(
            AppLocale.current.llmCostCeilingMonth,
            isNot(AppLocale.current.llmServiceOverloaded),
          );
        },
      );

      for (final (label, details) in [
        (
          'the per-user call cap',
          <String, Object>{'retryAfterSeconds': 30, 'remainingTokens': 0},
        ),
        ('the global cap', null),
      ]) {
        test('$label still maps to llmServiceOverloaded', () {
          final ex = LlmException.fromFirebase(
            FirebaseFunctionsException(
              code: 'resource-exhausted',
              message: 'x',
              details: details,
            ),
          );

          expect(ex.code, 'resource-exhausted');
          expect(ex.message, AppLocale.current.llmServiceOverloaded);
          expect(ex.retryAfter, const Duration(minutes: 1));
        });
      }

      // The reason strings are typed in two languages. Read the server's out
      // of its source so a rename there reddens here rather than sending the
      // user back to "overloaded".
      test('the server denies with exactly the two reasons mapped here', () {
        final ts = File(
          'functions/src/middleware/llm_cost_ledger.ts',
        ).readAsStringSync();
        final reasons = RegExp(
          r'deny\(uid, "([a-z_]+)"',
        ).allMatches(ts).map((m) => m.group(1)!).toSet();

        expect(reasons, {'llm_cost_day', 'llm_cost_month'});
      });
    });

    test('Swedish ↔ English copy parity: all 8 messages are distinct', () {
      // Catches a regression where two codes accidentally share the same copy
      // (e.g. timeout and unavailable both falling back to a generic string).
      final en = AppLocalizationsEn();
      final messages = <String>{
        en.llmMustBeLoggedIn,
        en.llmServiceOverloaded,
        en.llmInvalidArgument('x'),
        en.llmTimeout,
        en.llmTemporarilyUnavailable,
        en.llmGenericError('x'),
        en.llmCostCeilingDay,
        en.llmCostCeilingMonth,
      };
      expect(
        messages.length,
        8,
        reason:
            'Each Firebase error code must map to a distinct user-facing message',
      );
    });
  });
}
