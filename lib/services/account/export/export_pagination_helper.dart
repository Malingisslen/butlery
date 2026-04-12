// lib/services/account/export/export_pagination_helper.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;

/// Sanitizes Firestore data for JSON serialization.
/// Converts Timestamp, GeoPoint, DocumentReference, and other
/// non-JSON-serializable types to safe representations.
dynamic sanitizeForJson(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate().toIso8601String();
  if (value is DateTime) return value.toIso8601String();
  if (value is GeoPoint) {
    return {'latitude': value.latitude, 'longitude': value.longitude};
  }
  if (value is DocumentReference) return value.path;
  if (value is Blob) return '[binary data: ${value.bytes.length} bytes]';
  if (value is Map) {
    return value.map((k, v) => MapEntry(k.toString(), sanitizeForJson(v)));
  }
  if (value is List) return value.map(sanitizeForJson).toList();
  // Primitives (String, int, double, bool) pass through
  return value;
}

/// Helper for paginated exports to prevent timeout on large datasets.
/// Implements cursor-based pagination for GDPR data exports.
///
/// Usage:
/// ```dart
/// final results = await ExportPaginationHelper.paginatedQuery(
///   query: firestore.collection('recipes').where('userId', isEqualTo: userId),
///   batchSize: 500,
///   maxDocuments: 5000,
/// );
/// ```
class ExportPaginationHelper {
  static const String _logTag = 'ExportPaginationHelper';

  /// Default batch size for paginated queries
  static const int defaultBatchSize = 500;

  /// Maximum documents to export per query type (safety limit)
  static const int defaultMaxDocuments = 10000;

  /// Execute a paginated query with cursor-based pagination
  ///
  /// [query] - Base Firestore query (without limit)
  /// [batchSize] - Number of documents per batch (default: 500)
  /// [maxDocuments] - Maximum total documents to fetch (default: 10000)
  ///
  /// Returns list of document snapshots from all batches
  static Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      paginatedQuery({
    required Query<Map<String, dynamic>> query,
    int batchSize = defaultBatchSize,
    int maxDocuments = defaultMaxDocuments,
  }) async {
    final results = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    DocumentSnapshot? lastDoc;
    var totalFetched = 0;

    while (totalFetched < maxDocuments) {
      var batchQuery = query.limit(batchSize);

      if (lastDoc != null) {
        batchQuery = batchQuery.startAfterDocument(lastDoc);
      }

      final snapshot = await batchQuery.get();

      if (snapshot.docs.isEmpty) {
        break;
      }

      results.addAll(snapshot.docs);
      totalFetched += snapshot.docs.length;
      lastDoc = snapshot.docs.last;

      app_logger.AppLogger.debug(
          '[$_logTag] Fetched batch: ${snapshot.docs.length} docs (total: $totalFetched)');

      // If batch returned fewer than requested, we've reached the end
      if (snapshot.docs.length < batchSize) {
        break;
      }
    }

    if (totalFetched >= maxDocuments) {
      app_logger.AppLogger.warning(
          '[$_logTag] Export hit max document limit ($maxDocuments). Some data may be truncated.');
    }

    return results;
  }

  /// Export collection reference with pagination (for user subcollections)
  static Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      paginatedCollectionExport({
    required CollectionReference<Map<String, dynamic>> collection,
    int batchSize = defaultBatchSize,
    int maxDocuments = defaultMaxDocuments,
  }) async {
    return paginatedQuery(
      query: collection,
      batchSize: batchSize,
      maxDocuments: maxDocuments,
    );
  }

  /// Export with mapping function for transformation
  static Future<List<T>> paginatedExport<T>({
    required Query<Map<String, dynamic>> query,
    required T Function(QueryDocumentSnapshot<Map<String, dynamic>>) mapper,
    int batchSize = defaultBatchSize,
    int maxDocuments = defaultMaxDocuments,
  }) async {
    final docs = await paginatedQuery(
      query: query,
      batchSize: batchSize,
      maxDocuments: maxDocuments,
    );

    return docs.map(mapper).toList();
  }

  /// Export documents as raw maps with IDs
  static Future<List<Map<String, dynamic>>> paginatedExportWithIds({
    required Query<Map<String, dynamic>> query,
    String idField = 'id',
    int batchSize = defaultBatchSize,
    int maxDocuments = defaultMaxDocuments,
  }) async {
    final docs = await paginatedQuery(
      query: query,
      batchSize: batchSize,
      maxDocuments: maxDocuments,
    );

    return docs
        .map((doc) => {
              idField: doc.id,
              ...doc.data(),
            })
        .toList();
  }

  /// Get document count without fetching all documents
  static Future<int> getDocumentCount(Query<Map<String, dynamic>> query) async {
    try {
      final countQuery = await query.count().get();
      return countQuery.count ?? 0;
    } catch (e) {
      app_logger.AppLogger.warning(
          '[$_logTag] Count query failed, falling back to limit estimate: $e');
      // Fallback: fetch minimal data to estimate
      final snapshot = await query.limit(1).get();
      return snapshot.docs.isEmpty ? 0 : -1; // -1 indicates unknown
    }
  }

  /// Export limits for different content types
  static const Map<String, int> exportLimits = {
    'recipes': 2000,
    'menus': 1000,
    'shopping_lists': 500,
    'personal_tags': 500,
    'personal_tag_groups': 100,
    'friends': 1000,
    'friend_requests': 500,
    'conversations': 500,
    'messages_per_conversation': 1000,
    'comments': 1000,
    'ratings': 1000,
    'consent_records': 100,
    'weekly_menu_plans': 260, // ~5 years × 52 weeks
    'pantry_items': 1000,
  };

  /// Get export limit for content type
  static int getLimitForType(String type) {
    return exportLimits[type] ?? defaultBatchSize;
  }
}
