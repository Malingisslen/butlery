/// Tests for ContentReport serialization.
///
/// The wire shape is persisted in production `reports/*` documents — every
/// field tested here is part of the Firestore contract. BUT-649 added
/// `guidelineVersion` so historical reports cite the guideline version that
/// was in force at submission time.
library;

import 'dart:io';

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

    // BUT-1522: a report cites this constant, so it must name the version
    // the user could actually read.
    for (final lang in ['sv', 'en']) {
      test('community_guidelines_$lang.md carries the current version', () {
        final text = File(
          'assets/legal/community_guidelines_$lang.md',
        ).readAsStringSync();
        expect(
          RegExp(
            r'^Version: (\S+)$',
            multiLine: true,
          ).firstMatch(text)?.group(1),
          kCurrentGuidelineVersion,
        );
      });
    }

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

    test('a report whose reporter was erased reads as reporterErased', () async {
      // The server nulls reporterId on an open case's report when the reporter
      // deletes their account, and keeps what they wrote.
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('reports').doc('kept').set({
        'reporterId': null,
        'contentType': ContentType.comment.wireName,
        'contentId': 'comment1',
        'contentOwnerId': 'owner1',
        'reason': 'harassment',
        'description': 'what they wrote',
        'status': 'in_review',
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 9, 1)),
      });
      await firestore.collection('reports').doc('live').set({
        'reporterId': 'reporter1',
        'contentType': ContentType.comment.wireName,
        'contentId': 'comment1',
        'reason': 'spam',
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 9, 1)),
      });

      final kept = ContentReport.fromFirestore(
        await firestore.collection('reports').doc('kept').get(),
      );
      final live = ContentReport.fromFirestore(
        await firestore.collection('reports').doc('live').get(),
      );

      expect(kept, isNotNull);
      expect(kept!.reporterErased, isTrue);
      expect(kept.description, 'what they wrote');
      expect(live!.reporterErased, isFalse);
    });

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

    group('moderatorAction (BUT-2222)', () {
      Future<ContentReport?> parse(Map<String, dynamic> extra) async {
        final firestore = FakeFirebaseFirestore();
        await firestore.collection('reports').doc('r').set({
          'reporterId': 'reporter1',
          'contentType': 'comment',
          'contentId': 'c1',
          'reason': 'spam',
          'createdAt': Timestamp.fromDate(DateTime.utc(2026, 10, 1)),
          ...extra,
        });
        return ContentReport.fromFirestore(
          await firestore.collection('reports').doc('r').get(),
        );
      }

      test('parses both stamped values', () async {
        expect(
          (await parse({
            'moderatorAction': 'content_removed',
          }))!.moderatorAction,
          ModeratorDecision.contentRemoved,
        );
        expect(
          (await parse({'moderatorAction': 'profile_hidden'}))!.moderatorAction,
          ModeratorDecision.profileHidden,
        );
      });

      test('unknown, no_action and absent read as null', () async {
        expect(
          (await parse({'moderatorAction': 'banana'}))!.moderatorAction,
          isNull,
        );
        expect(
          (await parse({'moderatorAction': 'no_action'}))!.moderatorAction,
          isNull,
        );
        expect((await parse({}))!.moderatorAction, isNull);
      });

      test('toFirestore never contains it', () {
        final report = ContentReport(
          id: 'r',
          reporterId: 'reporter1',
          contentType: ContentType.comment,
          contentId: 'c1',
          reason: 'spam',
          createdAt: DateTime.utc(2026, 10, 1),
          moderatorAction: ModeratorDecision.contentRemoved,
        );
        expect(report.toFirestore().containsKey('moderatorAction'), isFalse);
      });

      test('fromWire is tolerant', () {
        expect(
          ModeratorDecision.fromWire('no_action'),
          ModeratorDecision.noAction,
        );
        expect(ModeratorDecision.fromWire('x'), isNull);
        expect(ModeratorDecision.fromWire(null), isNull);
      });
    });
  });
}
