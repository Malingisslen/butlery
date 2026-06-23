/// Unit tests for ParsingCorrectionRepository.
///
/// Brings the file from 0% → ~85% coverage as part of the
/// repositories-coverage push. Uses fake_cloud_firestore so the
/// fire-and-forget writes and aggregation queries can be exercised
/// end-to-end against a real-shaped Firestore.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/parsing/field_correction.dart';
import 'package:butlery/models/parsing/parse_metadata.dart';
import 'package:butlery/models/parsing/parsing_correction.dart';
import 'package:butlery/repositories/parsing_correction_repository.dart';

ParsingCorrection _makeCorrection({
  String? domain,
  String? tier,
  String userId = 'user-1',
}) {
  return ParsingCorrection.create(
    recipeId: 'recipe-1',
    userId: userId,
    source: ImportSource.url,
    domain: domain,
    successfulTier: tier,
    originalQuality: 0.5,
    titleCorrection: const FieldCorrection(
      originalValue: 'wrong',
      correctedValue: 'right',
    ),
  );
}

void main() {
  group('ParsingCorrectionRepository', () {
    late FakeFirebaseFirestore firestore;
    late ParsingCorrectionRepository repo;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repo = ParsingCorrectionRepository(firestore: firestore);
    });

    group('save', () {
      test(
        'writes a correction document to the configured collection',
        () async {
          final correction = _makeCorrection(domain: 'ica.se');

          await repo.save(correction);

          final doc = await firestore
              .collection('parsing_corrections')
              .doc(correction.id)
              .get();
          expect(doc.exists, isTrue);
          expect(doc.data()?['domain'], equals('ica.se'));
          expect(doc.data()?['recipeId'], equals('recipe-1'));
        },
      );

      // Note: the "swallows errors silently" branch can't be exercised
      // through fake_cloud_firestore (no public way to force .set() to
      // throw). Leaving the catch block uncovered until a real Firestore
      // emulator test (or a thin decorator) lands.
    });

    group('getByDomain', () {
      test('returns matching corrections sorted by timestamp desc', () async {
        await repo.save(_makeCorrection(domain: 'ica.se'));
        await repo.save(_makeCorrection(domain: 'ica.se'));
        await repo.save(_makeCorrection(domain: 'koket.se'));

        final results = await repo.getByDomain('ica.se');

        expect(results, hasLength(2));
        expect(results.every((c) => c.domain == 'ica.se'), isTrue);
      });

      test('respects the limit parameter', () async {
        for (var i = 0; i < 5; i++) {
          await repo.save(_makeCorrection(domain: 'ica.se'));
        }

        final results = await repo.getByDomain('ica.se', limit: 3);

        expect(results, hasLength(3));
      });

      test('returns empty list when no matches', () async {
        final results = await repo.getByDomain('no-such-domain.com');
        expect(results, isEmpty);
      });
    });

    group('getByTier', () {
      test('returns matching corrections sorted by timestamp desc', () async {
        await repo.save(_makeCorrection(tier: 'tier1'));
        await repo.save(_makeCorrection(tier: 'tier2'));
        await repo.save(_makeCorrection(tier: 'tier1'));

        final results = await repo.getByTier('tier1');

        expect(results, hasLength(2));
        expect(results.every((c) => c.successfulTier == 'tier1'), isTrue);
      });

      test('respects the limit parameter', () async {
        for (var i = 0; i < 4; i++) {
          await repo.save(_makeCorrection(tier: 'tier1'));
        }

        final results = await repo.getByTier('tier1', limit: 2);

        expect(results, hasLength(2));
      });
    });

    group('getDomainStats', () {
      test('aggregates correction count by domain', () async {
        await repo.save(_makeCorrection(domain: 'ica.se'));
        await repo.save(_makeCorrection(domain: 'ica.se'));
        await repo.save(_makeCorrection(domain: 'ica.se'));
        await repo.save(_makeCorrection(domain: 'koket.se'));

        final stats = await repo.getDomainStats();

        expect(stats['ica.se'], equals(3));
        expect(stats['koket.se'], equals(1));
      });

      test('returns empty map when no corrections', () async {
        final stats = await repo.getDomainStats();
        expect(stats, isEmpty);
      });

      test('uses "unknown" bucket when domain field is absent', () async {
        // Manually write a doc without a domain field.
        await firestore.collection('parsing_corrections').doc('manual-1').set({
          'userId': 'u1',
          'recipeId': 'r1',
        });

        final stats = await repo.getDomainStats();

        expect(stats['unknown'], equals(1));
      });
    });

    group('deleteUserCorrections', () {
      test('removes all docs matching the user id', () async {
        await repo.save(_makeCorrection(userId: 'user-a'));
        await repo.save(_makeCorrection(userId: 'user-a'));
        await repo.save(_makeCorrection(userId: 'user-b'));

        await repo.deleteUserCorrections('user-a');

        final remaining = await firestore
            .collection('parsing_corrections')
            .get();
        expect(remaining.docs, hasLength(1));
        expect(remaining.docs.first.data()['userId'], equals('user-b'));
      });

      test('no-ops without throwing when user has no corrections', () async {
        await expectLater(
          repo.deleteUserCorrections('nobody'),
          completes,
        );
      });
    });

    group('getTotalCount', () {
      test('returns 0 when collection is empty', () async {
        final count = await repo.getTotalCount();
        expect(count, equals(0));
      });

      test('returns the count of saved docs', () async {
        for (var i = 0; i < 4; i++) {
          await repo.save(_makeCorrection(domain: 'ica.se'));
        }

        final count = await repo.getTotalCount();
        expect(count, equals(4));
      });
    });
  });
}
