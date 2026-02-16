/// Syncs ingredient data from CSV files to Firebase Firestore.
///
/// Usage:
///   dart run tools/sync_ingredients.dart [options]
///
/// Options:
///   --dry-run    Preview changes without applying
///   --force      Skip confirmation prompts
///   --verbose    Show detailed logging
///
/// CSV files should be in docs/tagging/data/:
///   - Butlery_Ingredients_INGREDIENTS.csv
///   - Butlery_Ingredients_PROPERTIES.csv
///   - Butlery_Ingredients_GROUPS.csv
// ignore_for_file: avoid_print
library;

import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:butlery/firebase_options.dart';

/// Main entry point.
Future<void> main(List<String> args) async {
  final options = _parseArgs(args);

  print('🔄 Ingredient Sync Tool');
  print('=' * 50);

  // Initialize Firebase
  print('\n📡 Initializing Firebase...');
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.windows,
  );
  final firestore = FirebaseFirestore.instance;

  // Load CSV files
  print('\n📂 Loading CSV files...');
  final csvDir = Directory('docs/tagging/data');
  if (!csvDir.existsSync()) {
    print('❌ Error: CSV directory not found: ${csvDir.path}');
    exit(1);
  }

  // Load ingredients
  final ingredientsFile =
      File('${csvDir.path}/Butlery_Ingredients_INGREDIENTS.csv');
  if (!ingredientsFile.existsSync()) {
    print('❌ Error: Ingredients CSV not found');
    exit(1);
  }

  final csvIngredients = await _loadCsv(ingredientsFile);
  print('   Loaded ${csvIngredients.length} ingredients from CSV');

  // Load current Firestore data
  print('\n📥 Loading current Firestore data...');
  final currentSnapshot = await firestore.collection('ingredients').get();
  final currentData = {
    for (final doc in currentSnapshot.docs) doc.id: doc.data(),
  };
  print('   Found ${currentData.length} ingredients in Firestore');

  // Calculate diff
  print('\n🔍 Calculating changes...');
  final diff = _calculateDiff(csvIngredients, currentData, options);

  // Show summary
  print('\n📊 Change Summary:');
  print('   ➕ Adding: ${diff.toAdd.length}');
  print('   ✏️  Updating: ${diff.toUpdate.length}');
  print('   ➖ Removing: ${diff.toRemove.length}');
  print('   ✅ Unchanged: ${diff.unchanged}');

  if (options.verbose) {
    if (diff.toAdd.isNotEmpty) {
      print('\n   New ingredients:');
      for (final id in diff.toAdd.take(10)) {
        print('     - $id');
      }
      if (diff.toAdd.length > 10) {
        print('     ... and ${diff.toAdd.length - 10} more');
      }
    }

    if (diff.toUpdate.isNotEmpty) {
      print('\n   Updated ingredients:');
      for (final id in diff.toUpdate.take(10)) {
        print('     - $id');
      }
      if (diff.toUpdate.length > 10) {
        print('     ... and ${diff.toUpdate.length - 10} more');
      }
    }

    if (diff.toRemove.isNotEmpty) {
      print('\n   Removed ingredients:');
      for (final id in diff.toRemove.take(10)) {
        print('     - $id');
      }
      if (diff.toRemove.length > 10) {
        print('     ... and ${diff.toRemove.length - 10} more');
      }
    }
  }

  // Exit if no changes
  if (diff.toAdd.isEmpty && diff.toUpdate.isEmpty && diff.toRemove.isEmpty) {
    print('\n✅ No changes needed. Firestore is up to date.');
    exit(0);
  }

  // Dry run check
  if (options.dryRun) {
    print('\n🔍 Dry run mode - no changes applied.');
    exit(0);
  }

  // Confirmation
  if (!options.force) {
    print('\n⚠️  Apply these changes to Firestore? (y/N)');
    final response = stdin.readLineSync()?.toLowerCase() ?? '';
    if (response != 'y' && response != 'yes') {
      print('Cancelled.');
      exit(0);
    }
  }

  // Apply changes
  print('\n📤 Applying changes...');
  final batch = firestore.batch();
  var batchCount = 0;
  const maxBatchSize = 500;

  // Add new ingredients
  for (final id in diff.toAdd) {
    final data = diff.newData[id]!;
    batch.set(firestore.collection('ingredients').doc(id), data);
    batchCount++;

    if (batchCount >= maxBatchSize) {
      await batch.commit();
      batchCount = 0;
      print('   Committed batch of $maxBatchSize');
    }
  }

  // Update existing ingredients
  for (final id in diff.toUpdate) {
    final data = diff.newData[id]!;
    batch.update(firestore.collection('ingredients').doc(id), data);
    batchCount++;

    if (batchCount >= maxBatchSize) {
      await batch.commit();
      batchCount = 0;
      print('   Committed batch of $maxBatchSize');
    }
  }

  // Remove deleted ingredients (soft delete by setting status)
  for (final id in diff.toRemove) {
    batch.update(
      firestore.collection('ingredients').doc(id),
      {'status': 'deleted', 'deletedAt': FieldValue.serverTimestamp()},
    );
    batchCount++;

    if (batchCount >= maxBatchSize) {
      await batch.commit();
      batchCount = 0;
      print('   Committed batch of $maxBatchSize');
    }
  }

  // Commit remaining
  if (batchCount > 0) {
    await batch.commit();
  }

  print('\n✅ Sync complete!');
  print('   Added: ${diff.toAdd.length}');
  print('   Updated: ${diff.toUpdate.length}');
  print('   Removed: ${diff.toRemove.length}');

  exit(0);
}

/// Parses command line arguments.
_Options _parseArgs(List<String> args) {
  return _Options(
    dryRun: args.contains('--dry-run'),
    force: args.contains('--force'),
    verbose: args.contains('--verbose') || args.contains('-v'),
  );
}

/// Loads a CSV file into a list of maps.
Future<List<Map<String, dynamic>>> _loadCsv(File file) async {
  final lines = await file.readAsLines(encoding: utf8);
  if (lines.isEmpty) return [];

  // Parse header
  final headers = _parseCsvLine(lines.first);

  // Parse data rows
  final results = <Map<String, dynamic>>[];
  for (var i = 1; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty) continue;

    final values = _parseCsvLine(line);
    if (values.length != headers.length) {
      print(
          '   ⚠️ Skipping malformed row $i: ${values.length} vs ${headers.length} columns');
      continue;
    }

    final row = <String, dynamic>{};
    for (var j = 0; j < headers.length; j++) {
      row[headers[j]] = values[j];
    }
    results.add(row);
  }

  return results;
}

/// Parses a CSV line handling quoted fields.
List<String> _parseCsvLine(String line) {
  final result = <String>[];
  var current = StringBuffer();
  var inQuotes = false;

  for (var i = 0; i < line.length; i++) {
    final char = line[i];

    if (char == '"') {
      if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
        // Escaped quote
        current.write('"');
        i++;
      } else {
        inQuotes = !inQuotes;
      }
    } else if (char == ',' && !inQuotes) {
      result.add(current.toString().trim());
      current = StringBuffer();
    } else {
      current.write(char);
    }
  }

  result.add(current.toString().trim());
  return result;
}

/// Calculates the diff between CSV and Firestore data.
_Diff _calculateDiff(
  List<Map<String, dynamic>> csvData,
  Map<String, Map<String, dynamic>> currentData,
  _Options options,
) {
  final toAdd = <String>[];
  final toUpdate = <String>[];
  final toRemove = <String>[];
  final newData = <String, Map<String, dynamic>>{};
  var unchanged = 0;

  // Process CSV data
  for (final row in csvData) {
    final id = row['id']?.toString() ?? '';
    if (id.isEmpty) continue;

    // Convert CSV row to Firestore format
    final firestoreData = _csvToFirestore(row);
    newData[id] = firestoreData;

    if (!currentData.containsKey(id)) {
      // New ingredient
      toAdd.add(id);
    } else {
      // Check if changed
      if (_hasChanges(currentData[id]!, firestoreData)) {
        toUpdate.add(id);
      } else {
        unchanged++;
      }
    }
  }

  // Find removed ingredients
  for (final id in currentData.keys) {
    if (!newData.containsKey(id)) {
      // Don't remove if already marked as deleted
      if (currentData[id]!['status'] != 'deleted') {
        toRemove.add(id);
      }
    }
  }

  return _Diff(
    toAdd: toAdd,
    toUpdate: toUpdate,
    toRemove: toRemove,
    newData: newData,
    unchanged: unchanged,
  );
}

/// Converts CSV row to Firestore document format.
Map<String, dynamic> _csvToFirestore(Map<String, dynamic> row) {
  // Parse properties from comma-separated string
  final propertiesStr = row['properties']?.toString() ?? '';
  final properties = propertiesStr
      .split(',')
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();

  // Parse aliases from semicolon-separated string
  final aliasesSvStr = row['aliases_sv']?.toString() ?? '';
  final aliasesSv = aliasesSvStr
      .split(';')
      .map((a) => a.trim())
      .where((a) => a.isNotEmpty)
      .toList();

  final aliasesEnStr = row['aliases_en']?.toString() ?? '';
  final aliasesEn = aliasesEnStr
      .split(';')
      .map((a) => a.trim())
      .where((a) => a.isNotEmpty)
      .toList();

  final searchTermsStr = row['search_terms']?.toString() ?? '';
  final searchTerms = searchTermsStr
      .split(';')
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toList();

  return {
    'id': row['id']?.toString() ?? '',
    'swedish': row['swedish']?.toString() ?? '',
    'english': row['english']?.toString() ?? '',
    'group': row['group']?.toString() ?? '',
    'properties': properties,
    'aliasesSv': aliasesSv,
    'aliasesEn': aliasesEn,
    'searchTerms': searchTerms,
    'status': row['status']?.toString() ?? 'validated',
    'updatedAt': FieldValue.serverTimestamp(),
  };
}

/// Checks if the document has changes.
bool _hasChanges(
  Map<String, dynamic> current,
  Map<String, dynamic> newData,
) {
  // Compare key fields
  final fieldsToCompare = ['swedish', 'english', 'group', 'status'];
  for (final field in fieldsToCompare) {
    if (current[field]?.toString() != newData[field]?.toString()) {
      return true;
    }
  }

  // Compare properties
  final currentProps = (current['properties'] as List?)?.cast<String>() ?? [];
  final newProps = (newData['properties'] as List?)?.cast<String>() ?? [];
  if (!_listEquals(currentProps, newProps)) {
    return true;
  }

  // Compare aliases
  final currentAliasesSv =
      (current['aliasesSv'] as List?)?.cast<String>() ?? [];
  final newAliasesSv = (newData['aliasesSv'] as List?)?.cast<String>() ?? [];
  if (!_listEquals(currentAliasesSv, newAliasesSv)) {
    return true;
  }

  return false;
}

/// Compares two lists for equality (order-independent).
bool _listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  final setA = Set<String>.from(a);
  final setB = Set<String>.from(b);
  return setA.containsAll(setB) && setB.containsAll(setA);
}

/// Command line options.
class _Options {
  final bool dryRun;
  final bool force;
  final bool verbose;

  const _Options({
    required this.dryRun,
    required this.force,
    required this.verbose,
  });
}

/// Diff result.
class _Diff {
  final List<String> toAdd;
  final List<String> toUpdate;
  final List<String> toRemove;
  final Map<String, Map<String, dynamic>> newData;
  final int unchanged;

  const _Diff({
    required this.toAdd,
    required this.toUpdate,
    required this.toRemove,
    required this.newData,
    required this.unchanged,
  });
}
