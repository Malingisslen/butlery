// Proves the 2026-10-27 empty-trash report (tasks/trash-data-loss-plan.md).
//
// Release builds are compiled with --obfuscate (build-validation.yml), which
// renames classes: a Firestore Timestamp's runtimeType.toString() is then not
// 'Timestamp'. SerializationUtils.parseDateTimeValue recognises a Timestamp
// only by that name, so every stored trash row parses to null and the list
// drops it. A JIT test cannot obfuscate, so a subclass with another name
// stands in for the renamed class: it IS a Timestamp, only its name differs.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/utils/serialization_utils.dart';
import 'package:butlery/models/trash_item.dart';

class _RenamedTimestamp extends Timestamp {
  _RenamedTimestamp(super.seconds, super.nanoseconds);
}

Map<String, dynamic> _row(Timestamp Function(DateTime) stamp) {
  final deletedAt = DateTime.utc(2026, 10, 26, 23, 30);
  return {
    'kind': 'recipe',
    'ownerId': 'uid-1',
    'sourceId': 'r1',
    'title': 'Kladdkaka',
    'thumbnailUrl': null,
    'payload': {'core': <String, dynamic>{}, 'type': 0},
    'deletedAt': stamp(deletedAt),
    'expireAt': stamp(deletedAt.add(TrashItem.keptFor)),
  };
}

Timestamp _renamed(DateTime d) {
  final t = Timestamp.fromDate(d);
  return _RenamedTimestamp(t.seconds, t.nanoseconds);
}

void main() {
  test('an unrenamed Timestamp parses (debug and test builds)', () {
    expect(TrashItem.fromFirestore('r1', _row(Timestamp.fromDate)), isNotNull);
  });

  test(
    'a Timestamp whose class name is not "Timestamp" is still a date',
    () {
      final t = _renamed(DateTime.utc(2026, 10, 26, 23, 30));
      expect(t, isA<Timestamp>());
      expect(SerializationUtils.parseDateTimeValue(t), isNotNull);
    },
  );

  test('a trash row read in a release build is offered', () {
    expect(TrashItem.fromFirestore('r1', _row(_renamed)), isNotNull);
  });
}
