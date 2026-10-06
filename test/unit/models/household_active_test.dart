// BUT-2267: a member who joins a group's household belongs to two households,
// and every reader must agree on which one the menu and settings use.
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/household.dart';

const _me = 'me';
const _owner = 'owner';

HouseholdMember _m(String uid) => HouseholdMember(
  userId: uid,
  permission: SharedListPermission.admin,
  addedAt: DateTime.utc(2026, 1, 1),
);

Household _hh(
  String id, {
  String createdBy = _me,
  List<String> members = const [_me],
  DateTime? createdAt,
  String? sourceGroupId,
  String? sourceGroupOwnerId,
}) => Household(
  id: id,
  name: Household.defaultName,
  members: [for (final uid in members) _m(uid)],
  createdBy: createdBy,
  createdAt: createdAt ?? DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
  sourceGroupId: sourceGroupId,
  sourceGroupOwnerId: sourceGroupOwnerId,
);

void main() {
  group('isLinkedToGroup', () {
    test('a link written by the group owner counts', () {
      final hh = _hh('a', sourceGroupId: 'g', sourceGroupOwnerId: _me);
      expect(hh.isLinkedToGroup, isTrue);
    });

    test('a link naming someone else\'s group does not count', () {
      // The forged-link case: a household its creator pointed at a stranger's
      // group must not outrank the household that group really belongs to.
      final hh = _hh('a', sourceGroupId: 'g', sourceGroupOwnerId: _owner);
      expect(hh.isLinkedToGroup, isFalse);
    });

    test('no group id, no link', () {
      expect(_hh('a', sourceGroupOwnerId: _me).isLinkedToGroup, isFalse);
    });
  });

  group('pickActive', () {
    test('nothing to pick from', () {
      expect(Household.pickActive(const [], _me), isNull);
    });

    test('a household the user is not a member of is never picked', () {
      final hh = _hh('a', members: const [_owner], createdBy: _owner);
      expect(Household.pickActive([hh], _me), isNull);
    });

    test('a joined group household outranks the user\'s own solo one', () {
      final solo = _hh('a-solo', createdAt: DateTime.utc(2025));
      final joined = _hh(
        'z-joined',
        createdBy: _owner,
        members: const [_owner, _me],
        createdAt: DateTime.utc(2027),
        sourceGroupId: 'g',
        sourceGroupOwnerId: _owner,
      );
      expect(Household.pickActive([solo, joined], _me)!.id, 'z-joined');
      expect(Household.pickActive([joined, solo], _me)!.id, 'z-joined');
    });

    test('the household of the user\'s own group outranks one they joined', () {
      final joined = _hh(
        'a-joined',
        createdBy: _owner,
        members: const [_owner, _me],
        createdAt: DateTime.utc(2025),
        sourceGroupId: 'g1',
        sourceGroupOwnerId: _owner,
      );
      final own = _hh(
        'z-own',
        members: const [_me, 'friend'],
        createdAt: DateTime.utc(2027),
        sourceGroupId: 'g2',
        sourceGroupOwnerId: _me,
      );
      expect(Household.pickActive([joined, own], _me)!.id, 'z-own');
    });

    test('a forged link ranks as unlinked', () {
      final forged = _hh(
        'a-forged',
        createdAt: DateTime.utc(2025),
        sourceGroupId: 'g',
        sourceGroupOwnerId: _owner,
      );
      final joined = _hh(
        'z-joined',
        createdBy: _owner,
        members: const [_owner, _me],
        createdAt: DateTime.utc(2027),
        sourceGroupId: 'g',
        sourceGroupOwnerId: _owner,
      );
      expect(Household.pickActive([forged, joined], _me)!.id, 'z-joined');
    });

    test('within a rank the oldest wins, then the lowest id', () {
      final older = _hh('z', createdAt: DateTime.utc(2025));
      final newer = _hh('a', createdAt: DateTime.utc(2026));
      expect(Household.pickActive([newer, older], _me)!.id, 'z');

      final b = _hh('b');
      final a = _hh('a');
      expect(Household.pickActive([b, a], _me)!.id, 'a');
      expect(Household.pickActive([a, b], _me)!.id, 'a');
    });
  });

  group('the link survives serialisation', () {
    final linked = _hh('a', sourceGroupId: 'g', sourceGroupOwnerId: _me);

    test('through Firestore', () {
      final back = Household.fromMap('a', linked.toFirestore());
      expect(back.sourceGroupId, 'g');
      expect(back.sourceGroupOwnerId, _me);
      expect(back.isLinkedToGroup, isTrue);
    });

    test('through JSON', () {
      final back = Household.fromJson(linked.toJson());
      expect(back.sourceGroupId, 'g');
      expect(back.sourceGroupOwnerId, _me);
    });

    test('through copyWith', () {
      final back = linked.copyWith(name: 'Nytt namn');
      expect(back.sourceGroupId, 'g');
      expect(back.sourceGroupOwnerId, _me);
    });

    test('an unlinked household writes no link keys', () {
      final map = _hh('a').toFirestore();
      expect(map.containsKey('sourceGroupId'), isFalse);
      expect(map.containsKey('sourceGroupOwnerId'), isFalse);
    });
  });
}
