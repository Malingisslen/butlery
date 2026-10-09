/// BUT-907: state of the trash view: the kept rows, the selection, and the
/// three changes a user can make (restore, delete for good, empty).
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
  final Set<String> _selectedIds = {};
  bool _isWorking = false;

  List<TrashItem> get items => _items;
  bool get isEmpty => _items.isEmpty;
  Set<String> get selectedIds => Set.unmodifiable(_selectedIds);
  int get selectedCount => _selectedIds.length;
  bool get hasSelection => _selectedIds.isNotEmpty;
  bool get allSelected =>
      _items.isNotEmpty && _selectedIds.length == _items.length;

  /// True while a restore or delete runs, so the footer cannot fire twice.
  bool get isWorking => _isWorking;

  bool isSelected(String id) => _selectedIds.contains(id);

  /// Whole days left of a row's 30 days at [now], never below zero.
  static int daysLeft(TrashItem item, DateTime now) {
    final left = item.expireAt.difference(now);
    if (left.isNegative) return 0;
    return (left.inHours / 24).ceil();
  }

  /// Share of the 30 days still left at [now], from 0 to 1.
  static double fractionLeft(TrashItem item, DateTime now) {
    final left = item.expireAt.difference(now).inSeconds;
    final total = TrashItem.keptFor.inSeconds;
    return (left / total).clamp(0.0, 1.0);
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
        // The row is not shown without its stream, so the selection goes too.
        _selectedIds.clear();
        setError(AppLocale.current.trashLoadFailed);
      },
    );
  }

  void _onItems(List<TrashItem> items) {
    if (isDisposed) return;
    _items = items;
    _selectedIds.retainAll(items.map((i) => i.id));
    clearError();
    setLoading(false);
  }

  void toggle(String id) {
    if (_isWorking || !_items.any((i) => i.id == id)) return;
    if (!_selectedIds.remove(id)) _selectedIds.add(id);
    notifyListeners();
  }

  /// Selects every row, or clears the selection when every row is selected.
  void toggleAll() {
    if (_isWorking) return;
    if (allSelected) {
      _selectedIds.clear();
    } else {
      _selectedIds.addAll(_items.map((i) => i.id));
    }
    notifyListeners();
  }

  Future<TrashActionResult?> restoreSelected() {
    final chosen = _items.where((i) => _selectedIds.contains(i.id)).toList();
    return _run(
      TrashAction.restore,
      chosen.length,
      () => _service.restore(chosen),
    );
  }

  Future<TrashActionResult?> deleteSelected() {
    final ids = _selectedIds.toList();
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
      // Rows that went stay out of the selection even before the stream says so.
      _selectedIds.removeAll(outcome.doneIds);
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
