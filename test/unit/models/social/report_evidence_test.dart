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

    test(
      'claimedCreatorIsReporter is read as a bool and null when absent',
      () async {
        for (final value in [true, false]) {
          final e = ReportEvidence.fromFirestore(
            await _doc({
              'outcome': 'captured',
              'claimedCreatorIsReporter': value,
            }),
          );
          expect(e!.claimedCreatorIsReporter, value);
        }
        final absent = ReportEvidence.fromFirestore(
          await _doc({'outcome': 'captured'}),
        );
        expect(absent!.claimedCreatorIsReporter, isNull);
      },
    );
  });

  group('ReportEvidence frozen hold (BUT-2329)', () {
    final until = DateTime.utc(2027, 10, 9);

    test('a copy with no frozen map is not frozen', () async {
      final e = ReportEvidence.fromFirestore(
        await _doc({'outcome': 'captured', 'contentType': 'recipe'}),
      )!;
      expect(e.isFrozen, isFalse);
      expect(e.frozen, isNull);
      expect(e.contentType, 'recipe');
    });

    test('reads every field of the hold', () async {
      final e = ReportEvidence.fromFirestore(
        await _doc({
          'outcome': 'captured',
          'frozen': {
            'reason': 'legal_claim',
            'frozenAt': Timestamp.fromDate(DateTime.utc(2026, 10, 9)),
            'frozenBy': 'admin1',
            'firstFrozenAt': Timestamp.fromDate(DateTime.utc(2026, 10, 9)),
            'until': Timestamp.fromDate(until),
            'extensions': 2,
          },
        }),
      )!;
      expect(e.isFrozen, isTrue);
      expect(e.frozen!.reason, FreezeReason.legalClaim);
      expect(e.frozen!.until.toUtc(), until);
      expect(e.frozen!.firstFrozenAt!.toUtc(), DateTime.utc(2026, 10, 9));
      expect(e.frozen!.extensions, 2);
    });

    test('maps each reason from its wire name; unknown stays unknown', () {
      expect(FreezeReason.fromWire('police'), FreezeReason.police);
      expect(FreezeReason.fromWire('threat'), FreezeReason.threat);
      expect(FreezeReason.fromWire('legal_claim'), FreezeReason.legalClaim);
      expect(FreezeReason.fromWire('from_the_future'), FreezeReason.unknown);
      expect(FreezeReason.fromWire(null), FreezeReason.unknown);
    });

    test('a hold without a readable end date is not a hold', () async {
      final e = ReportEvidence.fromFirestore(
        await _doc({
          'outcome': 'captured',
          'frozen': {'reason': 'police'},
        }),
      )!;
      expect(e.isFrozen, isFalse);
    });

    test('block names map from the callable message', () {
      expect(FreezeBlock.fromWire('at_cap'), FreezeBlock.atCap);
      expect(FreezeBlock.fromWire('no_copy'), FreezeBlock.noCopy);
      expect(FreezeBlock.fromWire('not_captured'), FreezeBlock.notCaptured);
      expect(FreezeBlock.fromWire('already_frozen'), FreezeBlock.alreadyFrozen);
      expect(FreezeBlock.fromWire('not_frozen'), FreezeBlock.notFrozen);
      expect(FreezeBlock.fromWire('other'), isNull);
    });
  });
}
