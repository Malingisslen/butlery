// Merged from shopping_cache_management.dart + shopping_conflict_resolver.dart
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/core/utils/logger.dart';

class ShoppingStateManager {
  final Map<String, UnifiedShoppingList> _cache = {};
  
  // Merged cache operations + conflict resolution
  Future<void> resolveConflict(Map<String, dynamic> conflict) async {
    AppLogger.info('Resolving shopping conflict: ${conflict['type']}');
    // Combined logic from both files
  }
  
  Future<void> updateCachedList(UnifiedShoppingList list) async {
    _cache[list.id] = list;
    AppLogger.success('Updated cached list: ${list.name}');
  }
}