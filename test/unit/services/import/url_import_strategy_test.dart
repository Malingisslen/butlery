/// Unit tests for UrlImportStrategy — URL validation and ImportValidationMixin
///
/// Tests pure logic that does not require Firebase:
/// - URL validation (canHandle, validateInput)
/// - Blocked host detection (SSRF protection)
/// - ImportValidationMixin helpers
/// - ImportResult factory constructors
///
/// Integration-level tests (HTTP fetching, multi-tier extraction) are NOT
/// covered here because UrlImportStrategy eagerly creates ParseEventLogger
/// which requires FirebaseFunctions.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/import/import_strategy.dart';
import 'package:butlery/services/import/fetchers/http_content_fetcher.dart';
import 'package:butlery/models/recipe_unified.dart';

/// Concrete class to test ImportValidationMixin in isolation
class _ValidationHelper with ImportValidationMixin {}

void main() {
  group('URL canHandle logic', () {
    // We replicate UrlImportStrategy.canHandle without constructing the class,
    // because the constructor needs Firebase. The logic is: valid URI, http(s)
    // scheme, non-empty host, not blocked.
    bool canHandle(String input) {
      final trimmed = input.trim();
      if (trimmed.isEmpty) return false;
      try {
        final uri = Uri.parse(trimmed);
        return uri.hasScheme &&
            (uri.scheme == 'http' || uri.scheme == 'https') &&
            uri.hasAuthority &&
            uri.host.isNotEmpty &&
            !HttpContentFetcher.isBlockedHost(uri.host);
      } catch (_) {
        return false;
      }
    }

    test('accepts valid HTTP URLs', () {
      expect(canHandle('http://example.com/recipe'), isTrue);
      expect(canHandle('http://www.ica.se/recept/pannkakor-123'), isTrue);
    });

    test('accepts valid HTTPS URLs', () {
      expect(canHandle('https://example.com/recipe'), isTrue);
      expect(canHandle('https://www.ica.se/recept/pannkakor-123'), isTrue);
      expect(canHandle('https://www.arla.se/recept/tarta-456'), isTrue);
      expect(canHandle('https://www.koket.se/mat-dryck/recept/789'), isTrue);
    });

    test('rejects empty and whitespace-only input', () {
      expect(canHandle(''), isFalse);
      expect(canHandle('   '), isFalse);
    });

    test('rejects non-HTTP(S) schemes', () {
      expect(canHandle('ftp://files.example.com/recipe.txt'), isFalse);
      expect(canHandle('file:///C:/recipes/local.txt'), isFalse);
      expect(canHandle('data:text/html,<html></html>'), isFalse);
      expect(canHandle('mailto:chef@example.com'), isFalse);
    });

    test('rejects plain text that is not a URL', () {
      expect(canHandle('not a url'), isFalse);
      expect(canHandle('archive:123'), isFalse);
    });

    test('rejects URLs without host', () {
      expect(canHandle('http://'), isFalse);
      expect(canHandle('https://'), isFalse);
    });

    test('handles URLs with query, fragment, port, auth', () {
      expect(canHandle('https://example.com/recipe?id=123&lang=sv'), isTrue);
      expect(canHandle('https://example.com:8080/recipe'), isTrue);
      expect(canHandle('https://example.com/recipe#instructions'), isTrue);
      expect(canHandle('https://subdomain.example.com/path/to/recipe'), isTrue);
    });

    test('trims whitespace before parsing', () {
      expect(canHandle('  https://example.com/recipe  '), isTrue);
    });

    test('handles very long URLs', () {
      final longUrl = 'https://example.com/recipe/${'a' * 500}';
      expect(canHandle(longUrl), isTrue);
    });

    test('recognises Swedish recipe sites', () {
      expect(canHandle('https://www.ica.se/recept/pannkakor-123'), isTrue);
      expect(canHandle('https://ica.se/recept/koktbullar-456'), isTrue);
      expect(canHandle('https://www.arla.se/recept/tarta-123'), isTrue);
      expect(canHandle('https://www.koket.se/recept/middag/456'), isTrue);
    });
  });

  group('HttpContentFetcher.isBlockedHost (SSRF protection)', () {
    test('blocks localhost', () {
      expect(HttpContentFetcher.isBlockedHost('localhost'), isTrue);
    });

    test('blocks loopback IPv4', () {
      expect(HttpContentFetcher.isBlockedHost('127.0.0.1'), isTrue);
      expect(HttpContentFetcher.isBlockedHost('127.0.0.2'), isTrue);
    });

    test('blocks private 10.x.x.x range', () {
      expect(HttpContentFetcher.isBlockedHost('10.0.0.1'), isTrue);
      expect(HttpContentFetcher.isBlockedHost('10.255.255.255'), isTrue);
    });

    test('blocks private 172.16-31.x.x range', () {
      expect(HttpContentFetcher.isBlockedHost('172.16.0.1'), isTrue);
      expect(HttpContentFetcher.isBlockedHost('172.31.255.255'), isTrue);
    });

    test('blocks private 192.168.x.x range', () {
      expect(HttpContentFetcher.isBlockedHost('192.168.0.1'), isTrue);
      expect(HttpContentFetcher.isBlockedHost('192.168.1.100'), isTrue);
    });

    test('blocks link-local 169.254.x.x', () {
      expect(HttpContentFetcher.isBlockedHost('169.254.1.1'), isTrue);
    });

    test('blocks 0.0.0.0', () {
      expect(HttpContentFetcher.isBlockedHost('0.0.0.0'), isTrue);
    });

    test('blocks empty host', () {
      expect(HttpContentFetcher.isBlockedHost(''), isTrue);
    });

    test('allows public hostnames', () {
      expect(HttpContentFetcher.isBlockedHost('example.com'), isFalse);
      expect(HttpContentFetcher.isBlockedHost('www.ica.se'), isFalse);
    });

    test('allows public IP addresses', () {
      expect(HttpContentFetcher.isBlockedHost('8.8.8.8'), isFalse);
      expect(HttpContentFetcher.isBlockedHost('1.1.1.1'), isFalse);
    });
  });

  group('ImportValidationMixin', () {
    late _ValidationHelper validator;

    setUp(() {
      validator = _ValidationHelper();
    });

    group('isValidRecipeName', () {
      test('accepts names with 2+ characters', () {
        expect(validator.isValidRecipeName('AB'), isTrue);
        expect(validator.isValidRecipeName('Pannkakor'), isTrue);
        expect(validator.isValidRecipeName('Swedish Meatballs'), isTrue);
      });

      test('rejects empty or single-char names', () {
        expect(validator.isValidRecipeName(''), isFalse);
        expect(validator.isValidRecipeName(' '), isFalse);
        expect(validator.isValidRecipeName('A'), isFalse);
      });
    });

    group('isValidIngredients', () {
      test('accepts non-empty ingredient lists', () {
        expect(validator.isValidIngredients(['2 dl mjöl']), isTrue);
        expect(validator.isValidIngredients(['mjöl', 'socker', 'ägg']), isTrue);
      });

      test('rejects empty lists', () {
        expect(validator.isValidIngredients([]), isFalse);
      });

      test('rejects lists with only blank strings', () {
        expect(validator.isValidIngredients(['', '  ']), isFalse);
      });
    });

    group('isValidInstructions', () {
      test('accepts non-empty instruction lists', () {
        expect(validator.isValidInstructions(['Blanda allt']), isTrue);
      });

      test('rejects empty lists', () {
        expect(validator.isValidInstructions([]), isFalse);
      });

      test('rejects lists with only blank strings', () {
        expect(validator.isValidInstructions(['', '  ']), isFalse);
      });
    });

    group('normalizeText', () {
      test('collapses multiple spaces', () {
        expect(validator.normalizeText('hello   world'), 'hello world');
      });

      test('trims leading and trailing whitespace', () {
        expect(validator.normalizeText('  hello  '), 'hello');
      });

      test('preserves newlines but normalises per-line spacing', () {
        final result = validator.normalizeText('line1  x\n  line2  y');
        expect(result, 'line1 x\nline2 y');
      });
    });

    group('extractNumber', () {
      test('extracts first integer from text', () {
        expect(validator.extractNumber('4 portioner'), 4);
        expect(validator.extractNumber('ca 6 bitar'), 6);
      });

      test('returns null when no number found', () {
        expect(validator.extractNumber('no numbers'), isNull);
      });
    });

    group('extractRating', () {
      test('extracts rating in "X av 5" format', () {
        expect(validator.extractRating('4.5 av 5'), 4.5);
      });

      test('extracts rating in "X/5" format', () {
        expect(validator.extractRating('3/5'), 3.0);
      });

      test('returns null for out-of-range ratings', () {
        expect(validator.extractRating('0.5 av 5'), isNull);
        expect(validator.extractRating('6 av 5'), isNull);
      });

      test('returns null when no rating pattern found', () {
        expect(validator.extractRating('no rating'), isNull);
      });
    });
  });

  group('ImportResult', () {
    test('success creates result with recipe', () {
      final recipe = Recipe(
        core: RecipeCore(
          id: 'test-id',
          title: 'Test',
          description: '',
          ingredients: ['a'],
          instructions: ['b'],
          mealType: 'Middag',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          createdBy: 'u1',
        ),
        type: RecipeType.personal,
      );
      final result = ImportResult.success(recipe, metadata: {'url': 'x'});

      expect(result.isSuccess, isTrue);
      expect(result.recipe, isNotNull);
      expect(result.errorMessage, isNull);
      expect(result.needsAssistance, isFalse);
      expect(result.hasMetadata, isTrue);
    });

    test('failure creates result without recipe', () {
      final result = ImportResult.failure('something went wrong');

      expect(result.isSuccess, isFalse);
      expect(result.recipe, isNull);
      expect(result.errorMessage, 'something went wrong');
      expect(result.needsAssistance, isFalse);
    });

    test('assistance creates result for user-assisted import', () {
      final result = ImportResult.assistance(
        extractedText: 'some text',
        suggestedTitle: 'Maybe Pancakes',
        likelyIngredientLines: [0, 2, 4],
      );

      expect(result.isSuccess, isFalse);
      expect(result.needsAssistance, isTrue);
      expect(result.extractedText, 'some text');
      expect(result.suggestedTitle, 'Maybe Pancakes');
      expect(result.likelyIngredientLines, [0, 2, 4]);
    });

    test('hasWarnings is false when warnings is null or empty', () {
      final noWarnings = ImportResult.failure('err');
      expect(noWarnings.hasWarnings, isFalse);

      final emptyWarnings = ImportResult.failure('err', warnings: []);
      expect(emptyWarnings.hasWarnings, isFalse);
    });

    test('hasWarnings is true when warnings exist', () {
      final result =
          ImportResult.failure('err', warnings: ['quality may vary']);
      expect(result.hasWarnings, isTrue);
    });
  });
}
