/// BUT-907: state of the trash view: the kept rows and the
/// changes a user can make (restore, delete for good, empty).
library;

import 'dart:async';

import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/trash_item.dart';
import 'package:butlery/services/trash/trash_service.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';

enum TrashAction { restore, deleteForever, emptyTrash }

/// What one action did, with the number of rows it was asked to change.
class TrashActionResult {
  const TrashActionResult({
    required this.action,
    required this.requested,
    required this.outcome,
  });

  final TrashAction action;
  final int requested;
  final TrashOutcome outcome;
}

class TrashViewModel extends BaseViewModel {
  TrashViewModel({TrashService? service})
    : _service = service ?? ServiceLocator.get<TrashService>();

  final TrashService _service;
  StreamSubscription<List<TrashItem>>? _subscription;

  List<TrashItem> _items = const [];
  bool _isWorking = false;

  List<TrashItem> get items => _items;
  bool get isEmpty => _items.isEmpty;

  /// True while a restore or delete runs, so a change cannot fire twice.
  bool get isWorking => _isWorking;

  /// Whole days left of a row's retention at [now], never below zero.
  static int daysLeft(TrashItem item, DateTime now) {
    final left = item.expireAt.difference(now);
    if (left.isNegative) return 0;
    return (left.inHours / 24).ceil();
  }

  /// Starts listening; calling it again after an error listens afresh.
  void start() {
    unawaited(_subscription?.cancel());
    _items = const [];
    clearError();
    setLoading(true);
    _subscription = _service.watchTrash().listen(
      _onItems,
      onError: (Object _) {
        setError(AppLocale.current.trashLoadFailed);
      },
    );
  }

  void _onItems(List<TrashItem> items) {
    if (isDisposed) return;
    _items = items;
    clearError();
    setLoading(false);
  }

  Future<TrashActionResult?> restoreOne(String id) {
    final chosen = _items.where((i) => i.id == id).toList();
    return _run(
      TrashAction.restore,
      chosen.length,
      () => _service.restore(chosen),
    );
  }

  Future<TrashActionResult?> restoreAll() {
    final all = List.of(_items);
    return _run(TrashAction.restore, all.length, () => _service.restore(all));
  }

  Future<TrashActionResult?> deleteOne(String id) {
    final ids = _items.where((i) => i.id == id).map((i) => i.id).toList();
    return _run(
      TrashAction.deleteForever,
      ids.length,
      () => _service.deleteForever(ids),
    );
  }

  Future<TrashActionResult?> emptyTrash() => _run(
    TrashAction.emptyTrash,
    _items.length,
    _service.emptyTrash,
  );

  /// Null when nothing was asked for or another change is still running.
  Future<TrashActionResult?> _run(
    TrashAction action,
    int requested,
    Future<TrashOutcome> Function() change,
  ) async {
    if (_isWorking || isDisposed) return null;
    if (requested == 0) return null;
    _isWorking = true;
    notifyListeners();
    try {
      final outcome = await change();
      return TrashActionResult(
        action: action,
        requested: requested,
        outcome: outcome,
      );
    } finally {
      _isWorking = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    super.dispose();
  }
}
