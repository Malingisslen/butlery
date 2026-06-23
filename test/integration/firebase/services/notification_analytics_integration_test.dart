/// Integration tests for FieldValue operations in notification analytics
///
/// Verifies FieldValue operations that the in-memory fake cannot reproduce:
/// serverTimestamp(), increment(), arrayUnion/arrayRemove, batch writes.
///
/// Runs against the Firebase emulator via the lane helper from BUT-387 Phase 7.
/// Mock tier skips the group cleanly; emulator tier runs it.
@Tags(['integration', 'firebase'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../test_support/emulator_lane.dart';

void main() {
  group(
    'Notification Analytics - Firebase FieldValue Integration',
    () {
      late FirebaseFirestore firestore;
      const String testUserId = 'test_user_analytics';

      setUp(() async {
        firestore = await firestoreForLane();
        await clearLane();
      });

      test(
        'should handle FieldValue.serverTimestamp() for notification events',
        () async {
          // Act - Create notification event with server timestamp
          await firestore
              .collection('notification_analytics')
              .doc('test_notif')
              .set({
                'notificationId': 'test_notif',
                'userId': testUserId,
                'action': 'sent',
                'sentAt': FieldValue.serverTimestamp(),
                'metadata': {
                  'type': 'recipe_comment',
                  'priority': 'normal',
                },
              });

          // Assert
          final doc = await firestore
              .collection('notification_analytics')
              .doc('test_notif')
              .get();

          expect(doc.exists, isTrue);
          final data = doc.data()!;
          expect(data['notificationId'], equals('test_notif'));
          expect(data['userId'], equals(testUserId));
          expect(data['action'], equals('sent'));
          expect(data['sentAt'], isA<Timestamp>());
          expect(data['metadata']['type'], equals('recipe_comment'));

          // Verify timestamp is recent (within last 5 seconds)
          final timestamp = (data['sentAt'] as Timestamp).toDate();
          expect(
            timestamp.difference(DateTime.now()).inSeconds.abs(),
            lessThan(5),
          );
        },
      );

      test(
        'should handle FieldValue.increment() for analytics counters',
        () async {
          // Setup - Create initial analytics document
          await firestore
              .collection('notification_stats')
              .doc('daily_stats')
              .set({
                'sentCount': 0,
                'deliveredCount': 0,
                'openedCount': 0,
                'date': FieldValue.serverTimestamp(),
              });

          // Act - Increment counters using FieldValue
          await firestore
              .collection('notification_stats')
              .doc('daily_stats')
              .update({
                'sentCount': FieldValue.increment(1),
              });

          await firestore
              .collection('notification_stats')
              .doc('daily_stats')
              .update({
                'deliveredCount': FieldValue.increment(1),
              });

          await firestore
              .collection('notification_stats')
              .doc('daily_stats')
              .update({
                'openedCount': FieldValue.increment(1),
              });

          // Assert
          final doc = await firestore
              .collection('notification_stats')
              .doc('daily_stats')
              .get();
          final data = doc.data()!;

          expect(data['sentCount'], equals(1));
          expect(data['deliveredCount'], equals(1));
          expect(data['openedCount'], equals(1));
          expect(data['date'], isA<Timestamp>());
        },
      );

      test(
        'should handle batch operations with FieldValue operations',
        () async {
          // Act - Create batch with multiple FieldValue operations
          final batch = firestore.batch();

          // Add multiple notification events with server timestamps
          for (int i = 0; i < 3; i++) {
            final ref = firestore
                .collection('notification_analytics')
                .doc('batch_notif_$i');
            batch.set(ref, {
              'notificationId': 'batch_notif_$i',
              'userId': testUserId,
              'action': 'sent',
              'sentAt': FieldValue.serverTimestamp(),
              'batchIndex': i,
            });
          }

          // Update statistics with increments
          final statsRef = firestore
              .collection('notification_stats')
              .doc('batch_stats');
          batch.set(statsRef, {
            'totalSent': FieldValue.increment(3),
            'lastUpdated': FieldValue.serverTimestamp(),
          });

          await batch.commit();

          // Assert - Check all events were created
          final query = await firestore
              .collection('notification_analytics')
              .where('userId', isEqualTo: testUserId)
              .get();

          expect(query.docs.length, equals(3));

          // Verify all have timestamps
          for (final doc in query.docs) {
            expect(doc.data()['sentAt'], isA<Timestamp>());
          }

          // Check stats were updated
          final statsDoc = await firestore
              .collection('notification_stats')
              .doc('batch_stats')
              .get();
          final statsData = statsDoc.data()!;
          expect(statsData['totalSent'], equals(3));
          expect(statsData['lastUpdated'], isA<Timestamp>());
        },
      );

      test(
        'should handle FieldValue.arrayUnion() for notification categories',
        () async {
          // Setup - Create initial document
          await firestore
              .collection('user_notification_prefs')
              .doc(testUserId)
              .set({
                'enabledCategories': ['recipe_comments'],
                'lastUpdated': FieldValue.serverTimestamp(),
              });

          // Act - Add new category using arrayUnion
          await firestore
              .collection('user_notification_prefs')
              .doc(testUserId)
              .update({
                'enabledCategories': FieldValue.arrayUnion([
                  'friend_requests',
                  'menu_shares',
                ]),
                'lastUpdated': FieldValue.serverTimestamp(),
              });

          // Assert
          final doc = await firestore
              .collection('user_notification_prefs')
              .doc(testUserId)
              .get();
          final data = doc.data()!;

          final categories = List<String>.from(data['enabledCategories']);
          expect(
            categories,
            containsAll(['recipe_comments', 'friend_requests', 'menu_shares']),
          );
          expect(categories.length, equals(3));
          expect(data['lastUpdated'], isA<Timestamp>());
        },
      );

      test(
        'should handle FieldValue.arrayRemove() for notification categories',
        () async {
          // Setup - Create document with multiple categories
          await firestore
              .collection('user_notification_prefs')
              .doc(testUserId)
              .set({
                'enabledCategories': [
                  'recipe_comments',
                  'friend_requests',
                  'menu_shares',
                  'recipe_likes',
                ],
                'lastUpdated': FieldValue.serverTimestamp(),
              });

          // Act - Remove categories using arrayRemove
          await firestore
              .collection('user_notification_prefs')
              .doc(testUserId)
              .update({
                'enabledCategories': FieldValue.arrayRemove([
                  'friend_requests',
                  'menu_shares',
                ]),
                'lastUpdated': FieldValue.serverTimestamp(),
              });

          // Assert
          final doc = await firestore
              .collection('user_notification_prefs')
              .doc(testUserId)
              .get();
          final data = doc.data()!;

          final categories = List<String>.from(data['enabledCategories']);
          expect(categories, equals(['recipe_comments', 'recipe_likes']));
          expect(categories.length, equals(2));
          expect(data['lastUpdated'], isA<Timestamp>());
        },
      );

      test('should handle complex query with timestamps and ordering', () async {
        // Setup - Create multiple notification events with different timestamps
        final now = DateTime.now();

        for (int i = 0; i < 5; i++) {
          await firestore
              .collection('notification_analytics')
              .doc('timed_notif_$i')
              .set({
                'notificationId': 'timed_notif_$i',
                'userId': testUserId,
                'action': 'sent',
                'sentAt': Timestamp.fromDate(now.subtract(Duration(hours: i))),
                'priority': i < 3 ? 'high' : 'normal',
              });
        }

        // Act - Query recent high-priority notifications
        final query = await firestore
            .collection('notification_analytics')
            .where('userId', isEqualTo: testUserId)
            .where('priority', isEqualTo: 'high')
            .orderBy('sentAt', descending: true)
            .limit(2)
            .get();

        // Assert
        expect(query.docs.length, equals(2));

        // Verify ordering (most recent first)
        final firstDoc = query.docs[0].data();
        final secondDoc = query.docs[1].data();

        final firstTime = (firstDoc['sentAt'] as Timestamp).toDate();
        final secondTime = (secondDoc['sentAt'] as Timestamp).toDate();

        expect(firstTime.isAfter(secondTime), isTrue);
        expect(firstDoc['priority'], equals('high'));
        expect(secondDoc['priority'], equals('high'));
      });
    },
    skip: emulatorOnlySkip,
  );
}
