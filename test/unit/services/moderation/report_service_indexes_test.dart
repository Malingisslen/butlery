/// Structural guard for the moderation queue's composite index.
///
/// `ReportService.watchOpenReports` combines `whereIn('status', [...])` with
/// `orderBy('createdAt', descending: true)`. Per the project's accepted
/// deviations, pure-equality filters need no composite — but `in` + sort is
/// exactly the combination that DOES. Without the declared index the query
/// throws `failed-precondition` at runtime and the moderator dashboard is
/// simply broken.
///
/// FakeFirebaseFirestore has no index planner, so every in-memory test of
/// `watchOpenReports` passes whether or not the index exists — the gap this
/// file closes (see the lessons-digest Firebase note: assert the DECLARED
/// index config in a test).
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'firestore.indexes.json declares (status ASC, createdAt DESC) on reports',
    () {
      final raw = File('firestore.indexes.json').readAsStringSync();
      final indexes =
          (jsonDecode(raw) as Map<String, dynamic>)['indexes'] as List<dynamic>;

      final reportIndexes = indexes
          .cast<Map<String, dynamic>>()
          .where((i) => i['collectionGroup'] == 'reports')
          .toList();

      expect(
        reportIndexes,
        isNotEmpty,
        reason:
            'watchOpenReports uses whereIn(status) + orderBy(createdAt) — '
            'without a composite index on `reports` the moderation queue '
            'throws failed-precondition in production',
      );

      final fields = reportIndexes
          .map(
            (i) => (i['fields'] as List<dynamic>)
                .cast<Map<String, dynamic>>()
                .map((f) => '${f['fieldPath']}:${f['order']}')
                .toList(),
          )
          .toList();

      expect(
        fields,
        // equals(...) is required: Dart list equality is identity-based, so a
        // bare contains([...]) would never match a nested list.
        contains(equals(['status:ASCENDING', 'createdAt:DESCENDING'])),
        reason:
            'field order is load-bearing: the equality/in filter (status) must '
            'come first, then the sort field (createdAt) in the direction the '
            'query sorts (descending, newest-first)',
      );

      // The query is a top-level `.collection('reports')`, so the index must be
      // COLLECTION-scoped; a collection-group flip would keep field order green
      // while failing the actual query at runtime.
      final scopes = reportIndexes.map((i) => i['queryScope']).toSet();
      expect(
        scopes,
        contains('COLLECTION'),
        reason: 'watchOpenReports queries the reports collection, not a group',
      );
    },
  );
}
