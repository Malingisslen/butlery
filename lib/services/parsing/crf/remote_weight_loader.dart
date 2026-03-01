import 'dart:convert';
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/parsing/crf/crf_ingredient_parser.dart';
import 'package:butlery/services/parsing/crf/crf_viterbi_decoder.dart';

/// Downloads updated CRF weights from Firebase Storage when available.
///
/// The active learning loop:
/// 1. User corrections are stored in Firestore (ParsingCorrectionRepository)
/// 2. A Cloud Function periodically retrains the CRF model from corrections
/// 3. New weights are uploaded to Firebase Storage with a version number
/// 4. This loader checks for newer weights and downloads them
///
/// Weights are cached locally so the app works offline after first download.
/// The loader is fire-and-forget -- failures never block parsing.
class RemoteWeightLoader {
  static const _storagePath = 'models/crf_ingredient_weights.json';
  static const _localFileName = 'crf_remote_weights.json';
  static const _versionFileName = 'crf_remote_version.txt';
  static const _serviceName = 'RemoteWeightLoader';

  /// Minimum time between remote checks (avoid hammering Storage).
  static const _checkInterval = Duration(hours: 6);

  final FirebaseStorage? _injectedStorage;
  DateTime? _lastCheckTime;
  bool _checking = false;

  RemoteWeightLoader({FirebaseStorage? storage}) : _injectedStorage = storage;

  FirebaseStorage get _storage => _injectedStorage ?? FirebaseStorage.instance;

  /// Try to load remote weights if newer than the given bundled version.
  ///
  /// Returns a new [CrfIngredientParser] if remote weights are available
  /// and newer than [bundledVersion]. Returns null otherwise.
  ///
  /// This method never throws -- all errors are caught and logged.
  Future<CrfIngredientParser?> tryLoadRemoteWeights({
    required int bundledVersion,
  }) async {
    // Don't check too frequently
    if (_checking) return null;
    if (_lastCheckTime != null &&
        DateTime.now().difference(_lastCheckTime!) < _checkInterval) {
      return null;
    }

    _checking = true;
    try {
      // First try locally cached weights (fast, offline-capable)
      final localParser =
          await _tryLoadCachedWeights(bundledVersion: bundledVersion);
      if (localParser != null) {
        return localParser;
      }

      // Then try downloading from Firebase Storage
      if (kIsWeb) {
        // Web doesn't support path_provider file caching
        return await _tryDownloadWeights(bundledVersion: bundledVersion);
      }

      return await _tryDownloadAndCache(bundledVersion: bundledVersion);
    } catch (e) {
      AppLogger.debug('$_serviceName: Remote weight check failed: $e');
      return null;
    } finally {
      _lastCheckTime = DateTime.now();
      _checking = false;
    }
  }

  /// Load weights from local cache if newer than bundled.
  Future<CrfIngredientParser?> _tryLoadCachedWeights({
    required int bundledVersion,
  }) async {
    if (kIsWeb) return null;

    try {
      final dir = await getApplicationSupportDirectory();
      final versionFile = File('${dir.path}/$_versionFileName');
      final weightsFile = File('${dir.path}/$_localFileName');

      if (!versionFile.existsSync() || !weightsFile.existsSync()) {
        return null;
      }

      final cachedVersion = int.tryParse(versionFile.readAsStringSync().trim());
      if (cachedVersion == null || cachedVersion <= bundledVersion) {
        return null;
      }

      final jsonString = weightsFile.readAsStringSync();
      final weights = CrfWeights.fromJson(jsonString);
      final decoder = CrfViterbiDecoder(weights: weights);

      AppLogger.info(
        '$_serviceName: Using cached remote weights v$cachedVersion '
        '(bundled: v$bundledVersion)',
      );
      return CrfIngredientParser(decoder);
    } catch (e) {
      AppLogger.debug('$_serviceName: Could not load cached weights: $e');
      return null;
    }
  }

  /// Download weights from Firebase Storage, cache locally.
  Future<CrfIngredientParser?> _tryDownloadAndCache({
    required int bundledVersion,
  }) async {
    try {
      final ref = _storage.ref(_storagePath);
      final metadata = await ref.getMetadata();

      final remoteVersion =
          int.tryParse(metadata.customMetadata?['version'] ?? '');
      if (remoteVersion == null || remoteVersion <= bundledVersion) {
        AppLogger.debug(
          '$_serviceName: Remote weights not newer '
          '(remote: v$remoteVersion, bundled: v$bundledVersion)',
        );
        return null;
      }

      // Download to memory
      final data = await ref.getData(5 * 1024 * 1024); // 5MB max
      if (data == null) return null;

      final jsonString = utf8.decode(data);
      final weights = CrfWeights.fromJson(jsonString);
      final decoder = CrfViterbiDecoder(weights: weights);

      // Cache locally
      final dir = await getApplicationSupportDirectory();
      File('${dir.path}/$_localFileName').writeAsStringSync(jsonString);
      File('${dir.path}/$_versionFileName')
          .writeAsStringSync(remoteVersion.toString());

      AppLogger.info(
        '$_serviceName: Downloaded remote weights v$remoteVersion '
        '(was bundled v$bundledVersion)',
      );
      return CrfIngredientParser(decoder);
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') {
        AppLogger.debug('$_serviceName: No remote weights uploaded yet');
      } else {
        AppLogger.debug('$_serviceName: Firebase Storage error: ${e.code}');
      }
      return null;
    }
  }

  /// Download weights on web (no local caching).
  Future<CrfIngredientParser?> _tryDownloadWeights({
    required int bundledVersion,
  }) async {
    try {
      final ref = _storage.ref(_storagePath);
      final metadata = await ref.getMetadata();

      final remoteVersion =
          int.tryParse(metadata.customMetadata?['version'] ?? '');
      if (remoteVersion == null || remoteVersion <= bundledVersion) {
        return null;
      }

      final data = await ref.getData(5 * 1024 * 1024);
      if (data == null) return null;

      final jsonString = utf8.decode(data);
      final weights = CrfWeights.fromJson(jsonString);
      final decoder = CrfViterbiDecoder(weights: weights);

      AppLogger.info(
        '$_serviceName: Downloaded remote weights v$remoteVersion (web)',
      );
      return CrfIngredientParser(decoder);
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') {
        AppLogger.debug('$_serviceName: Firebase Storage error: ${e.code}');
      }
      return null;
    }
  }
}
