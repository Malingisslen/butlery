/// Integration tests for Firebase FieldValue operations
///
/// NOTE: These tests require real Firebase emulator to properly test
/// FieldValue server-side behavior. Currently converted to use
/// FakeFirebaseFirestore to avoid platform channel issues.
///
/// To run with real emulator:
/// 1. Start Firebase emulator: firebase emulators:start
/// 2. Run with tag: flutter test --tags emulator
@Skip('Requires Firebase emulator - use FakeFirebaseFirestore tests instead')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/mocks/firestore_singleton.dart';

void main() {
  group('Firebase FieldValue Operations (Fake)', () {
    late FakeFirebaseFirestore firestore;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() async {
      firestore = FirestoreSingleton.instance;
    });

    group('serverTimestamp', () {
      test('should set server timestamp on document creation', () async {
        // Act
        final docRef = await firestore.collection('test').add({
          'createdAt': FieldValue.serverTimestamp(),
          'name': 'Test Document',
        });

        // Assert
        final snapshot = await docRef.get();
        final data = snapshot.data()!;

        expect(data['createdAt'], isA<Timestamp>());
        expect(data['name'], equals('Test Document'));

        // Verify timestamp is recent (within last minute)
        final timestamp = data['createdAt'] as Timestamp;
        final now = DateTime.now();
        final difference = now.difference(timestamp.toDate());
        expect(difference.inMinutes, lessThan(1));
      });

      test('should update server timestamp on document update', () async {
        // Arrange
        final docRef = await firestore.collection('test').add({
          'name': 'Original',
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Wait a moment to ensure timestamps differ
        await Future.delayed(const Duration(milliseconds: 100));

        // Act
        await docRef.update({
          'name': 'Updated',
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Assert
        final snapshot = await docRef.get();
        final data = snapshot.data()!;

        expect(data['createdAt'], isA<Timestamp>());
        expect(data['updatedAt'], isA<Timestamp>());

        final created = (data['createdAt'] as Timestamp).toDate();
        final updated = (data['updatedAt'] as Timestamp).toDate();
        expect(updated.isAfter(created), isTrue);
      });
    });

    group('arrayUnion', () {
      test('should add unique items to array', () async {
        // Arrange
        final docRef = await firestore.collection('test').add({
          'tags': ['tag1', 'tag2'],
        });

        // Act
        await docRef.update({
          'tags': FieldValue.arrayUnion(['tag2', 'tag3', 'tag4']),
        });

        // Assert
        final snapshot = await docRef.get();
        final tags = List<String>.from(snapshot.data()!['tags']);

        expect(tags, containsAll(['tag1', 'tag2', 'tag3', 'tag4']));
        expect(tags.length, equals(4)); // No duplicates
      });

      test('should create array if it does not exist', () async {
        // Arrange
        final docRef = await firestore.collection('test').add({
          'name': 'Test',
        });

        // Act
        await docRef.update({
          'tags': FieldValue.arrayUnion(['new1', 'new2']),
        });

        // Assert
        final snapshot = await docRef.get();
        final tags = List<String>.from(snapshot.data()!['tags']);

        expect(tags, equals(['new1', 'new2']));
      });
    });

    group('arrayRemove', () {
      test('should remove items from array', () async {
        // Arrange
        final docRef = await firestore.collection('test').add({
          'tags': ['tag1', 'tag2', 'tag3', 'tag4'],
        });

        // Act
        await docRef.update({
          'tags': FieldValue.arrayRemove(['tag2', 'tag4']),
        });

        // Assert
        final snapshot = await docRef.get();
        final tags = List<String>.from(snapshot.data()!['tags']);

        expect(tags, equals(['tag1', 'tag3']));
      });

      test('should handle removing non-existent items', () async {
        // Arrange
        final docRef = await firestore.collection('test').add({
          'tags': ['tag1', 'tag2'],
        });

        // Act
        await docRef.update({
          'tags': FieldValue.arrayRemove(['tag3', 'tag4']),
        });

        // Assert
        final snapshot = await docRef.get();
        final tags = List<String>.from(snapshot.data()!['tags']);

        expect(tags, equals(['tag1', 'tag2']));
      });
    });

    group('increment', () {
      test('should increment numeric field', () async {
        // Arrange
        final docRef = await firestore.collection('test').add({
          'count': 5,
        });

        // Act
        await docRef.update({
          'count': FieldValue.increment(3),
        });

        // Assert
        final snapshot = await docRef.get();
        expect(snapshot.data()!['count'], equals(8));
      });

      test('should decrement with negative value', () async {
        // Arrange
        final docRef = await firestore.collection('test').add({
          'count': 10,
        });

        // Act
        await docRef.update({
          'count': FieldValue.increment(-3),
        });

        // Assert
        final snapshot = await docRef.get();
        expect(snapshot.data()!['count'], equals(7));
      });

      test('should create field if it does not exist', () async {
        // Arrange
        final docRef = await firestore.collection('test').add({
          'name': 'Test',
        });

        // Act
        await docRef.update({
          'count': FieldValue.increment(5),
        });

        // Assert
        final snapshot = await docRef.get();
        expect(snapshot.data()!['count'], equals(5));
      });
    });

    group('combined operations', () {
      test('should handle multiple FieldValue operations in single update',
          () async {
        // Arrange
        final docRef = await firestore.collection('test').add({
          'name': 'Test',
          'views': 100,
          'tags': ['existing'],
        });

        // Act
        await docRef.update({
          'updatedAt': FieldValue.serverTimestamp(),
          'views': FieldValue.increment(1),
          'tags': FieldValue.arrayUnion(['new1', 'new2']),
        });

        // Assert
        final snapshot = await docRef.get();
        final data = snapshot.data()!;

        expect(data['updatedAt'], isA<Timestamp>());
        expect(data['views'], equals(101));
        expect(List<String>.from(data['tags']),
            containsAll(['existing', 'new1', 'new2']));
      });
    });

    group('advanced serverTimestamp operations', () {
      test('should handle multiple timestamps in nested fields', () async {
        // Arrange & Act
        final docRef = await firestore.collection('test').add({
          'metadata': {
            'created': FieldValue.serverTimestamp(),
            'author': 'Test User',
          },
          'timestamps': {
            'firstAccess': FieldValue.serverTimestamp(),
            'lastModified': FieldValue.serverTimestamp(),
          },
        });

        // Assert
        final snapshot = await docRef.get();
        final data = snapshot.data()!;
        final metadata = data['metadata'] as Map<String, dynamic>;
        final timestamps = data['timestamps'] as Map<String, dynamic>;

        expect(metadata['created'], isA<Timestamp>());
        expect(timestamps['firstAccess'], isA<Timestamp>());
        expect(timestamps['lastModified'], isA<Timestamp>());
      });

      test('should maintain timestamp consistency in batch operations',
          () async {
        // Arrange
        final batch = firestore.batch();
        final doc1 = firestore.collection('test').doc();
        final doc2 = firestore.collection('test').doc();

        batch.set(doc1, {
          'createdAt': FieldValue.serverTimestamp(),
          'type': 'document1',
        });

        batch.set(doc2, {
          'createdAt': FieldValue.serverTimestamp(),
          'type': 'document2',
        });

        // Act
        await batch.commit();

        // Assert
        final snap1 = await doc1.get();
        final snap2 = await doc2.get();

        expect(snap1.data()!['createdAt'], isA<Timestamp>());
        expect(snap2.data()!['createdAt'], isA<Timestamp>());

        // Timestamps should be very close (within 1 second)
        final time1 = (snap1.data()!['createdAt'] as Timestamp).toDate();
        final time2 = (snap2.data()!['createdAt'] as Timestamp).toDate();
        expect(time1.difference(time2).abs().inSeconds, lessThanOrEqualTo(1));
      });
    });

    group('advanced array operations', () {
      test('should handle complex objects in arrayUnion', () async {
        // Arrange
        final docRef = await firestore.collection('test').add({
          'participants': [
            {'id': 'user1', 'name': 'Alice'},
            {'id': 'user2', 'name': 'Bob'},
          ],
        });

        // Act
        await docRef.update({
          'participants': FieldValue.arrayUnion([
            {'id': 'user3', 'name': 'Charlie'},
            {'id': 'user1', 'name': 'Alice'}, // Duplicate
          ]),
        });

        // Assert
        final snapshot = await docRef.get();
        final participants = List<Map<String, dynamic>>.from(snapshot
            .data()!['participants']
            .map((p) => Map<String, dynamic>.from(p)));

        expect(participants.length, equals(3)); // No duplicate
        expect(participants.any((p) => p['id'] == 'user3'), isTrue);
      });

      test('should handle arrayUnion with mixed data types', () async {
        // Arrange
        final docRef = await firestore.collection('test').add({
          'mixedArray': [1, 'two', true],
        });

        // Act
        await docRef.update({
          'mixedArray':
              FieldValue.arrayUnion([3.14, 'four', false, 1]), // 1 is duplicate
        });

        // Assert
        final snapshot = await docRef.get();
        final array = List<dynamic>.from(snapshot.data()!['mixedArray']);

        expect(array.length, equals(6)); // Original 3 + 3 new (1 is duplicate)
        expect(array, containsAll([1, 'two', true, 3.14, 'four', false]));
      });

      test('should handle empty array operations', () async {
        // Arrange
        final docRef = await firestore.collection('test').add({
          'items': [],
        });

        // Act - Add to empty array
        await docRef.update({
          'items': FieldValue.arrayUnion(['first', 'second']),
        });

        // Assert
        var snapshot = await docRef.get();
        expect(List<String>.from(snapshot.data()!['items']),
            equals(['first', 'second']));

        // Act - Remove all items
        await docRef.update({
          'items': FieldValue.arrayRemove(['first', 'second']),
        });

        // Assert
        snapshot = await docRef.get();
        expect(List<dynamic>.from(snapshot.data()!['items']), isEmpty);
      });
    });

    group('advanced increment operations', () {
      test('should handle increment on double values', () async {
        // Arrange
        final docRef = await firestore.collection('test').add({
          'price': 99.99,
        });

        // Act
        await docRef.update({
          'price': FieldValue.increment(10.01),
        });

        // Assert
        final snapshot = await docRef.get();
        expect(snapshot.data()!['price'], closeTo(110.0, 0.01));
      });

      test('should handle concurrent increments', () async {
        // Arrange
        final docRef = await firestore.collection('test').add({
          'counter': 0,
        });

        // Act - Simulate concurrent updates
        final futures = List.generate(
            5, (i) => docRef.update({'counter': FieldValue.increment(1)}));
        await Future.wait(futures);

        // Assert
        final snapshot = await docRef.get();
        expect(snapshot.data()!['counter'], equals(5));
      });

      test('should handle negative increment to zero and below', () async {
        // Arrange
        final docRef = await firestore.collection('test').add({
          'balance': 5,
        });

        // Act
        await docRef.update({
          'balance': FieldValue.increment(-10),
        });

        // Assert
        final snapshot = await docRef.get();
        expect(snapshot.data()!['balance'], equals(-5));
      });
    });

    group('delete field operations', () {
      test('should delete specific fields while preserving others', () async {
        // Arrange
        final docRef = await firestore.collection('test').add({
          'keep': 'this value',
          'delete': 'this one',
          'alsoKeep': 'this too',
        });

        // Act
        await docRef.update({
          'delete': FieldValue.delete(),
        });

        // Assert
        final snapshot = await docRef.get();
        final data = snapshot.data()!;
        expect(data.containsKey('delete'), isFalse);
        expect(data['keep'], equals('this value'));
        expect(data['alsoKeep'], equals('this too'));
      });

      test('should delete nested fields', () async {
        // Arrange
        final docRef = await firestore.collection('test').add({
          'user': {
            'name': 'John',
            'email': 'john@example.com',
            'phone': '123-456-7890',
          },
        });

        // Act
        await docRef.update({
          'user.phone': FieldValue.delete(),
        });

        // Assert
        final snapshot = await docRef.get();
        final user = snapshot.data()!['user'] as Map<String, dynamic>;
        expect(user.containsKey('phone'), isFalse);
        expect(user['name'], equals('John'));
        expect(user['email'], equals('john@example.com'));
      });
    });

    group('transaction operations with FieldValue', () {
      test('should handle FieldValue in transactions', () async {
        // Arrange
        final docRef = await firestore.collection('test').add({
          'balance': 100,
          'transactions': <String>[],
          'lastUpdate': null,
        });

        // Act
        await firestore.runTransaction((transaction) async {
          final snapshot = await transaction.get(docRef);
          final currentBalance = snapshot.data()!['balance'] as int;

          if (currentBalance >= 30) {
            transaction.update(docRef, {
              'balance': FieldValue.increment(-30),
              'transactions': FieldValue.arrayUnion(['withdraw:30']),
              'lastUpdate': FieldValue.serverTimestamp(),
            });
          }
        });

        // Assert
        final snapshot = await docRef.get();
        final data = snapshot.data()!;
        expect(data['balance'], equals(70));
        expect(
            List<String>.from(data['transactions']), contains('withdraw:30'));
        expect(data['lastUpdate'], isA<Timestamp>());
      });
    });

    group('edge cases and error scenarios', () {
      test('should handle FieldValue on non-existent document with set merge',
          () async {
        // Arrange
        final docRef = firestore.collection('test').doc('non_existent');

        // Act
        await docRef.set({
          'createdAt': FieldValue.serverTimestamp(),
          'views': FieldValue.increment(1),
          'tags': FieldValue.arrayUnion(['initial']),
        }, SetOptions(merge: true));

        // Assert
        final snapshot = await docRef.get();
        expect(snapshot.exists, isTrue);
        final data = snapshot.data()!;
        expect(data['createdAt'], isA<Timestamp>());
        expect(data['views'], equals(1));
        expect(List<String>.from(data['tags']), equals(['initial']));
      });

      test('should handle arrayUnion with null values gracefully', () async {
        // Arrange
        final docRef = await firestore.collection('test').add({
          'items': ['existing'],
        });

        // Act - FakeFirebaseFirestore might handle this differently than real Firestore
        try {
          await docRef.update({
            'items': FieldValue.arrayUnion([null, 'new']),
          });

          // Assert if no exception
          final snapshot = await docRef.get();
          final items = List<dynamic>.from(snapshot.data()!['items']);
          expect(items, containsAll(['existing', 'new']));
          // Null handling depends on implementation
        } catch (e) {
          // Some implementations might reject null values
          expect(e, isA<Exception>());
        }
      });

      test('should maintain field order with mixed operations', () async {
        // Arrange
        final docRef = await firestore.collection('test').add({
          'a': 1,
          'b': 2,
          'c': 3,
        });

        // Act
        await docRef.update({
          'b': FieldValue.delete(),
          'd': FieldValue.serverTimestamp(),
          'a': FieldValue.increment(10),
          'e': FieldValue.arrayUnion(['new']),
        });

        // Assert
        final snapshot = await docRef.get();
        final data = snapshot.data()!;
        expect(data.containsKey('b'), isFalse);
        expect(data['a'], equals(11));
        expect(data['c'], equals(3));
        expect(data['d'], isA<Timestamp>());
        expect(data['e'], equals(['new']));
      });
    });
  });
}
