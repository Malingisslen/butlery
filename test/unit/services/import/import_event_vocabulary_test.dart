/// BUT-2238: the parse event's vocabularies exist twice, in the app and in
/// the `logParseEvent` Cloud Function that validates them. A value the
/// function does not list is stored as null, silently, so the two copies are
/// compared here by reading the function's source.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/import/import_event.dart';
import 'package:butlery/services/import/models/import_result_v2.dart';

final _source = File(
  'functions/src/events/log-parse-event.ts',
).readAsStringSync();

Set<String> _tsList(String name) {
  final match = RegExp(
    r'export const ' + name + r'\s*=\s*\[([^\]]*)\]',
  ).firstMatch(_source);
  expect(match, isNotNull, reason: '$name is gone from log-parse-event.ts');
  return RegExp(
    r'"([^"]+)"',
  ).allMatches(match!.group(1)!).map((m) => m.group(1)!).toSet();
}

void main() {
  test('channels', () {
    expect(
      _tsList('VALID_CHANNELS'),
      ImportChannel.values.map((c) => c.name).toSet(),
    );
  });

  test('strategy ids', () {
    expect(_tsList('VALID_STRATEGIES'), ImportEvent.strategyIds.toSet());
  });

  test('error codes', () {
    expect(
      _tsList('VALID_ERROR_CODES'),
      ImportErrorCode.values.map((c) => c.name).toSet(),
    );
  });

  test('outcomes', () {
    expect(_tsList('VALID_OUTCOMES'), {'recipe', 'assistance', 'failure'});
  });
}
