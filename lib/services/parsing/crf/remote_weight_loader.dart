import 'dart:convert';
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/parsing/crf/crf_ingredient_parser.dart';
import 'package:butlery/services/parsing/crf/crf_viterbi_decoder.dart';
import 'package:butlery/services/parsing/remote_model_loader.dart';

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
class RemoteWeightLoader extends RemoteModelLoader {
  static const _storagePath = 'models/crf_ingredient_weights.json';
  static const _localFileName = 'crf_remote_weights.json';
  static const _versionFileName = 'crf_remote_version.txt';

  RemoteWeightLoader({super.storage});

  @override
  String get serviceName => 'RemoteWeightLoader';

  @override
  String get localDirName => 'crf_remote';

  @override
  Duration get checkInterval => const Duration(hours: 6);

  /// Try to load remote weights if newer than the given bundled version.
  ///
  /// Returns a new [CrfIngredientParser] if remote weights are available
  /// and newer than [bundledVersion]. Returns null otherwise.
  ///
  /// This method never throws -- all errors are caught and logged.
  Future<CrfIngredientParser?> tryLoadRemoteWeights({
    required int bundledVersion,
  }) async {
    if (isCheckThrottled) return null;

    startCheck();
    try {
      final localParser =
          await _tryLoadCachedWeights(bundledVersion: bundledVersion);
      if (localParser != null) return localParser;

      if (!canCacheLocally) {
        return await _tryDownloadWeights(bundledVersion: bundledVersion);
      }

      return await _tryDownloadAndCache(bundledVersion: bundledVersion);
    } catch (e) {
      AppLogger.debug('$serviceName: Remote weight check failed: $e');
      return null;
    } finally {
      endCheck();
    }
  }

  Future<CrfIngredientParser?> _tryLoadCachedWeights({
    required int bundledVersion,
  }) async {
    if (!canCacheLocally) return null;

    try {
      final dir = await getCacheDir();
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
        '$serviceName: Using cached remote weights v$cachedVersion '
        '(bundled: v$bundledVersion)',
      );
      return CrfIngredientParser(decoder);
    } catch (e) {
      AppLogger.debug('$serviceName: Could not load cached weights: $e');
      return null;
    }
  }

  Future<CrfIngredientParser?> _tryDownloadAndCache({
    required int bundledVersion,
  }) async {
    try {
      final ref = storage.ref(_storagePath);
      final metadata = await ref.getMetadata();

      final remoteVersion =
          int.tryParse(metadata.customMetadata?['version'] ?? '');
      if (remoteVersion == null || remoteVersion <= bundledVersion) {
        AppLogger.debug(
          '$serviceName: Remote weights not newer '
          '(remote: v$remoteVersion, bundled: v$bundledVersion)',
        );
        return null;
      }

      final data = await ref.getData(5 * 1024 * 1024);
      if (data == null) return null;

      final jsonString = utf8.decode(data);
      final weights = CrfWeights.fromJson(jsonString);
      final decoder = CrfViterbiDecoder(weights: weights);

      final dir = await getCacheDir();
      await dir.create(recursive: true);
      File('${dir.path}/$_localFileName').writeAsStringSync(jsonString);
      File('${dir.path}/$_versionFileName')
          .writeAsStringSync(remoteVersion.toString());

      AppLogger.info(
        '$serviceName: Downloaded remote weights v$remoteVersion '
        '(was bundled v$bundledVersion)',
      );
      return CrfIngredientParser(decoder);
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') {
        AppLogger.debug('$serviceName: No remote weights uploaded yet');
      } else {
        AppLogger.debug('$serviceName: Firebase Storage error: ${e.code}');
      }
      return null;
    }
  }

  Future<CrfIngredientParser?> _tryDownloadWeights({
    required int bundledVersion,
  }) async {
    try {
      final ref = storage.ref(_storagePath);
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
        '$serviceName: Downloaded remote weights v$remoteVersion (web)',
      );
      return CrfIngredientParser(decoder);
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') {
        AppLogger.debug('$serviceName: Firebase Storage error: ${e.code}');
      }
      return null;
    }
  }
}
