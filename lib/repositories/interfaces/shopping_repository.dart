import 'package:butlery/repositories/interfaces/repository.dart';
import 'package:butlery/models/unified/shopping_row_snapshot.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';

/// What a membership write is FOR, which decides which guard it is held to.
///
/// BUT-1718: an add, a removal by the owner and a permission change are all
/// somebody acting on the roster and are refused to anyone but the owner. A
/// self-removal is a member withdrawing their own access, which the same guards
/// refuse outright — including for a view-only member, who cannot write
/// anything else at all. The two cases are structurally identical edits to one
/// map, so the write has to say which it is; the server draws the same line in
/// `firestore.rules`.
enum MembershipWriteIntent {
  /// Add, remove somebody else, or change a permission level.
  ordinary,

  /// The caller removing their own key, and nothing else.
  selfRemoval,
}

/// BUT-2140: what the week menu's merge asks to write into a personal list.
///
/// [rows] is a function rather than a list because "Ersätt listan" carries a
/// bought tick over from the recipe rows it takes off (produktregler.md § 8.7),
/// and which rows those are is only known once the server's copy is read. It
/// is called with no rows for a plain add. It must return the same row ids on
/// every call: the write may be computed twice, once against the server and
/// once against the copy in memory when the device turns out to be offline.
class PersonalMergeRequest {
  const PersonalMergeRequest({
    required this.rows,
    required this.replace,
    this.generatedForWeek,
  });

  final List<UnifiedShoppingItem> Function(List<UnifiedShoppingItem> removed)
  rows;

  /// Takes off the rows the list's `menuItemIds` names before adding.
  final bool replace;
  final String? generatedForWeek;
}

/// BUT-2140: what a personal-list merge wrote, as the server holds it.
class PersonalMergeResult {
  const PersonalMergeResult({
    required this.list,
    required this.added,
    required this.removed,
    required this.concurrentChange,
  });

  /// The list after the merge, built on the server's rows when they could be
  /// read, so rows another device added show up here too.
  final UnifiedShoppingList list;
  final List<UnifiedShoppingItem> added;

  /// The recipe rows a replace took off, as the server held them. A row
  /// another device deleted first is not here, so Ångra cannot bring it back.
  final List<UnifiedShoppingItem> removed;

  /// The server's list differed from the copy in memory: another device had
  /// changed it. False whenever the server could not be read, and while this
  /// device still has writes of its own waiting to sync, which would otherwise
  /// read as somebody else's change.
  final bool concurrentChange;
}

/// Repository interface for shopping list operations.
abstract class ShoppingRepository extends Repository<UnifiedShoppingList> {
  /// Stream of collaborative lists for real-time updates from Firestore
  Stream<List<UnifiedShoppingList>> collaborativeListsStream();

  /// Adds a new item to the specified shopping list.
  Future<void> addItem(String listId, UnifiedShoppingItem item);

  /// Adds multiple items to the specified shopping list using batch operations.
  Future<void> addItemsBatch(String listId, List<UnifiedShoppingItem> items);

  /// Removes an item from the specified shopping list.
  ///
  /// BUT-2140: [removed] is the caller's copy of the row, which a personal
  /// list records in `recentlyRemoved` for the 30-day restore. Without it the
  /// removal keeps no history there. A shared list records the live row and
  /// ignores it.
  Future<void> removeItem(
    String listId,
    String itemId, {
    UnifiedShoppingItem? removed,
  });

  /// Updates an existing item in the specified shopping list atomically.
  ///
  /// BUT-2140: [before] is the caller's copy of the row before the edit. On a
  /// personal list a content edit against it keeps [before]'s content as the
  /// row's `previous`; without it `previous` is left as stored. A shared list
  /// takes `previous` from the live row and ignores it.
  Future<void> updateItem(
    String listId,
    UnifiedShoppingItem item, {
    UnifiedShoppingItem? before,
  });

  /// BUT-1697: updates several existing items in ONE write. On a
  /// collaborative list that is a single transaction, not one per item —
  /// N transactions against the same document contend and roll each other
  /// back ("avmarkera alla" on a full list). Items not present on the list
  /// are ignored rather than resurrected.
  Future<void> updateItemsBatch(String listId, List<UnifiedShoppingItem> items);

  /// Removes multiple items from the specified shopping list using batch operations.
  /// [removed] works as on [removeItem].
  Future<void> removeItemsBatch(
    String listId,
    List<String> itemIds, {
    List<UnifiedShoppingItem> removed = const [],
  });

  /// BUT-2140: puts the removed row [entry] back with its old id and takes it
  /// out of `recentlyRemoved` in the same write, stamping the caller as
  /// `addedBy`. A row already holding that id is not duplicated. Returns the
  /// row as written, or null when nothing was put back. On a shared list this
  /// needs edit rights, as any row write does.
  Future<UnifiedShoppingItem?> restoreRemovedRow(
    String listId,
    ShoppingRowSnapshot entry,
  );

  /// BUT-2140: swaps row [itemId]'s content with its `previous`, so the
  /// version it replaces becomes the new `previous`. Returns the row as
  /// written, or null when it has nothing restorable.
  Future<UnifiedShoppingItem?> restoreChangedRow(String listId, String itemId);

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
  /// For an [MembershipWriteIntent.ordinary] write, [base] is compared against
  /// the server's current copy. A disagreement means the answer being replayed
  /// was computed about state that no longer exists, and the write is refused
  /// with a [StaleAccessControlBaseException] rather than applied. This is NOT a
  /// merge point: the caller must re-read and let the user decide again against
  /// what the list actually says now.
  ///
  /// Only [ListType.collaborative] lists have members; a personal list throws.
  ///
  /// Why membership is a NAMED method rather than an optional argument on the
  /// ordinary update — and why the first, smaller shape shipped green while
  /// writing nothing — is recorded in
  /// `docs/architecture/ADR-002-collaborative-list-membership-guard.md`
  /// (BUT-1726/BUT-1752). Read it before widening this signature.
  ///
  /// [intent] is REQUIRED rather than defaulted, and that is ADR-002's lesson
  /// applied to its own file: the shape that shipped green while writing
  /// nothing was an OPTIONAL argument nobody passed. A default of
  /// `ordinary` would silently hold a departure to the guards that refuse it.
  ///
  /// **Under [MembershipWriteIntent.selfRemoval], [updated] is NOT what gets
  /// written, and the [base] paragraph above does not apply.** The
  /// implementation derives the write from the stored document — the caller's
  /// own key removed — and returns THAT. A caller cannot express a departure
  /// that touches anybody else, which is the point; a caller that reads the
  /// return value gets the derived list, not its own.
  ///
  /// [base] is therefore not compared for this intent: a derived write makes no
  /// claim about anyone, so there is no stale claim to refuse. It is still
  /// required, and still decides the OFFLINE refusal — a membership change
  /// computed against a cached document is not replayable either way.
  Future<UnifiedShoppingList> updateCollaborativeListMembership(
    UnifiedShoppingList updated,
    UnifiedShoppingList base, {
    required MembershipWriteIntent intent,
  });

  /// BUT-2140: writes the week menu's rows into the personal list [base] by
  /// operation, never by replacing the list document, so a change the same
  /// account made on another device survives. [base] is the copy in memory:
  /// the server's copy is compared against it to tell the user about such a
  /// change, and the write falls back on it offline.
  Future<PersonalMergeResult> applyPersonalMerge(
    UnifiedShoppingList base,
    PersonalMergeRequest request,
  );

  /// BUT-2140: Ångra for [applyPersonalMerge]. Takes off exactly the rows
  /// [addedIds] names and puts [restore] back, and touches nothing else.
  /// Returns [base] as it reads after the undo.
  Future<UnifiedShoppingList> undoPersonalMerge(
    UnifiedShoppingList base, {
    required List<String> addedIds,
    required List<UnifiedShoppingItem> restore,
  });

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
