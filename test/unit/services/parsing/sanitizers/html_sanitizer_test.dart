import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/parsing/sanitizers/html_sanitizer.dart';

void main() {
  late HtmlSanitizer sanitizer;

  setUp(() {
    sanitizer = HtmlSanitizer.instance;
  });

  group('HtmlSanitizer', () {
    // ---------------------------------------------------------------
    // SEC-1: State-machine tag removal (no ReDoS)
    // ---------------------------------------------------------------
    group('sanitize - SEC-1: script/style removal (state-machine)', () {
      test('should remove script tag with content', () {
        final input = '<div>Hello</div><script>alert("x")</script><p>World</p>';
        final result = sanitizer.sanitize(input);

        expect(result, contains('Hello'));
        expect(result, contains('World'));
        expect(result, isNot(contains('script')));
        expect(result, isNot(contains('alert')));
      });

      test('should remove script tag with single-quoted content', () {
        final input = "<script>alert('xss')</script>Safe content";
        final result = sanitizer.sanitize(input);

        expect(result, equals('Safe content'));
        expect(result, isNot(contains('alert')));
      });

      test('should remove style tag with content', () {
        final input = '<style>.x{color:red}</style><p>Visible text</p>';
        final result = sanitizer.sanitize(input);

        expect(result, contains('Visible text'));
        expect(result, isNot(contains('style')));
        expect(result, isNot(contains('color:red')));
      });

      test('should remove nested script tags', () {
        // The state-machine matches the first <script to the first </script>.
        // With truly nested tags, the outer close tag remains as leftover text.
        // This tests that the inner content is fully stripped and the
        // remainder is processed (the second pass picks up leftover </script>
        // as plain text since there is no matching open tag).
        final input =
            '<script>outer<script>inner</script>still outer</script>Safe';
        final result = sanitizer.sanitize(input);

        // The first <script...inner</script> is removed. "still outer</script>"
        // remains as text. The close tag is harmless text at that point.
        expect(result, isNot(contains('<script')));
        expect(result, isNot(contains('inner')));
        expect(result, contains('Safe'));
      });

      test('should remove sequential script tags completely', () {
        // Two separate (non-nested) script blocks are both removed
        final input = '<script>first()</script><script>second()</script>Safe';
        final result = sanitizer.sanitize(input);

        expect(result, equals('Safe'));
        expect(result, isNot(contains('first')));
        expect(result, isNot(contains('second')));
      });

      test(
        'should complete quickly on pathological input with many unclosed <',
        () {
          // Pathological input: many '<' without matching close tags.
          // A naive regex approach would backtrack exponentially here.
          final pathological = '<' * 10000 + 'safe content';
          final stopwatch = Stopwatch()..start();
          final result = sanitizer.sanitize(pathological);
          stopwatch.stop();

          // Should complete in well under 1 second (state-machine is O(n))
          expect(
            stopwatch.elapsedMilliseconds,
            lessThan(1000),
            reason:
                'State-machine approach should not hang on pathological input',
          );
          // The content may be truncated since there is no close tag,
          // but it should not hang
          expect(result, isNotNull);
        },
      );

      test('should remove multiple script tags in same content', () {
        final input =
            'Before<script>first()</script>Middle<script>second()</script>After';
        final result = sanitizer.sanitize(input);

        expect(result, equals('BeforeMiddleAfter'));
      });

      test('should preserve content outside removed tags', () {
        final input = 'Keep this<script>remove this</script> and keep this too';
        final result = sanitizer.sanitize(input);

        expect(result, equals('Keep this and keep this too'));
      });

      test('should handle script tags case-insensitively', () {
        final input =
            '<SCRIPT>evil()</SCRIPT>Safe<Script>alsoEvil()</Script>OK';
        final result = sanitizer.sanitize(input);

        expect(result, equals('SafeOK'));
      });

      test('should handle script tags with attributes', () {
        final input =
            '<script type="text/javascript" src="evil.js">code()</script>Safe';
        final result = sanitizer.sanitize(input);

        expect(result, equals('Safe'));
      });

      test('should preserve JSON-LD script tags', () {
        final input =
            '<div>Hello</div>'
            '<script type="application/ld+json">{"@type":"Recipe","name":"Pancakes"}</script>'
            '<script>alert("xss")</script>'
            '<p>World</p>';
        final result = sanitizer.sanitize(input);

        expect(result, contains('application/ld+json'));
        expect(result, contains('Pancakes'));
        expect(result, isNot(contains('alert')));
        expect(result, contains('Hello'));
        expect(result, contains('World'));
      });

      test('should preserve multiple JSON-LD blocks', () {
        final input =
            '<script type="application/ld+json">{"@type":"Recipe"}</script>'
            '<script>evil()</script>'
            '<script type="application/ld+json">{"@type":"BreadcrumbList"}</script>';
        final result = sanitizer.sanitize(input);

        expect(result, contains('"@type":"Recipe"'));
        expect(result, contains('"@type":"BreadcrumbList"'));
        expect(result, isNot(contains('evil')));
      });
    });

    // ---------------------------------------------------------------
    // SEC-2: Dangerous tag types removal
    // ---------------------------------------------------------------
    group('sanitize - SEC-2: dangerous tag removal', () {
      test('should remove iframe with content', () {
        final input = '<iframe src="evil.com">content</iframe>Safe';
        final result = sanitizer.sanitize(input);

        expect(result, equals('Safe'));
        expect(result, isNot(contains('iframe')));
        expect(result, isNot(contains('evil')));
      });

      test('should remove embed tag with content', () {
        final input = '<embed type="application/pdf">content</embed>Safe';
        final result = sanitizer.sanitize(input);

        expect(result, equals('Safe'));
      });

      test('should remove object tag with content', () {
        final input = '<object data="evil.swf">content</object>Safe';
        final result = sanitizer.sanitize(input);

        expect(result, equals('Safe'));
      });

      test('should remove form tag with content', () {
        final input =
            '<form action="steal.php"><input name="secret"></form>Safe';
        final result = sanitizer.sanitize(input);

        expect(result, equals('Safe'));
      });

      test('should remove svg tag with onload handler', () {
        final input = '<svg onload="alert(1)">circle</svg>Safe';
        final result = sanitizer.sanitize(input);

        expect(result, equals('Safe'));
      });

      test('should remove meta tag with http-equiv refresh', () {
        final input =
            '<meta http-equiv="refresh" content="0;url=evil.com">Safe';
        final result = sanitizer.sanitize(input);

        expect(result, equals('Safe'));
        expect(result, isNot(contains('meta')));
      });

      test('should remove base tag with evil href', () {
        final input = '<base href="https://evil.com/">Safe';
        final result = sanitizer.sanitize(input);

        expect(result, equals('Safe'));
        expect(result, isNot(contains('base')));
      });

      test('should remove link tag with rel import', () {
        final input = '<link rel="import" href="evil.html">Safe';
        final result = sanitizer.sanitize(input);

        expect(result, equals('Safe'));
        expect(result, isNot(contains('link')));
      });

      test('should remove self-closing meta tag', () {
        final input = '<meta charset="utf-8"/>Safe';
        final result = sanitizer.sanitize(input);

        expect(result, equals('Safe'));
      });

      test('should NOT remove benign div tag', () {
        final input = '<div class="recipe">Content</div>';
        final result = sanitizer.sanitize(input);

        expect(result, contains('<div'));
        expect(result, contains('Content'));
        expect(result, contains('</div>'));
      });

      test('should NOT remove benign p tag', () {
        final input = '<p>Paragraph text</p>';
        final result = sanitizer.sanitize(input);

        expect(result, contains('<p>'));
        expect(result, contains('Paragraph text'));
      });

      test('should NOT remove benign span tag', () {
        final input = '<span class="highlight">Text</span>';
        final result = sanitizer.sanitize(input);

        expect(result, contains('<span'));
        expect(result, contains('Text'));
      });

      test('should NOT remove benign ul/li tags', () {
        final input = '<ul><li>Item 1</li><li>Item 2</li></ul>';
        final result = sanitizer.sanitize(input);

        expect(result, contains('<ul>'));
        expect(result, contains('<li>'));
        expect(result, contains('Item 1'));
      });

      test('should NOT remove benign h1-h6 tags', () {
        final input = '<h1>Title</h1><h2>Subtitle</h2>';
        final result = sanitizer.sanitize(input);

        expect(result, contains('<h1>'));
        expect(result, contains('Title'));
        expect(result, contains('<h2>'));
      });
    });

    // ---------------------------------------------------------------
    // SEC-3: looksLikeErrorPage false positive fix
    // ---------------------------------------------------------------
    group('looksLikeErrorPage - SEC-3: false positive prevention', () {
      test('should NOT flag "500 g mjol" as error page', () {
        final result = sanitizer.looksLikeErrorPage('500 g mjol');

        expect(
          result,
          isFalse,
          reason: '"500 g" is a cooking quantity, not an HTTP error',
        );
      });

      test('should NOT flag "400 ml vatten" as error page', () {
        final result = sanitizer.looksLikeErrorPage('400 ml vatten');

        expect(
          result,
          isFalse,
          reason: '"400 ml" is a cooking quantity, not an HTTP error',
        );
      });

      test('should flag "Internal server error 500" as error page', () {
        final result = sanitizer.looksLikeErrorPage(
          'Internal server error 500',
        );

        expect(result, isTrue);
      });

      test('should flag "404 Not Found" as error page', () {
        final result = sanitizer.looksLikeErrorPage('Error 404 Not Found');

        expect(result, isTrue);
      });

      test('should flag "Sidan kunde inte hittas" as error page', () {
        final result = sanitizer.looksLikeErrorPage('Sidan kunde inte hittas');

        expect(result, isTrue);
      });

      test(
        'should NOT flag recipe content containing "500 g" with recipe indicators as error',
        () {
          // Cross-check: content has "500" but also recipe indicators
          final recipeContent = '''
          Ingredienser:
          500 g mjol
          2 dl vatten
          Tillagning:
          Blanda allt.
        ''';
          final result = sanitizer.looksLikeErrorPage(recipeContent);

          expect(
            result,
            isFalse,
            reason:
                'Recipe content with "500 g" and recipe indicators should not be an error page',
          );
        },
      );

      test('should NOT flag "403" alone without error context', () {
        final result = sanitizer.looksLikeErrorPage('403 g socker');

        expect(
          result,
          isFalse,
          reason: '"403 g" is a cooking quantity, not a Forbidden error',
        );
      });

      test('should flag "HTTP 403 Forbidden" as error page', () {
        final result = sanitizer.looksLikeErrorPage('Forbidden');

        expect(result, isTrue);
      });

      test('should flag "Access denied" as error page', () {
        final result = sanitizer.looksLikeErrorPage('Access denied');

        expect(result, isTrue);
      });

      test('should NOT flag normal recipe text as error page', () {
        final result = sanitizer.looksLikeErrorPage(
          'Koka pastan i 10 minuter. Servera med sas.',
        );

        expect(result, isFalse);
      });
    });

    // ---------------------------------------------------------------
    // Size guard
    // ---------------------------------------------------------------
    group('sanitize - size guard', () {
      test('should return empty string for content over 5MB', () {
        final hugeContent = 'x' * 5000001;
        final result = sanitizer.sanitize(hugeContent);

        expect(result, equals(''));
      });

      test('should process content exactly at 5MB limit', () {
        final content = 'x' * 5000000;
        final result = sanitizer.sanitize(content);

        expect(result, equals(content));
      });

      test('should flag content over 5MB as critical in check()', () {
        final hugeContent = 'x' * 5000001;
        final result = sanitizer.check(hugeContent);

        expect(result.hasCriticalIssues, isTrue);
        expect(
          result.issues.any((i) => i.type == IssueType.excessiveLength),
          isTrue,
        );
      });
    });

    // ---------------------------------------------------------------
    // Event handler removal
    // ---------------------------------------------------------------
    group('sanitize - event handler removal', () {
      test('should remove onclick handler', () {
        final input = '<div onclick="evil()">Content</div>';
        final result = sanitizer.sanitize(input);

        expect(result, isNot(contains('onclick')));
        expect(result, isNot(contains('evil')));
        expect(result, contains('Content'));
      });

      test('should remove onerror handler', () {
        final input = '<img onerror="alert(1)" src="x.jpg">';
        final result = sanitizer.sanitize(input);

        expect(result, isNot(contains('onerror')));
        expect(result, isNot(contains('alert')));
      });

      test('should remove onload handler', () {
        final input = '<body onload="malicious()">';
        final result = sanitizer.sanitize(input);

        expect(result, isNot(contains('onload')));
        expect(result, isNot(contains('malicious')));
      });

      test('should remove onmouseover handler', () {
        final input = '<a onmouseover="steal()">Link</a>';
        final result = sanitizer.sanitize(input);

        expect(result, isNot(contains('onmouseover')));
        expect(result, isNot(contains('steal')));
      });

      test('should remove event handler without quotes', () {
        final input = '<div onclick=evil()>Content</div>';
        final result = sanitizer.sanitize(input);

        expect(result, isNot(contains('onclick')));
      });
    });

    // ---------------------------------------------------------------
    // javascript: URL neutralization
    // ---------------------------------------------------------------
    group('sanitize - javascript URL neutralization', () {
      test('should neutralize javascript: href', () {
        final input = '<a href="javascript:alert(1)">Click</a>';
        final result = sanitizer.sanitize(input);

        expect(result, isNot(contains('javascript:')));
        expect(result, contains('href="#"'));
      });

      test('should neutralize javascript: with mixed case', () {
        final input = '<a href="JavaScript:void(0)">Click</a>';
        final result = sanitizer.sanitize(input);

        expect(result, isNot(contains('JavaScript:')));
        expect(result, isNot(contains('javascript:')));
      });

      test('should block javascript: URL in sanitizeUrl', () {
        final result = sanitizer.sanitizeUrl('javascript:alert(1)');

        expect(result, equals(''));
      });

      test('should block data: URL in sanitizeUrl', () {
        final result = sanitizer.sanitizeUrl('data:text/html,<h1>evil</h1>');

        expect(result, equals(''));
      });

      test('should block vbscript: URL in sanitizeUrl', () {
        final result = sanitizer.sanitizeUrl('vbscript:MsgBox("evil")');

        expect(result, equals(''));
      });

      test('should allow normal http URL in sanitizeUrl', () {
        final result = sanitizer.sanitizeUrl('https://example.com/recipe');

        expect(result, equals('https://example.com/recipe'));
      });
    });

    // ---------------------------------------------------------------
    // Null byte removal
    // ---------------------------------------------------------------
    group('sanitize - null byte removal', () {
      test('should remove null bytes from HTML', () {
        final input = 'Hello\x00World';
        final result = sanitizer.sanitize(input);

        expect(result, equals('HelloWorld'));
        expect(result, isNot(contains('\x00')));
      });

      test('should remove null bytes from text', () {
        final input = 'Recipe\x00Title';
        final result = sanitizer.sanitizeText(input);

        expect(result, isNot(contains('\x00')));
      });

      test('should remove null bytes from URLs', () {
        final input = 'https://example\x00.com/recipe';
        final result = sanitizer.sanitizeUrl(input);

        expect(result, isNot(contains('\x00')));
      });

      test('should detect null bytes in check()', () {
        final input = 'Clean\x00Content';
        final result = sanitizer.check(input);

        expect(result.hasCriticalIssues, isTrue);
        expect(
          result.issues.any((i) => i.type == IssueType.nullByte),
          isTrue,
        );
      });
    });

    // ---------------------------------------------------------------
    // Homoglyph normalization
    // ---------------------------------------------------------------
    group('sanitize - homoglyph normalization', () {
      test('should normalize Cyrillic "a" to Latin "a"', () {
        // \u0430 is Cyrillic small letter a
        final input = 'p\u0430ssword';
        final result = sanitizer.normalizeHomoglyphs(input);

        expect(result, equals('password'));
      });

      test('should normalize multiple Cyrillic homoglyphs', () {
        // Mix of Cyrillic and Latin characters
        final input = '\u0410\u0412\u0421'; // Cyrillic A, V(B), S(C)
        final result = sanitizer.normalizeHomoglyphs(input);

        expect(result, equals('ABC'));
      });

      test('should detect homoglyphs in check()', () {
        final input = 'p\u0430ssword'; // Cyrillic 'a'
        final result = sanitizer.check(input);

        expect(
          result.issues.any((i) => i.type == IssueType.homoglyph),
          isTrue,
        );
      });

      test('should normalize homoglyphs in sanitize()', () {
        final input = '<div>\u0410pple</div>'; // Cyrillic A + "pple"
        final result = sanitizer.sanitize(input);

        expect(result, contains('Apple'));
        expect(result, isNot(contains('\u0410')));
      });

      test('should normalize homoglyphs in sanitizeText()', () {
        final input = '\u0441\u0430ke'; // Cyrillic c + Cyrillic a + "ke"
        final result = sanitizer.sanitizeText(input);

        expect(result, equals('cake'));
      });

      test('should leave pure Latin text unchanged', () {
        final input = 'Normal Latin text 123';
        final result = sanitizer.normalizeHomoglyphs(input);

        expect(result, equals(input));
      });
    });

    // ---------------------------------------------------------------
    // check() - SanitizationResult
    // ---------------------------------------------------------------
    group('check - result properties', () {
      test('should return clean result for safe content', () {
        final result = sanitizer.check('Safe content with no issues');

        expect(result.isClean, isTrue);
        expect(result.hasCriticalIssues, isFalse);
        expect(result.issues, isEmpty);
      });

      test('surfaces non-JSON-LD script tags as warning (BUT-1061)', () {
        // Warning, not critical, because real recipe sites carry inline
        // analytics scripts — critical severity would abort the URL-import
        // happy path. Warning lets callers audit while keeping imports green.
        final result = sanitizer.check('<script>alert("xss")</script>');

        expect(
          result.hasCriticalIssues,
          isFalse,
          reason: 'Script tags must not abort URL imports',
        );
        expect(
          result.isClean,
          isTrue,
          reason: 'Warnings alone do not fail the security gate',
        );
        expect(
          result.issues.any(
            (i) =>
                i.type == IssueType.scriptInjection &&
                i.severity == IssueSeverity.warning,
          ),
          isTrue,
          reason: 'Script presence must be surfaced for audit',
        );
      });

      test(
        'surfaces <script type="text/javascript"> as warning (BUT-1061)',
        () {
          final result = sanitizer.check(
            '<script type="text/javascript">window.x=1</script>',
          );

          expect(result.hasCriticalIssues, isFalse);
          expect(
            result.issues.any(
              (i) =>
                  i.type == IssueType.scriptInjection &&
                  i.severity == IssueSeverity.warning,
            ),
            isTrue,
          );
        },
      );

      test('does NOT surface JSON-LD script blocks (BUT-1061)', () {
        // schema.org structured data is a legitimate recipe artefact —
        // sanitize() preserves these blocks for the parser to extract.
        final result = sanitizer.check(
          '<script type="application/ld+json">{"@type":"Recipe"}</script>',
        );

        expect(result.hasCriticalIssues, isFalse);
        expect(result.isClean, isTrue);
        expect(
          result.issues.where((i) => i.type == IssueType.scriptInjection),
          isEmpty,
          reason: 'JSON-LD must not generate a warning',
        );
      });

      test(
        'does NOT bypass via fake JSON-LD in unrelated attribute (BUT-1061)',
        () {
          // Tightened regex: only a real `type=` attribute exempts the tag.
          // A `data-note="application/ld+json"` decoy must still trip the warning.
          final result = sanitizer.check(
            '<script data-note="application/ld+json">alert(1)</script>',
          );

          expect(
            result.issues.any(
              (i) =>
                  i.type == IssueType.scriptInjection &&
                  i.severity == IssueSeverity.warning,
            ),
            isTrue,
            reason:
                'Lookahead must anchor on `type=` to avoid attribute bypass',
          );
        },
      );

      test('should return warning for homoglyphs (not critical)', () {
        // Homoglyphs alone are a warning, not critical
        final result = sanitizer.check('p\u0430ss'); // Cyrillic a

        expect(result.hasCriticalIssues, isFalse);
        expect(
          result.isClean,
          isTrue,
          reason: 'Homoglyph warnings alone do not make content unclean',
        );
        expect(result.issues, hasLength(1));
        expect(result.issues.first.severity, IssueSeverity.warning);
      });

      test(
        'should not flag event handler attributes (handled by sanitize())',
        () {
          final result = sanitizer.check('<div onclick="evil()">');

          expect(
            result.isClean,
            isTrue,
            reason:
                'Event handlers are stripped by sanitize(), not rejected by check()',
          );
        },
      );

      test('should not flag javascript: protocol (handled by sanitize())', () {
        final result = sanitizer.check('href="javascript:void(0)"');

        expect(
          result.isClean,
          isTrue,
          reason:
              'javascript: URLs are neutralized by sanitize(), not rejected by check()',
        );
      });
    });

    // ---------------------------------------------------------------
    // looksLikeRecipeContent
    // ---------------------------------------------------------------
    group('looksLikeRecipeContent', () {
      test('should recognize Swedish recipe content', () {
        final content = 'Ingredienser: 2 dl mjol. Tillagning: Blanda allt.';
        final result = sanitizer.looksLikeRecipeContent(content);

        expect(result, isTrue);
      });

      test('should recognize English recipe content', () {
        final content = 'Ingredients: flour, sugar. Instructions: Mix well.';
        final result = sanitizer.looksLikeRecipeContent(content);

        expect(result, isTrue);
      });

      test('should NOT recognize random text as recipe', () {
        final result = sanitizer.looksLikeRecipeContent(
          'The weather is nice today',
        );

        expect(result, isFalse);
      });

      test('should require at least 2 indicators', () {
        // Only one indicator ("recept")
        final result = sanitizer.looksLikeRecipeContent('Detta ar ett recept');

        expect(result, isFalse, reason: 'A single indicator is not enough');
      });

      test('should recognize content with portion and minutes', () {
        final content = '4 portioner. Tillagningstid: 30 minuter.';
        final result = sanitizer.looksLikeRecipeContent(content);

        expect(result, isTrue);
      });
    });

    // ---------------------------------------------------------------
    // sanitizeText
    // ---------------------------------------------------------------
    group('sanitizeText', () {
      test('should remove control characters except newlines and tabs', () {
        final input = 'Hello\x01World\nNew line\tTab';
        final result = sanitizer.sanitizeText(input);

        expect(result, contains('HelloWorld'));
        expect(result, contains('\n'));
        expect(result, contains('\t'));
      });

      test('should preserve normal text', () {
        const input = 'A normal recipe title with numbers 123';
        final result = sanitizer.sanitizeText(input);

        expect(result, equals(input));
      });

      test('should handle empty string', () {
        final result = sanitizer.sanitizeText('');

        expect(result, equals(''));
      });

      test('changes bytes but NEVER the number of rows', () {
        // `OCRExtractionService` sanitizes a whole on-device page in ONE call
        // and then relies on the recognizer's per-line indices still
        // addressing the right rows of the result. That argument is a property
        // of THIS function: it holds only while every transformation here
        // distributes over the row separator - null-byte removal, 1:1 homoglyph
        // substitution, and a control class that excludes \n, \r and \t.
        //
        // Nothing pinned it, and the plausible break is inside this very class:
        // the sibling `stripToPlainText` already collapses `\n{3,}` to two
        // newlines and trims. Either of those added to `sanitizeText` would
        // shift every line index downstream while leaving the suite green.
        //
        // Escapes, not literal characters: a Cyrillic homoglyph and a control
        // byte are invisible in an editor and would be silently 'tidied' back
        // into plain Latin, leaving the test proving nothing.
        const input =
            'Ingredienser\r\n'
            '\n'
            '\n'
            '2 dl mj\u00f6l\n'
            '\tVisp\u0430 smeten och gr\u00e4dda i ugn.\u0007\n';

        final result = sanitizer.sanitizeText(input);

        expect(
          result,
          isNot(equals(input)),
          reason:
              'positive control - an identity function would satisfy every '
              'assertion below without preserving anything',
        );
        expect(result.split('\n'), hasLength(input.split('\n').length));
        // Row by row, not just the count: a transformation that merged two
        // rows and split a third would keep the total unchanged.
        expect(
          result.split('\n'),
          equals(<String>[
            'Ingredienser\r',
            '',
            '',
            '2 dl mj\u00f6l',
            '\tVispa smeten och gr\u00e4dda i ugn.',
            '',
          ]),
        );
      });
    });

    // ---------------------------------------------------------------
    // Edge cases
    // ---------------------------------------------------------------
    group('sanitize - edge cases', () {
      test('should handle empty string', () {
        final result = sanitizer.sanitize('');

        expect(result, equals(''));
      });

      test('should handle content with no HTML', () {
        const input = 'Just plain text, no HTML here.';
        final result = sanitizer.sanitize(input);

        expect(result, equals(input));
      });

      test('should handle multiple dangerous tags mixed together', () {
        final input =
            '<script>evil()</script><iframe>ad</iframe>'
            '<style>.x{}</style><div>Safe</div>';
        final result = sanitizer.sanitize(input);

        expect(result, isNot(contains('evil')));
        expect(result, isNot(contains('iframe')));
        expect(result, isNot(contains('style')));
        expect(result, contains('<div>Safe</div>'));
      });

      test('should handle script tag with no closing tag', () {
        final input = 'Before<script>evil()After';
        final result = sanitizer.sanitize(input);

        // Without a closing tag, _removeTagWithContent removes
        // everything from the open tag onward
        expect(result, equals('Before'));
        expect(result, isNot(contains('evil')));
      });
    });
  });
}
