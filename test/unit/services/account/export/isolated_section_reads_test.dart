/// Direct tests for [IsolatedSectionReads] (BUT-2004, BUT-2008): the collector
/// every multi-read export section now builds its failure markers with.
///
/// The section suites prove each section's own wording. This one proves the
/// rule they all lean on: a refused read costs its own key and nothing else,
/// and the section-level tokens say "partial" or "failed" by counting.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/account/export/isolated_section_reads.dart';

Map<String, dynamic> _outcome(IsolatedSectionReads reads) => reads.outcome(
  partialCode: 'x-partial',
  failedCode: 'x-failed',
  failedMessage: 'X could not be exported.',
);

Future<int> _refused() async =>
    throw StateError('permission-denied reading blocks/me_uid-of-someone-else');

void main() {
  late IsolatedSectionReads reads;

  setUp(() => reads = IsolatedSectionReads(logTag: 'Test'));

  test('reads that all succeed leave no error key anywhere', () async {
    expect(await reads.read('a', () async => 1), 1);
    expect(await reads.read('b', () async => 2), 2);

    expect(reads.section, isEmpty);
    expect(reads.allFailed, isFalse);
    expect(_outcome(reads), isEmpty);
  });

  test(
    'one refused read of two costs only its own key and is partial',
    () async {
      final a = await reads.read('a', () async => 1);
      final b = await reads.read('b', _refused);

      expect(a, 1);
      expect(b, isNull, reason: 'no value, so the caller cannot derive one');
      expect(reads.section, {
        'b_error': 'Could not export b.',
        'b_error_code': 'b-export-failed',
      });
      expect(reads.section.containsKey('b'), isFalse);
      expect(reads.allFailed, isFalse);
      // `error` is the "could not be exported at all" claim, which would be
      // false about the rows `a` delivered.
      expect(_outcome(reads), {'error_code': 'x-partial'});
    },
  );

  test('the order of the refused read does not matter', () async {
    await reads.read('a', _refused);
    await reads.read('b', () async => 2);

    expect(reads.section.keys, ['a_error', 'a_error_code']);
    expect(_outcome(reads), {'error_code': 'x-partial'});
  });

  test(
    'every read refused is an outright failure, not a partial one',
    () async {
      await reads.read('a', _refused);
      await reads.read('b', _refused);

      expect(reads.allFailed, isTrue);
      expect(_outcome(reads), {
        'error': 'X could not be exported.',
        'error_code': 'x-failed',
      });
      expect(
        _outcome(reads).containsValue('x-partial'),
        isFalse,
        reason:
            'a partial token over a section that delivered nothing '
            'contradicts the sentence beside it',
      );
    },
  );

  test('a single read that is refused is an outright failure', () async {
    await reads.read('a', _refused);

    expect(reads.allFailed, isTrue);
    expect(_outcome(reads)['error_code'], 'x-failed');
  });

  test('a collector that read nothing reports nothing', () {
    // `0 failed == 0 attempted` would otherwise read as "all failed".
    expect(reads.allFailed, isFalse);
    expect(_outcome(reads), isEmpty);
  });

  test('the exception text never reaches the section', () async {
    await reads.read('a', _refused);

    expect(
      reads.section.values.join(' '),
      isNot(contains('uid-of-someone-else')),
      reason: 'the bundle may be forwarded; the exception is only logged',
    );
  });
}
