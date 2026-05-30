import 'package:butlery/viewmodels/import_base_viewmodel.dart';

/// BUT-410 heirloom ("Farmors lapp") form state, extracted from
/// [PhotoImportViewModel] (BUT-1154 decomposition).
///
/// Kept separate from OCR state because heirloom is an opt-in overlay on the
/// same photo — toggling it must not reset OCR progress and vice versa. Lives
/// in a mixin so it shares the host VM's `notifyListeners`/`isDisposed`
/// lifecycle while keeping the photo VM focused on the OCR pipeline.
mixin PhotoImportHeirloomFormMixin on ImportBaseViewModel {
  bool _isHeirloom = false;
  String _heirloomWriterName = '';
  int? _heirloomYear;
  String _heirloomNote = '';
  bool _isOfflineQueued = false;

  /// Whether the user has marked this scan as an heirloom recipe.
  bool get isHeirloom => _isHeirloom;

  /// Writer attribution, as currently typed. Empty string = not provided.
  String get heirloomWriterName => _heirloomWriterName;

  /// Year parsed from the year field, or null if empty/invalid.
  int? get heirloomYear => _heirloomYear;

  /// Short origin note, as currently typed.
  String get heirloomNote => _heirloomNote;

  /// True while an heirloom upload is pending because the device is offline.
  bool get isOfflineQueued => _isOfflineQueued;

  set isHeirloom(bool value) {
    if (isDisposed || _isHeirloom == value) return;
    _isHeirloom = value;
    notifyListeners();
  }

  set heirloomWriterName(String value) {
    if (isDisposed) return;
    // Guard against very long paste-ins — HeirloomMetadata enforces 100 at
    // construction time, but we truncate here so the field stays usable.
    final trimmed = value.length > 100 ? value.substring(0, 100) : value;
    if (_heirloomWriterName == trimmed) return;
    _heirloomWriterName = trimmed;
    notifyListeners();
  }

  set heirloomYear(int? value) {
    if (isDisposed || _heirloomYear == value) return;
    _heirloomYear = value;
    notifyListeners();
  }

  set heirloomNote(String value) {
    if (isDisposed) return;
    final trimmed = value.length > 200 ? value.substring(0, 200) : value;
    if (_heirloomNote == trimmed) return;
    _heirloomNote = trimmed;
    notifyListeners();
  }

  /// Resets all heirloom fields — called when the photo is cleared, since the
  /// form belongs to the same capture. Does not notify (the caller does).
  void clearHeirloomForm() {
    _isHeirloom = false;
    _heirloomWriterName = '';
    _heirloomYear = null;
    _heirloomNote = '';
    _isOfflineQueued = false;
  }
}
