import 'package:clock/clock.dart';
import 'dart:io';
import 'dart:isolate';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/parsing/_expected_model_hashes.dart';

/// Shared infrastructure for classes that download model files from
/// Firebase Storage with local caching and throttled version checks.
///
/// Provides: storage access, check throttling, and cache directory management.
/// Subclasses implement their own download/version/caching logic.
abstract class RemoteModelLoader {
  final FirebaseStorage? _injectedStorage;
  DateTime? _lastCheckTime;
  bool _checking = false;
  Directory? _cacheDir;

  RemoteModelLoader({FirebaseStorage? storage}) : _injectedStorage = storage;

  @protected
  FirebaseStorage get storage {
    if (_injectedStorage == null) {
      throw StateError('FirebaseStorage not injected — register via DI');
    }
    return _injectedStorage;
  }

  @protected
  String get serviceName;

  @protected
  String get localDirName;

  @protected
  Duration get checkInterval;

  /// Whether a check is in progress or was done recently.
  @protected
  bool get isCheckThrottled {
    if (_checking) return true;
    return _lastCheckTime != null &&
        clock.now().difference(_lastCheckTime!) < checkInterval;
  }

  @protected
  void startCheck() => _checking = true;

  @protected
  void endCheck() {
    _lastCheckTime = clock.now();
    _checking = false;
  }

  /// Lazy-initialized local cache directory under app support.
  @protected
  Future<Directory> getCacheDir() async {
    if (_cacheDir != null) return _cacheDir!;
    final appDir = await getApplicationSupportDirectory();
    _cacheDir = Directory('${appDir.path}/$localDirName');
    return _cacheDir!;
  }

  /// Whether local file caching is available (false on web).
  @protected
  bool get canCacheLocally => !kIsWeb;

  /// BUT-792 — verify downloaded ONNX bytes against the registered SHA-256.
  /// Returns true when the bytes are safe to write to disk (matched, or
  /// transitional state with empty registry). Returns false on registered
  /// mismatch — caller must abort the download.
  ///
  /// SHA-256 of a 25 MB blob takes ~200-400 ms in pure Dart, enough to
  /// drop frames on the main isolate. Verification runs in `Isolate.run`
  /// when the registry has entries; while the registry is empty
  /// (transitional rollout) we skip the hash entirely and emit a sentinel
  /// so the gap surfaces in Crashlytics.
  @protected
  Future<bool> verifyModelDownload({
    required List<int> modelBytes,
    required int version,
    required Map<int, String> hashRegistry,
    required String modelName,
    required String registryConstantName,
  }) async {
    if (hashRegistry.isEmpty) {
      AppLogger.error(
        '$serviceName: SHA-256 unverified — $registryConstantName is empty '
        '(transitional). Populate it to enable mismatch detection.',
        StateError('$modelName hash registry is empty'),
      );
      return true;
    }

    final result = await Isolate.run(
      () => verifyOnnxBytes(
        modelBytes: modelBytes,
        version: version,
        hashRegistry: hashRegistry,
      ),
    );

    if (result.unverified) {
      AppLogger.error(
        '$serviceName: SHA-256 unverified for v$version (no entry in '
        '$registryConstantName). Computed: ${result.actualHash}.',
        StateError('$modelName hash registry missing entry for v$version'),
      );
      return true;
    }
    if (result.ok) return true;

    final failure = ModelIntegrityCheckFailure(
      modelName: modelName,
      version: version,
      expected: result.expectedHash!,
      actual: result.actualHash,
    );
    AppLogger.error('$serviceName: $failure', failure);
    return false;
  }
}
