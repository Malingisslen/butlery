/// The app reads the AI cost ledger by field name, the Cloud Function writes
/// it by field name, and Firestore does not connect the two. A rename on one
/// side makes the app read 0 spend forever, silently.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/import/models/rate_limit_models.dart';

const _fields = ['costToday', 'dayKey', 'costThisMonth', 'monthKey'];

void main() {
  final ts = File(
    'functions/src/middleware/llm_cost_ledger.ts',
  ).readAsStringSync();
  final dart = File(
    'lib/services/import/models/rate_limit_models.dart',
  ).readAsStringSync();

  group('cost-ledger field names shared by the server and the app', () {
    for (final name in _fields) {
      test('the server writes `$name`', () {
        expect(
          RegExp('\\b$name:').hasMatch(ts),
          isTrue,
          reason: '`$name:` is gone from the ledger write in llm_cost_ledger.ts',
        );
      });

      test('the app reads `$name` as a string literal', () {
        expect(
          dart.contains("data['$name']") || dart.contains("read('$name')"),
          isTrue,
          reason: '`$name` is no longer read by ServerLlmCost.fromFirestore',
        );
      });
    }

    test('a document keyed with the server names is read by the app', () {
      final now = DateTime.utc(2026, 2, 1, 12);
      final cost = ServerLlmCost.fromFirestore({
        'costToday': 0.3,
        'dayKey': ServerLlmCost.dayKeyOf(now),
        'costThisMonth': 4.0,
        'monthKey': ServerLlmCost.monthKeyOf(now),
      }, now);
      expect(cost.costToday, 0.3);
      expect(cost.costThisMonth, 4.0);
    });
  });
}
