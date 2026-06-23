/// Tests for HeirloomMetadata model (BUT-410).
///
/// Covers:
/// - Construction happy-path
/// - JSON + Firestore round-trip with all nullable permutations
/// - Validation rejection for year/writerName/note
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/models/recipe/heirloom_metadata.dart';

void main() {
  group('HeirloomMetadata', () {
    final baseAddedAt = DateTime.utc(2026, 4, 19, 12, 30);
    const baseUserId = 'user_abc';
    const baseImageUrl =
        'https://firebasestorage.googleapis.com/v0/b/x/o/users%2Fuser_abc%2Frecipes%2Fr1%2Fheirloom%2Fdeadbeefcafef00d.jpg';

    HeirloomMetadata buildFull() => HeirloomMetadata(
      sourceImageUrl: baseImageUrl,
      writerName: 'Farmor Elsa',
      year: 1978,
      note: 'Skriven på bakbordet i köket i Lund.',
      addedAt: baseAddedAt,
      addedByUserId: baseUserId,
    );

    group('construction', () {
      test('accepts all fields populated', () {
        final meta = buildFull();
        expect(meta.writerName, 'Farmor Elsa');
        expect(meta.year, 1978);
        expect(meta.note, isNotEmpty);
        expect(meta.addedByUserId, baseUserId);
      });

      test('accepts all optional fields null', () {
        final meta = HeirloomMetadata(
          sourceImageUrl: baseImageUrl,
          addedAt: baseAddedAt,
          addedByUserId: baseUserId,
        );
        expect(meta.writerName, isNull);
        expect(meta.year, isNull);
        expect(meta.note, isNull);
      });
    });

    group('JSON round-trip', () {
      test('full metadata round-trips through toJson/fromMap', () {
        final original = buildFull();
        final roundTripped = HeirloomMetadata.fromMap(original.toJson());

        expect(roundTripped.sourceImageUrl, original.sourceImageUrl);
        expect(roundTripped.writerName, original.writerName);
        expect(roundTripped.year, original.year);
        expect(roundTripped.note, original.note);
        expect(roundTripped.addedAt, original.addedAt);
        expect(roundTripped.addedByUserId, original.addedByUserId);
      });

      test('all-nullable-null round-trips', () {
        final original = HeirloomMetadata(
          sourceImageUrl: baseImageUrl,
          addedAt: baseAddedAt,
          addedByUserId: baseUserId,
        );
        final roundTripped = HeirloomMetadata.fromMap(original.toJson());

        expect(roundTripped.writerName, isNull);
        expect(roundTripped.year, isNull);
        expect(roundTripped.note, isNull);
        expect(roundTripped.sourceImageUrl, original.sourceImageUrl);
        expect(roundTripped.addedAt, original.addedAt);
      });

      test('year-only round-trips (writer + note null)', () {
        final original = HeirloomMetadata(
          sourceImageUrl: baseImageUrl,
          year: 1954,
          addedAt: baseAddedAt,
          addedByUserId: baseUserId,
        );
        final roundTripped = HeirloomMetadata.fromMap(original.toJson());
        expect(roundTripped.year, 1954);
        expect(roundTripped.writerName, isNull);
        expect(roundTripped.note, isNull);
      });

      test('writerName-only round-trips (year + note null)', () {
        final original = HeirloomMetadata(
          sourceImageUrl: baseImageUrl,
          writerName: 'Mormor Greta',
          addedAt: baseAddedAt,
          addedByUserId: baseUserId,
        );
        final roundTripped = HeirloomMetadata.fromMap(original.toJson());
        expect(roundTripped.writerName, 'Mormor Greta');
        expect(roundTripped.year, isNull);
        expect(roundTripped.note, isNull);
      });
    });

    group('Firestore round-trip', () {
      test('Timestamp addedAt round-trips to DateTime', () {
        final original = buildFull();
        final firestoreMap = original.toFirestore();

        expect(firestoreMap['addedAt'], isA<Timestamp>());

        final roundTripped = HeirloomMetadata.fromMap(firestoreMap);
        // Firestore Timestamp.toDate() returns a local DateTime even when the
        // original was UTC, so compare by instant rather than flag.
        expect(
          roundTripped.addedAt.isAtSameMomentAs(original.addedAt),
          isTrue,
        );
        expect(roundTripped.writerName, original.writerName);
        expect(roundTripped.year, original.year);
        expect(roundTripped.note, original.note);
      });

      test('note-only round-trips via Firestore shape', () {
        final original = HeirloomMetadata(
          sourceImageUrl: baseImageUrl,
          note: 'Ärvd från min farmor',
          addedAt: baseAddedAt,
          addedByUserId: baseUserId,
        );
        final roundTripped = HeirloomMetadata.fromMap(original.toFirestore());
        expect(roundTripped.note, 'Ärvd från min farmor');
        expect(roundTripped.writerName, isNull);
        expect(roundTripped.year, isNull);
      });
    });

    group('validation', () {
      test('rejects year below 1800', () {
        expect(
          () => HeirloomMetadata(
            sourceImageUrl: baseImageUrl,
            year: 1799,
            addedAt: baseAddedAt,
            addedByUserId: baseUserId,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('rejects year above current year', () {
        final futureYear = DateTime.now().year + 1;
        expect(
          () => HeirloomMetadata(
            sourceImageUrl: baseImageUrl,
            year: futureYear,
            addedAt: baseAddedAt,
            addedByUserId: baseUserId,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('rejects writerName exceeding 100 characters', () {
        final longName = 'x' * 101;
        expect(
          () => HeirloomMetadata(
            sourceImageUrl: baseImageUrl,
            writerName: longName,
            addedAt: baseAddedAt,
            addedByUserId: baseUserId,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('accepts writerName exactly 100 characters (boundary)', () {
        final exactName = 'x' * 100;
        expect(
          () => HeirloomMetadata(
            sourceImageUrl: baseImageUrl,
            writerName: exactName,
            addedAt: baseAddedAt,
            addedByUserId: baseUserId,
          ),
          returnsNormally,
        );
      });

      test('rejects note exceeding 200 characters', () {
        final longNote = 'n' * 201;
        expect(
          () => HeirloomMetadata(
            sourceImageUrl: baseImageUrl,
            note: longNote,
            addedAt: baseAddedAt,
            addedByUserId: baseUserId,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('accepts year 1800 (lower boundary)', () {
        expect(
          () => HeirloomMetadata(
            sourceImageUrl: baseImageUrl,
            year: 1800,
            addedAt: baseAddedAt,
            addedByUserId: baseUserId,
          ),
          returnsNormally,
        );
      });
    });
  });
}
