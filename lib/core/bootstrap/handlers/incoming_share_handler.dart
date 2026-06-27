/// BUT-941: routes shared photos (from the OS share sheet) into the existing
/// photo-import flow.
///
/// Mirrors [DeepLinkHandler]'s lifecycle: capture any cold-start share at
/// startup, then route it once a navigation context + authenticated user are
/// available. Warm-start shares (app already running) route immediately.
///
/// Both the cold- and warm-start paths route through the global navigator key
/// (not a caller-supplied context) so the two paths behave identically — a
/// share is held pending whenever auth or a live navigator isn't ready yet,
/// and drained on the next [processPendingShare].
///
/// Deliberately separate from [DeepLinkHandler]: that handler owns URI
/// deep-links; this one owns image-file shares. They never share intent
/// surface (the native guard claims only `image/*` SEND intents).
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/services/import/incoming_share_service.dart';
import 'package:butlery/widgets/common/feedback_fab.dart' show appNavigatorKey;

class IncomingShareHandler {
  static final IncomingShareHandler _instance =
      IncomingShareHandler._internal();
  factory IncomingShareHandler() => _instance;
  IncomingShareHandler._internal();

  bool _isInitialized = false;
  List<String>? _pendingPaths;
  StreamSubscription<List<String>>? _warmSub;

  bool get isInitialized => _isInitialized;

  /// Test seam: resolves the auth repository. Defaults to the service locator.
  @visibleForTesting
  AuthRepository? Function() authResolver = () =>
      ServiceLocator.tryGet<AuthRepository>();

  /// Test seam: performs the navigation. Defaults to the global navigator key.
  /// Returns false when no live navigator is available (share stays pending).
  @visibleForTesting
  bool Function(List<String> paths) navigate = _defaultNavigate;

  static bool _defaultNavigate(List<String> paths) {
    final context = appNavigatorKey.currentContext;
    if (context == null || !context.mounted) return false;
    Navigator.of(context).pushNamed(Routes.photoImport, arguments: paths);
    return true;
  }

  /// Capture the cold-start share and subscribe to warm-start shares.
  ///
  /// [service] is injectable for tests; production resolves it from the
  /// service locator.
  Future<void> initialize({IncomingShareService? service}) async {
    if (_isInitialized) return;
    try {
      service ??= ServiceLocator.tryGet<IncomingShareService>();
      if (service != null) {
        _pendingPaths = await service.getInitialSharedImages();
        _warmSub ??= service.mediaStream.listen(_onWarmShare);
      }
    } catch (e) {
      // Never let share wiring break startup.
      AppLogger.warning('IncomingShareHandler.initialize failed: $e');
    } finally {
      _isInitialized = true;
    }
  }

  /// Route a pending share once a navigator + auth are ready. No-op when
  /// nothing is pending.
  Future<void> processPendingShare() async {
    final paths = _pendingPaths;
    if (paths == null || paths.isEmpty) return;
    if (_route(paths)) {
      _pendingPaths = null;
    }
  }

  void _onWarmShare(List<String> paths) {
    if (paths.isEmpty) return;
    // Hold the share if it can't route yet (no auth / no live navigator) —
    // the next processPendingShare drains it. Merge with any already-pending
    // share (e.g. a cold-start capture not yet drained) so an earlier batch is
    // never silently dropped; the import caps the combined set itself.
    if (!_route(paths)) {
      _pendingPaths = [...?_pendingPaths, ...paths];
    }
  }

  /// Auth-gated navigation to the photo-import screen. Returns false (keeping
  /// the share pending) when auth isn't ready — same gate as
  /// [DeepLinkHandler.processDeepLink] — or when no live navigator exists.
  bool _route(List<String> paths) {
    final authRepo = authResolver();
    if (authRepo?.currentUser == null) {
      return false;
    }
    return navigate(paths);
  }

  /// Reset for testing.
  @visibleForTesting
  void reset() {
    _isInitialized = false;
    _pendingPaths = null;
    _warmSub?.cancel();
    _warmSub = null;
    authResolver = () => ServiceLocator.tryGet<AuthRepository>();
    navigate = _defaultNavigate;
  }
}
