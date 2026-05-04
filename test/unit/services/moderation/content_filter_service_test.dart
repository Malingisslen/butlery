// BUT-517 — coverage for the canonical pre-publish profanity gate.
//
// `ensureClean()` is the helper every UGC surface (recipe titles, group
// names, profile bios, cook-snap captions, comments, chat messages) is
// supposed to call BEFORE the API write. The contract under test:
//   - empty / whitespace passes (length-required is a separate validator's
//     job — the gate must not double-reject as "field empty")
//   - clean text passes
//   - profanity (Swedish + English) is rejected with the localized
//     `contentFilterWarning` reason
//   - mixed clean+dirty text is rejected (any token match → reject)
//   - the result records the originating `fieldName` for telemetry but the
//     user-facing reason is generic (no field-name leak)
//   - per-field-type behavior is identical: the helper does NOT branch on
//     `fieldName` semantically — verified explicitly because the surface
//     wiring depends on this guarantee.

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/services/moderation/content_filter_service.dart';

void main() {
  late ContentFilterService service;

  setUp(() {
    service = ContentFilterService();
  });

  group('ContentFilterService.ensureClean', () {
    test('clean text passes', () {
      final result = service.ensureClean(
        'Pasta carbonara med pancetta och ägg',
        fieldName: 'recipe_title',
      );

      expect(result.isClean, isTrue);
      expect(result.reason, isNull);
      expect(result.fieldName, isNull);
    });

    test('empty string passes (required-ness is a separate validator)', () {
      final result = service.ensureClean('', fieldName: 'recipe_title');

      expect(result.isClean, isTrue,
          reason: 'ensureClean must not double-reject empty input — the '
              'required-validator owns that error message.');
      expect(result.reason, isNull);
    });

    test('whitespace-only passes', () {
      final result = service.ensureClean('   \n\t  ', fieldName: 'bio');

      expect(result.isClean, isTrue);
      expect(result.reason, isNull);
    });

    test('Swedish profanity is rejected with the localized warning', () {
      final result = service.ensureClean(
        'Det här är jävla bra mat',
        fieldName: 'recipe_description',
      );

      expect(result.isClean, isFalse);
      expect(result.reason, equals(AppLocale.current.contentFilterWarning));
      expect(result.fieldName, equals('recipe_description'),
          reason: 'fieldName must be preserved on the result for telemetry.');
    });

    test('English profanity is rejected with the localized warning', () {
      final result = service.ensureClean(
        'this fucking recipe is amazing',
        fieldName: 'group_name',
      );

      expect(result.isClean, isFalse);
      expect(result.reason, equals(AppLocale.current.contentFilterWarning));
    });

    test('mixed clean + dirty text is rejected (any token match)', () {
      final result = service.ensureClean(
        'En väldigt bra rätt men kuk smakar konstigt',
        fieldName: 'comment',
      );

      expect(result.isClean, isFalse);
      expect(result.reason, equals(AppLocale.current.contentFilterWarning));
    });

    test('rejection message does not leak the field name (UI-safe)', () {
      final result = service.ensureClean(
        'fan',
        fieldName: 'super_secret_internal_field',
      );

      expect(result.isClean, isFalse);
      expect(result.reason, isNot(contains('super_secret_internal_field')),
          reason: 'User-facing reason must be generic so the same string '
              'works in inline errorText AND SnackBar without a field name '
              'leaking into the UI.');
    });

    test('per-field-type behavior is identical (no fieldName branching)', () {
      // Surfaces wired in BUT-517 (recipe title/instructions, group
      // name/description, profile displayName/bio, cook-snap caption) all
      // route through the same gate. Future regression: if someone branches
      // on fieldName here without updating the wiring, this test breaks.
      const dirty = 'fan';
      final fields = [
        'recipe_title',
        'recipe_description',
        'recipe_ingredient',
        'recipe_instruction',
        'group_name',
        'group_description',
        'profile_displayName',
        'profile_bio',
        'cook_snap_caption',
        'comment',
      ];

      for (final f in fields) {
        final result = service.ensureClean(dirty, fieldName: f);
        expect(result.isClean, isFalse,
            reason: 'expected reject for fieldName=$f');
        expect(result.reason, equals(AppLocale.current.contentFilterWarning));
      }
    });

    test('word-boundary matching — substrings inside other words pass', () {
      // 'fan' is in the blocklist, but 'fantastisk' should NOT match because
      // of the word-boundary regex. This is the headline reason we use a
      // regex with \b instead of plain substring matching.
      final result = service.ensureClean(
        'Det här är fantastisk mat',
        fieldName: 'recipe_title',
      );

      expect(result.isClean, isTrue,
          reason: '"fantastisk" contains "fan" as a substring but is not the '
              'standalone profanity. Substring match would be a false '
              'positive that ships into Swedish UGC daily.');
    });

    test('case-insensitive matching', () {
      final upper = service.ensureClean('FAN', fieldName: 'group_name');
      final mixed = service.ensureClean('FaN', fieldName: 'group_name');

      expect(upper.isClean, isFalse);
      expect(mixed.isClean, isFalse);
    });
  });

  group('ContentFilterService.containsProfanity (legacy)', () {
    test('preserves boolean API for chat + comments warning UI', () {
      // chat_viewmodel.dart:92 + social_comments_manager.dart:57 still
      // expose this as a non-blocking warning (UI hint while typing). The
      // ensureClean refactor must NOT change that surface.
      expect(service.containsProfanity('clean text'), isFalse);
      expect(service.containsProfanity('fan'), isTrue);
      expect(service.containsProfanity(''), isFalse);
    });
  });

  group('ContentFilterService.filterText', () {
    test('replaces matched profanity with asterisks of equal length', () {
      final filtered = service.filterText('det är fan så jävla bra');
      // 'fan' (3) + 'jävla' (5) — both replaced with same-length asterisks.
      expect(filtered, equals('det är *** så ***** bra'));
    });

    test('empty input is returned as-is', () {
      expect(service.filterText(''), equals(''));
    });
  });

  // BUT-525: normalization gates that close the trivial-bypass holes
  // flagged in the Trust & Safety report. The matcher applies a
  // length-preserving normalize (lowercase → diacritic strip → leet→letter)
  // before the regex, and the regex uses `c+` quantifiers per character so
  // run-collapse variants (`fuuuck`) match without a separate normalizer
  // step. These tests are the contract.
  group('ContentFilterService.containsProfanity — BUT-525 normalization', () {
    test('leetspeak: 5h1t (numerals → s/i/t) is rejected', () {
      expect(service.containsProfanity('this is 5h1t'), isTrue);
    });

    test('leetspeak: b1tch is rejected', () {
      expect(service.containsProfanity('what a b1tch'), isTrue);
    });

    test('leetspeak: f4n (Swedish "fan" with 4→a) is rejected', () {
      expect(service.containsProfanity('åh f4n'), isTrue);
    });

    test('run-collapse: fuuuuck is rejected', () {
      expect(service.containsProfanity('what the fuuuuck'), isTrue);
    });

    test('run-collapse: shiiit is rejected', () {
      expect(service.containsProfanity('oh shiiit'), isTrue);
    });

    test('diacritic strip: bög written as bog still rejected', () {
      // Risk accepted in content_filter_words.dart: this means the English
      // word `bog` (marsh / bog roll) ALSO trips. On a Swedish-first cooking
      // app the FP risk is judged acceptable.
      expect(service.containsProfanity('what a bog'), isTrue);
    });

    test('expanded SV slur "svartskalle" is rejected', () {
      expect(service.containsProfanity('din svartskalle'), isTrue);
    });

    test('expanded EN slur "twat" is rejected', () {
      expect(service.containsProfanity('absolute twat'), isTrue);
    });

    test('legitimate Swedish food vocabulary still passes', () {
      // Regression guard: the canonical Swedish recipe vocabulary must
      // not trip after BUT-525's expanded blocklist + normalization.
      const safe = [
        'kanelbullar med smör och socker',
        'pasta carbonara med pancetta',
        'ärtsoppa och pannkakor',
        'köttbullar med lingonsylt',
        'falukorv med stuvade makaroner',
      ];
      for (final s in safe) {
        expect(service.containsProfanity(s), isFalse,
            reason: 'expected legitimate recipe text to pass: "$s"');
      }
    });
  });

  group('ContentFilterService.filterText — BUT-525 offset preservation', () {
    test('asterisks the original input span (length-preserving normalize)', () {
      // `f4n` (3 chars) normalizes to `fan` (3 chars), matches at the same
      // offsets, replaced with `***`. The user's surrounding casing/spacing
      // survives intact.
      final out = service.filterText('Helvete vad f4n');
      expect(out, equals('******* vad ***'));
    });

    test('run-collapse variants asterisk the full original run', () {
      // `fuuuuck` is 7 chars in the original; after normalization
      // `fuuuuck` is still 7 chars (no run-collapse in the normalizer);
      // the regex `f+u+c+k+` matches the full 7-char span, replaced
      // with 7 asterisks.
      final out = service.filterText('what the fuuuuck dude');
      expect(out, equals('what the ******* dude'));
    });
  });
}
