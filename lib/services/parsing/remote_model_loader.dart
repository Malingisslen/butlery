import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

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
        DateTime.now().difference(_lastCheckTime!) < checkInterval;
  }

  @protected
  void startCheck() => _checking = true;

  @protected
  void endCheck() {
    _lastCheckTime = DateTime.now();
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
}
