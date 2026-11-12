// BUT-1520 condition C8: the adversarial precision set for the pool key. Reads
// the SAME fixture as functions/src/__tests__/pool-key-adversarial.test.ts.
//
// A case marked `known_gap` is pinned to its measured behaviour, so fixing the
// key turns it red and the fixture entry must drop `known_gap`.

import 'dart:convert';
import 'dart:io';

import 'package:butlery/services/rating/canonical_pool_key.dart';
import 'package:flutter_test/flutter_test.dart';

String? _key(Map<String, dynamic> recipe) => CanonicalPoolKey.compute(
  title: recipe['title'] as String,
  ingredients: (recipe['ingredients'] as List).cast<String>(),
);

void main() {
  final fixture =
      jsonDecode(
            File('test/fixtures/pool_key_adversarial.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
  final classes = (fixture['classes'] as List).cast<String>().toSet();
  final distinct = (fixture['distinct'] as List).cast<Map<String, dynamic>>();
  final mustNotPool = (fixture['must_not_pool'] as List)
      .cast<Map<String, dynamic>>();

  bool isGap(Map<String, dynamic> c) => c['known_gap'] is String;

  test('every class has at least one case that is not a known gap', () {
    expect(classes, isNotEmpty);
    expect(distinct, isNotEmpty);
    expect(mustNotPool, isNotEmpty);
    final covered = {
      for (final c in [...distinct, ...mustNotPool])
        if (!isGap(c)) c['class'] as String,
    };
    expect(covered, classes);
    for (final c in [...distinct, ...mustNotPool]) {
      expect(classes, contains(c['class']), reason: '${c['why']}');
    }
  });

  group('distinct dishes never share a key', () {
    for (final c in distinct) {
      final gap = isGap(c);
      test('${c['class']}: ${c['why']}${gap ? ' (known gap)' : ''}', () {
        final a = _key(c['a'] as Map<String, dynamic>);
        final b = _key(c['b'] as Map<String, dynamic>);
        if (gap) {
          expect(a, isNotNull);
          expect(a, b, reason: 'gap fixed? drop known_gap from this case');
        } else {
          expect(a == null || a != b, isTrue, reason: 'false merge: $a');
        }
      });
    }
  });

  group('generic titles fail closed', () {
    for (final c in mustNotPool) {
      final gap = isGap(c);
      test('${c['class']}: ${c['why']}${gap ? ' (known gap)' : ''}', () {
        final key = _key(c['recipe'] as Map<String, dynamic>);
        if (gap) {
          expect(key, isNotNull, reason: 'gap fixed? drop known_gap');
        } else {
          expect(key, isNull);
        }
      });
    }
  });
}
