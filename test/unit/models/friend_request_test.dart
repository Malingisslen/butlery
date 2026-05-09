import 'package:flutter_test/flutter_test.dart';
import 'package:clock/clock.dart';
import 'package:butlery/models/friend_request.dart';
import 'helpers/model_test_base.dart';

// Mid-day pin so day/hour/minute boundaries can't be straddled by CI lane
// drift. Both fixture and production resolve `clock.now()` to this exact
// instant under withClock — no relative-time drift possible.
final DateTime _kFixedNow = DateTime(2026, 5, 9, 12, 0, 0);

void _atFixedClock(void Function() body) =>
    withClock(Clock.fixed(_kFixedNow), body);

void main() {
  ModelTestBase.testModelGroup('FriendRequest', () {
    group('Construction', () {
      test('should create with required parameters', () {
        final request = FriendRequest(
          id: 'req_123',
          fromUserId: 'user_1',
          toUserId: 'user_2',
        );

        expect(request.id, equals('req_123'));
        expect(request.fromUserId, equals('user_1'));
        expect(request.toUserId, equals('user_2'));
        expect(request.status, equals(FriendRequestStatus.pending));
        expect(request.sentAt, isNotNull);
        expect(request.respondedAt, isNull);
        expect(request.message, isNull);
      });

      test('should create with all parameters', () {
        final sentTime = DateTime(2024, 1, 15, 10, 30);
        final respondedTime = DateTime(2024, 1, 15, 11, 0);

        final request = FriendRequest(
          id: 'req_123',
          fromUserId: 'user_1',
          toUserId: 'user_2',
          status: FriendRequestStatus.accepted,
          sentAt: sentTime,
          respondedAt: respondedTime,
          message: 'Hej! Vi träffades igår.',
        );

        expect(request.status, equals(FriendRequestStatus.accepted));
        expect(request.sentAt, equals(sentTime));
        expect(request.respondedAt, equals(respondedTime));
        expect(request.message, equals('Hej! Vi träffades igår.'));
      });

      test('should use current time when sentAt not provided', () {
        final beforeCreation = DateTime.now();
        final request = FriendRequest(
          id: 'req_123',
          fromUserId: 'user_1',
          toUserId: 'user_2',
        );
        final afterCreation = DateTime.now();

        expect(
            request.sentAt
                .isAfter(beforeCreation.subtract(Duration(seconds: 1))),
            isTrue);
        expect(request.sentAt.isBefore(afterCreation.add(Duration(seconds: 1))),
            isTrue);
      });
    });

    group('Factory Methods', () {
      test('should create with auto-generated ID', () {
        final request = FriendRequest.create(
          fromUserId: 'user_1',
          toUserId: 'user_2',
          message: 'Let\'s connect!',
        );

        expect(request.id, isNotEmpty);
        expect(request.id.length, equals(36)); // UUID v4 length
        expect(request.fromUserId, equals('user_1'));
        expect(request.toUserId, equals('user_2'));
        expect(request.message, equals('Let\'s connect!'));
        expect(request.status, equals(FriendRequestStatus.pending));
      });

      test('should create different IDs for multiple requests', () {
        final request1 = FriendRequest.create(
          fromUserId: 'user_1',
          toUserId: 'user_2',
        );
        final request2 = FriendRequest.create(
          fromUserId: 'user_1',
          toUserId: 'user_3',
        );

        expect(request1.id, isNot(equals(request2.id)));
      });
    });

    group('Status Operations', () {
      late FriendRequest pendingRequest;

      setUp(() {
        pendingRequest = FriendRequest(
          id: 'req_123',
          fromUserId: 'user_1',
          toUserId: 'user_2',
          sentAt: DateTime.now().subtract(Duration(hours: 1)),
        );
      });

      test('should accept request with updated status and timestamp', () {
        final beforeAccept = DateTime.now();
        final accepted = pendingRequest.accept();
        final afterAccept = DateTime.now();

        expect(accepted.id, equals(pendingRequest.id));
        expect(accepted.status, equals(FriendRequestStatus.accepted));
        expect(accepted.respondedAt, isNotNull);
        expect(
            accepted.respondedAt!
                .isAfter(beforeAccept.subtract(Duration(seconds: 1))),
            isTrue);
        expect(
            accepted.respondedAt!
                .isBefore(afterAccept.add(Duration(seconds: 1))),
            isTrue);
        expect(accepted.sentAt, equals(pendingRequest.sentAt));
      });

      test('should reject request with updated status and timestamp', () {
        final beforeReject = DateTime.now();
        final rejected = pendingRequest.reject();
        final afterReject = DateTime.now();

        expect(rejected.id, equals(pendingRequest.id));
        expect(rejected.status, equals(FriendRequestStatus.rejected));
        expect(rejected.respondedAt, isNotNull);
        expect(
            rejected.respondedAt!
                .isAfter(beforeReject.subtract(Duration(seconds: 1))),
            isTrue);
        expect(
            rejected.respondedAt!
                .isBefore(afterReject.add(Duration(seconds: 1))),
            isTrue);
      });

      test('should cancel request with updated status and timestamp', () {
        final beforeCancel = DateTime.now();
        final cancelled = pendingRequest.cancel();
        final afterCancel = DateTime.now();

        expect(cancelled.id, equals(pendingRequest.id));
        expect(cancelled.status, equals(FriendRequestStatus.cancelled));
        expect(cancelled.respondedAt, isNotNull);
        expect(
            cancelled.respondedAt!
                .isAfter(beforeCancel.subtract(Duration(seconds: 1))),
            isTrue);
        expect(
            cancelled.respondedAt!
                .isBefore(afterCancel.add(Duration(seconds: 1))),
            isTrue);
      });

      test('should preserve message when changing status', () {
        final request = FriendRequest(
          id: 'req_123',
          fromUserId: 'user_1',
          toUserId: 'user_2',
          message: 'Important message',
        );

        final accepted = request.accept();
        expect(accepted.message, equals('Important message'));
      });
    });

    group('Status Checkers', () {
      test('should correctly identify pending status', () {
        final request = FriendRequest(
          id: 'req_123',
          fromUserId: 'user_1',
          toUserId: 'user_2',
        );

        expect(request.isPending, isTrue);
        expect(request.isAccepted, isFalse);
        expect(request.isRejected, isFalse);
        expect(request.isCancelled, isFalse);
        expect(request.isCompleted, isFalse);
      });

      test('should correctly identify accepted status', () {
        final request = FriendRequest(
          id: 'req_123',
          fromUserId: 'user_1',
          toUserId: 'user_2',
          status: FriendRequestStatus.accepted,
          respondedAt: DateTime.now(),
        );

        expect(request.isPending, isFalse);
        expect(request.isAccepted, isTrue);
        expect(request.isRejected, isFalse);
        expect(request.isCancelled, isFalse);
        expect(request.isCompleted, isTrue);
      });

      test('should correctly identify rejected status', () {
        final request = FriendRequest(
          id: 'req_123',
          fromUserId: 'user_1',
          toUserId: 'user_2',
          status: FriendRequestStatus.rejected,
          respondedAt: DateTime.now(),
        );

        expect(request.isPending, isFalse);
        expect(request.isAccepted, isFalse);
        expect(request.isRejected, isTrue);
        expect(request.isCancelled, isFalse);
        expect(request.isCompleted, isTrue);
      });

      test('should correctly identify cancelled status', () {
        final request = FriendRequest(
          id: 'req_123',
          fromUserId: 'user_1',
          toUserId: 'user_2',
          status: FriendRequestStatus.cancelled,
          respondedAt: DateTime.now(),
        );

        expect(request.isPending, isFalse);
        expect(request.isAccepted, isFalse);
        expect(request.isRejected, isFalse);
        expect(request.isCancelled, isTrue);
        expect(request.isCompleted, isTrue);
      });

      test('should identify completed when respondedAt is set', () {
        final pending = FriendRequest(
          id: 'req_123',
          fromUserId: 'user_1',
          toUserId: 'user_2',
        );
        expect(pending.isCompleted, isFalse);

        final completed = pending.accept();
        expect(completed.isCompleted, isTrue);
      });
    });

    group('Expiration Detection', () {
      test('should not be expired when sent recently', () {
        _atFixedClock(() {
          final request = FriendRequest(
            id: 'req_123',
            fromUserId: 'user_1',
            toUserId: 'user_2',
            sentAt: clock.now(),
          );

          expect(request.isExpired, isFalse);
        });
      });

      test('should not be expired when sent 6 days ago', () {
        _atFixedClock(() {
          final request = FriendRequest(
            id: 'req_123',
            fromUserId: 'user_1',
            toUserId: 'user_2',
            sentAt: clock.now().subtract(Duration(days: 6)),
          );

          expect(request.isExpired, isFalse);
        });
      });

      test('should be expired when sent 8 days ago', () {
        _atFixedClock(() {
          final request = FriendRequest(
            id: 'req_123',
            fromUserId: 'user_1',
            toUserId: 'user_2',
            sentAt: clock.now().subtract(Duration(days: 8)),
          );

          expect(request.isExpired, isTrue);
        });
      });

      test('should not be expired when sent exactly 7 days ago', () {
        _atFixedClock(() {
          final request = FriendRequest(
            id: 'req_123',
            fromUserId: 'user_1',
            toUserId: 'user_2',
            sentAt: clock.now().subtract(Duration(days: 7)),
          );

          expect(request.isExpired,
              isFalse); // Not expired until > 7 complete days
        });
      });
    });

    group('Time Display Formatting', () {
      test('should display "Nu" for very recent requests', () {
        _atFixedClock(() {
          final request = FriendRequest(
            id: 'req_123',
            fromUserId: 'user_1',
            toUserId: 'user_2',
            sentAt: clock.now().subtract(Duration(seconds: 30)),
          );

          expect(request.timeAgoText, equals('Nu'));
        });
      });

      test('should display minutes for requests less than 1 hour old', () {
        _atFixedClock(() {
          final request = FriendRequest(
            id: 'req_123',
            fromUserId: 'user_1',
            toUserId: 'user_2',
            sentAt: clock.now().subtract(Duration(minutes: 30)),
          );

          expect(request.timeAgoText, equals('30 min sedan'));
        });
      });

      test('should display hours for requests less than 1 day old', () {
        _atFixedClock(() {
          final request = FriendRequest(
            id: 'req_123',
            fromUserId: 'user_1',
            toUserId: 'user_2',
            sentAt: clock.now().subtract(Duration(hours: 5)),
          );

          expect(request.timeAgoText, equals('5 tim sedan'));
        });
      });

      test('should display days for requests less than 1 week old', () {
        _atFixedClock(() {
          final request = FriendRequest(
            id: 'req_123',
            fromUserId: 'user_1',
            toUserId: 'user_2',
            sentAt: clock.now().subtract(Duration(days: 3)),
          );

          expect(request.timeAgoText, equals('3 dagar sedan'));
        });
      });

      test('should display weeks for older requests', () {
        _atFixedClock(() {
          final request = FriendRequest(
            id: 'req_123',
            fromUserId: 'user_1',
            toUserId: 'user_2',
            sentAt: clock.now().subtract(Duration(days: 14)),
          );

          expect(request.timeAgoText, equals('2 veckor sedan'));
        });
      });

      test('should handle edge case of exactly 1 week', () {
        _atFixedClock(() {
          final request = FriendRequest(
            id: 'req_123',
            fromUserId: 'user_1',
            toUserId: 'user_2',
            sentAt: clock.now().subtract(Duration(days: 7)),
          );

          expect(request.timeAgoText, equals('1 veckor sedan'));
        });
      });
    });

    group('JSON Serialization', () {
      test('should serialize to JSON', () {
        final sentTime = DateTime(2024, 1, 15, 10, 30);
        final respondedTime = DateTime(2024, 1, 15, 11, 0);

        final request = FriendRequest(
          id: 'req_123',
          fromUserId: 'user_1',
          toUserId: 'user_2',
          status: FriendRequestStatus.accepted,
          sentAt: sentTime,
          respondedAt: respondedTime,
          message: 'Test message',
        );

        final json = request.toJson();

        expect(json['id'], equals('req_123'));
        expect(json['fromUserId'], equals('user_1'));
        expect(json['toUserId'], equals('user_2'));
        expect(json['status'], equals('accepted'));
        expect(json['sentAt'], equals(sentTime.toIso8601String()));
        expect(json['respondedAt'], equals(respondedTime.toIso8601String()));
        expect(json['message'], equals('Test message'));
      });

      test('should deserialize from JSON', () {
        final json = {
          'id': 'req_123',
          'fromUserId': 'user_1',
          'toUserId': 'user_2',
          'status': 'rejected',
          'sentAt': '2024-01-15T10:30:00.000',
          'respondedAt': '2024-01-15T11:00:00.000',
          'message': 'Test message',
        };

        final request = FriendRequest.fromJson(json);

        expect(request.id, equals('req_123'));
        expect(request.fromUserId, equals('user_1'));
        expect(request.toUserId, equals('user_2'));
        expect(request.status, equals(FriendRequestStatus.rejected));
        expect(request.sentAt, equals(DateTime(2024, 1, 15, 10, 30)));
        expect(request.respondedAt, equals(DateTime(2024, 1, 15, 11, 0)));
        expect(request.message, equals('Test message'));
      });

      test('should handle null values in JSON', () {
        final json = {
          'id': 'req_123',
          'fromUserId': 'user_1',
          'toUserId': 'user_2',
          'status': 'pending',
          'sentAt': '2024-01-15T10:30:00.000',
          'respondedAt': null,
          'message': null,
        };

        final request = FriendRequest.fromJson(json);

        expect(request.respondedAt, isNull);
        expect(request.message, isNull);
      });

      test('should handle invalid status in JSON', () {
        final json = {
          'id': 'req_123',
          'fromUserId': 'user_1',
          'toUserId': 'user_2',
          'status': 'invalid_status',
          'sentAt': '2024-01-15T10:30:00.000',
        };

        final request = FriendRequest.fromJson(json);
        expect(request.status, equals(FriendRequestStatus.pending));
      });
    });

    group('Firestore Serialization', () {
      test('should serialize to Firestore format', () {
        final sentTime = DateTime(2024, 1, 15, 10, 30);
        final respondedTime = DateTime(2024, 1, 15, 11, 0);

        final request = FriendRequest(
          id: 'req_123',
          fromUserId: 'user_1',
          toUserId: 'user_2',
          status: FriendRequestStatus.accepted,
          sentAt: sentTime,
          respondedAt: respondedTime,
          message: 'Test message',
        );

        final firestore = request.toFirestore();

        expect(firestore['fromUserId'], equals('user_1'));
        expect(firestore['toUserId'], equals('user_2'));
        expect(firestore['status'], equals('accepted'));
        expect(firestore['message'], equals('Test message'));
        expect(firestore.containsKey('id'),
            isFalse); // ID is document ID, not in data

        // Check timestamp format
        expect(firestore['sentAt'], isNotNull);
        expect(firestore['respondedAt'], isNotNull);
      });

      test('should handle null respondedAt in Firestore format', () {
        final request = FriendRequest(
          id: 'req_123',
          fromUserId: 'user_1',
          toUserId: 'user_2',
        );

        final firestore = request.toFirestore();
        expect(firestore['respondedAt'], isNull);
      });
    });

    group('fromMap Factory', () {
      test('should create from map with all fields', () {
        final data = {
          'fromUserId': 'user_1',
          'toUserId': 'user_2',
          'status': 'accepted',
          'sentAt': DateTime(2024, 1, 15, 10, 30),
          'respondedAt': DateTime(2024, 1, 15, 11, 0),
          'message': 'Test message',
        };

        final request = FriendRequest.fromMap('req_123', data);

        expect(request.id, equals('req_123'));
        expect(request.fromUserId, equals('user_1'));
        expect(request.toUserId, equals('user_2'));
        expect(request.status, equals(FriendRequestStatus.accepted));
        expect(request.message, equals('Test message'));
      });

      test('should handle Firestore timestamp format', () {
        final data = {
          'fromUserId': 'user_1',
          'toUserId': 'user_2',
          'status': 'pending',
          'sentAt': {
            'seconds': 1705312200, // 2024-01-15 10:30:00 UTC
            'nanoseconds': 0,
          },
          'respondedAt': null,
          'message': null,
        };

        final request = FriendRequest.fromMap('req_123', data);

        expect(request.sentAt, isNotNull);
        expect(request.respondedAt, isNull);
      });

      test('should handle missing timestamp with current time', () {
        final beforeCreation = DateTime.now();

        final data = {
          'fromUserId': 'user_1',
          'toUserId': 'user_2',
          'status': 'pending',
          'sentAt': null,
        };

        final request = FriendRequest.fromMap('req_123', data);
        final afterCreation = DateTime.now();

        expect(
            request.sentAt
                .isAfter(beforeCreation.subtract(Duration(seconds: 1))),
            isTrue);
        expect(request.sentAt.isBefore(afterCreation.add(Duration(seconds: 1))),
            isTrue);
      });
    });

    group('Equality and Hashing', () {
      test('should be equal when IDs match', () {
        final request1 = FriendRequest(
          id: 'req_123',
          fromUserId: 'user_1',
          toUserId: 'user_2',
        );

        final request2 = FriendRequest(
          id: 'req_123',
          fromUserId: 'user_3',
          toUserId: 'user_4',
        );

        expect(request1, equals(request2));
        expect(request1.hashCode, equals(request2.hashCode));
      });

      test('should not be equal when IDs differ', () {
        final request1 = FriendRequest(
          id: 'req_123',
          fromUserId: 'user_1',
          toUserId: 'user_2',
        );

        final request2 = FriendRequest(
          id: 'req_456',
          fromUserId: 'user_1',
          toUserId: 'user_2',
        );

        expect(request1, isNot(equals(request2)));
      });

      test('should be equal to itself', () {
        final request = FriendRequest(
          id: 'req_123',
          fromUserId: 'user_1',
          toUserId: 'user_2',
        );

        expect(request, equals(request));
      });
    });

    group('toString', () {
      test('should provide meaningful string representation', () {
        final request = FriendRequest(
          id: 'req_123',
          fromUserId: 'user_1',
          toUserId: 'user_2',
          status: FriendRequestStatus.accepted,
        );

        final str = request.toString();

        expect(str, contains('req_123'));
        expect(str, contains('user_1'));
        expect(str, contains('user_2'));
        expect(str, contains('accepted'));
      });
    });

    group('Edge Cases', () {
      test('should handle very long message', () {
        final longMessage = 'A' * 1000;
        final request = FriendRequest.create(
          fromUserId: 'user_1',
          toUserId: 'user_2',
          message: longMessage,
        );

        expect(request.message, equals(longMessage));

        final json = request.toJson();
        expect(json['message'], equals(longMessage));
      });

      test('should handle empty message string', () {
        final request = FriendRequest.create(
          fromUserId: 'user_1',
          toUserId: 'user_2',
          message: '',
        );

        expect(request.message, equals(''));
      });

      test('should handle same user as sender and receiver', () {
        final request = FriendRequest.create(
          fromUserId: 'user_1',
          toUserId: 'user_1',
        );

        expect(request.fromUserId, equals('user_1'));
        expect(request.toUserId, equals('user_1'));
      });

      test('should handle multiple status transitions', () {
        final request = FriendRequest(
          id: 'req_123',
          fromUserId: 'user_1',
          toUserId: 'user_2',
        );

        final accepted = request.accept();
        expect(accepted.status, equals(FriendRequestStatus.accepted));

        // Can still transition from accepted (though unusual)
        final rejected = accepted.reject();
        expect(rejected.status, equals(FriendRequestStatus.rejected));
      });
    });
  });
}
