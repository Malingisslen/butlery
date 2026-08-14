/// Unit tests for [ChatGroup] (BUT-1838).
///
/// The model is READ-ONLY from the app — there is no `toFirestore` — so the
/// whole of its contract is `fromFirestore` plus the three predicates the UI
/// reads off it. [ChatGroup.isAdmin] is the sole authority
/// `GroupDetailViewModel` consults before offering rename / remove-member, so
/// a corrupt document must resolve to "nobody is an admin", never to a
/// throw (which would blank the screen) and never to "everybody".
library;

import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/messaging/chat_group.dart';

const _groupId = 'chat-group-1';
const _admin = 'uid-admin';
const _member = 'uid-member';
const _stranger = 'uid-stranger';

/// A COMPLETE, well-formed document. Every malformed-input test below starts
/// from this and corrupts exactly one key, so the assertion that fails names
/// the field that broke rather than "the fixture was never valid".
Map<String, dynamic> _wellFormed() => <String, dynamic>{
  'name': 'Middagsgänget',
  'memberIds': <String>[_admin, _member],
  'adminIds': <String>[_admin],
  'memberDisplayNames': <String, dynamic>{_admin: 'Anna', _member: 'Erik'},
  'memberAvatarUrls': <String, dynamic>{
    _admin: 'https://cdn/anna.png',
    _member: null,
  },
  'conversationId': 'conv-1',
  'createdBy': _admin,
  'createdAt': Timestamp.fromDate(DateTime.utc(2026, 1, 2, 3, 4)),
  'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 2, 3, 4, 5)),
};

Future<DocumentSnapshot<Map<String, dynamic>>> _read(
  FakeFirebaseFirestore firestore,
  Map<String, dynamic> data, {
  String id = _groupId,
}) async {
  await firestore.collection('chat_groups').doc(id).set(data);
  return firestore.collection('chat_groups').doc(id).get();
}

void main() {
  group('fromFirestore — well-formed document', () {
    test('reads every field, taking the id from the document path', () async {
      final firestore = FakeFirebaseFirestore();

      final group = ChatGroup.fromFirestore(
        await _read(firestore, _wellFormed()),
      );

      // The id is NOT a body field — it comes from doc.id, so a body that
      // disagreed could not silently win.
      expect(group.id, _groupId);
      expect(group.name, 'Middagsgänget');
      expect(group.memberIds, [_admin, _member]);
      expect(group.adminIds, [_admin]);
      expect(group.memberDisplayNames, {_admin: 'Anna', _member: 'Erik'});
      expect(group.memberAvatarUrls, {
        _admin: 'https://cdn/anna.png',
        _member: null,
      });
      expect(group.conversationId, 'conv-1');
      expect(group.createdBy, _admin);
      expect(group.createdAt.toUtc(), DateTime.utc(2026, 1, 2, 3, 4));
      expect(group.updatedAt.toUtc(), DateTime.utc(2026, 2, 3, 4, 5));
    });

    test(
      'isAdmin separates an admin from an ordinary member and a stranger',
      () async {
        // The discriminator GroupDetailViewModel.isAdmin depends on: the
        // ordinary member is IN memberIds and OUT of adminIds, so an
        // implementation reading membership instead of adminIds is caught.
        final firestore = FakeFirebaseFirestore();
        final group = ChatGroup.fromFirestore(
          await _read(firestore, _wellFormed()),
        );

        expect(group.isAdmin(_admin), isTrue);
        expect(group.isAdmin(_member), isFalse);
        expect(group.isAdmin(_stranger), isFalse);

        expect(group.isMember(_admin), isTrue);
        expect(group.isMember(_member), isTrue);
        expect(group.isMember(_stranger), isFalse);
      },
    );

    test('displayNameOf and avatarUrlOf fall back per field', () async {
      final firestore = FakeFirebaseFirestore();
      final group = ChatGroup.fromFirestore(
        await _read(firestore, _wellFormed()),
      );

      expect(group.displayNameOf(_admin), 'Anna');
      // A missing NAME renders as '?', a missing AVATAR as null — they are
      // different fallbacks and a shared one would break the avatar widget.
      expect(group.displayNameOf(_stranger), '?');
      expect(group.avatarUrlOf(_member), isNull);
      expect(group.avatarUrlOf(_stranger), isNull);
    });
  });

  group('fromFirestore — malformed document', () {
    test(
      'adminIds stored as a Map instead of a List admits nobody as admin',
      () async {
        // The safety-relevant direction: a shape the parser does not
        // recognise must fail CLOSED. If it degraded to "everyone", the
        // group-detail screen would offer remove-member to any participant.
        final firestore = FakeFirebaseFirestore();
        final data = _wellFormed()
          ..['adminIds'] = <String, dynamic>{'0': _admin};

        final group = ChatGroup.fromFirestore(await _read(firestore, data));

        expect(group.adminIds, isEmpty);
        expect(group.isAdmin(_admin), isFalse);
        // Positive control: the rest of the document still parsed, so the
        // empty adminIds is the corruption and not a dead fixture.
        expect(group.memberIds, [_admin, _member]);
        expect(group.name, 'Middagsgänget');
      },
    );

    test('memberIds missing entirely yields an empty roster', () async {
      final firestore = FakeFirebaseFirestore();
      final data = _wellFormed()..remove('memberIds');

      final group = ChatGroup.fromFirestore(await _read(firestore, data));

      expect(group.memberIds, isEmpty);
      expect(group.isMember(_admin), isFalse);
      expect(group.adminIds, [_admin]); // positive control
    });

    test(
      'a non-String display name becomes "?" rather than throwing',
      () async {
        final firestore = FakeFirebaseFirestore();
        final data = _wellFormed()
          ..['memberDisplayNames'] = <String, dynamic>{
            _admin: 42,
            _member: 'Erik',
          };

        final group = ChatGroup.fromFirestore(await _read(firestore, data));

        expect(group.displayNameOf(_admin), '?');
        expect(group.displayNameOf(_member), 'Erik');
      },
    );

    test('a non-String avatar url becomes null rather than throwing', () async {
      final firestore = FakeFirebaseFirestore();
      final data = _wellFormed()
        ..['memberAvatarUrls'] = <String, dynamic>{
          _admin: 42,
          _member: 'https://cdn/erik.png',
        };

      final group = ChatGroup.fromFirestore(await _read(firestore, data));

      expect(group.avatarUrlOf(_admin), isNull);
      expect(group.avatarUrlOf(_member), 'https://cdn/erik.png');
    });

    test(
      'memberDisplayNames stored as a List degrades to an empty map',
      () async {
        final firestore = FakeFirebaseFirestore();
        final data = _wellFormed()
          ..['memberDisplayNames'] = <String>['Anna', 'Erik'];

        final group = ChatGroup.fromFirestore(await _read(firestore, data));

        expect(group.memberDisplayNames, isEmpty);
        expect(group.displayNameOf(_admin), '?');
        expect(group.memberIds, [_admin, _member]); // positive control
      },
    );

    test(
      'missing timestamps fall back to the clock, not to a throw',
      () async {
        // Pinned through package:clock rather than the real wall clock, so the
        // expectation is exact instead of "roughly now". (Spelled without the
        // literal call: real-time-guard matches it inside comments too.)
        final firestore = FakeFirebaseFirestore();
        final frozen = DateTime.utc(2026, 6, 1, 12);
        final data = _wellFormed()
          ..remove('createdAt')
          ..remove('updatedAt');
        final doc = await _read(firestore, data);

        final group = withClock(
          Clock.fixed(frozen),
          () => ChatGroup.fromFirestore(doc),
        );

        expect(group.createdAt.toUtc(), frozen);
        expect(group.updatedAt.toUtc(), frozen);
      },
    );

    test(
      'a snapshot with no data at all yields a group that admits nobody',
      () async {
        // `doc.data() ?? const {}` — reachable from any caller that skips the
        // exists check. It must not throw, and it must not make anyone admin.
        final firestore = FakeFirebaseFirestore();
        final missing = await firestore
            .collection('chat_groups')
            .doc('never-written')
            .get();
        expect(missing.exists, isFalse, reason: 'premise: the doc is absent');

        final group = ChatGroup.fromFirestore(missing);

        expect(group.id, 'never-written');
        expect(group.name, '');
        expect(group.memberIds, isEmpty);
        expect(group.adminIds, isEmpty);
        expect(group.isAdmin(_admin), isFalse);
        expect(group.isMember(_admin), isFalse);
      },
    );
  });

  group('identity', () {
    test('equality and hashCode are decided by id alone', () async {
      // An equal PAIR on its own would pass even if `==` regressed to
      // `=> true`, so a deliberately-unequal instance is asserted too.
      final firestore = FakeFirebaseFirestore();
      final a = ChatGroup.fromFirestore(await _read(firestore, _wellFormed()));
      final sameIdDifferentBody = ChatGroup.fromFirestore(
        await _read(firestore, _wellFormed()..['name'] = 'Omdöpt'),
      );
      final otherId = ChatGroup.fromFirestore(
        await _read(firestore, _wellFormed(), id: 'chat-group-2'),
      );

      expect(a, equals(sameIdDifferentBody));
      expect(a.hashCode, equals(sameIdDifferentBody.hashCode));
      expect(a.name, isNot(equals(sameIdDifferentBody.name)));
      expect(a, isNot(equals(otherId)));
    });
  });
}
