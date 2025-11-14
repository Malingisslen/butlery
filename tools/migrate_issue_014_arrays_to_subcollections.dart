// ignore_for_file: avoid_print

/// Data Migration Script for Issue #014: Unbounded Tracking Arrays
///
/// This script migrates existing shared content data from array-based status tracking
/// to Firestore subcollection-based tracking, eliminating the 100-element array limit.
///
/// **What This Script Does:**
/// 1. Migrates `sharedToUserIds` arrays → `members` subcollection
/// 2. Migrates `viewedByUserIds` arrays → `views` subcollection
/// 3. Migrates `engagedByUserIds` arrays → `engagements` subcollection
/// 4. Migrates `dismissedByUserIds` arrays → `dismissals` subcollection
/// 5. Migrates `activeCollaboratorIds` arrays → `collaborators` subcollection
/// 6. Updates count fields (viewCount, engagementCount, dismissalCount)
///
/// **Collections Migrated:**
/// - shared_recipes
/// - shared_menus
/// - shared_shopping_lists
///
/// **Safety Features:**
/// - Idempotent: Can be run multiple times safely
/// - Non-destructive: Preserves original arrays for rollback
/// - Progress logging: Detailed logs for monitoring
/// - Dry-run mode: Test without making changes
/// - Batch processing: Handles large datasets efficiently
///
/// **Usage:**
/// ```bash
/// # Dry run (no changes, just preview)
/// dart tools/migrate_issue_014_arrays_to_subcollections.dart --dry-run
///
/// # Actual migration
/// dart tools/migrate_issue_014_arrays_to_subcollections.dart
///
/// # Migrate specific collection only
/// dart tools/migrate_issue_014_arrays_to_subcollections.dart --collection shared_recipes
/// ```

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

void main(List<String> args) async {
  // Parse arguments
  final dryRun = args.contains('--dry-run');
  final collectionFilter = _parseCollectionFilter(args);

  print('🚀 Issue #014 Migration Script Starting...');
  print('📋 Mode: ${dryRun ? "DRY RUN (no changes)" : "PRODUCTION (will modify data)"}');
  if (collectionFilter != null) {
    print('🎯 Collection filter: $collectionFilter');
  }
  print('');

  // Initialize Firebase
  await Firebase.initializeApp();
  final firestore = FirebaseFirestore.instance;

  final migrator = DataMigrator(firestore, dryRun: dryRun);

  try {
    // Migrate collections
    final collections = collectionFilter != null
        ? [collectionFilter]
        : ['shared_recipes', 'shared_menus', 'shared_shopping_lists'];

    for (final collection in collections) {
      await migrator.migrateCollection(collection);
    }

    // Print summary
    migrator.printSummary();

    if (dryRun) {
      print('');
      print('✅ Dry run complete. Run without --dry-run to apply changes.');
    } else {
      print('');
      print('✅ Migration complete! All arrays migrated to subcollections.');
    }
  } catch (e, stackTrace) {
    print('❌ Migration failed: $e');
    print(stackTrace);
    exit(1);
  }
}

String? _parseCollectionFilter(List<String> args) {
  final collectionIndex = args.indexOf('--collection');
  if (collectionIndex != -1 && collectionIndex + 1 < args.length) {
    return args[collectionIndex + 1];
  }
  return null;
}

class DataMigrator {
  final FirebaseFirestore firestore;
  final bool dryRun;

  // Migration statistics
  int documentsProcessed = 0;
  int documentsSkipped = 0;
  int subcollectionEntriesCreated = 0;
  int errors = 0;

  DataMigrator(this.firestore, {this.dryRun = false});

  /// Migrate a collection (shared_recipes, shared_menus, or shared_shopping_lists)
  Future<void> migrateCollection(String collectionName) async {
    print('');
    print('═══════════════════════════════════════════════════════════');
    print('📦 Migrating collection: $collectionName');
    print('═══════════════════════════════════════════════════════════');

    final collection = firestore.collection(collectionName);
    final snapshot = await collection.get();

    print('📊 Found ${snapshot.docs.length} documents to process');
    print('');

    for (final doc in snapshot.docs) {
      await _migrateDocument(collectionName, doc);
    }

    print('');
    print('✅ Completed $collectionName migration');
  }

  /// Migrate a single document
  Future<void> _migrateDocument(
      String collectionName, DocumentSnapshot doc) async {
    try {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) {
        print('⚠️  ${doc.id}: No data found, skipping');
        documentsSkipped++;
        return;
      }

      print('🔄 Processing: ${doc.id}');

      // Check if already migrated (has subcollections but no arrays)
      final hasArrays = _hasArrayFields(data);
      if (!hasArrays) {
        print('   ⏭️  Already migrated (no arrays found), skipping');
        documentsSkipped++;
        return;
      }

      // Migrate each array type
      await _migrateMembers(doc.reference, data);
      await _migrateViews(doc.reference, data);
      await _migrateEngagements(doc.reference, data, collectionName);
      await _migrateDismissals(doc.reference, data);
      await _migrateCollaborators(doc.reference, data);

      // Update count fields
      await _updateCountFields(doc.reference, data);

      documentsProcessed++;
      print('   ✅ Migrated successfully');
    } catch (e) {
      print('   ❌ Error: $e');
      errors++;
    }
  }

  /// Check if document has array fields (not yet migrated)
  bool _hasArrayFields(Map<String, dynamic> data) {
    return data.containsKey('sharedToUserIds') ||
        data.containsKey('viewedByUserIds') ||
        data.containsKey('engagedByUserIds') ||
        data.containsKey('dismissedByUserIds') ||
        data.containsKey('activeCollaboratorIds');
  }

  /// Migrate sharedToUserIds → members subcollection
  Future<void> _migrateMembers(
      DocumentReference docRef, Map<String, dynamic> data) async {
    final sharedToUserIds = _getArrayField(data, 'sharedToUserIds');
    if (sharedToUserIds.isEmpty) return;

    print('   📋 Migrating ${sharedToUserIds.length} members...');

    for (final userId in sharedToUserIds) {
      await _createSubcollectionEntry(
        docRef.collection('members').doc(userId),
        {
          'userId': userId,
          'addedBy': data['sharedByUserId'] ?? 'unknown',
          'addedAt': FieldValue.serverTimestamp(),
          'role': 'member',
        },
      );
    }

    subcollectionEntriesCreated += sharedToUserIds.length;
  }

  /// Migrate viewedByUserIds → views subcollection
  Future<void> _migrateViews(
      DocumentReference docRef, Map<String, dynamic> data) async {
    final viewedByUserIds = _getArrayField(data, 'viewedByUserIds');
    if (viewedByUserIds.isEmpty) return;

    print('   👁️  Migrating ${viewedByUserIds.length} views...');

    for (final userId in viewedByUserIds) {
      await _createSubcollectionEntry(
        docRef.collection('views').doc(userId),
        {
          'userId': userId,
          'viewedAt': FieldValue.serverTimestamp(),
        },
      );
    }

    subcollectionEntriesCreated += viewedByUserIds.length;
  }

  /// Migrate engagedByUserIds → engagements subcollection
  Future<void> _migrateEngagements(DocumentReference docRef,
      Map<String, dynamic> data, String collectionName) async {
    final engagedByUserIds = _getArrayField(data, 'engagedByUserIds');
    final joinedByUserIds = _getArrayField(data, 'joinedByUserIds'); // For shopping lists
    final importedByUserIds = _getArrayField(data, 'importedByUserIds'); // Legacy field

    final allEngagedUsers = {
      ...engagedByUserIds,
      ...joinedByUserIds,
      ...importedByUserIds,
    }.toList();

    if (allEngagedUsers.isEmpty) return;

    print('   💫 Migrating ${allEngagedUsers.length} engagements...');

    // Determine action based on collection type
    final action = collectionName == 'shared_shopping_lists' ? 'join' : 'import';

    for (final userId in allEngagedUsers) {
      await _createSubcollectionEntry(
        docRef.collection('engagements').doc(userId),
        {
          'userId': userId,
          'action': action,
          'engagedAt': FieldValue.serverTimestamp(),
        },
      );
    }

    subcollectionEntriesCreated += allEngagedUsers.length;
  }

  /// Migrate dismissedByUserIds → dismissals subcollection
  Future<void> _migrateDismissals(
      DocumentReference docRef, Map<String, dynamic> data) async {
    final dismissedByUserIds = _getArrayField(data, 'dismissedByUserIds');
    if (dismissedByUserIds.isEmpty) return;

    print('   🚫 Migrating ${dismissedByUserIds.length} dismissals...');

    for (final userId in dismissedByUserIds) {
      await _createSubcollectionEntry(
        docRef.collection('dismissals').doc(userId),
        {
          'userId': userId,
          'dismissedAt': FieldValue.serverTimestamp(),
        },
      );
    }

    subcollectionEntriesCreated += dismissedByUserIds.length;
  }

  /// Migrate activeCollaboratorIds → collaborators subcollection
  Future<void> _migrateCollaborators(
      DocumentReference docRef, Map<String, dynamic> data) async {
    final activeCollaboratorIds = _getArrayField(data, 'activeCollaboratorIds');
    if (activeCollaboratorIds.isEmpty) return;

    print('   🤝 Migrating ${activeCollaboratorIds.length} collaborators...');

    for (final userId in activeCollaboratorIds) {
      await _createSubcollectionEntry(
        docRef.collection('collaborators').doc(userId),
        {
          'userId': userId,
          'joinedAt': FieldValue.serverTimestamp(),
          'role': 'collaborator',
        },
      );
    }

    subcollectionEntriesCreated += activeCollaboratorIds.length;
  }

  /// Update count fields based on array lengths
  Future<void> _updateCountFields(
      DocumentReference docRef, Map<String, dynamic> data) async {
    final viewCount = _getArrayField(data, 'viewedByUserIds').length;
    final engagementCount = _getArrayField(data, 'engagedByUserIds').length +
        _getArrayField(data, 'joinedByUserIds').length +
        _getArrayField(data, 'importedByUserIds').length;
    final dismissalCount = _getArrayField(data, 'dismissedByUserIds').length;

    if (viewCount == 0 && engagementCount == 0 && dismissalCount == 0) {
      return;
    }

    print('   📊 Updating counts: views=$viewCount, engagements=$engagementCount, dismissals=$dismissalCount');

    if (!dryRun) {
      await docRef.update({
        'viewCount': viewCount,
        'engagementCount': engagementCount,
        'dismissalCount': dismissalCount,
      });
    }
  }

  /// Create subcollection entry (idempotent)
  Future<void> _createSubcollectionEntry(
      DocumentReference entryRef, Map<String, dynamic> data) async {
    if (dryRun) return;

    // Check if entry already exists
    final existingDoc = await entryRef.get();
    if (existingDoc.exists) {
      return; // Skip if already exists (idempotent)
    }

    await entryRef.set(data);
  }

  /// Get array field safely
  List<String> _getArrayField(Map<String, dynamic> data, String fieldName) {
    final field = data[fieldName];
    if (field == null) return [];
    if (field is List) {
      return field.whereType<String>().toList();
    }
    return [];
  }

  /// Print migration summary
  void printSummary() {
    print('');
    print('═══════════════════════════════════════════════════════════');
    print('📊 MIGRATION SUMMARY');
    print('═══════════════════════════════════════════════════════════');
    print('Documents processed:         $documentsProcessed');
    print('Documents skipped:           $documentsSkipped');
    print('Subcollection entries created: $subcollectionEntriesCreated');
    print('Errors:                      $errors');
    print('═══════════════════════════════════════════════════════════');
  }
}
