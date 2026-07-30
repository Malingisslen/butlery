import 'package:butlery/repositories/interfaces/repository.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';

/// Repository interface for shopping list operations.
abstract class ShoppingRepository extends Repository<UnifiedShoppingList> {
  /// Stream of collaborative lists for real-time updates from Firestore
  Stream<List<UnifiedShoppingList>> collaborativeListsStream();

  /// Adds a new item to the specified shopping list.
  Future<void> addItem(String listId, UnifiedShoppingItem item);

  /// Adds multiple items to the specified shopping list using batch operations.
  Future<void> addItemsBatch(String listId, List<UnifiedShoppingItem> items);

  /// Removes an item from the specified shopping list.
  Future<void> removeItem(String listId, String itemId);

  /// Updates an existing item in the specified shopping list atomically.
  Future<void> updateItem(String listId, UnifiedShoppingItem item);

  /// BUT-1697: updates several existing items in ONE write. On a
  /// collaborative list that is a single transaction, not one per item —
  /// N transactions against the same document contend and roll each other
  /// back ("avmarkera alla" on a full list). Items not present on the list
  /// are ignored rather than resurrected.
  Future<void> updateItemsBatch(String listId, List<UnifiedShoppingItem> items);

  /// Removes multiple items from the specified shopping list using batch operations.
  Future<void> removeItemsBatch(String listId, List<String> itemIds);

  /// BUT-1665: applies [mutate] to a collaborative list inside a Firestore
  /// transaction that re-reads the live document, so a concurrent household
  /// member's edit is merged instead of overwritten. Returns the merged list.
  Future<UnifiedShoppingList> mutateCollaborativeList(
    String listId,
    UnifiedShoppingList Function(UnifiedShoppingList live) mutate,
  );

  /// BUT-1726: the ONE way to change who may see or edit a collaborative list —
  /// add a member, remove one, change a permission, leave the list.
  ///
  /// Separate from [update] on purpose. `update` takes a whole entity and can
  /// only guess whether the `memberPermissions` map it carries is a deliberate
  /// change or a stale copy riding along on a rename; guessing wrong either
  /// reinstates a member the owner removed elsewhere or drops one they added.
  /// So `update` never writes access control at all, and a caller that means to
  /// says so here by handing over [base] — the exact copy of the list it
  /// computed [updated] from.
  ///
  /// [base] is compared against the server's current copy. A disagreement means
  /// the answer being replayed was computed about state that no longer exists,
  /// and the write is refused with a [StaleAccessControlBaseException] rather
  /// than applied. This is NOT a merge point: the caller must re-read and let
  /// the user decide again against what the list actually says now.
  ///
  /// Only [ListType.collaborative] lists have members; a personal list throws.
  ///
  /// Why membership is a NAMED method rather than an optional argument on the
  /// ordinary update — and why the first, smaller shape shipped green while
  /// writing nothing — is recorded in
  /// `docs/architecture/ADR-002-collaborative-list-membership-guard.md`
  /// (BUT-1726/BUT-1752). Read it before widening this signature.
  Future<UnifiedShoppingList> updateCollaborativeListMembership(
    UnifiedShoppingList updated,
    UnifiedShoppingList base,
  );

  /// BUT-1723: how many items the SERVER holds for [listId], or null when that
  /// could not be confirmed (cached read, missing list, failed read). Callers
  /// deleting an original after copying it MUST treat null as "keep it".
  Future<int?> confirmPersistedItemCount(String listId);

  // Template operations
  Future<String> saveAsTemplate({
    required String listId,
    required String templateName,
    String? description,
    List<String>? tags,
    bool isPublic = false,
  });

  Future<void> updateTemplate({
    required String templateId,
    String? name,
    String? description,
    List<String>? tags,
    bool? isPublic,
  });

  Future<void> deleteTemplate(String templateId);

  Future<List<Map<String, dynamic>>> getUserTemplates();

  Future<List<Map<String, dynamic>>> getPublicTemplates({
    int limit = 20,
    String? searchQuery,
    List<String>? tags,
  });

  Future<String> createListFromTemplate({
    required String templateId,
    required String listName,
    String? description,
  });
}
