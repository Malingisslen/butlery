// lib/models/unified/shopping_display_name_keys.dart

/// Every cached display name a shopping list or its items persist, keyed to the
/// uid field that says whose name it is.
///
/// The share copy and the GDPR export both redact by this one map, so a name
/// field added to the models can only be missed once.
const Map<String, String> shoppingDisplayNameKeysByUserIdKey = {
  'ownerDisplayName': 'ownerId',
  'lastActivityByDisplayName': 'lastActivityByUserId',
  'addedByDisplayName': 'addedByUserId',
  'purchasedByDisplayName': 'purchasedByUserId',
  'lastModifiedByDisplayName': 'lastModifiedByUserId',
  'assignedToDisplayName': 'assignedToUserId',
};

/// A copy of [source] with every name in [shoppingDisplayNameKeysByUserIdKey]
/// removed at every depth. The uid fields stay: erasure and the Art. 15 export
/// find rows by them.
Map<String, dynamic> withoutShoppingDisplayNames(Map<String, dynamic> source) {
  Object? walk(Object? node) {
    if (node is List) return node.map(walk).toList();
    if (node is! Map) return node;
    return <String, dynamic>{
      for (final entry in node.entries)
        if (!shoppingDisplayNameKeysByUserIdKey.containsKey(entry.key))
          entry.key.toString(): walk(entry.value),
    };
  }

  return walk(source) as Map<String, dynamic>;
}
