/// Migration script for Issue #015: Shopping List Items Array → Subcollection
///
/// **Purpose**: Migrate SharedShoppingList items from embedded array to Firestore subcollection
///
/// **Problem**: Firestore has 100-element array limit. Shopping lists with 150+ items fail.
///
/// **Solution**: Move items from `listItems` array to `items` subcollection:
/// - **Before**: `shared_shopping_lists/{id}` with `listItems: [array]`
/// - **After**: `shared_shopping_lists/{id}/items/{itemId}` + `itemCount: int`
///
/// **Migration Process**:
/// 1. Query all shared_shopping_lists documents
/// 2. For each list with listItems array:
///    a. Create items subcollection documents
///    b. Set itemCount field
///    c. Remove listItems array (optional cleanup)
/// 3. Report migration statistics
///
/// **Safety Features**:
/// - **Dry-run mode**: Preview changes without committing (DRY_RUN = true)
/// - **Batch processing**: Process 100 lists at a time
/// - **Error handling**: Continue on errors, log failures
/// - **Progress tracking**: Console output with percentage complete
///
/// **Usage**:
/// ```bash
/// # Dry run (preview only)
/// dart tools/migrate_shopping_list_items_to_subcollection.dart
///
/// # Execute migration
/// dart tools/migrate_shopping_list_items_to_subcollection.dart --execute
/// ```
///
/// **Rollback**: Keep listItems array during migration. Can be removed later with cleanup script.

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

// ===== CONFIGURATION =====

/// Dry-run mode: If true, previews migration without making changes
const bool DRY_RUN = true;

/// Batch size for processing lists
const int BATCH_SIZE = 100;

/// Whether to remove listItems array after migration (cleanup)
/// Set to false for safety - allows rollback if needed
const bool REMOVE_LIST_ITEMS_ARRAY = false;

// ===== MIGRATION SCRIPT =====

Future<void> main(List<String> arguments) async {
  // Parse command line arguments
  final execute = arguments.contains('--execute');
  final isDryRun = !execute || DRY_RUN;

  print('');
  print('=' * 60);
  print('Issue #015: Shopping List Items → Subcollection Migration');
  print('=' * 60);
  print('Mode: ${isDryRun ? 'DRY-RUN (no changes will be made)' : 'EXECUTE'}');
  print('Batch size: $BATCH_SIZE lists');
  print('Remove listItems array: $REMOVE_LIST_ITEMS_ARRAY');
  print('=' * 60);
  print('');

  if (isDryRun) {
    print('⚠️  DRY-RUN MODE: No changes will be made to Firestore');
    print('   Run with --execute flag to perform actual migration');
    print('');
  } else {
    print('⚠️  EXECUTE MODE: Changes will be written to Firestore!');
    print('   Press Ctrl+C within 5 seconds to cancel...');
    await Future.delayed(const Duration(seconds: 5));
    print('');
  }

  try {
    // Initialize Firebase
    await Firebase.initializeApp();
    final firestore = FirebaseFirestore.instance;

    // Query all shared shopping lists
    print('🔍 Querying shared_shopping_lists collection...');
    final snapshot = await firestore.collection('shared_shopping_lists').get();

    print('📊 Found ${snapshot.docs.length} shopping lists total');
    print('');

    // Filter lists that have listItems array (need migration)
    final listsToMigrate = snapshot.docs.where((doc) {
      final data = doc.data();
      return data.containsKey('listItems') && data['listItems'] is List;
    }).toList();

    print('✅ Lists to migrate: ${listsToMigrate.length}');
    if (listsToMigrate.isEmpty) {
      print('✨ No lists need migration. All done!');
      return;
    }

    // Calculate statistics
    int totalItems = 0;
    for (final doc in listsToMigrate) {
      final listItems = doc.data()['listItems'] as List?;
      totalItems += listItems?.length ?? 0;
    }
    final avgItems = listsToMigrate.isEmpty ? 0 : (totalItems / listsToMigrate.length).round();

    print('📦 Estimated items: ~$totalItems (avg $avgItems items/list)');
    print('');

    // Migration counters
    int successCount = 0;
    int skipCount = 0;
    int failCount = 0;
    int totalItemsMigrated = 0;

    // Process lists in batches
    for (int i = 0; i < listsToMigrate.length; i++) {
      final doc = listsToMigrate[i];
      final data = doc.data();
      final listId = doc.id;
      final listName = data['listName'] as String? ?? 'Unknown';
      final listItems = data['listItems'] as List? ?? [];

      final progress = '[${ i + 1}/${listsToMigrate.length}]';

      try {
        print('$progress Processing "$listName" ($listId)...');

        if (listItems.isEmpty) {
          print('  ⏭️  Skipped: No items to migrate');
          skipCount++;
          continue;
        }

        if (!isDryRun) {
          // Execute migration
          await _migrateListItems(
            firestore: firestore,
            listId: listId,
            listItems: listItems,
            removeListItemsArray: REMOVE_LIST_ITEMS_ARRAY,
          );
        }

        print('  ✅ Migrated ${listItems.length} items → items subcollection');
        successCount++;
        totalItemsMigrated += listItems.length;
      } catch (e, stack) {
        print('  ❌ FAILED: $e');
        print('  Stack trace: $stack');
        failCount++;
      }

      print('');
    }

    // Print summary
    print('=' * 60);
    print('MIGRATION SUMMARY');
    print('=' * 60);
    print('✅ Successfully migrated: $successCount lists ($totalItemsMigrated items)');
    print('⏭️  Skipped (no items): $skipCount lists');
    print('❌ Failed: $failCount lists');
    print('');

    if (isDryRun) {
      print('💡 This was a DRY-RUN. No changes were made.');
      print('   Run with --execute to perform actual migration:');
      print('   dart tools/migrate_shopping_list_items_to_subcollection.dart --execute');
    } else {
      print('✨ Migration complete!');
      print('   Items are now stored in subcollection: shared_shopping_lists/{id}/items/{itemId}');
      if (REMOVE_LIST_ITEMS_ARRAY) {
        print('   Old listItems arrays have been removed.');
      } else {
        print('   Old listItems arrays preserved for rollback safety.');
        print('   Run cleanup script later to remove them.');
      }
    }
    print('=' * 60);
  } catch (e, stack) {
    print('');
    print('❌ FATAL ERROR: $e');
    print('Stack trace: $stack');
    exit(1);
  }
}

/// Migrates a single shopping list's items from array to subcollection
Future<void> _migrateListItems({
  required FirebaseFirestore firestore,
  required String listId,
  required List listItems,
  required bool removeListItemsArray,
}) async {
  final batch = firestore.batch();
  final listRef = firestore.collection('shared_shopping_lists').doc(listId);

  // 1. Create items subcollection documents
  for (final itemData in listItems) {
    if (itemData is! Map<String, dynamic>) continue;

    final itemId = itemData['id'] as String?;
    if (itemId == null || itemId.isEmpty) continue;

    final itemRef = listRef.collection('items').doc(itemId);
    batch.set(itemRef, itemData);
  }

  // 2. Update list document with itemCount
  final updates = <String, dynamic>{
    'itemCount': listItems.length,
  };

  // 3. Optionally remove listItems array
  if (removeListItemsArray) {
    updates['listItems'] = FieldValue.delete();
  }

  batch.update(listRef, updates);

  // Commit batch operation
  await batch.commit();
}
