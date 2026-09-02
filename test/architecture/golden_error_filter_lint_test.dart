/// BUT-1946: source lint keeping golden comparisons able to fail.
///
/// `LocalFileComparator.compare` throws a bare `FlutterError`, which
/// `matchesGoldenFile`'s own `on TestFailure` catch does not cover. `runAsync`
/// hands it to `FlutterError.onError` and returns null, and null is the
/// matcher's word for "the image matched". So a handler that swallows
/// everything turns every pixel mismatch and every wrong render size into a
/// passing test. Between 2026-04-17 and 2026-08-25 that is what this repo had,
/// and no golden image had ever survived a real comparison (BUT-1931).
///
/// The approved handler is `installGoldenImageErrorFilter` in
/// `test/widget/golden/golden_helper.dart`, which drops only the image-load
/// noise it was written for and lets everything else through.
///
/// Nothing else can hold this. `butleryGolden` is `@isTest` and registers its
/// own `testWidgets`, so no test can call it and assert on the result — every
/// golden in the repo stayed green while the comparison was blind, which is
/// what BUT-1946 was filed about.
///
/// Residual, named rather than left to be found: the pattern below only sees an
/// inline empty closure. `FlutterError.onError = _swallow;` or a body of
/// `{ return; }` evades it. Widening it costs more false positives than the
/// evasions are worth, since neither spelling has ever appeared here.
///
/// One marker also excuses a second violation sitting within its lookahead
/// window. No file carries two, and shrinking the window would break the
/// trailing same-line spelling the exemption is actually written as.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Assignments of a body-less closure to `FlutterError.onError`.
///
/// Whitespace-tolerant across newlines because the formatter wraps long
/// assignments, and the parameter list is unconstrained: `(_)` and
/// `(FlutterErrorDetails _)` are the same swallow. What identifies it is the
/// EMPTY body, so that is what the pattern keys on.
final _blankHandler = RegExp(
  r'FlutterError\s*\.\s*onError\s*=\s*\([^)]*\)\s*\{\s*\}',
);

/// A deliberate blank handler must say so on its own line.
///
/// The marker sits next to the violation rather than in a path list here, so
/// adding one is visible in the diff that adds it. A path list is edited far
/// from the code it excuses and nobody reviewing the test file sees it.
const _exemptMarker = 'LINT-EXEMPT: golden-blindness';

void main() {
  group('Golden error-filter lint', () {
    test('no blank FlutterError.onError handler in test/', () {
      final testDir = Directory('test');
      expect(
        testDir.existsSync(),
        isTrue,
        reason: 'Lint must run from the repo root.',
      );

      final violations = <String>[];

      final dartFiles = testDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      for (final file in dartFiles) {
        final relPath = file.path.replaceAll(r'\', '/');
        final raw = file.readAsStringSync();

        // Comments are blanked BEFORE matching, and that is load-bearing:
        // `golden_helper.dart` quotes the forbidden spelling verbatim in the
        // doc comment explaining why it is forbidden, so a lint reading raw
        // source is red on the file that constitutes the fix.
        //
        // Blanked to the SAME LENGTH rather than removed, so an offset in
        // `stripped` is the same offset in `raw`. Deleting the comments instead
        // shifts every later offset, and the marker lookup below then has to
        // find its match by searching for the text — which returns the FIRST
        // identical spelling in the file, so one marked handler would excuse
        // every other handler spelled the same way, including ones added later.
        String blank(Match m) => ' ' * m.group(0)!.length;
        final stripped = raw
            .replaceAllMapped(RegExp(r'/\*[\s\S]*?\*/'), blank)
            .replaceAllMapped(RegExp(r'//[^\n]*'), blank);

        for (final match in _blankHandler.allMatches(stripped)) {
          // Read from RAW at the SAME offset: blanking preserved the comment
          // text's length but not its content, so the marker only survives in
          // `raw`.
          final windowEnd = (match.end + 200).clamp(0, raw.length);
          final excused = raw
              .substring(match.start, windowEnd)
              .contains(_exemptMarker);

          if (!excused) violations.add(relPath);
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'A blank FlutterError.onError handler makes every golden '
            'comparison in scope pass unconditionally (BUT-1931/BUT-1941).\n'
            'Use installGoldenImageErrorFilter() from '
            'test/widget/golden/golden_helper.dart instead.\n'
            'If the blank handler IS the subject of the test, put '
            '"$_exemptMarker" on the assignment line.\n'
            'Violations:\n${violations.toSet().join('\n')}',
      );
    });

    test('the approved filter is still the one the helper installs', () {
      // Without this the lint above is satisfied by a file that has no handler
      // at all — including a golden_helper.dart whose call was simply deleted.
      final helper = File(
        'test/widget/golden/golden_helper.dart',
      ).readAsStringSync();
      // Keyed on the CALL spelling, not the bare identifier: the declaration
      // `void Function(FlutterErrorDetails)? installGoldenImageErrorFilter() {`
      // contains the identifier too, so a `contains('…()')` assertion is
      // satisfied by a file that only DEFINES the filter — exactly the
      // defined-but-unused state this test claims to catch.
      expect(
        helper.contains('= installGoldenImageErrorFilter();'),
        isTrue,
        reason:
            'golden_helper.dart must CALL installGoldenImageErrorFilter, not '
            'merely define it — a defined-but-unused filter is the BUT-1931 '
            'state, and the lint above cannot see it.',
      );
    });
  });
}
