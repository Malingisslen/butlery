/// BUT-1245: unit tests for the pure threshold-decision helpers extracted from
/// [ImportResultHandler.checkForDuplicates].
///
/// These two static methods own every boundary the duplicate-detection flow
/// depends on:
///
///   meetsContentDuplicateThreshold(score)
///     → true iff score >= 0.6 (the Jaccard similarity floor for content
///       fingerprint matches). A score just below 0.6 must NOT trigger the
///       duplicate path; exactly 0.6 must.
///
///   clampToExactMatchFloor(score)
///     → score, but never below 0.8. URL / title matches already confirmed
///       by metadata carry a sentinel matchScore==1.0; when the computed
///       content similarity comes back below 0.8 the sheet must still show
///       at least 80% — a floor of 0.5 or 0.0 would be misleading.
///
/// No service, no dialog, no BuildContext, no DI bridge — the helpers are
/// pure doubles-in / result-out.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/views/smart_import/import_result_handler.dart';

void main() {
  group('ImportResultHandler.meetsContentDuplicateThreshold', () {
    // Threshold is 0.6. Scores strictly below it must NOT trigger the
    // duplicate path — if they did, near-similar but distinct recipes would
    // be incorrectly flagged as duplicates.

    test(
        'returns false for a score just below 0.6 '
        '(would not flag as content duplicate)', () {
      // If this fails, the threshold has been lowered below 0.6 or the
      // comparison has been flipped.
      expect(
        ImportResultHandler.meetsContentDuplicateThreshold(0.5999),
        isFalse,
      );
    });

    test('returns true at exactly 0.6 — the lower boundary triggers the flag',
        () {
      // If this fails, the threshold has been changed from >= to >.
      expect(
        ImportResultHandler.meetsContentDuplicateThreshold(0.6),
        isTrue,
      );
    });

    test('returns true for a score well above 0.6 (clear duplicate)', () {
      expect(
        ImportResultHandler.meetsContentDuplicateThreshold(0.9),
        isTrue,
      );
    });

    test('returns false for zero (no similarity at all)', () {
      expect(
        ImportResultHandler.meetsContentDuplicateThreshold(0.0),
        isFalse,
      );
    });
  });

  group('ImportResultHandler.clampToExactMatchFloor', () {
    // Floor is 0.8. URL / title matches are confirmed duplicates by
    // definition; the sheet must never display a similarity below 80% for
    // such matches, even if the content fingerprint happens to score low.

    test(
        'clamps a score below 0.8 up to 0.8 '
        '(prevents misleadingly low display percentage)', () {
      // If this fails, the 0.8 floor has been removed or lowered.
      expect(
        ImportResultHandler.clampToExactMatchFloor(0.5),
        equals(0.8),
      );
    });

    test('clamps a score just below 0.8 to exactly 0.8 — boundary is strict',
        () {
      // If this fails, the boundary condition has been changed from < to <=.
      expect(
        ImportResultHandler.clampToExactMatchFloor(0.7999),
        equals(0.8),
      );
    });

    test(
        'passes through a score of exactly 0.8 unchanged '
        '(boundary is inclusive on the pass-through side)', () {
      // If this fails, the clamping has been made too aggressive (<=).
      expect(
        ImportResultHandler.clampToExactMatchFloor(0.8),
        equals(0.8),
      );
    });

    test('passes through a score above 0.8 unchanged (no upper clamping)', () {
      // Scores like 0.95 or 1.0 (URL match sentinel) must not be capped.
      expect(
        ImportResultHandler.clampToExactMatchFloor(0.95),
        equals(0.95),
      );

      expect(
        ImportResultHandler.clampToExactMatchFloor(1.0),
        equals(1.0),
      );
    });

    test(
        'score of 0.0 is clamped to 0.8 '
        '(even a completely dissimilar URL-confirmed match shows the floor)',
        () {
      expect(
        ImportResultHandler.clampToExactMatchFloor(0.0),
        equals(0.8),
      );
    });
  });
}
