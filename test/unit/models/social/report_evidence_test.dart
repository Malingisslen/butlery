/// Tests for ReportEvidence parsing of the admin-only `report_evidence/*`
/// documents written by the Cloud Function (BUT-1842).
library;

import 'package:butlery/models/social/report_evidence.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

Future<DocumentSnapshot> _doc(Map<String, dynamic>? data) async {
  final firestore = FakeFirebaseFirestore();
  final ref = firestore.collection('report_evidence').doc('r1');
  if (data != null) await ref.set(data);
  return ref.get();
}

void main() {
  group('ReportEvidence.fromFirestore', () {
    test('a missing document is null (report predates the feature)', () async {
      expect(ReportEvidence.fromFirestore(await _doc(null)), isNull);
    });

    test('parses every known outcome from its wire name', () async {
      const wire = {
        'captured': EvidenceOutcome.captured,
        'missing': EvidenceOutcome.missing,
        'owner_mismatch': EvidenceOutcome.ownerMismatch,
        'not_visible_to_reporter': EvidenceOutcome.notVisibleToReporter,
        'unsupported_type': EvidenceOutcome.unsupportedType,
        'invalid_ref': EvidenceOutcome.invalidRef,
        'capture_failed': EvidenceOutcome.captureFailed,
      };
      for (final entry in wire.entries) {
        final e = ReportEvidence.fromFirestore(
          await _doc({'outcome': entry.key, 'reportId': 'r1'}),
        );
        expect(e!.outcome, entry.value, reason: entry.key);
        expect(e.text, isEmpty);
        expect(e.truncated, isFalse);
      }
    });

    test(
      'an unknown or absent outcome is unknown, not captureFailed',
      () async {
        expect(
          ReportEvidence.fromFirestore(
            await _doc({'outcome': 'from_the_future'}),
          )!.outcome,
          EvidenceOutcome.unknown,
        );
        expect(
          ReportEvidence.fromFirestore(await _doc({'reportId': 'r1'}))!.outcome,
          EvidenceOutcome.unknown,
        );
      },
    );

    test(
      'captured text: strings kept, list values joined by newline',
      () async {
        final capturedAt = DateTime.utc(2026, 10, 9, 8, 30);
        final e = ReportEvidence.fromFirestore(
          await _doc({
            'reportId': 'r1',
            'outcome': 'captured',
            'capturedAt': Timestamp.fromDate(capturedAt),
            'truncated': true,
            'text': {
              'title': 'Pannkakor',
              'steps': ['Vispa', 'Stek'],
            },
          }),
        )!;
        expect(e.reportId, 'r1');
        expect(e.outcome, EvidenceOutcome.captured);
        expect(e.truncated, isTrue);
        expect(e.capturedAt!.toUtc(), capturedAt);
        expect(e.text, [('title', 'Pannkakor'), ('steps', 'Vispa\nStek')]);
      },
    );

    test(
      'a recipe copy reads in recipe order, whatever order is stored',
      () async {
        final e = ReportEvidence.fromFirestore(
          await _doc({
            'outcome': 'captured',
            'text': {
              'description': 'd',
              'ingredients': ['i'],
              'instructions': ['s'],
              'title': 't',
            },
          }),
        )!;
        expect(e.text.map((f) => f.$1), [
          'title',
          'description',
          'ingredients',
          'instructions',
        ]);
      },
    );

    test('text values of unexpected type are skipped', () async {
      final e = ReportEvidence.fromFirestore(
        await _doc({
          'outcome': 'captured',
          'text': {'title': 'ok', 'bad': 42},
        }),
      )!;
      expect(e.text, [('title', 'ok')]);
    });
  });
}
