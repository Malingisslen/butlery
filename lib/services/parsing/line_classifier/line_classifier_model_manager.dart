import 'dart:convert';
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/parsing/_expected_model_hashes.dart';
import 'package:butlery/services/parsing/remote_model_loader.dart';

/// Manages download, caching, and versioning of the line classifier ONNX model.
///
/// Same pattern as [NerModelManager] — downloads from Firebase Storage,
/// caches locally, checks for updates every 12 hours.
///
/// File layout in Firebase Storage:
///   models/line_classifier/v{N}/model.onnx
///   models/line_classifier/v{N}/vocab.txt
///   models/line_classifier/latest_version.txt
class LineClassifierModelManager extends RemoteModelLoader {
  static const _storageBasePath = 'models/line_classifier';
  static const _modelFileName = 'model.onnx';
  static const _vocabFileName = 'vocab.txt';
  static const _versionFileName = 'version.txt';

  static const _maxModelSize = 25 * 1024 * 1024;
  static const _maxVocabSize = 5 * 1024 * 1024;

  LineClassifierModelManager({super.storage});

  @override
  String get serviceName => 'LineClassifierModelManager';

  @override
  String get localDirName => 'line_classifier_model';

  @override
  Duration get checkInterval => const Duration(hours: 12);

  bool get isModelAvailable => _cachedModelPath != null;

  String? _cachedModelPath;

  /// Ensure model files are available locally.
  ///
  /// Returns paths and vocab content, or null if unavailable.
  Future<LineClassifierModelFiles?> ensureModelAvailable() async {
    final cached = await _tryLoadCached();
    if (cached != null) {
      _checkForUpdateInBackground(cached.version);
      return cached;
    }
    return await _tryDownload();
  }

  Future<LineClassifierModelFiles?> _tryLoadCached() async {
    if (!canCacheLocally) return null;

    try {
      final dir = await getCacheDir();
      final modelPath = '${dir.path}/$_modelFileName';

      final modelFile = File(modelPath);
      if (!await modelFile.exists()) return null;

      final fileSize = await modelFile.length();
      if (fileSize == 0 || fileSize > _maxModelSize) return null;

      final vocabFile = File('${dir.path}/$_vocabFileName');
      final versionFile = File('${dir.path}/$_versionFileName');
      if (!await vocabFile.exists() || !await versionFile.exists()) return null;

      // Clean up any leftover .tmp files from interrupted writes
      final tmpModel = File('$modelPath.tmp');
      if (await tmpModel.exists()) await tmpModel.delete();

      final [vocabContent, versionStr] = await Future.wait([
        vocabFile.readAsString(),
        versionFile.readAsString(),
      ]);
      final version = int.tryParse(versionStr.trim());
      if (version == null) return null;

      _cachedModelPath = modelPath;
      AppLogger.debug('$serviceName: Using cached model v$version');

      return LineClassifierModelFiles(
        modelPath: modelPath,
        vocabContent: vocabContent,
        version: version,
      );
    } catch (e) {
      AppLogger.debug('$serviceName: Cache load failed: $e');
      return null;
    }
  }

  Future<LineClassifierModelFiles?> _tryDownload() async {
    if (!canCacheLocally || isCheckThrottled) return null;
    startCheck();
    try {
      return await _downloadModel();
    } finally {
      endCheck();
    }
  }

  Future<LineClassifierModelFiles?> _downloadModel({int? knownVersion}) async {
    try {
      final latestVersion = knownVersion ?? await _getLatestVersion();
      if (latestVersion == null) {
        AppLogger.debug('$serviceName: No model versions found in Storage');
        return null;
      }

      final versionPath = '$_storageBasePath/v$latestVersion';

      final modelRef = storage.ref('$versionPath/$_modelFileName');
      final vocabRef = storage.ref('$versionPath/$_vocabFileName');
      final [modelData, vocabData] = await Future.wait([
        modelRef.getData(_maxModelSize),
        vocabRef.getData(_maxVocabSize),
      ]);
      if (modelData == null || vocabData == null) {
        AppLogger.warning('$serviceName: Download returned null');
        return null;
      }

      // BUT-792: verify SHA-256 before any disk write.
      final ok = await verifyModelDownload(
        modelBytes: modelData,
        version: latestVersion,
        hashRegistry: kExpectedLineClassifierModelHashes,
        modelName: 'line_classifier',
        registryConstantName: 'kExpectedLineClassifierModelHashes',
      );
      if (!ok) return null;

      final vocabContent = utf8.decode(vocabData);

      final dir = await getCacheDir();
      await dir.create(recursive: true);

      final modelPath = '${dir.path}/$_modelFileName';
      final vocabPath = '${dir.path}/$_vocabFileName';
      final localVersionPath = '${dir.path}/$_versionFileName';

      final modelTmpFile = File('$modelPath.tmp');
      await modelTmpFile.writeAsBytes(modelData);

      final vocabTmpFile = File('$vocabPath.tmp');
      await vocabTmpFile.writeAsString(vocabContent);

      // Rename atomically (model + vocab first, version LAST as commit marker)
      await modelTmpFile.rename(modelPath);
      await vocabTmpFile.rename(vocabPath);

      // Version file written last — if it exists, all other files are complete
      final versionTmpFile = File('$localVersionPath.tmp');
      await versionTmpFile.writeAsString(latestVersion.toString());
      await versionTmpFile.rename(localVersionPath);

      _cachedModelPath = modelPath;

      AppLogger.info(
        '$serviceName: Downloaded and cached model v$latestVersion '
        '(${(modelData.length / (1024 * 1024)).toStringAsFixed(1)} MB)',
      );

      return LineClassifierModelFiles(
        modelPath: modelPath,
        vocabContent: vocabContent,
        version: latestVersion,
      );
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') {
        AppLogger.debug('$serviceName: No model uploaded yet');
      } else {
        AppLogger.debug('$serviceName: Storage error: ${e.code}');
      }
      return null;
    } catch (e) {
      AppLogger.debug('$serviceName: Download failed: $e');
      return null;
    }
  }

  Future<int?> _getLatestVersion() async {
    try {
      final metaRef = storage.ref('$_storageBasePath/latest_version.txt');
      final data = await metaRef.getData(1024);
      if (data != null) {
        final version = int.tryParse(utf8.decode(data).trim());
        if (version != null) return version;
      }
    } on FirebaseException {
      // Fall back to checking v1 directly
    }

    try {
      final ref = storage.ref('$_storageBasePath/v1/$_modelFileName');
      await ref.getMetadata();
      return 1;
    } on FirebaseException {
      return null;
    }
  }

  void _checkForUpdateInBackground(int cachedVersion) {
    if (isCheckThrottled || !canCacheLocally) return;
    startCheck();

    Future(() async {
      try {
        final latestVersion = await _getLatestVersion();
        if (latestVersion == null) return;

        if (latestVersion > cachedVersion) {
          AppLogger.info(
            '$serviceName: Newer model available '
            '(v$latestVersion > v$cachedVersion)',
          );
          await _downloadModel(knownVersion: latestVersion);
        }
      } catch (e) {
        AppLogger.debug('$serviceName: Update check failed: $e');
      } finally {
        endCheck();
      }
    });
  }
}

/// Paths and content for a downloaded line classifier model.
class LineClassifierModelFiles {
  final String modelPath;
  final String vocabContent;
  final int version;

  const LineClassifierModelFiles({
    required this.modelPath,
    required this.vocabContent,
    required this.version,
  });
}
