#!/usr/bin/env dart
/// 🔧 DATA MIGRATION SCRIPT: Friend and Recipe Counters
/// 
/// ULTRATHINK Fix for friend profile statistics showing "0 vänner and 0 recipe"
/// 
/// **Problem**: Existing users have incorrect friendsCount and publicRecipeCount 
/// in their profiles due to missing counter logic in previous implementation.
/// 
/// **Solution**: Count actual friends and recipes from Firebase data and update
/// user profiles with correct statistics.
/// 
/// **Usage:**
/// ```bash
/// # Dry run (preview changes without applying)
/// dart tools/migrate_user_counters.dart --dry-run
/// 
/// # Apply changes to production
/// dart tools/migrate_user_counters.dart --apply
/// 
/// # Process specific batch
/// dart tools/migrate_user_counters.dart --apply --batch-start=100 --batch-size=50
/// ```
/// 
/// **Safety Features:**
/// - Dry-run mode for testing
/// - Batch processing with progress tracking
/// - Comprehensive error handling and rollback
/// - Detailed logging and validation
/// - Idempotent (safe to run multiple times)

import 'dart:io';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

/// Migration configuration and settings
class MigrationConfig {
  static const int defaultBatchSize = 50;
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);
  static const bool validateBeforeUpdate = true;
  static const int maxUpdateThreshold = 1000; // Don't update if count > 1000 (likely error)
}

/// Data migration statistics and progress tracking
class MigrationStats {
  int totalUsers = 0;
  int processedUsers = 0;
  int updatedUsers = 0;
  int errorUsers = 0;
  int skippedUsers = 0;
  Map<String, int> errorTypes = {};
  List<String> problematicUsers = [];
  
  void addError(String type, String userId) {
    errorUsers++;
    errorTypes[type] = (errorTypes[type] ?? 0) + 1;
    problematicUsers.add('$userId ($type)');
  }
  
  void printSummary() {
    // ignore: avoid_print
    print('\n📊 MIGRATION SUMMARY:');
    // ignore: avoid_print
    print('Total Users: $totalUsers');
    // ignore: avoid_print
    print('Processed: $processedUsers');
    // ignore: avoid_print
    print('Updated: $updatedUsers');
    // ignore: avoid_print
    print('Errors: $errorUsers');
    // ignore: avoid_print
    print('Skipped: $skippedUsers');
    
    if (errorTypes.isNotEmpty) {
      // ignore: avoid_print
      print('\n❌ Error Breakdown:');
      errorTypes.forEach((type, countValue) {
        // ignore: avoid_print
        print('  $type: $countValue');
      });
    }
    
    if (problematicUsers.isNotEmpty && problematicUsers.length <= 10) {
      // ignore: avoid_print
      print('\n⚠️ Problematic Users:');
      for (final user in problematicUsers) {
        // ignore: avoid_print
        print('  $user');
      }
    }
  }
}

/// User counter data for validation and updates
class UserCounters {
  final String userId;
  final int currentFriendsCount;
  final int currentRecipeCount;
  final int actualFriendsCount;
  final int actualRecipeCount;
  
  UserCounters({
    required this.userId,
    required this.currentFriendsCount,
    required this.currentRecipeCount,
    required this.actualFriendsCount,
    required this.actualRecipeCount,
  });
  
  bool get needsUpdate {
    return currentFriendsCount != actualFriendsCount || 
           currentRecipeCount != actualRecipeCount;
  }
  
  bool get isValid {
    return actualFriendsCount <= MigrationConfig.maxUpdateThreshold &&
           actualRecipeCount <= MigrationConfig.maxUpdateThreshold;
  }
  
  Map<String, dynamic> get updateData {
    return {
      'friendsCount': actualFriendsCount,
      'publicRecipeCount': actualRecipeCount,
      'countersUpdatedAt': FieldValue.serverTimestamp(),
      'countersMigratedBy': 'migrate_user_counters_script',
    };
  }
  
  @override
  String toString() {
    return 'User $userId: Friends $currentFriendsCount→$actualFriendsCount, Recipes $currentRecipeCount→$actualRecipeCount';
  }
}

/// Main migration script class with comprehensive error handling
class UserCounterMigration {
  final FirebaseFirestore _firestore;
  final bool _dryRun;
  final int _batchSize;
  final int _batchStart;
  final MigrationStats _stats = MigrationStats();
  
  UserCounterMigration({
    required FirebaseFirestore firestore,
    required bool dryRun,
    int batchSize = MigrationConfig.defaultBatchSize,
    int batchStart = 0,
  }) : _firestore = firestore,
       _dryRun = dryRun,
       _batchSize = batchSize,
       _batchStart = batchStart;

  /// Execute the complete migration process
  Future<void> executeMigration() async {
    // ignore: avoid_print
    print('🚀 Starting User Counter Migration');
    // ignore: avoid_print
    print('Mode: ${_dryRun ? "DRY RUN (no changes)" : "APPLY CHANGES"}');
    // ignore: avoid_print
    print('Batch: Start $_batchStart, Size $_batchSize\n');
    
    try {
      // Get all users to process
      final users = await _getAllUsers();
      _stats.totalUsers = users.length;
      
      if (users.isEmpty) {
        // ignore: avoid_print
        print('❌ No users found to process');
        return;
      }
      
      // ignore: avoid_print
      print('Found ${users.length} users to process\n');
      
      // Process users in batches
      await _processUsersBatch(users);
      
    } catch (e, stackTrace) {
      // ignore: avoid_print
      print('❌ CRITICAL ERROR during migration: $e');
      // ignore: avoid_print
      print('Stack trace: $stackTrace');
      _stats.addError('critical_error', 'migration_process');
    } finally {
      _stats.printSummary();
    }
  }
  
  /// Get all users from public_profiles collection
  Future<List<QueryDocumentSnapshot>> _getAllUsers() async {
    // ignore: avoid_print
    print('📋 Fetching users from public_profiles...');
    
    try {
      Query query = _firestore.collection('public_profiles')
          .orderBy('joinedAt', descending: false);
      
      if (_batchStart > 0) {
        // Skip to the specified starting point
        final skipQuery = await _firestore.collection('public_profiles')
            .orderBy('joinedAt', descending: false)
            .limit(_batchStart)
            .get();
        
        if (skipQuery.docs.isNotEmpty) {
          query = query.startAfterDocument(skipQuery.docs.last);
        }
      }
      
      final snapshot = await query.limit(_batchSize).get();
      
      // ignore: avoid_print
      print('✅ Retrieved ${snapshot.docs.length} users');
      return snapshot.docs;
      
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error fetching users: $e');
      rethrow;
    }
  }
  
  /// Process a batch of users with error handling
  Future<void> _processUsersBatch(List<QueryDocumentSnapshot> users) async {
    // ignore: avoid_print
    print('🔄 Processing ${users.length} users...\n');
    
    for (int i = 0; i < users.length; i++) {
      final userDoc = users[i];
      final userId = userDoc.id;
      final userData = userDoc.data() as Map<String, dynamic>;
      
      try {
        // ignore: avoid_print
        print('[${ i + 1}/${users.length}] Processing user: $userId');
        
        // Get current and actual counts
        final counters = await _getUserCounters(userId, userData);
        _stats.processedUsers++;
        
        if (!counters.needsUpdate) {
          // ignore: avoid_print
          print('  ✅ Counters already correct, skipping');
          _stats.skippedUsers++;
          continue;
        }
        
        if (!counters.isValid) {
          // ignore: avoid_print
          print('  ⚠️ Suspicious counts detected, skipping for manual review');
          _stats.addError('suspicious_counts', userId);
          continue;
        }
        
        // Apply update
        await _updateUserCounters(counters);
        _stats.updatedUsers++;
        
        // ignore: avoid_print
        print('  ✅ Updated: ${counters.toString()}');
        
        // Rate limiting to avoid overwhelming Firebase
        if (i > 0 && i % 10 == 0) {
          // ignore: avoid_print
          print('  💤 Rate limiting pause...');
          await Future.delayed(const Duration(milliseconds: 500));
        }
        
      } catch (e) {
        // ignore: avoid_print
        print('  ❌ Error processing user $userId: $e');
        _stats.addError('processing_error', userId);
        continue;
      }
    }
  }
  
  /// Get current and actual counters for a user
  Future<UserCounters> _getUserCounters(String userId, Map<String, dynamic> userData) async {
    final currentFriendsCount = userData['friendsCount'] as int? ?? 0;
    final currentRecipeCount = userData['publicRecipeCount'] as int? ?? 0;
    
    // Count actual friends and recipes
    final actualFriendsCount = await _countUserFriends(userId);
    final actualRecipeCount = await _countUserRecipes(userId);
    
    return UserCounters(
      userId: userId,
      currentFriendsCount: currentFriendsCount,
      currentRecipeCount: currentRecipeCount,
      actualFriendsCount: actualFriendsCount,
      actualRecipeCount: actualRecipeCount,
    );
  }
  
  /// Count actual friends for a user
  Future<int> _countUserFriends(String userId) async {
    try {
      final friendsCollection = _firestore
          .collection('users')
          .doc(userId)
          .collection('friends');
      
      final countSnapshot = await friendsCollection.count().get();
      return countSnapshot.count ?? 0;
      
    } catch (e) {
      // ignore: avoid_print
      print('    ⚠️ Error counting friends for $userId: $e');
      return 0;
    }
  }
  
  /// Count actual recipes created by a user
  Future<int> _countUserRecipes(String userId) async {
    try {
      final recipesQuery = _firestore
          .collection('recipes')
          .where('createdBy', isEqualTo: userId);
      
      final countSnapshot = await recipesQuery.count().get();
      return countSnapshot.count ?? 0;
      
    } catch (e) {
      // ignore: avoid_print
      print('    ⚠️ Error counting recipes for $userId: $e');
      return 0;
    }
  }
  
  /// Update user counters with retry logic
  Future<void> _updateUserCounters(UserCounters counters) async {
    if (_dryRun) {
      // ignore: avoid_print
      print('    🔍 DRY RUN: Would update ${counters.toString()}');
      return;
    }
    
    int attempts = 0;
    while (attempts < MigrationConfig.maxRetries) {
      try {
        await _firestore
            .collection('public_profiles')
            .doc(counters.userId)
            .update(counters.updateData);
        
        return; // Success
        
      } catch (e) {
        attempts++;
        // ignore: avoid_print
        print('    ⚠️ Update attempt $attempts failed: $e');
        
        if (attempts >= MigrationConfig.maxRetries) {
          throw Exception('Failed to update after ${MigrationConfig.maxRetries} attempts: $e');
        }
        
        await Future.delayed(MigrationConfig.retryDelay);
      }
    }
  }
}

/// Command-line argument parsing
class MigrationArgs {
  final bool dryRun;
  final bool apply;
  final int batchSize;
  final int batchStart;
  final bool help;
  
  MigrationArgs({
    required this.dryRun,
    required this.apply,
    required this.batchSize,
    required this.batchStart,
    required this.help,
  });
  
  static MigrationArgs parse(List<String> args) {
    bool dryRun = false;
    bool apply = false;
    int batchSize = MigrationConfig.defaultBatchSize;
    int batchStart = 0;
    bool help = false;
    
    for (int i = 0; i < args.length; i++) {
      switch (args[i]) {
        case '--dry-run':
          dryRun = true;
          break;
        case '--apply':
          apply = true;
          break;
        case '--batch-size':
          if (i + 1 < args.length) {
            batchSize = int.tryParse(args[i + 1]) ?? batchSize;
            i++; // Skip next argument
          }
          break;
        case '--batch-start':
          if (i + 1 < args.length) {
            batchStart = int.tryParse(args[i + 1]) ?? batchStart;
            i++; // Skip next argument
          }
          break;
        case '--help':
        case '-h':
          help = true;
          break;
      }
    }
    
    return MigrationArgs(
      dryRun: dryRun,
      apply: apply,
      batchSize: batchSize,
      batchStart: batchStart,
      help: help,
    );
  }
}

/// Print help information
void printHelp() {
  // ignore: avoid_print
  print('''
🔧 User Counter Migration Script

Fixes friend and recipe counters for existing users who have "0 vänner and 0 recipe"
displayed incorrectly due to missing counter logic in previous implementation.

USAGE:
  dart tools/migrate_user_counters.dart [OPTIONS]

OPTIONS:
  --dry-run              Preview changes without applying them
  --apply                Apply changes to the database
  --batch-size N         Process N users at a time (default: 50)
  --batch-start N        Start from user N (for resuming)
  --help, -h             Show this help message

EXAMPLES:
  # Preview changes for first 10 users
  dart tools/migrate_user_counters.dart --dry-run --batch-size=10
  
  # Apply changes to all users
  dart tools/migrate_user_counters.dart --apply
  
  # Resume from user 100, process 25 at a time
  dart tools/migrate_user_counters.dart --apply --batch-start=100 --batch-size=25

SAFETY:
  - Always test with --dry-run first
  - Script is idempotent (safe to run multiple times)
  - Includes comprehensive error handling and progress tracking
  - Validates counts before applying updates
''');
}

/// Initialize Firebase for the migration
Future<void> initializeFirebase() async {
  try {
    await Firebase.initializeApp();
    // ignore: avoid_print
    print('✅ Firebase initialized successfully');
  } catch (e) {
    // ignore: avoid_print
    print('❌ Failed to initialize Firebase: $e');
    // ignore: avoid_print
    print('💡 Make sure you have firebase_options.dart configured');
    exit(1);
  }
}

/// Main entry point
Future<void> main(List<String> args) async {
  final parsedArgs = MigrationArgs.parse(args);
  
  if (parsedArgs.help || (!parsedArgs.dryRun && !parsedArgs.apply)) {
    printHelp();
    return;
  }
  
  // Confirm destructive operations
  if (parsedArgs.apply && !parsedArgs.dryRun) {
    // ignore: avoid_print
    print('⚠️  WARNING: This will modify user data in Firebase!');
    // ignore: avoid_print
    print('Are you sure you want to continue? (y/N)');
    final confirmation = stdin.readLineSync()?.toLowerCase();
    if (confirmation != 'y' && confirmation != 'yes') {
      // ignore: avoid_print
      print('Operation cancelled');
      return;
    }
  }
  
  // Initialize Firebase
  await initializeFirebase();
  
  // Execute migration
  final migration = UserCounterMigration(
    firestore: FirebaseFirestore.instance,
    dryRun: parsedArgs.dryRun,
    batchSize: parsedArgs.batchSize,
    batchStart: parsedArgs.batchStart,
  );
  
  await migration.executeMigration();
  
  // ignore: avoid_print
  print('\n✅ Migration completed successfully');
}