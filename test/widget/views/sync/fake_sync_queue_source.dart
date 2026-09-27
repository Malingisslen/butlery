// Test doubles for the queue view (P4-U19): a SyncQueueSource driven by the
// test, and an OfflineService stand-in for the offline banner.

import 'dart:async';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/services/offline/sync_queue_source.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import '../../../infrastructure/di/test_service_locator.dart';

class FakeSyncQueueSource extends SyncQueueSource {
  FakeSyncQueueSource({List<QueuedChange> changes = const []}) {
    set(changes);
  }

  final List<StreamController<QueueSnapshot>> _changes = [];
  final List<StreamController<QueueCounts>> _counts = [];
  QueueSnapshot _last = QueueSnapshot.empty;

  bool online = true;
  int syncs = 0;
  final List<QueuedChange> retried = [];
  final List<QueuedChange> discarded = [];

  /// When set, every action throws it.
  Object? failWith;

  void _maybeFail() {
    final failure = failWith;
    if (failure != null) throw failure;
  }

  void set(List<QueuedChange> changes) {
    _last = QueueSnapshot(changes);
    for (final c in _changes) {
      c.add(_last);
    }
    for (final c in _counts) {
      c.add(_countsOf(_last));
    }
  }

  static QueueCounts _countsOf(QueueSnapshot q) =>
      QueueCounts(draining: q.draining.length, needsUser: q.needsUser.length);

  @override
  Stream<QueueSnapshot> watchChanges() {
    final c = StreamController<QueueSnapshot>()..add(_last);
    _changes.add(c);
    return c.stream;
  }

  @override
  Stream<QueueCounts> watchCounts() {
    final c = StreamController<QueueCounts>()..add(_countsOf(_last));
    _counts.add(c);
    return c.stream;
  }

  @override
  bool get isOnline => online;

  @override
  Future<void> syncNow() async {
    _maybeFail();
    syncs++;
  }

  @override
  Future<void> retry(QueuedChange change) async {
    _maybeFail();
    retried.add(change);
  }

  @override
  Future<void> discard(QueuedChange change) async {
    _maybeFail();
    discarded.add(change);
  }
}

/// Drives the offline banner's ServiceLocator lookup.
class FakeOfflineService extends ChangeNotifier implements OfflineService {
  bool _online = true;

  @override
  bool get isOnline => _online;

  void setOnline(bool value) {
    _online = value;
    notifyListeners();
  }

  @override
  bool get isInitialized => true;

  @override
  String? get currentUserId => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Registers [offline] where the offline banner looks for it.
Future<void> registerOffline(FakeOfflineService offline) async {
  await TestServiceLocator.initialize();
  production.ServiceLocator.initialize(DIContainer());
  final getIt = GetIt.instance;
  if (getIt.isRegistered<OfflineService>()) {
    getIt.unregister<OfflineService>();
  }
  getIt.registerSingleton<OfflineService>(offline);
}
