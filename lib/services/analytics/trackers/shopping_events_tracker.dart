import 'package:butlery/services/analytics/trackers/base_tracker.dart';

/// Tracks shopping list-related analytics events
class ShoppingEventsTracker extends BaseTracker {
  ShoppingEventsTracker({required super.repository});

  /// Log shopping list created
  Future<void> logShoppingListCreated({
    required String listId,
    required String listType,
    int? initialItemCount,
  }) async {
    if (!await hasAnalyticsConsent()) return;
    await logEvent(
      name: 'shopping_list_created',
      parameters: {
        'list_id': listId,
        'list_type': listType,
        if (initialItemCount != null) 'initial_item_count': initialItemCount,
      },
    );
  }

  /// Log shopping list item added
  Future<void> logShoppingListItemAdded({
    required String listId,
    String? source,
  }) async {
    if (!await hasAnalyticsConsent()) return;
    await logEvent(
      name: 'shopping_list_item_added',
      parameters: {'list_id': listId, if (source != null) 'source': source},
    );
  }

  /// Log shopping list item checked
  Future<void> logShoppingListItemChecked({
    required String listId,
    required int itemCount,
  }) async {
    if (!await hasAnalyticsConsent()) return;
    await logEvent(
      name: 'shopping_list_item_checked',
      parameters: {'list_id': listId, 'item_count': itemCount},
    );
  }

  /// Log shopping list shared
  Future<void> logShoppingListShared({
    required String listId,
    required int recipientCount,
    String? shareMethod,
  }) async {
    if (!await hasAnalyticsConsent()) return;
    await logEvent(
      name: 'shopping_list_shared',
      parameters: {
        'list_id': listId,
        'recipient_count': recipientCount,
        if (shareMethod != null) 'share_method': shareMethod,
      },
    );
  }

  /// Log shopping list completed
  Future<void> logShoppingListCompleted({
    required String listId,
    required int itemCount,
    int? timeToCompleteMinutes,
  }) async {
    if (!await hasAnalyticsConsent()) return;
    await logEvent(
      name: 'shopping_list_completed',
      parameters: {
        'list_id': listId,
        'item_count': itemCount,
        if (timeToCompleteMinutes != null)
          'time_to_complete_minutes': timeToCompleteMinutes,
      },
    );
  }
}
