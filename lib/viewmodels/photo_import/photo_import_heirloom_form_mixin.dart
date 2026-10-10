import 'package:flutter/foundation.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/recipe/heirloom_draft.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/import/heirloom_bridge.dart';
import 'package:butlery/services/import/heirloom_uploader.dart';
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

  /// Whether the heirloom form holds user-entered content that a clear would
  /// discard (writer, year, or note). Used to gate a confirm dialog before the
  /// "remove image" action wipes the form along with the photo.
  bool get hasHeirloomContent =>
      _heirloomWriterName.isNotEmpty ||
      _heirloomYear != null ||
      _heirloomNote.isNotEmpty;

  set isHeirloom(bool value) {
    if (isDisposed || _isHeirloom == value) return;
    _isHeirloom = value;
    // BUT-2280: a scan stashed before the user opted out must not be saved.
    if (!value) _dropPendingScan();
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
    _dropPendingScan();
  }

  /// The photo the form describes; the host view model owns it.
  Uint8List? get imageBytes;

  /// The scan and the form as one draft, or null when the form is off or
  /// there is no photo.
  HeirloomDraft? get heirloomDraft {
    final bytes = imageBytes;
    if (!_isHeirloom || bytes == null) return null;
    return HeirloomDraft(
      imageBytes: bytes,
      writerName: _heirloomWriterName.isEmpty ? null : _heirloomWriterName,
      year: _heirloomYear,
      note: _heirloomNote.isEmpty ? null : _heirloomNote,
    );
  }

  /// BUT-2286: [recipe] as the multi-recipe picker saves it, carrying the
  /// scan and the form when the user filled one in. Null when the scan could
  /// not be stored, so the recipe is not saved without it.
  Future<Recipe?> withHeirloomScan(Recipe recipe) async {
    final draft = heirloomDraft;
    if (draft == null) return recipe;
    return ServiceLocator.tryGet<HeirloomUploader>()?.attachTo(recipe, draft);
  }

  /// BUT-2280: a scan stashed for a parse that never happened must not be
  /// bound to the next, unrelated text import once this screen is gone.
  @override
  void dispose() {
    _dropPendingScan();
    super.dispose();
  }

  void _dropPendingScan() => ServiceLocator.tryGet<HeirloomBridge>()?.clear();
}
