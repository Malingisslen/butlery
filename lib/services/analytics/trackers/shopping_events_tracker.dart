import 'package:butlery/services/analytics/analytics_events.dart';
import 'package:butlery/services/analytics/trackers/base_tracker.dart';

/// Tracks shopping list-related analytics events
class ShoppingEventsTracker extends BaseTracker {
  ShoppingEventsTracker({required super.repository});

  /// Log shopping list created.
  ///
  /// BUT-1681: [source] is how a generated list is told apart from a hand-made
  /// one (`manual` / `menu_generated`). `list_type` answers personal-vs-shared,
  /// which is a different question and was the only one this event could
  /// answer before.
  Future<void> logShoppingListCreated({
    required String listId,
    required String listType,
    int? initialItemCount,
    String? source,
  }) async {
    await logEvent(
      name: AnalyticsEvents.shoppingListCreated,
      parameters: {
        'list_id': listId,
        'list_type': listType,
        'initial_item_count': ?initialItemCount,
        'source': ?source,
      },
    );
  }

  /// Log shopping list item added.
  ///
  /// BUT-1681: bulk paths pass [itemCount] and fire this ONCE for the batch
  /// rather than once per line. A week's menu or a recipe's ingredient list is
  /// 12–40 rows, and per-row events multiply the cost of the funnel by the
  /// size of the shopping list without answering a question the count doesn't.
  Future<void> logShoppingListItemAdded({
    required String listId,
    String? source,
    int? itemCount,
  }) async {
    await logEvent(
      name: AnalyticsEvents.shoppingListItemAdded,
      parameters: {
        'list_id': listId,
        'source': ?source,
        'item_count': ?itemCount,
      },
    );
  }

  /// Log shopping list item checked
  Future<void> logShoppingListItemChecked({
    required String listId,
    required int itemCount,
  }) async {
    await logEvent(
      name: AnalyticsEvents.shoppingListItemChecked,
      parameters: {'list_id': listId, 'item_count': itemCount},
    );
  }

  /// Log shopping list shared
  Future<void> logShoppingListShared({
    required String listId,
    required int recipientCount,
    String? shareMethod,
  }) async {
    await logEvent(
      name: AnalyticsEvents.shoppingListShared,
      parameters: {
        'list_id': listId,
        'recipient_count': recipientCount,
        'share_method': ?shareMethod,
      },
    );
  }

  /// Log shopping list completed
  Future<void> logShoppingListCompleted({
    required String listId,
    required int itemCount,
    int? timeToCompleteMinutes,
  }) async {
    await logEvent(
      name: AnalyticsEvents.shoppingListCompleted,
      parameters: {
        'list_id': listId,
        'item_count': itemCount,
        'time_to_complete_minutes': ?timeToCompleteMinutes,
      },
    );
  }
}
