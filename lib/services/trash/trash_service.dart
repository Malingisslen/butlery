/// BUT-907: the user's trash — what they deleted, kept 30 days.
///
/// Lists the trash, restores from it, and deletes from it for good. Every
/// change needs the network: a restore must see the server's copy to know it
/// is still there, and a delete that waited offline would leave a row the
/// user believed gone. Offline, nothing is attempted and the outcome says so.
library;

import 'dart:async';

import 'package:clock/clock.dart';

import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/trash_item.dart';
import 'package:butlery/repositories/interfaces/trash_repository.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/trash/trash_restore.dart';

/// Why one item's restore or delete did not happen.
enum TrashFailure {
  /// The device is offline; nothing was attempted.
  offline,

  /// Its 30 days have passed.
  expired,

  /// It is no longer in the trash (restored or deleted elsewhere), or its
  /// recipe is already back.
  gone,

  /// Anything else; the item is untouched.
  failed,
}

/// What a trash change did, item by item.
class TrashOutcome {
  const TrashOutcome({
    this.doneIds = const [],
    this.failures = const {},
    this.notRun,
  });

  /// The change did not run at all, for [reason]; each of [ids] carries it.
  factory TrashOutcome.notRun(Iterable<String> ids, TrashFailure reason) =>
      TrashOutcome(
        failures: {for (final id in ids) id: reason},
        notRun: reason,
      );

  /// Ids of the items it was done for.
  final List<String> doneIds;

  /// Item id to why it was not done.
  final Map<String, TrashFailure> failures;

  /// Why the change as a whole did not run (offline, signed out, a failed
  /// write), or null when it ran.
  final TrashFailure? notRun;

  bool get isComplete => notRun == null && failures.isEmpty;

  bool get wasOffline => notRun == TrashFailure.offline;
}

class TrashService extends BaseService {
  TrashService({
    required TrashRepository repository,
    required TrashRestore restorer,
    bool Function()? isOnline,
    String? Function()? currentUserId,
  }) : _repository = repository,
       _restorer = restorer,
       _isOnline = isOnline ?? _offlineServiceSaysOnline,
       _currentUserId = currentUserId ?? _signedInUserId;

  final TrashRepository _repository;
  final TrashRestore _restorer;
  final bool Function() _isOnline;
  final String? Function() _currentUserId;

  @override
  String get serviceName => 'TrashService';

  /// The signed-in user, from the auth source (not the profile).
  static String? _signedInUserId() =>
      ServiceLocator.tryGet<PermissionService>()?.currentUserId;

  static bool _offlineServiceSaysOnline() =>
      ServiceLocator.tryGet<OfflineService>()?.isOnline ?? true;

  /// The signed-in user's trash, newest first, without anything past its 30
  /// days at the moment each list arrives. Errors (signed out, a failed
  /// read) arrive on the stream.
  Stream<List<TrashItem>> watchTrash() {
    try {
      return _repository.watchTrash().map(stillKept);
    } catch (e) {
      return Stream.error(e);
    }
  }

  /// [items] without those whose 30 days have passed at [clock.now].
  static List<TrashItem> stillKept(List<TrashItem> items) {
    final now = clock.now();
    return [
      for (final item in items)
        if (item.isKeptAt(now)) item,
    ];
  }

  /// Puts each of [items] back among the user's recipes.
  Future<TrashOutcome> restore(List<TrashItem> items) => _change(
    items.map((i) => i.id),
    'Restore from trash',
    (uid) async {
      final done = <String>[];
      final failures = <String, TrashFailure>{};
      final now = clock.now();
      for (final item in items) {
        if (!item.isKeptAt(now)) {
          failures[item.id] = TrashFailure.expired;
          continue;
        }
        try {
          await _restorer.restore(item, uid);
          done.add(item.id);
        } on TrashItemExpiredException {
          failures[item.id] = TrashFailure.expired;
        } on TrashItemGoneException {
          failures[item.id] = TrashFailure.gone;
        } catch (e) {
          // Errors too: one item must not drop the ids already restored.
          AppLogger.error('Restore of ${item.id} failed: $e');
          failures[item.id] = TrashFailure.failed;
        }
      }
      return TrashOutcome(doneIds: done, failures: failures);
    },
  );

  /// Deletes [ids] from the trash for good; their photos go with them
  /// (`onTrashItemDeleted`).
  Future<TrashOutcome> deleteForever(List<String> ids) =>
      _change(ids, 'Delete from trash', (_) async {
        await _repository.deleteForever(ids);
        return TrashOutcome(doneIds: List.of(ids));
      });

  /// Deletes everything in the trash for good. The outcome names no items;
  /// [TrashOutcome.isComplete] says whether it ran.
  Future<TrashOutcome> emptyTrash() => _change(const [], 'Empty trash', (
    _,
  ) async {
    await _repository.emptyTrash();
    return const TrashOutcome();
  });

  /// Runs [change] online and signed in, or reports why it did not run.
  Future<TrashOutcome> _change(
    Iterable<String> ids,
    String name,
    Future<TrashOutcome> Function(String uid) change,
  ) async {
    final failedAll = TrashOutcome.notRun(ids, TrashFailure.failed);
    if (!_isOnline()) return TrashOutcome.notRun(ids, TrashFailure.offline);
    final outcome = await executeServiceOperation(() async {
      final uid = _currentUserId();
      if (uid == null) return failedAll;
      return change(uid);
    }, operationName: name);
    return outcome ?? failedAll;
  }
}
