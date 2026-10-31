/// Repository for loading and caching menu lexicon overrides from Firestore.
///
/// Mirrors the [SiteConfigRepository] pattern: one-shot `.get()` with a
/// 1-hour TTL cache. Returns partial data (only categories with Firestore
/// overrides); the caller merges with [CodeLexiconProvider] defaults via
/// [Lexicon.mergedWith].
library;

import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/menu/parser/lexicon_provider.dart';

class FirebaseMenuLexiconRepository {
  final FirebaseFirestore _firestore;

  /// Cached result from last Firestore fetch.
  Map<LexiconCategory, Map<String, String>>? _cache;
  DateTime? _cachedAt;

  static const _cacheDuration = Duration(hours: 1);

  FirebaseMenuLexiconRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(FirestoreCollections.menuLexicon);

  /// Loads all lexicon override categories from Firestore.
  ///
  /// Returns a map of category → entries. Categories not present in
  /// Firestore are omitted (the caller falls back to code defaults).
  Future<Map<LexiconCategory, Map<String, String>>> loadOverrides() async =>
      (await loadOverridesWithStatus()).overrides;

  /// Like [loadOverrides], but says whether the fetch failed, so a caller can
  /// tell "no overrides exist" from "the overrides could not be read".
  Future<({Map<LexiconCategory, Map<String, String>> overrides, bool failed})>
  loadOverridesWithStatus() async {
    // TTL cache: skip Firestore if fresh enough.
    if (_cache != null && _cachedAt != null) {
      if (clock.now().difference(_cachedAt!) < _cacheDuration) {
        return (overrides: _cache!, failed: false);
      }
    }

    try {
      final snapshot = await _collection.get();
      final result = <LexiconCategory, Map<String, String>>{};

      for (final doc in snapshot.docs) {
        final category = _parseCategory(doc.id);
        if (category == null) {
          AppLogger.warning(
            'MenuLexiconRepository: skipping unknown category "${doc.id}"',
          );
          continue;
        }

        final data = doc.data();
        final entries = data['entries'];
        if (entries is! Map) {
          AppLogger.warning(
            'MenuLexiconRepository: skipping "${doc.id}" — '
            'entries field is not a Map',
          );
          continue;
        }

        final typed = <String, String>{};
        for (final entry in entries.entries) {
          if (entry.key is String && entry.value is String) {
            typed[entry.key as String] = entry.value as String;
          }
        }
        if (typed.isNotEmpty) {
          result[category] = typed;
        }
      }

      // Offline, persistence answers get() from the device cache without an
      // error, possibly empty on a fresh install. That is not the server's
      // answer, so it is neither cached here nor reported as complete.
      if (snapshot.metadata.isFromCache) {
        return (overrides: result, failed: true);
      }
      _cache = result;
      _cachedAt = clock.now();
      if (result.isNotEmpty) {
        AppLogger.debug(
          'MenuLexiconRepository: loaded ${result.length} category overrides',
        );
      }
      return (overrides: result, failed: false);
    } catch (e) {
      AppLogger.warning(
        'MenuLexiconRepository: Firestore unavailable, '
        'falling back to code lexicon: $e',
      );
      return (
        overrides: const <LexiconCategory, Map<String, String>>{},
        failed: true,
      );
    }
  }

  /// Forces the next [loadOverrides] call to re-fetch from Firestore.
  void clearCache() {
    _cache = null;
    _cachedAt = null;
  }

  static final _categoryByName = LexiconCategory.values.asNameMap();

  static LexiconCategory? _parseCategory(String docId) =>
      _categoryByName[docId];
}
