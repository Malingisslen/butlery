// Simplified friends caching
class FriendsCache {
  final Map<String, dynamic> _cache = {};
  void cache(String key, dynamic value) => _cache[key] = value;
  T? get<T>(String key) => _cache[key] as T?;
}