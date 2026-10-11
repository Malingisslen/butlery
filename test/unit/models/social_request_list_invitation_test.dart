/// A list invitation is a `social_requests` row the server writes. These pin
/// that the model carries its list fields both ways and that rows from other
/// types, or from before the type existed, are not read as one.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/social_request.dart';

Map<String, dynamic> _row({Object? type = 'listInvitation'}) => {
  'type': type,
  'fromUserId': 'anna',
  'toUserId': 'bob',
  'status': 'pending',
  'listId': 'list-1',
  'listName': 'Veckohandling',
  'permission': 'view',
  'fromUserName': 'Anna',
};

void main() {
  group('SocialRequest list invitation', () {
    test('reads the list fields and says it is a list invitation', () {
      final r = SocialRequest.fromMap('inv-1', _row());

      expect(r.type, SocialRequestType.listInvitation);
      expect(r.isListInvitation, isTrue);
      expect(r.isFriendRequest, isFalse);
      expect(r.isGroupInvitation, isFalse);
      expect(r.listId, 'list-1');
      expect(r.listName, 'Veckohandling');
      expect(r.permission, 'view');
    });

    test('survives a round trip through Firestore data', () {
      final original = SocialRequest.fromMap('inv-1', _row());
      final again = SocialRequest.fromMap('inv-1', original.toFirestore());

      expect(again.type, SocialRequestType.listInvitation);
      expect(again.listId, original.listId);
      expect(again.listName, original.listName);
      expect(again.permission, original.permission);
    });

    test('copyWith keeps the list fields', () {
      final r = SocialRequest.fromMap('inv-1', _row());
      final declined = r.copyWith(status: SocialRequestStatus.rejected);

      expect(declined.listId, 'list-1');
      expect(declined.listName, 'Veckohandling');
      expect(declined.permission, 'view');
    });

    test('writes the list keys only when present', () {
      final friend = SocialRequest.friendRequest(
        fromUserId: 'a',
        toUserId: 'b',
      ).toFirestore();
      final group = SocialRequest.groupInvitation(
        fromUserId: 'a',
        toUserId: 'b',
        groupId: 'g',
        groupName: 'G',
        groupEmoji: 'x',
        fromUserName: 'A',
      ).toFirestore();

      for (final data in [friend, group]) {
        expect(data.containsKey('listId'), isFalse);
        expect(data.containsKey('listName'), isFalse);
        expect(data.containsKey('permission'), isFalse);
      }
    });

    test(
      'a legacy friend row has no list fields and is not a list invitation',
      () {
        final r = SocialRequest.fromMap('old', {
          'type': 'friend',
          'fromUserId': 'a',
          'toUserId': 'b',
          'status': 'pending',
        });

        expect(r.isListInvitation, isFalse);
        expect(r.listId, isNull);
        expect(r.listName, isNull);
        expect(r.permission, isNull);
      },
    );

    test(
      'an unknown type keeps its old fallback and is not a list invitation',
      () {
        final r = SocialRequest.fromMap('x', _row(type: 'somethingNew'));

        expect(r.isListInvitation, isFalse);
        expect(r.type, SocialRequestType.friend);
      },
    );

    test(
      'a list invitation is never mistaken for a friend or group request',
      () {
        final r = SocialRequest.fromMap('inv-1', _row());

        expect(r.type, isNot(SocialRequestType.friend));
        expect(r.type, isNot(SocialRequestType.groupInvitation));
        expect(r.toFirestore()['type'], 'listInvitation');
      },
    );
  });
}
