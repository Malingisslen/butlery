// lib/services/account/export/export_pagination_helper.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;

/// Renders a Firestore [Timestamp] or a [DateTime] as an ISO-8601 string in
/// UTC, so the printed instant carries a `Z` and reads the same wherever the
/// bundle is opened.
///
/// `Timestamp.toDate()` returns a LOCAL `DateTime`, and `toIso8601String()` on
/// a local `DateTime` emits neither `Z` nor a numeric offset. `.toUtc()` on a
/// `DateTime` already in UTC returns it unchanged, so a source that is already
/// UTC — Firebase Auth's `UserMetadata`, which builds its two stamps with
/// `isUtc: true` — passes through this untouched.
///
/// A String is accepted because writers store an instant as text rather
/// than as a [Timestamp] — `BlockRecord.toFirestore()` and the audit-log
/// callable — so those values reach the bundle without passing through any
/// [Timestamp] branch. An unparseable string yields null rather than a guess,
/// leaving the caller its own fallback.
///
/// Returns null for anything it cannot render as an instant, null included,
/// so a caller decides its own absent-value wording.
String? sanitizeTimestamp(dynamic value) {
  if (value is Timestamp) return value.toDate().toUtc().toIso8601String();
  if (value is DateTime) return value.toUtc().toIso8601String();
  if (value is String) {
    return DateTime.tryParse(value)?.toUtc().toIso8601String();
  }
  return null;
}

/// Rewrites the instants at [paths] of [row] to UTC, in place.
///
/// A path is a dot-separated walk through nested maps (`guardianConsent.at`),
/// so a section NAMES the few fields it knows hold an instant. That narrowness
/// is the whole design: a recursive sweep rewriting every date-shaped string
/// would also rewrite user content that merely looks like a stamp — a recipe
/// step, a pasted source artefact, a chat message — which is why
/// [sanitizeForJson] leaves strings alone and why this runs AFTER it instead of
/// inside it.
///
/// Only a value [sanitizeTimestamp] can render as an instant is replaced, so a
/// field holding something else is left as stored rather than nulled:
/// under-normalising is visible in the bundle, destroying a value is not.
///
/// Needed because a model's `toJson()`/`toFirestore()` can store an instant as
/// a LOCAL `toIso8601String()` — no `Z`, no numeric offset — which reaches the
/// bundle through [sanitizeForJson]'s primitive arm untouched, under an
/// `export_metadata.timezone` line that promises every stamp is UTC.
void normalizeTimestampPaths(Map<String, dynamic> row, List<String> paths) {
  for (final path in paths) {
    final segments = path.split('.');
    dynamic node = row;
    for (var i = 0; i < segments.length - 1 && node is Map; i++) {
      node = node[segments[i]];
    }
    if (node is! Map) continue;
    final leaf = segments.last;
    if (!node.containsKey(leaf)) continue;
    final normalised = sanitizeTimestamp(node[leaf]);
    if (normalised != null) node[leaf] = normalised;
  }
}

/// Normalises every zone-less stamp a serialised RECIPE document carries,
/// under [prefix] ('' for the document root, 'recipe' where a realtime
/// document embeds a whole recipe).
///
/// These are the fields `RecipeSerialization.toFirestore` delegates to a
/// `toJson()` rather than writing as a `Timestamp`. They are enumerated rather
/// than discovered, so a field added to one of those `toJson()` methods is NOT
/// covered until it is named here — and there is deliberately ONE list, because
/// two sections embed this document at different depths.
///
/// Both the `core.`-nested and the flat spelling are carried: the live writer
/// nests, while `RecipeSerialization.fromMap` still reads a flat document as a
/// legacy shape. A path whose parent is absent is skipped, so the spelling that
/// does not apply costs nothing.
void normalizeRecipeDocumentStamps(
  Map<String, dynamic> row, {
  String prefix = '',
}) {
  final p = prefix.isEmpty ? '' : '$prefix.';
  normalizeTimestampPaths(row, [
    '${p}core.sourceArtefact.fetchedAt',
    '${p}core.tagOverrides.lastEditedAt',
    '${p}sourceArtefact.fetchedAt',
    '${p}tagOverrides.lastEditedAt',
    '${p}realtimeData.lastEditedAt',
  ]);
  // Keys are uids, so there is no leaf to name.
  normalizeTimestampMapValues(row, '${p}realtimeData.lastSeenAt');
}

/// Normalises every VALUE of the map at [path], for a field whose keys are
/// data rather than a fixed name — a uid-keyed map of instants cannot be
/// addressed by [normalizeTimestampPaths], which needs a leaf to name.
///
/// A value [sanitizeTimestamp] cannot render is left as stored, for the same
/// reason: under-normalising is visible in the bundle, destroying a value is
/// not.
void normalizeTimestampMapValues(Map<String, dynamic> row, String path) {
  final segments = path.split('.');
  dynamic node = row;
  for (var i = 0; i < segments.length - 1 && node is Map; i++) {
    node = node[segments[i]];
  }
  if (node is! Map) return;
  final target = node[segments.last];
  if (target is! Map) return;
  for (final key in target.keys.toList()) {
    final normalised = sanitizeTimestamp(target[key]);
    if (normalised != null) target[key] = normalised;
  }
}

/// Sanitizes Firestore data for JSON serialization.
/// Converts Timestamp, GeoPoint, DocumentReference, and other
/// non-JSON-serializable types to safe representations.
dynamic sanitizeForJson(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return sanitizeTimestamp(value);
  if (value is DateTime) return sanitizeTimestamp(value);
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

/// Narrows a raw Firestore document to the fields an export section declares.
///
/// An ALLOWLIST, so the projection fails CLOSED: a field [keep] does not name
/// is withheld, including one nobody has decided about yet. Neither
/// `recipe_comments` nor `recipe_ratings` bounds its create limb with
/// `keys().hasOnly`, so a hand-rolled client can store a field of its own —
/// which this drops, and which is why every section using this owes its reader
/// a `data_minimisation` sentence saying so.
///
/// The mechanic lives here rather than in each section so the two
/// comments-and-ratings sections share one loop (`content_export_manager.dart`
/// carries another). The
/// FIELD LISTS stay with their sections: the list is the privacy decision and
/// belongs where that decision is reviewed, the loop is not.
Map<String, dynamic> projectExportFields(Object? data, List<String> keep) {
  if (data is! Map) return const {};
  return {
    for (final field in keep)
      if (data.containsKey(field)) field: data[field],
  };
}

/// One capped export read: the rows to include, plus whether the source
/// actually held more than the cap.
///
/// [truncated] is decided by an N+1 probe, never by comparing [items].length
/// to the cap — see [ExportPaginationHelper.fetchCapped].
class CappedExport<T> {
  const CappedExport({required this.items, required this.truncated});

  final List<T> items;
  final bool truncated;

  int get length => items.length;
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
        '[$_logTag] Fetched batch: ${snapshot.docs.length} docs (total: $totalFetched)',
      );

      // If batch returned fewer than requested, we've reached the end
      if (snapshot.docs.length < batchSize) {
        break;
      }
    }

    if (totalFetched >= maxDocuments) {
      app_logger.AppLogger.warning(
        '[$_logTag] Export hit max document limit ($maxDocuments). Some data may be truncated.',
      );
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
        .map(
          (doc) => {
            idField: doc.id,
            ...doc.data(),
          },
        )
        .toList();
  }

  /// Get document count without fetching all documents
  static Future<int> getDocumentCount(Query<Map<String, dynamic>> query) async {
    try {
      final countQuery = await query.count().get();
      return countQuery.count ?? 0;
    } catch (e) {
      app_logger.AppLogger.warning(
        '[$_logTag] Count query failed, falling back to limit estimate: $e',
      );
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
    // BUT-1698: pinned at the repository default this section was already
    // riding, so declaring the cap here adds the truncation probe without
    // shrinking anyone's export.
    'feedback': 1000,
    'consent_records': 100,
    'weekly_menu_plans': 260, // ~5 years × 52 weeks
    'pantry_items': 1000,
    'recipe_cook_events': 2000, // ~5 years of daily cooking
    // BUT-1662: pinned at the value they already resolved to via the
    // defaultBatchSize fallback, so the truncation probe keys off a declared
    // contract rather than a coincidence. Behaviour is unchanged.
    'cook_snaps': 500,
    'activity_events': 500,
    // BUT-1450: notification analytics (Art. 15 export). History + delivery
    // can be high-volume, so cap explicitly rather than fall through to 10k.
    'notification_history': 2000,
    'notification_delivery': 1000,
    'notification_batches': 500,
    'notification_engagement': 1000,
    // Explicit so the export cap is a defined contract, not a fallback
    // coincidence — the truncation signal in PreferencesExportManager keys off
    // this value (BUT-1562).
    'user_notifications': 500,
    // BUT-1957: the `users/{uid}/notifications` SUBCOLLECTION — a different
    // collection from the line above, and its own key so the two truncation
    // probes cannot key off each other's cap.
    'delivered_notifications': 500,
    // Increment 5: pooled-rating events (one per pool the user voted in).
    'canonical_rating_events': 1000,
    // BUT-1732: pinned at the value the section already resolved to via the
    // defaultBatchSize fallback, so its three truncation probes key off a
    // declared contract rather than a coincidence. Behaviour is unchanged.
    'shared_shopping_lists': 500,
    // BUT-2003: the three `users/{uid}` subcollections BUT-1992 added to the
    // bundle. Pinned at the caps those reads already carried as their own
    // default arguments, so declaring them here adds the N+1 truncation probe
    // without shrinking anyone's export. Three keys rather than one, because
    // the three collections grow at completely different rates and a shared
    // key would make one section's cap decide another's.
    'user_ingredients': 500,
    'user_onboarding': 50,
    'user_acquisition': 50,
    // The `settings` collection, `preferences` INCLUDED — the query is not
    // filtered, so the section additionally reads that one document by id
    // (`exportUserPreferencesDocument`) and drops it from the page afterwards
    // when both reads found it.
    'user_settings': 50,
    // BUT-2028: ingredient suggestions. Declared with the section rather than
    // after it, so the truncation probe keys off a stated cap rather than the
    // `defaultBatchSize` fallback. 500 matches `cook_snaps`, and is also what
    // `defaultBatchSize` is today — so deleting this line changes no behaviour
    // and loses only the contract, which is why the test asserts the entry
    // resolves to 500 (null would not).
    //
    // The binding itself stays unprovable while the two numbers agree: the
    // section passes the literal `'ingredient_suggestions'`, and a typo there
    // falls back to 500 with nothing reddening. A cap different from
    // `defaultBatchSize` is what would make key, value and wiring all pinnable.
    'ingredient_suggestions': 500,
  };

  /// Get export limit for content type
  static int getLimitForType(String type) {
    return exportLimits[type] ?? defaultBatchSize;
  }

  /// Run one capped export read with an N+1 truncation probe.
  ///
  /// [fetch] receives `cap + 1` so "exactly `cap` rows exist" stays
  /// distinguishable from "more than `cap` exist, some omitted". Deriving the
  /// flag from the returned length instead (`length >= cap`) cannot tell those
  /// apart and stamps a COMPLETE bundle as truncated — a false incompleteness
  /// claim on a GDPR Art. 15/20 export (BUT-1562; generalized here in
  /// BUT-1662, which also retires the merged-length-vs-one-cap miscount: a
  /// section fed by several sub-queries probes each one and ORs the flags).
  ///
  /// Costs exactly one extra document read per section.
  static Future<CappedExport<T>> fetchCapped<T>({
    required String type,
    required Future<List<T>> Function(int maxDocuments) fetch,
  }) async {
    final cap = getLimitForType(type);
    final rows = await fetch(cap + 1);
    final truncated = rows.length > cap;
    return CappedExport(
      items: truncated ? rows.sublist(0, cap) : rows,
      truncated: truncated,
    );
  }
}
