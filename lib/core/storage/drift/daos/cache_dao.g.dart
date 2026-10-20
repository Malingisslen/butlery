// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cache_dao.dart';

// ignore_for_file: type=lint
mixin _$CacheDaoMixin on DatabaseAccessor<AppDatabase> {
  $JsonCacheEntriesTable get jsonCacheEntries =>
      attachedDatabase.jsonCacheEntries;
  $ParseCacheEntriesTable get parseCacheEntries =>
      attachedDatabase.parseCacheEntries;
  CacheDaoManager get managers => CacheDaoManager(this);
}

class CacheDaoManager {
  final _$CacheDaoMixin _db;
  CacheDaoManager(this._db);
  $$JsonCacheEntriesTableTableManager get jsonCacheEntries =>
      $$JsonCacheEntriesTableTableManager(
        _db.attachedDatabase,
        _db.jsonCacheEntries,
      );
  $$ParseCacheEntriesTableTableManager get parseCacheEntries =>
      $$ParseCacheEntriesTableTableManager(
        _db.attachedDatabase,
        _db.parseCacheEntries,
      );
}
