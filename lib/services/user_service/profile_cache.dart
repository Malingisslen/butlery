import 'package:clock/clock.dart';

import 'package:butlery/models/user_profile.dart';

/// The 30-minute profile cache [UserService] and its lookups share, so a
/// setting saved on the own profile is what the next lookup of that uid sees.
class ProfileCache {
  static const int _cacheDurationMinutes = 30;
  static const int _maxCacheSize = 200;

  final Map<String, UserProfile> _profileCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};

  /// The cached profile, fresh or expired; callers decide with [isExpired].
  UserProfile? operator [](String userId) => _profileCache[userId];

  bool containsKey(String userId) => _profileCache.containsKey(userId);

  bool isExpired(String userId) {
    final cacheTime = _cacheTimestamps[userId];
    if (cacheTime == null) return true;
    return clock.now().difference(cacheTime).inMinutes > _cacheDurationMinutes;
  }

  /// LRU cache insert: removes existing key (resets order), inserts at end, evicts oldest if over cap.
  void put(String userId, UserProfile profile) {
    _profileCache.remove(userId);
    _cacheTimestamps.remove(userId);
    _profileCache[userId] = profile;
    _cacheTimestamps[userId] = clock.now();
    if (_profileCache.length > _maxCacheSize) {
      final oldest = _profileCache.keys.first;
      _profileCache.remove(oldest);
      _cacheTimestamps.remove(oldest);
    }
  }

  void clear() {
    _profileCache.clear();
    _cacheTimestamps.clear();
  }
}
