import 'package:drift/drift.dart';

/// Status of an upload queue entry
enum UploadQueueStatus {
  pending,
  uploading,
  completed,
  failed,
  cancelled,
}

/// Table for tracking pending image upload operations
/// Ensures uploads survive app restarts and are resumed on reconnection
class UploadQueueEntries extends Table {
  /// Unique upload ID (UUID from the upload request)
  TextColumn get id => text()();

  /// User ID for data isolation
  TextColumn get userId => text()();

  /// Local file path of the image to upload
  TextColumn get localPath => text()();

  /// Target storage path in Firebase Storage
  TextColumn get targetPath => text()();

  /// Content type of the file (e.g., 'image/jpeg')
  TextColumn get contentType =>
      text().withDefault(const Constant('image/jpeg'))();

  /// File size in bytes
  IntColumn get fileSizeBytes => integer()();

  /// Current status of the upload
  TextColumn get status => text().withDefault(const Constant('pending'))();

  /// Number of retry attempts
  IntColumn get retryCount => integer().withDefault(const Constant(0))();

  /// Last error message if upload failed
  TextColumn get lastError => text().nullable()();

  /// When the upload was queued
  DateTimeColumn get queuedAt => dateTime()();

  /// When the last attempt was made
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();

  /// Associated entity ID (e.g., recipe ID)
  TextColumn get entityId => text().nullable()();

  /// Type of entity (e.g., 'recipe', 'profile')
  TextColumn get entityType => text().nullable()();

  /// Additional metadata as JSON string
  TextColumn get metadata => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
