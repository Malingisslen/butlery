// lib/repositories/firebase/modules/shopping_repository_query_module.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';
import 'package:butlery/core/constants/firestore_collections.dart';

/// Module handling query operations for shopping lists.
/// Provides read operations and real-time streams for both personal and collaborative lists.
class ShoppingRepositoryQueryModule {
  final FirebaseFirestore firestore;
  final CollectionReference<Map<String, dynamic>> sharedListsRef;
  final String Function() requireCurrentUserId;
  final CollectionReference<Map<String, dynamic>> Function(String userId)
  getUserCollection;
  final UnifiedShoppingList Function(DocumentSnapshot<Map<String, dynamic>> doc)
  fromFirestore;
  final Future<UnifiedShoppingList?> Function(String id) readList;

  ShoppingRepositoryQueryModule({
    required this.firestore,
    required this.sharedListsRef,
    required this.requireCurrentUserId,
    required this.getUserCollection,
    required this.fromFirestore,
    required this.readList,
  });

  /// Read all shopping lists (personal + collaborative) with items loaded from subcollections
  Future<List<UnifiedShoppingList>> readAll() async {
    try {
      final uid = requireCurrentUserId();
      AppLogger.info('Loading shopping lists for user: ${uid.maskedUserId}');

      // Get personal lists using user collection
      final personalRef = getUserCollection(uid);
      final personalSnapshot = await personalRef.get();
      final personalLists = <UnifiedShoppingList>[];

      // Load each list with its items from subcollection
      for (final listDoc in personalSnapshot.docs) {
        final list = fromFirestore(listDoc);

        // Load items for this list from subcollection
        final itemsSnapshot = await getUserCollection(
          uid,
        ).doc(list.id).collection(FirestoreCollections.items).get();

        final items = itemsSnapshot.docs
            .map((doc) => UnifiedShoppingItem.fromFirestore(doc.data()))
            .toList();

        // Create list with loaded items
        final listWithItems = list.copyWith(items: items);
        personalLists.add(listWithItems);

        AppLogger.info(
          'Loaded list "${list.name}" with ${items.length} items',
          'ShoppingRepository',
        );
      }

      // Get shared/collaborative lists where user is a member
      final sharedSnapshot = await sharedListsRef
          .where('memberPermissions.$uid', isNotEqualTo: null)
          .limit(20) // Most users won't have more than 20 shared lists
          .get();

      final sharedLists = <UnifiedShoppingList>[];
      for (final doc in sharedSnapshot.docs) {
        try {
          final list = UnifiedShoppingList.fromFirestore(doc);

          // Safety check: Skip lists with invalid data
          if (list.name.isEmpty) {
            AppLogger.warning(
              'Skipping collaborative list with empty name: ${doc.id}',
            );
            continue;
          }

          AppLogger.info(
            'Loaded collaborative list "${list.name}" with ${list.items.length} items (origin: ${list.collaborativeOrigin ?? "direct"})',
            'ShoppingRepository',
          );

          // Debug log each item to verify they're loading correctly
          for (int i = 0; i < list.items.length && i < 3; i++) {
            final item = list.items[i];
            AppLogger.info(
              '  Item ${i + 1}: "${item.name}" (bought: ${item.bought})',
              'ShoppingRepository',
            );
          }
          if (list.items.length > 3) {
            AppLogger.info(
              '  ... and ${list.items.length - 3} more items',
              'ShoppingRepository',
            );
          }

          sharedLists.add(list);
        } catch (e) {
          AppLogger.error('Failed to load collaborative list ${doc.id}: $e');
          // Continue loading other lists
        }
      }

      // Combine and sort by updatedAt (most recent first)
      final allLists = [...personalLists, ...sharedLists];
      allLists.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      AppLogger.success(
        'Successfully loaded ${allLists.length} shopping lists (${personalLists.length} personal, ${sharedLists.length} collaborative)',
      );
      return allLists;
    } catch (e) {
      AppLogger.error('Failed to load shopping lists: $e');
      // Fallback to empty list to prevent app crashes
      return [];
    }
  }

  /// BUT-1723: how many items the SERVER actually holds for [listId], or null
  /// when that could not be established.
  ///
  /// Null means "not confirmed" — a cached read or a failed read. Firestore
  /// serves a local write straight back out of its cache while offline, so a
  /// plain `get()` would report a conversion copy as complete before a byte
  /// left the device, which is how the source list got deleted with the copy
  /// still empty.
  ///
  /// A list that exists nowhere counts as 0, not null: the caller compares
  /// against how many items it expected, so a vanished copy of a non-empty
  /// list already fails the comparison. Only a copy that was expected to be
  /// empty passes, and there is nothing there to lose.
  ///
  /// Both storage shapes are covered: a collaborative list keeps its items
  /// inline on the document, a personal list keeps them in the `items`
  /// subcollection. The shared probe runs first and is allowed to FAIL — under
  /// the live rules a `get` on a shared-list id that does not exist is denied
  /// rather than answered, which is what every personal list id looks like.
  /// Only the personal leg may conclude "unconfirmed".
  Future<int?> confirmPersistedItemCount(String listId) async {
    try {
      final shared = await sharedListsRef.doc(listId).get();
      if (shared.metadata.isFromCache) return null;
      if (shared.exists) {
        final items = shared.data()?['items'];
        return items is List ? items.length : 0;
      }
    } catch (e) {
      // NOT a failure to report — the normal answer for a personal list id.
      // The shared-list read rule dereferences `resource.data.ownerId`, and
      // `resource` is null for a document that does not exist, so the
      // expression errors and the client gets `permission-denied` instead of
      // an `exists == false` snapshot. Returning null here would make the
      // personal leg below unreachable in production and would block every
      // convert-to-personal. Fall through, exactly as
      // `FirebaseShoppingRepository.read()` already does for the same probe.
      AppLogger.warning(
        'Shared-list probe for $listId did not resolve ($e); '
        'trying the personal collection',
      );
    }

    try {
      final uid = requireCurrentUserId();
      final snapshot = await getUserCollection(
        uid,
      ).doc(listId).collection(FirestoreCollections.items).get();
      if (snapshot.metadata.isFromCache) return null;
      return snapshot.docs.length;
    } catch (e) {
      AppLogger.warning(
        'Could not confirm persisted items for personal list $listId: $e',
      );
      return null;
    }
  }

  /// Get currently active list
  Future<UnifiedShoppingList?> getActiveList(String? activeListId) async {
    if (activeListId == null) return null;
    return readList(activeListId);
  }

  /// Stream of user's personal lists
  Stream<List<UnifiedShoppingList>> personalListsStream() {
    try {
      final uid = requireCurrentUserId();
      return getUserCollection(uid)
          .orderBy('updatedAt', descending: true)
          .limit(20) // Limit personal lists to 20 most recent
          .snapshots()
          .map((snap) => snap.docs.map(fromFirestore).toList());
    } catch (e) {
      return const Stream.empty();
    }
  }

  /// Stream of collaborative lists where user is a member
  Stream<List<UnifiedShoppingList>> collaborativeListsStream() {
    try {
      final uid = requireCurrentUserId();
      // Firestore forbids combining an inequality filter (memberPermissions.$uid
      // isNotEqualTo null) with an orderBy on a *different* field — it throws and
      // the stream silently emits nothing. The membership key is also per-user
      // dynamic, so it can't be the first orderBy. Filter server-side, then sort
      // by updatedAt client-side (mirrors readAll()). A small limit(20) without
      // the orderBy would truncate arbitrary docs, so we sort+take(20) for
      // display — but still cap server-side reads at 200 (in Firestore's natural
      // doc order) so the listener can never stream an unbounded set. No real
      // household approaches 200 collaborative lists.
      return sharedListsRef
          .where('memberPermissions.$uid', isNotEqualTo: null)
          .limit(200)
          .snapshots()
          .map((snap) {
            final lists = snap.docs
                .map(UnifiedShoppingList.fromFirestore)
                .toList();
            lists.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
            return lists.take(20).toList();
          });
    } catch (e) {
      return const Stream.empty();
    }
  }
}
