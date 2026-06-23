/// The key-lock test: the three metric registries (catalog / resolvers /
/// explanations) must each cover EXACTLY the MetricKey enum — no more, no less.
/// This is what makes "add a metric" a mechanical checklist: forget any one of
/// the three parts and this fails. Pins each registry to the enum (the source
/// of truth), so all three can't quietly agree on a wrong set.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/admin/metrics/catalog.dart';
import 'package:butlery/models/admin/metrics/explanations.dart';
import 'package:butlery/models/admin/metrics/metric_key.dart';
import 'package:butlery/models/admin/metrics/resolvers.dart';

void main() {
  final allKeys = MetricKey.values.toSet();

  test('catalog covers exactly MetricKey.values', () {
    expect(catalog.keys.toSet(), allKeys, reason: 'CATALOG drift');
  });

  test('resolvers covers exactly MetricKey.values', () {
    expect(resolvers.keys.toSet(), allKeys, reason: 'RESOLVERS drift');
  });

  test('explanations covers exactly MetricKey.values', () {
    expect(explanations.keys.toSet(), allKeys, reason: 'EXPLANATIONS drift');
  });

  test('every descriptor key matches its map key and its category', () {
    for (final entry in catalog.entries) {
      expect(entry.value.key, entry.key, reason: 'descriptor key mismatch');
      expect(
        entry.value.category,
        entry.key.category,
        reason: 'descriptor category must match the key category',
      );
    }
  });
}
