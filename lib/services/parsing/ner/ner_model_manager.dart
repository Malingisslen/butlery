import 'dart:convert';
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'package:butlery/core/utils/logger.dart';

/// Manages download, caching, and versioning of the BERT NER ONNX model.
///
/// The model is downloaded from Firebase Storage on first use and cached
/// in the app's documents directory. Version checking ensures the latest
/// model is used without unnecessary re-downloads.
///
/// File layout in Firebase Storage:
///   models/ingredient_ner/v{N}/model.onnx
///   models/ingredient_ner/v{N}/vocab.txt
///   models/ingredient_ner/v{N}/model_info.json
///
/// Local cache layout:
///   {appSupportDir}/ner_model/model.onnx
///   {appSupportDir}/ner_model/vocab.txt
///   {appSupportDir}/ner_model/version.txt
class NerModelManager {
  static const _serviceName = 'NerModelManager';
  static const _storageBasePath = 'models/ingredient_ner';
  static const _localDirName = 'ner_model';
  static const _modelFileName = 'model.onnx';
  static const _vocabFileName = 'vocab.txt';
  static const _versionFileName = 'version.txt';

  /// Maximum model file size (25MB — safety limit).
  static const _maxModelSize = 25 * 1024 * 1024;

  /// Minimum time between remote version checks.
  static const _checkInterval = Duration(hours: 12);

  final FirebaseStorage? _injectedStorage;
  DateTime? _lastCheckTime;
  bool _checking = false;
  Directory? _modelDir;

  NerModelManager({FirebaseStorage? storage}) : _injectedStorage = storage;

  FirebaseStorage get _storage => _injectedStorage ?? FirebaseStorage.instance;

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
    // Try cached version first
    final cached = await _tryLoadCached();
    if (cached != null) {
      // Trigger background update check
      _checkForUpdateInBackground();
      return cached;
    }

    // Download from Firebase Storage
    return await _tryDownload();
  }

  /// Load model from local cache.
  Future<NerModelFiles?> _tryLoadCached() async {
    if (kIsWeb) return null; // Web doesn't support file caching

    try {
      final dir = await _getModelDir();
      final modelPath = '${dir.path}/$_modelFileName';

      // Check model file first — cheapest check and most likely to fail
      if (!await File(modelPath).exists()) return null;

      // Read vocab and version in parallel — catch handles missing files
      final results = await Future.wait([
        File('${dir.path}/$_vocabFileName').readAsString(),
        File('${dir.path}/$_versionFileName').readAsString(),
      ]);
      final vocabContent = results[0];
      final version = results[1].trim();

      _cachedModelPath = modelPath;
      AppLogger.debug('$_serviceName: Using cached model v$version');

      return NerModelFiles(
        modelPath: modelPath,
        vocabContent: vocabContent,
        version: version,
      );
    } catch (e) {
      AppLogger.debug('$_serviceName: Cache load failed: $e');
      return null;
    }
  }

  /// Download model from Firebase Storage and cache locally.
  ///
  /// On web, returns null — ONNX Runtime requires a different loading approach.
  Future<NerModelFiles?> _tryDownload({int? knownVersion}) async {
    if (_checking || kIsWeb) return null;
    _checking = true;

    try {
      // Find the latest version
      final latestVersion = knownVersion ?? await _getLatestVersion();
      if (latestVersion == null) {
        AppLogger.debug('$_serviceName: No model versions found in Storage');
        return null;
      }

      final versionPath = '$_storageBasePath/v$latestVersion';

      // Download model and vocab in parallel
      final modelRef = _storage.ref('$versionPath/$_modelFileName');
      final vocabRef = _storage.ref('$versionPath/$_vocabFileName');
      final results = await Future.wait([
        modelRef.getData(_maxModelSize),
        vocabRef.getData(5 * 1024 * 1024), // 5MB max
      ]);
      final modelData = results[0];
      final vocabData = results[1];
      if (modelData == null || vocabData == null) {
        AppLogger.warning('$_serviceName: Download returned null');
        return null;
      }

      final vocabContent = utf8.decode(vocabData);

      final dir = await _getModelDir();
      await dir.create(recursive: true);

      final modelFile = File('${dir.path}/$_modelFileName');
      await modelFile.writeAsBytes(modelData);

      final vocabFile = File('${dir.path}/$_vocabFileName');
      await vocabFile.writeAsString(vocabContent);

      final versionFile = File('${dir.path}/$_versionFileName');
      await versionFile.writeAsString(latestVersion.toString());

      _cachedModelPath = modelFile.path;

      AppLogger.info(
        '$_serviceName: Downloaded and cached model v$latestVersion '
        '(${(modelData.length / (1024 * 1024)).toStringAsFixed(1)} MB)',
      );

      return NerModelFiles(
        modelPath: modelFile.path,
        vocabContent: vocabContent,
        version: latestVersion.toString(),
      );
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') {
        AppLogger.debug('$_serviceName: No model uploaded yet');
      } else {
        AppLogger.debug('$_serviceName: Storage error: ${e.code}');
      }
      return null;
    } catch (e) {
      AppLogger.debug('$_serviceName: Download failed: $e');
      return null;
    } finally {
      _lastCheckTime = DateTime.now();
      _checking = false;
    }
  }

  /// Get the latest model version number from Firebase Storage metadata.
  Future<int?> _getLatestVersion() async {
    try {
      // Check the base path for a 'latest_version' metadata file
      final metaRef = _storage.ref('$_storageBasePath/latest_version.txt');
      final data = await metaRef.getData(1024);
      if (data != null) {
        final version = int.tryParse(utf8.decode(data).trim());
        if (version != null) return version;
      }
    } on FirebaseException {
      // Fall back to checking v1 directly
    }

    // Default: check if v1 exists
    try {
      final ref = _storage.ref('$_storageBasePath/v1/$_modelFileName');
      await ref.getMetadata();
      return 1;
    } on FirebaseException {
      return null;
    }
  }

  /// Background check for newer model versions.
  void _checkForUpdateInBackground() {
    if (_checking) return;
    if (_lastCheckTime != null &&
        DateTime.now().difference(_lastCheckTime!) < _checkInterval) {
      return;
    }

    Future(() async {
      try {
        final latestVersion = await _getLatestVersion();
        _lastCheckTime = DateTime.now(); // Record check regardless of result
        if (latestVersion == null) return;

        // Read current cached version
        if (kIsWeb) return;
        final dir = await _getModelDir();
        final cachedVersionStr =
            await File('${dir.path}/$_versionFileName').readAsString();
        final cachedVersion = int.tryParse(cachedVersionStr.trim()) ?? 0;

        if (latestVersion > cachedVersion) {
          AppLogger.info(
            '$_serviceName: Newer model available (v$latestVersion > v$cachedVersion)',
          );
          await _tryDownload(knownVersion: latestVersion);
        }
      } catch (e) {
        _lastCheckTime = DateTime.now(); // Don't retry immediately on error
        AppLogger.debug('$_serviceName: Update check failed: $e');
      }
    });
  }

  Future<Directory> _getModelDir() async {
    if (_modelDir != null) return _modelDir!;
    final appDir = await getApplicationSupportDirectory();
    _modelDir = Directory('${appDir.path}/$_localDirName');
    return _modelDir!;
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
