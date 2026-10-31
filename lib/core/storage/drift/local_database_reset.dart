import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:butlery/core/utils/logger.dart';

/// The encrypted database file's name in the documents directory.
const encryptedDatabaseFileName = 'butlery_drift_encrypted.sqlite';

/// Deletes the encrypted database file and SQLite's side files, so the next
/// start makes an empty one. Only ever called after the person
/// confirmed "Börja om med tom lokal data": what was not yet synced is gone.
///
/// The key in secure storage is left alone. When it is lost, a new one is made
/// for the new file; when it was only unreadable, it still fits a new file.
Future<void> resetLocalDatabase() async {
  final dir = await getApplicationDocumentsDirectory();
  final base = p.join(dir.path, encryptedDatabaseFileName);
  for (final suffix in const ['', '-wal', '-shm', '-journal']) {
    final file = File('$base$suffix');
    if (file.existsSync()) await file.delete();
  }
  AppLogger.warning('Local database deleted after the person confirmed');
}
