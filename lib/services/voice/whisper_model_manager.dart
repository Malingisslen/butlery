import 'dart:convert';
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/parsing/_expected_model_hashes.dart';
import 'package:butlery/services/parsing/remote_model_loader.dart';

/// Manages download, caching, and versioning of the KB-Whisper Swedish
/// speech-to-text model (GGML format, executed by whisper.cpp).
///
/// Same delivery contract as the parsing models (NerModelManager /
/// LineClassifierModelManager): downloaded from Firebase Storage on first
/// use, SHA-256 fail-close verified against the registry BEFORE any disk
/// write, cached under app support, version-checked at most once per
/// [checkInterval]. Unlike the ONNX models there is no vocab sidecar — a
/// GGML file is self-contained.
///
/// File layout in Firebase Storage:
///   models/whisper_sv/v{N}/ggml-model.bin
///   models/whisper_sv/latest_version.txt
///
/// Local cache layout:
///   {appSupportDir}/whisper_model/ggml-model.bin
///   {appSupportDir}/whisper_model/version.txt
class WhisperModelManager extends RemoteModelLoader {
  static const _storageBasePath = 'models/whisper_sv';
  static const _modelFileName = 'ggml-model.bin';
  static const _versionFileName = 'version.txt';

  /// Maximum model file size. The speech model is far bigger than the 25 MB
  /// parsing models: kb-whisper-base q5_0 is 55.3 MB; 80 MB leaves headroom
  /// for a q8 variant without permitting a silent jump to `small` (190 MB),
  /// which would be a deliberate product decision, not a version bump.
  static const _maxModelSize = 80 * 1024 * 1024;

  WhisperModelManager({super.storage});

  @override
  String get serviceName => 'WhisperModelManager';

  @override
  String get localDirName => 'whisper_model';

  @override
  Duration get checkInterval => const Duration(hours: 12);

  String? _cachedModelPath;

  bool get isModelAvailable => _cachedModelPath != null;

  /// Ensure the speech model is available locally, downloading on first use.
  ///
  /// Returns the model file path + version, or null when unavailable
  /// (offline, not yet published, integrity refusal). Never throws — the
  /// voice feature degrades to typed input, mirroring how the parsing
  /// cascade falls back when its models are missing.
  Future<WhisperModelFile?> ensureModelAvailable() async {
    final cached = await _tryLoadCached();
    if (cached != null) {
      _checkForUpdateInBackground(cached.version);
      return cached;
    }
    return await _tryDownload();
  }

  Future<WhisperModelFile?> _tryLoadCached() async {
    if (!canCacheLocally) return null;

    try {
      final dir = await getCacheDir();
      final modelPath = '${dir.path}/$_modelFileName';

      final modelFile = File(modelPath);
      if (!await modelFile.exists()) return null;

      final fileSize = await modelFile.length();
      if (fileSize == 0 || fileSize > _maxModelSize) return null;

      final versionFile = File('${dir.path}/$_versionFileName');
      if (!await versionFile.exists()) return null;

      final tmpModel = File('$modelPath.tmp');
      if (await tmpModel.exists()) await tmpModel.delete();

      final version = int.tryParse((await versionFile.readAsString()).trim());
      if (version == null) return null;

      _cachedModelPath = modelPath;
      AppLogger.debug('$serviceName: Using cached model v$version');

      return WhisperModelFile(modelPath: modelPath, version: version);
    } catch (e) {
      AppLogger.debug('$serviceName: Cache load failed: $e');
      return null;
    }
  }

  Future<WhisperModelFile?> _tryDownload() async {
    if (!canCacheLocally || isCheckThrottled) return null;
    startCheck();
    WhisperModelFile? result;
    try {
      result = await _downloadModel();
      return result;
    } finally {
      // Downloads here are USER-initiated (mic tap). Arm the 12h throttle
      // only on success — a transient failure (offline, Storage hiccup)
      // must not brick the voice feature until app restart; the next tap
      // simply retries.
      if (result != null) {
        endCheck();
      } else {
        abortCheck();
      }
    }
  }

  Future<WhisperModelFile?> _downloadModel({int? knownVersion}) async {
    try {
      final latestVersion = knownVersion ?? await _getLatestVersion();
      if (latestVersion == null) {
        AppLogger.debug('$serviceName: No model versions found in Storage');
        return null;
      }

      final modelRef = storage.ref(
        '$_storageBasePath/v$latestVersion/$_modelFileName',
      );
      // KNOWN LIMITATION (accepted for v1, follow-up candidate): getData
      // holds the full 55 MB in heap and Isolate.run's message copy briefly
      // doubles it during hashing. One-time cost on the download path only —
      // inference mmaps the cached FILE, never loads it into Dart heap. If
      // low-RAM crash reports appear, switch verification to
      // TransferableTypedData or a quarantine-file stream hash.
      final modelData = await modelRef.getData(_maxModelSize);
      if (modelData == null) {
        AppLogger.warning('$serviceName: Download returned null');
        return null;
      }

      // Fail-close integrity gate (BUT-792/BUT-877): mismatched or
      // unregistered bytes never touch the cache.
      final ok = await verifyModelDownload(
        modelBytes: modelData,
        version: latestVersion,
        hashRegistry: kExpectedWhisperModelHashes,
        modelName: 'whisper_sv',
        registryConstantName: 'kExpectedWhisperModelHashes',
      );
      if (!ok) return null;

      final dir = await getCacheDir();
      await dir.create(recursive: true);

      final modelPath = '${dir.path}/$_modelFileName';
      final localVersionPath = '${dir.path}/$_versionFileName';

      final modelTmpFile = File('$modelPath.tmp');
      await modelTmpFile.writeAsBytes(modelData);
      await modelTmpFile.rename(modelPath);

      // Version file written last — its presence marks a complete install.
      final versionTmpFile = File('$localVersionPath.tmp');
      await versionTmpFile.writeAsString(latestVersion.toString());
      await versionTmpFile.rename(localVersionPath);

      _cachedModelPath = modelPath;

      AppLogger.info(
        '$serviceName: Downloaded and cached model v$latestVersion '
        '(${(modelData.length / (1024 * 1024)).toStringAsFixed(1)} MB)',
      );

      return WhisperModelFile(modelPath: modelPath, version: latestVersion);
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
      // Fall back to checking v1 directly.
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

/// Path and version of a locally cached KB-Whisper model.
class WhisperModelFile {
  /// Path to the GGML model file on disk (whisper.cpp reads it directly).
  final String modelPath;

  /// Model version number.
  final int version;

  const WhisperModelFile({required this.modelPath, required this.version});
}
