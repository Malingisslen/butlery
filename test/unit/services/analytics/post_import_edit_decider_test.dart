/// Unit tests for [PostImportEditDecider] (BUT-569).
///
/// Validates the gates that determine whether a `recipe_edited` should
/// also emit `post_import_edit`:
///   - Imported recipe within window → fires with payload
///   - Imported recipe outside window → does NOT fire
///   - Non-imported recipe (no sourceUrl) → does NOT fire
///   - Empty fieldsChanged → does NOT fire
///   - tier_used included only when non-empty
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/analytics/post_import_edit_decider.dart';

void main() {
  group('PostImportEditDecider (BUT-569)', () {
    final fixedNow = DateTime(2026, 4, 27, 12, 0, 0);

    test('fires for imported recipe within window with full payload', () {
      final params = PostImportEditDecider.build(
        recipeId: 'r1',
        fieldsChanged: ['title', 'ingredients'],
        sourceUrl: 'https://www.koket.se/recipe',
        importedAt: fixedNow.subtract(const Duration(days: 2)),
        now: fixedNow,
        tierUsed: 'site_config',
      );

      expect(params, isNotNull);
      expect(params!['recipe_id'], 'r1');
      expect(params['fields_changed'], 'title,ingredients');
      expect(params['hours_since_import'], 48);
      expect(params['tier_used'], 'site_config');
    });

    test('does NOT fire when recipe was imported >N days ago', () {
      final params = PostImportEditDecider.build(
        recipeId: 'r1',
        fieldsChanged: ['title'],
        sourceUrl: 'https://www.koket.se/recipe',
        importedAt: fixedNow.subtract(const Duration(days: 31)),
        now: fixedNow,
        windowDays: 30,
      );

      expect(params, isNull);
    });

    test('fires at the edge of the window (exactly N days)', () {
      final params = PostImportEditDecider.build(
        recipeId: 'r1',
        fieldsChanged: ['title'],
        sourceUrl: 'https://x',
        importedAt: fixedNow.subtract(const Duration(days: 30)),
        now: fixedNow,
        windowDays: 30,
      );

      expect(params, isNotNull);
      expect(params!['hours_since_import'], 30 * 24);
    });

    test('does NOT fire for non-imported recipe (sourceUrl null)', () {
      final params = PostImportEditDecider.build(
        recipeId: 'r1',
        fieldsChanged: ['title'],
        sourceUrl: null,
        importedAt: fixedNow.subtract(const Duration(hours: 1)),
        now: fixedNow,
      );

      expect(params, isNull);
    });

    test('does NOT fire for non-imported recipe (sourceUrl empty)', () {
      final params = PostImportEditDecider.build(
        recipeId: 'r1',
        fieldsChanged: ['title'],
        sourceUrl: '',
        importedAt: fixedNow.subtract(const Duration(hours: 1)),
        now: fixedNow,
      );

      expect(params, isNull);
    });

    test('does NOT fire when no fields changed', () {
      final params = PostImportEditDecider.build(
        recipeId: 'r1',
        fieldsChanged: const [],
        sourceUrl: 'https://x',
        importedAt: fixedNow.subtract(const Duration(hours: 1)),
        now: fixedNow,
      );

      expect(params, isNull);
    });

    test('omits tier_used when null or empty', () {
      final paramsNull = PostImportEditDecider.build(
        recipeId: 'r1',
        fieldsChanged: ['title'],
        sourceUrl: 'https://x',
        importedAt: fixedNow.subtract(const Duration(hours: 1)),
        now: fixedNow,
        tierUsed: null,
      );
      final paramsEmpty = PostImportEditDecider.build(
        recipeId: 'r1',
        fieldsChanged: ['title'],
        sourceUrl: 'https://x',
        importedAt: fixedNow.subtract(const Duration(hours: 1)),
        now: fixedNow,
        tierUsed: '',
      );

      expect(paramsNull!.containsKey('tier_used'), isFalse);
      expect(paramsEmpty!.containsKey('tier_used'), isFalse);
    });

    test('does NOT fire when importedAt is in the future (clock skew)', () {
      final params = PostImportEditDecider.build(
        recipeId: 'r1',
        fieldsChanged: ['title'],
        sourceUrl: 'https://x',
        importedAt: fixedNow.add(const Duration(hours: 1)),
        now: fixedNow,
      );

      expect(params, isNull);
    });

    test('handles each tier_used value (site_config, regex, llm)', () {
      for (final tier in ['site_config', 'regex', 'llm']) {
        final params = PostImportEditDecider.build(
          recipeId: 'r1',
          fieldsChanged: ['title'],
          sourceUrl: 'https://x',
          importedAt: fixedNow.subtract(const Duration(hours: 1)),
          now: fixedNow,
          tierUsed: tier,
        );

        expect(params, isNotNull, reason: 'tier=$tier');
        expect(params!['tier_used'], tier);
      }
    });
  });
}
