import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/parsing/remote_model_loader.dart';

/// A sidecar file that ships alongside a model version (e.g. the WordPiece
/// vocab next to an ONNX graph). Sidecars are small text files: they are
/// downloaded with the model, cached next to it, and their absence makes a
/// cached install invalid.
class ModelSidecarSpec {
  final String fileName;
  final int maxSize;

  const ModelSidecarSpec({required this.fileName, required this.maxSize});
}

/// Template for the versioned model families (NER, line classifier,
/// KB-Whisper): one shared download/cache/version flow, per-family hooks
/// for what differs. Before this base each manager carried its own copy of
/// the identical ~150-line flow — three chances for the same future bug.
///
/// The shared contract (BUT-792/BUT-877 fail-close spine):
/// - Downloaded MODEL bytes are SHA-256-verified against the family's
///   registry BEFORE any disk write; refused bytes never touch the cache.
///   Sidecars are size-capped only, NOT hash-verified (pre-existing
///   BUT-792 scope — don't assume sidecar integrity in a new family).
/// - `version.txt` is written LAST as the atomic commit marker — a cache
///   without it is an interrupted install and is ignored.
/// - Version checks are throttled to [checkInterval]; whether a FAILED
///   download arms that throttle is a per-family decision
///   ([armThrottleOnFailedDownload]) — user-initiated families must stay
///   retryable, background families must back off.
/// - Never throws: every failure degrades to "model unavailable" and the
///   caller's fallback path (rule-based parser, typed input) takes over.
abstract class VersionedModelManager<T> extends RemoteModelLoader {
  VersionedModelManager({super.storage});

  static const versionFileName = 'version.txt';

  /// Firebase Storage folder holding `v{N}/` version dirs and
  /// `latest_version.txt`.
  @protected
  String get storageBasePath;

  /// The model artifact's file name (same in Storage and the local cache).
  @protected
  String get modelFileName;

  /// Per-family size cap — a deliberate product decision per family, not a
  /// shared constant (see each subclass's rationale).
  @protected
  int get maxModelSize;

  @protected
  Map<int, String> get hashRegistry;

  @protected
  String get modelName;

  /// Literal registry constant name, used in fail-close log messages and
  /// regex-matched by tools/ci/check_model_versions.py.
  @protected
  String get registryConstantName;

  /// Small text files shipped with each model version. Empty for
  /// self-contained formats (GGML).
  @protected
  List<ModelSidecarSpec> get sidecars => const [];

  /// Whether a FAILED download arms the [checkInterval] throttle.
  ///
  /// Background-loaded parsing models keep the default (true): a Storage
  /// hiccup backs off instead of hammering. The whisper family overrides to
  /// false because its downloads are user-initiated (mic tap) — a transient
  /// failure must not brick the voice feature for 12 hours; the user's next
  /// tap simply retries. Success always arms the throttle.
  @protected
  bool get armThrottleOnFailedDownload => true;

  /// Builds the family's result value from a completed install.
  /// [sidecarContents] is keyed by sidecar file name.
  @protected
  T buildResult({
    required String modelPath,
    required Map<String, String> sidecarContents,
    required int version,
  });

  String? _cachedModelPath;

  bool get isModelAvailable => _cachedModelPath != null;

  /// Ensure the model is available locally, downloading on first use.
  ///
  /// Returns the family result or null when unavailable (offline, not yet
  /// published, integrity refusal). Never throws.
  Future<T?> ensureModelAvailable() async {
    final cached = await _tryLoadCached();
    if (cached != null) {
      _checkForUpdateInBackground(cached.version);
      return cached.result;
    }
    return await _tryDownload();
  }

  Future<({T result, int version})?> _tryLoadCached() async {
    if (!canCacheLocally) return null;

    try {
      final dir = await getCacheDir();
      final modelPath = '${dir.path}/$modelFileName';

      final modelFile = File(modelPath);
      if (!await modelFile.exists()) return null;

      final fileSize = await modelFile.length();
      if (fileSize == 0 || fileSize > maxModelSize) return null;

      final versionFile = File('${dir.path}/$versionFileName');
      if (!await versionFile.exists()) return null;
      final sidecarContents = <String, String>{};
      for (final sidecar in sidecars) {
        final sidecarFile = File('${dir.path}/${sidecar.fileName}');
        if (!await sidecarFile.exists()) return null;
        sidecarContents[sidecar.fileName] = await sidecarFile.readAsString();
      }

      // Clean up any leftover .tmp file from an interrupted write.
      final tmpModel = File('$modelPath.tmp');
      if (await tmpModel.exists()) await tmpModel.delete();
      final version = int.tryParse((await versionFile.readAsString()).trim());
      if (version == null) return null;

      _cachedModelPath = modelPath;
      AppLogger.debug('$serviceName: Using cached model v$version');

      return (
        result: buildResult(
          modelPath: modelPath,
          sidecarContents: sidecarContents,
          version: version,
        ),
        version: version,
      );
    } catch (e) {
      AppLogger.debug('$serviceName: Cache load failed: $e');
      return null;
    }
  }

  /// Throttled entry point for downloading — manages the check lifecycle.
  Future<T?> _tryDownload() async {
    if (!canCacheLocally || isCheckThrottled) return null;
    startCheck();
    T? result;
    try {
      result = await _downloadModel();
      return result;
    } finally {
      if (result != null || armThrottleOnFailedDownload) {
        endCheck();
      } else {
        abortCheck();
      }
    }
  }

  /// Pure download logic — no check lifecycle management.
  Future<T?> _downloadModel({int? knownVersion}) async {
    try {
      final latestVersion = knownVersion ?? await _getLatestVersion();
      if (latestVersion == null) {
        AppLogger.debug('$serviceName: No model versions found in Storage');
        return null;
      }

      final versionPath = '$storageBasePath/v$latestVersion';
      final downloads = await Future.wait(<Future<Uint8List?>>[
        storage.ref('$versionPath/$modelFileName').getData(maxModelSize),
        for (final sidecar in sidecars)
          storage
              .ref('$versionPath/${sidecar.fileName}')
              .getData(sidecar.maxSize),
      ]);
      if (downloads.any((data) => data == null)) {
        AppLogger.warning('$serviceName: Download returned null');
        return null;
      }

      // Fail-close integrity gate (BUT-792/BUT-877): mismatched or
      // unregistered bytes never touch the cache. The verified bytes come
      // back from the hash isolate and are what gets written — the bytes
      // WRITTEN are the bytes HASHED. Wrapping + nulling the slot drops
      // every reference to the original blob before the hash runs, so a
      // 55 MB model never sits in heap twice while hashing or writing
      // (verifyModelDownload's memory contract).
      final model = TransferableTypedData.fromList([downloads.first!]);
      downloads[0] = null;
      final verified = await verifyModelDownload(
        model: model,
        version: latestVersion,
        hashRegistry: hashRegistry,
        modelName: modelName,
        registryConstantName: registryConstantName,
      );
      if (verified == null) return null;

      final sidecarContents = <String, String>{
        for (var i = 0; i < sidecars.length; i++)
          sidecars[i].fileName: utf8.decode(downloads[i + 1]!),
      };

      final dir = await getCacheDir();
      await dir.create(recursive: true);

      final modelPath = '${dir.path}/$modelFileName';
      final modelTmpFile = File('$modelPath.tmp');
      await modelTmpFile.writeAsBytes(verified);

      final sidecarRenames = <(File tmp, String target)>[];
      for (final sidecar in sidecars) {
        final targetPath = '${dir.path}/${sidecar.fileName}';
        final tmpFile = File('$targetPath.tmp');
        await tmpFile.writeAsString(sidecarContents[sidecar.fileName]!);
        sidecarRenames.add((tmpFile, targetPath));
      }

      // Rename atomically — model + sidecars first, version LAST: its
      // presence marks a complete install.
      await modelTmpFile.rename(modelPath);
      for (final (tmpFile, targetPath) in sidecarRenames) {
        await tmpFile.rename(targetPath);
      }
      final localVersionPath = '${dir.path}/$versionFileName';
      final versionTmpFile = File('$localVersionPath.tmp');
      await versionTmpFile.writeAsString(latestVersion.toString());
      await versionTmpFile.rename(localVersionPath);

      _cachedModelPath = modelPath;

      AppLogger.info(
        '$serviceName: Downloaded and cached model v$latestVersion '
        '(${(verified.length / (1024 * 1024)).toStringAsFixed(1)} MB)',
      );

      return buildResult(
        modelPath: modelPath,
        sidecarContents: sidecarContents,
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
      final metaRef = storage.ref('$storageBasePath/latest_version.txt');
      final data = await metaRef.getData(1024);
      if (data != null) {
        final version = int.tryParse(utf8.decode(data).trim());
        if (version != null) return version;
      }
    } on FirebaseException {
      // Fall back to checking v1 directly.
    }

    try {
      final ref = storage.ref('$storageBasePath/v1/$modelFileName');
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
        // Background checks always arm the throttle — success or failure,
        // the next check waits [checkInterval] (only USER-initiated
        // downloads get the abortCheck retry path, in _tryDownload).
        endCheck();
      }
    });
  }
}
