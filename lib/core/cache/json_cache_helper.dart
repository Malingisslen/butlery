import 'dart:async';
import 'dart:convert';

import 'package:butlery/core/storage/drift/daos/cache_dao.dart';
import 'package:butlery/core/utils/logger.dart';

/// JSON cache helper that uses Drift database for storage
/// Replaces the previous Hive-based implementation
class JsonCacheHelper {
  final String boxBaseName;
  final CacheDao _cacheDao;

  String? _currentUserId;

  JsonCacheHelper(this.boxBaseName, this._cacheDao);

  void setCurrentUser(String? userId) {
    _currentUserId = userId;
  }

  String get _userId {
    if (_currentUserId == null) {
      throw StateError('User not set - call setCurrentUser() first');
    }
    return _currentUserId!;
  }

  Future<bool> saveJson(String key, Map<String, dynamic> data) async {
    try {
      final jsonString = jsonEncode(data);
      await _cacheDao.putJson(
        boxName: boxBaseName,
        userId: _userId,
        key: key,
        value: jsonString,
      );

      AppLogger.debug('Saved JSON to cache: $key in ${boxBaseName}_$_userId');
      return true;
    } catch (e) {
      AppLogger.error('Failed to save JSON cache item $key: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> loadJson(String key) async {
    try {
      final jsonString = await _cacheDao.getJson(boxBaseName, _userId, key);

      if (jsonString == null) {
        return null;
      }

      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      AppLogger.debug('Loaded JSON from cache: $key from ${boxBaseName}_$_userId');
      return data;
    } catch (e) {
      AppLogger.error('Failed to load JSON cache item $key: $e');
      return null;
    }
  }

  Future<bool> saveJsonList(String key, List<Map<String, dynamic>> dataList) async {
    try {
      final jsonString = jsonEncode(dataList);
      await _cacheDao.putJson(
        boxName: boxBaseName,
        userId: _userId,
        key: key,
        value: jsonString,
      );

      AppLogger.debug(
          'Saved JSON list to cache: $key (${dataList.length} items) in ${boxBaseName}_$_userId');
      return true;
    } catch (e) {
      AppLogger.error('Failed to save JSON list $key: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>?> loadJsonList(String key) async {
    try {
      final jsonString = await _cacheDao.getJson(boxBaseName, _userId, key);

      if (jsonString == null) {
        return null;
      }

      final dataList = jsonDecode(jsonString) as List;
      final result = dataList.cast<Map<String, dynamic>>();
      AppLogger.debug(
          'Loaded JSON list from cache: $key (${result.length} items) from ${boxBaseName}_$_userId');
      return result;
    } catch (e) {
      AppLogger.error('Failed to load JSON list $key: $e');
      return null;
    }
  }

  Future<bool> delete(String key) async {
    try {
      await _cacheDao.deleteJson(boxBaseName, _userId, key);

      AppLogger.debug('Deleted cache item: $key from ${boxBaseName}_$_userId');
      return true;
    } catch (e) {
      AppLogger.error('Failed to delete cache item $key: $e');
      return false;
    }
  }

  Future<bool> exists(String key) async {
    try {
      final value = await _cacheDao.getJson(boxBaseName, _userId, key);
      return value != null;
    } catch (e) {
      AppLogger.error('Failed to check cache existence $key: $e');
      return false;
    }
  }

  Future<List<String>> getAllKeys() async {
    try {
      return await _cacheDao.getJsonKeys(boxBaseName, _userId);
    } catch (e) {
      AppLogger.error('Failed to get cache keys: $e');
      return [];
    }
  }

  Future<bool> clear() async {
    try {
      await _cacheDao.clearJsonBox(boxBaseName, _userId);

      AppLogger.info('Cleared all cache data from ${boxBaseName}_$_userId');
      return true;
    } catch (e) {
      AppLogger.error('Failed to clear cache: $e');
      return false;
    }
  }

  Future<JsonCacheStats> getStats() async {
    try {
      final keyCount = await _cacheDao.countJsonEntries(boxBaseName, _userId);

      return JsonCacheStats(
        boxName: '${boxBaseName}_$_userId',
        keyCount: keyCount,
        userId: _currentUserId,
      );
    } catch (e) {
      AppLogger.error('Failed to get cache stats: $e');
      return JsonCacheStats(
        boxName: '${boxBaseName}_$_userId',
        keyCount: 0,
        userId: _currentUserId,
      );
    }
  }

  Future<int> saveJsonBatch(Map<String, Map<String, dynamic>> items) async {
    int successCount = 0;

    try {
      final jsonBatch = <String, String>{};
      for (final entry in items.entries) {
        try {
          jsonBatch[entry.key] = jsonEncode(entry.value);
        } catch (e) {
          AppLogger.warning('Failed to encode item ${entry.key}: $e');
        }
      }

      await _cacheDao.putJsonBatch(
        boxName: boxBaseName,
        userId: _userId,
        entries: jsonBatch,
      );
      successCount = jsonBatch.length;

      AppLogger.info('Batch saved $successCount JSON items to ${boxBaseName}_$_userId');
    } catch (e) {
      AppLogger.error('Failed to batch save JSON items: $e');
    }

    return successCount;
  }

  Future<Map<String, Map<String, dynamic>>> loadJsonBatch(List<String> keys) async {
    final result = <String, Map<String, dynamic>>{};

    try {
      for (final key in keys) {
        try {
          final jsonString = await _cacheDao.getJson(boxBaseName, _userId, key);
          if (jsonString != null) {
            final data = jsonDecode(jsonString) as Map<String, dynamic>;
            result[key] = data;
          }
        } catch (e) {
          AppLogger.warning('Failed to decode item $key: $e');
        }
      }

      AppLogger.debug(
          'Batch loaded ${result.length}/${keys.length} JSON items from ${boxBaseName}_$_userId');
    } catch (e) {
      AppLogger.error('Failed to batch load JSON items: $e');
    }

    return result;
  }

  Future<bool> saveActiveId(String activeKey, String? itemId) async {
    try {
      if (itemId != null) {
        await _cacheDao.putJson(
          boxName: boxBaseName,
          userId: _userId,
          key: activeKey,
          value: itemId,
        );
        AppLogger.debug('Saved active ID: $activeKey = $itemId');
      } else {
        await _cacheDao.deleteJson(boxBaseName, _userId, activeKey);
        AppLogger.debug('Cleared active ID: $activeKey');
      }

      return true;
    } catch (e) {
      AppLogger.error('Failed to save active ID $activeKey: $e');
      return false;
    }
  }

  Future<String?> loadActiveId(String activeKey) async {
    try {
      final activeId = await _cacheDao.getJson(boxBaseName, _userId, activeKey);

      if (activeId != null) {
        AppLogger.debug('Loaded active ID: $activeKey = $activeId');
      }

      return activeId;
    } catch (e) {
      AppLogger.error('Failed to load active ID $activeKey: $e');
      return null;
    }
  }

  /// No-op: Drift manages its own connections
  Future<void> dispose() async {
    AppLogger.debug('Disposed JSON cache helper: $boxBaseName');
  }
}

class JsonCacheStats {
  final String boxName;
  final int keyCount;
  final String? userId;

  JsonCacheStats({
    required this.boxName,
    required this.keyCount,
    required this.userId,
  });

  @override
  String toString() {
    return 'JsonCacheStats($boxName: $keyCount items, user: $userId)';
  }
}

/// Factory for creating JSON cache helpers
/// Requires a CacheDao instance from the Drift database
class JsonCacheFactory {
  final CacheDao _cacheDao;

  JsonCacheFactory(this._cacheDao);

  JsonCacheHelper recipeCache() {
    return JsonCacheHelper('unified_recipes_cache', _cacheDao);
  }

  JsonCacheHelper shoppingCache() {
    return JsonCacheHelper('unified_shopping_lists_cache', _cacheDao);
  }

  JsonCacheHelper friendsCache() {
    return JsonCacheHelper('unified_friends_cache', _cacheDao);
  }

  JsonCacheHelper custom(String baseName) {
    return JsonCacheHelper(baseName, _cacheDao);
  }
}
