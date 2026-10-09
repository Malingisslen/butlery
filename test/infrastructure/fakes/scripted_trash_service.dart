import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/trash_item.dart';
import 'package:butlery/services/trash/trash_service.dart';

/// A [TrashService] whose list is pushed by the test and whose changes answer
/// with a scripted [TrashOutcome], recording what they were asked to do.
class ScriptedTrashService extends Fake implements TrashService {
  final StreamController<List<TrashItem>> list =
      StreamController<List<TrashItem>>.broadcast();

  /// What the next change answers; null means everything asked is done.
  TrashOutcome? next;

  final List<List<String>> restored = [];
  final List<List<String>> deleted = [];
  int emptied = 0;
  int watched = 0;

  @override
  Stream<List<TrashItem>> watchTrash() {
    watched++;
    return list.stream;
  }

  @override
  Future<TrashOutcome> restore(List<TrashItem> items) async {
    final ids = [for (final i in items) i.id];
    restored.add(ids);
    return next ?? TrashOutcome(doneIds: ids);
  }

  @override
  Future<TrashOutcome> deleteForever(List<String> ids) async {
    deleted.add(ids);
    return next ?? TrashOutcome(doneIds: ids);
  }

  @override
  Future<TrashOutcome> emptyTrash() async {
    emptied++;
    return next ?? const TrashOutcome();
  }
}

TrashItem trashItemFor(
  String id, {
  String? title,
  DateTime? now,
  Duration age = Duration.zero,
  String? thumbnailUrl,
}) {
  final deletedAt = (now ?? DateTime.utc(2026, 10, 9)).subtract(age);
  return TrashItem(
    id: id,
    kind: TrashItemKind.recipe,
    ownerId: 'u1',
    sourceId: id,
    title: title ?? 'Recept $id',
    thumbnailUrl: thumbnailUrl,
    payload: const {},
    deletedAt: deletedAt,
    expireAt: deletedAt.add(TrashItem.keptFor),
  );
}
