/// Tests for ContentReport serialization.
///
/// The wire shape is persisted in production `reports/*` documents — every
/// field tested here is part of the Firestore contract. BUT-649 added
/// `guidelineVersion` so historical reports cite the guideline version that
/// was in force at submission time.
library;

import 'package:butlery/models/social/content_report.dart';
import 'package:butlery/models/social/content_type.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ContentReport', () {
    test('kCurrentGuidelineVersion is non-empty and ISO-like', () {
      expect(kCurrentGuidelineVersion, isNotEmpty);
      // Loose ISO-date sanity — version stamps should be sortable.
      expect(
        RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(kCurrentGuidelineVersion),
        isTrue,
        reason:
            'Guideline version should be an ISO date so historical reports sort.',
      );
    });

    test('toFirestore round-trips guidelineVersion', () async {
      final firestore = FakeFirebaseFirestore();
      final now = DateTime.utc(2026, 5, 4, 12, 0);
      final report = ContentReport(
        id: '',
        reporterId: 'reporter1',
        contentType: ContentType.comment,
        contentId: 'comment1',
        contentOwnerId: 'owner1',
        reason: 'spam',
        description: 'duplicate post',
        createdAt: now,
        guidelineVersion: '2026-02-28',
      );

      final docRef = await firestore
          .collection('reports')
          .add(
            report.toFirestore(),
          );
      final snap = await docRef.get();
      final parsed = ContentReport.fromFirestore(snap);

      expect(parsed, isNotNull);
      expect(parsed!.guidelineVersion, equals('2026-02-28'));
      expect(parsed.reporterId, equals('reporter1'));
      expect(parsed.contentType, equals(ContentType.comment));
      expect(parsed.reason, equals('spam'));
      expect(parsed.description, equals('duplicate post'));
      expect(parsed.createdAt.toUtc(), equals(now));
    });

    test(
      'omitting guidelineVersion serializes as absent (null on read)',
      () async {
        final firestore = FakeFirebaseFirestore();
        final report = ContentReport(
          id: '',
          reporterId: 'reporter1',
          contentType: ContentType.recipe,
          contentId: 'recipe1',
          reason: 'inappropriate',
          createdAt: DateTime.utc(2026, 5, 4),
        );

        final map = report.toFirestore();
        expect(
          map.containsKey('guidelineVersion'),
          isFalse,
          reason:
              'Null guidelineVersion should be omitted from the wire map to '
              'avoid forcing legacy docs to carry an explicit null.',
        );

        final docRef = await firestore.collection('reports').add(map);
        final parsed = ContentReport.fromFirestore(await docRef.get());
        expect(parsed!.guidelineVersion, isNull);
      },
    );

    test('legacy doc without guidelineVersion still parses', () async {
      final firestore = FakeFirebaseFirestore();
      final docRef = await firestore.collection('reports').add({
        'reporterId': 'reporter1',
        'contentType': 'profile',
        'contentId': 'user1',
        'reason': 'harassment',
        'status': 'new',
        'createdAt': Timestamp.fromDate(DateTime.utc(2025, 12, 1)),
      });

      final parsed = ContentReport.fromFirestore(await docRef.get());
      expect(parsed, isNotNull);
      expect(parsed!.guidelineVersion, isNull);
      expect(parsed.reason, equals('harassment'));
    });

    test('copyWith preserves guidelineVersion across status transitions', () {
      final report = ContentReport(
        id: 'r1',
        reporterId: 'reporter1',
        contentType: ContentType.recipe,
        contentId: 'recipe1',
        reason: 'spam',
        createdAt: DateTime.utc(2026, 5, 4),
        guidelineVersion: '2026-02-28',
      );

      final reviewed = report.copyWith(status: ReportStatus.inReview);
      final actioned = reviewed.copyWith(status: ReportStatus.actioned);

      expect(reviewed.guidelineVersion, equals('2026-02-28'));
      expect(
        actioned.guidelineVersion,
        equals('2026-02-28'),
        reason:
            'Guideline version is the contract at submission time and must '
            'survive moderation lifecycle transitions.',
      );
    });
  });
}
