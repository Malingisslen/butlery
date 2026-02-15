// lib/services/realtime/resource_parser_module.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/models/realtime/realtime_resource.dart';
import 'package:butlery/models/realtime/realtime_recipe.dart';
import 'package:butlery/models/realtime/realtime_menu.dart';
import 'package:butlery/services/realtime/realtime_types.dart';
import 'package:butlery/core/l10n/app_locale.dart';

/// Module handling resource parsing and fetching for realtime sync.
/// Provides type-safe resource parsing, fetching, and DocumentReference helpers.
class ResourceParserModule {
  final FirestoreRepository firestoreRepository;

  ResourceParserModule({
    required this.firestoreRepository,
  });

  /// Get DocumentReference for a resource
  DocumentReference<Map<String, dynamic>> getResourceDocRef(String resourceId) {
    return firestoreRepository.realtimeResourceDoc(resourceId);
  }

  /// Parse resource from Firestore snapshot with type safety
  T parseResourceFromSnapshot<T extends RealtimeResource>(
      DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;
    final typeString = data['type'] as String? ?? 'recipe';

    RealtimeResourceType type;
    try {
      type = RealtimeResourceType.fromString(typeString);
    } catch (e) {
      // Fallback to recipe if unknown type
      type = RealtimeResourceType.recipe;
    }

    // Type-safe parsing based on resource type
    switch (type) {
      case RealtimeResourceType.recipe:
        return RealtimeRecipe.fromMap(
            snapshot.id, snapshot.data()! as Map<String, dynamic>) as T;
      case RealtimeResourceType.menu:
        return RealtimeMenu.fromMap(
            snapshot.id, snapshot.data()! as Map<String, dynamic>) as T;
      case RealtimeResourceType.shoppingList:
        // return RealtimeShoppingList.fromFirestore(snapshot) as T;
        throw SyncError(
          type: SyncErrorType.firestoreError,
          message: AppLocale.current.syncParsingNotImplemented,
          resourceId: snapshot.id,
        );
    }
  }

  /// Fetch latest version of resource from Firebase
  Future<T> getLatestResource<T extends RealtimeResource>(
      String resourceId) async {
    final snapshot =
        await firestoreRepository.getDocument(getResourceDocRef(resourceId));

    if (!snapshot.exists) {
      throw SyncError(
        type: SyncErrorType.documentNotFound,
        message: AppLocale.current.errorResourceNotFound,
        resourceId: resourceId,
      );
    }

    return parseResourceFromSnapshot<T>(snapshot);
  }
}
