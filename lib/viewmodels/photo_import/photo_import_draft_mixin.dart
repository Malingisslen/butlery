import 'dart:typed_data';

import 'package:butlery/services/persistence/auto_save_manager.dart';
import 'package:butlery/viewmodels/photo_import/photo_import_draft.dart';
import 'package:butlery/viewmodels/photo_import/draft_image_store_stub.dart'
    if (dart.library.io) 'package:butlery/viewmodels/photo_import/draft_image_store_io.dart'
    if (dart.library.js_interop) 'package:butlery/viewmodels/photo_import/draft_image_store_web.dart'
    as image_store;

/// BUT-910: draft persistence for the photo-import flow, kept out of
/// `PhotoImportViewModel` (500-line limit) the same way heirloom form state
/// lives in `PhotoImportHeirloomFormMixin`.
///
/// Owns the `AutoSaveManager<PhotoImportDraft>` lifecycle plus the on-disk
/// image staging. The ViewModel decides *when* (persist after OCR success,
/// discard on explicit clear) and *what to do* with a restored draft
/// (repopulate state, re-parse); this mixin owns the plumbing.
mixin PhotoImportDraftMixin {
  static const String _storageKey = 'photo_import_draft_v1';

  AutoSaveManager<PhotoImportDraft>? _draftManager;

  /// Called once from the ViewModel constructor. [manager] is a test seam —
  /// production passes nothing and gets the standard SharedPreferences-backed
  /// manager under the stable `photo_import_draft_v1` key.
  void initDraftPersistence({AutoSaveManager<PhotoImportDraft>? manager}) {
    _draftManager =
        manager ??
        AutoSaveManager<PhotoImportDraft>(
          storageKey: _storageKey,
          encode: encodePhotoImportDraft,
          decode: decodePhotoImportDraft,
          logLabel: 'PhotoImportViewModel.draft',
        );
  }

  /// Stages [imageBytes] on disk (native; no-op on web) and persists the
  /// draft. Best-effort end to end — a failed stage degrades to a text-only
  /// draft, a failed save logs inside the manager.
  Future<void> persistPhotoDraft({
    required Uint8List? imageBytes,
    required String ocrText,
  }) async {
    final manager = _draftManager;
    if (manager == null || ocrText.isEmpty) return;
    final imagePath = imageBytes == null
        ? null
        : await image_store.stageDraftImage(imageBytes);
    await manager.flush(
      PhotoImportDraft(
        ocrText: ocrText,
        imagePath: imagePath,
        savedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  /// Reads the persisted draft, if any.
  Future<PhotoImportDraft?> loadPersistedDraft() async => _draftManager?.load();

  /// Reads the staged image bytes referenced by [draft] (null on web or when
  /// the OS purged the temp file — the text half still restores).
  Future<Uint8List?> readDraftImage(PhotoImportDraft draft) =>
      image_store.readDraftImage(draft.imagePath);

  /// Drops the persisted draft and its staged image file.
  ///
  /// Deliberately not serialized against an in-flight [persistPhotoDraft]:
  /// both are fire-and-forget on a best-effort artefact, and the worst case
  /// of the millisecond race window is a stale draft that the next explicit
  /// clear removes. Don't "fix" this into a blocking await on the UI path.
  Future<void> discardPersistedDraft() async {
    final manager = _draftManager;
    if (manager == null) return;
    final draft = await manager.load();
    await image_store.deleteDraftImage(draft?.imagePath);
    await manager.clear();
  }

  /// Call from the owner's `dispose`. Does NOT discard — surviving disposal
  /// is the whole point of the draft (the VM dies with the view on nav-away).
  void disposeDraftPersistence() {
    _draftManager?.dispose();
  }
}
