import 'dart:convert';
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/parsing/remote_model_loader.dart';

/// Manages download, caching, and versioning of the BERT NER ONNX model.
///
/// The model is downloaded from Firebase Storage on first use and cached
/// in the app's documents directory. Version checking ensures the latest
/// model is used without unnecessary re-downloads.
///
/// File layout in Firebase Storage:
///   models/ingredient_ner/v{N}/model.onnx
///   models/ingredient_ner/v{N}/vocab.txt
///
/// Local cache layout:
///   {appSupportDir}/ner_model/model.onnx
///   {appSupportDir}/ner_model/vocab.txt
///   {appSupportDir}/ner_model/version.txt
class NerModelManager extends RemoteModelLoader {
  static const _storageBasePath = 'models/ingredient_ner';
  static const _modelFileName = 'model.onnx';
  static const _vocabFileName = 'vocab.txt';
  static const _versionFileName = 'version.txt';

  /// Maximum model file size (25MB — safety limit).
  static const _maxModelSize = 25 * 1024 * 1024;

  NerModelManager({super.storage});

  @override
  String get serviceName => 'NerModelManager';

  @override
  String get localDirName => 'ner_model';

  @override
  Duration get checkInterval => const Duration(hours: 12);

  /// Whether a cached model exists locally.
  bool get isModelAvailable => _cachedModelPath != null;

  String? _cachedModelPath;

  /// Ensure model files are available locally.
  ///
  /// Returns [NerModelFiles] with paths and content, or null if the model
  /// couldn't be obtained (no internet, not uploaded yet, etc.).
  ///
  /// This method never throws — all errors are caught and logged.
  Future<NerModelFiles?> ensureModelAvailable() async {
    final cached = await _tryLoadCached();
    if (cached != null) {
      _checkForUpdateInBackground();
      return cached;
    }
    return await _tryDownload();
  }

  Future<NerModelFiles?> _tryLoadCached() async {
    if (!canCacheLocally) return null;

    try {
      final dir = await getCacheDir();
      final modelPath = '${dir.path}/$_modelFileName';

      if (!await File(modelPath).exists()) return null;

      final results = await Future.wait([
        File('${dir.path}/$_vocabFileName').readAsString(),
        File('${dir.path}/$_versionFileName').readAsString(),
      ]);
      final vocabContent = results[0];
      final version = results[1].trim();

      _cachedModelPath = modelPath;
      AppLogger.debug('$serviceName: Using cached model v$version');

      return NerModelFiles(
        modelPath: modelPath,
        vocabContent: vocabContent,
        version: version,
      );
    } catch (e) {
      AppLogger.debug('$serviceName: Cache load failed: $e');
      return null;
    }
  }

  Future<NerModelFiles?> _tryDownload({int? knownVersion}) async {
    if (isCheckThrottled || !canCacheLocally) return null;
    startCheck();

    try {
      final latestVersion = knownVersion ?? await _getLatestVersion();
      if (latestVersion == null) {
        AppLogger.debug('$serviceName: No model versions found in Storage');
        return null;
      }

      final versionPath = '$_storageBasePath/v$latestVersion';

      final modelRef = storage.ref('$versionPath/$_modelFileName');
      final vocabRef = storage.ref('$versionPath/$_vocabFileName');
      final results = await Future.wait([
        modelRef.getData(_maxModelSize),
        vocabRef.getData(5 * 1024 * 1024),
      ]);
      final modelData = results[0];
      final vocabData = results[1];
      if (modelData == null || vocabData == null) {
        AppLogger.warning('$serviceName: Download returned null');
        return null;
      }

      final vocabContent = utf8.decode(vocabData);

      final dir = await getCacheDir();
      await dir.create(recursive: true);

      final modelFile = File('${dir.path}/$_modelFileName');
      await modelFile.writeAsBytes(modelData);

      final vocabFile = File('${dir.path}/$_vocabFileName');
      await vocabFile.writeAsString(vocabContent);

      final versionFile = File('${dir.path}/$_versionFileName');
      await versionFile.writeAsString(latestVersion.toString());

      _cachedModelPath = modelFile.path;

      AppLogger.info(
        '$serviceName: Downloaded and cached model v$latestVersion '
        '(${(modelData.length / (1024 * 1024)).toStringAsFixed(1)} MB)',
      );

      return NerModelFiles(
        modelPath: modelFile.path,
        vocabContent: vocabContent,
        version: latestVersion.toString(),
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
    } finally {
      endCheck();
    }
  }

  @visibleForTesting
  Future<int?> getLatestVersion() => _getLatestVersion();

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

  void _checkForUpdateInBackground() {
    if (isCheckThrottled) return;

    Future(() async {
      try {
        final latestVersion = await _getLatestVersion();
        endCheck();
        if (latestVersion == null) return;

        if (!canCacheLocally) return;
        final dir = await getCacheDir();
        final cachedVersionStr =
            await File('${dir.path}/$_versionFileName').readAsString();
        final cachedVersion = int.tryParse(cachedVersionStr.trim()) ?? 0;

        if (latestVersion > cachedVersion) {
          AppLogger.info(
            '$serviceName: Newer model available (v$latestVersion > v$cachedVersion)',
          );
          await _tryDownload(knownVersion: latestVersion);
        }
      } catch (e) {
        endCheck();
        AppLogger.debug('$serviceName: Update check failed: $e');
      }
    });
  }
}

/// Paths and content for a downloaded NER model.
class NerModelFiles {
  /// Path to the ONNX model file on disk.
  final String modelPath;

  /// Content of vocab.txt for the WordPiece tokenizer.
  final String vocabContent;

  /// Model version string.
  final String version;

  const NerModelFiles({
    required this.modelPath,
    required this.vocabContent,
    required this.version,
  });
}
