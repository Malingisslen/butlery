// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_queue_dao.dart';

// ignore_for_file: type=lint
mixin _$SyncQueueDaoMixin on DatabaseAccessor<AppDatabase> {
  $SyncQueueEntriesTable get syncQueueEntries =>
      attachedDatabase.syncQueueEntries;
  SyncQueueDaoManager get managers => SyncQueueDaoManager(this);
}

class SyncQueueDaoManager {
  final _$SyncQueueDaoMixin _db;
  SyncQueueDaoManager(this._db);
  $$SyncQueueEntriesTableTableManager get syncQueueEntries =>
      $$SyncQueueEntriesTableTableManager(
        _db.attachedDatabase,
        _db.syncQueueEntries,
      );
}
