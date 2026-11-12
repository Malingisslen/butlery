// lib/viewmodels/photo_import_viewmodel.dart

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/utils/text/import_fractions.dart';
import 'package:butlery/viewmodels/import_base_viewmodel.dart';
import 'package:butlery/viewmodels/photo_import/photo_import_heirloom_form_mixin.dart';
import 'package:butlery/viewmodels/photo_import/photo_import_draft.dart';
import 'package:butlery/viewmodels/photo_import/photo_import_draft_mixin.dart';
import 'package:butlery/viewmodels/photo_import/photo_import_ai_offer_mixin.dart';
import 'package:butlery/core/providers/application_provider.dart'
    show ServiceLocator;
import 'package:butlery/services/feature_flags/feature_flag_service.dart';
import 'package:butlery/services/import/document_scan_service.dart';
import 'package:butlery/services/ocr_extraction_service.dart';
import 'package:butlery/services/ocr/text_layout.dart';
import 'package:butlery/services/persistence/auto_save_manager.dart';
import 'package:butlery/core/l10n/app_locale.dart';

import 'package:butlery/viewmodels/photo_import/photo_import_pick_mixin.dart';
import 'package:butlery/viewmodels/photo_import/photo_import_read_mixin.dart';
import 'package:butlery/viewmodels/photo_import/photo_import_state_mixin.dart';
import 'package:butlery/viewmodels/photo_import/photo_page.dart';

export 'package:butlery/viewmodels/photo_import/photo_permission_notice.dart';

/// Photo-import ViewModel: camera/gallery capture → multi-provider OCR →
/// auto-parse to a Recipe. Extends [ImportBaseViewModel] for the shared
/// import lifecycle; heirloom form state lives in
/// [PhotoImportHeirloomFormMixin].
class PhotoImportViewModel extends ImportBaseViewModel
    with
        PhotoImportHeirloomFormMixin,
        PhotoImportDraftMixin,
        PhotoImportAiOfferMixin,
        PhotoImportStateMixin,
        PhotoImportPickMixin,
        PhotoImportReadMixin {
  // BUT-410 heirloom form state lives in PhotoImportHeirloomFormMixin.

  /// [draftManager] is a test seam (BUT-910) — production passes nothing.
  /// BUT-610: [connectivity] default-resolves from ServiceLocator so existing
  /// callers are unchanged; tests inject an offline double.
  PhotoImportViewModel({
    required super.importManager,
    AutoSaveManager<PhotoImportDraft>? draftManager,
    // BUT-1360: connectivity + the isOnline getter now live on
    // ImportBaseViewModel; forward the injection to super (no local copy).
    super.connectivity,
    DocumentScanService? documentScanner,
  }) : _documentScanner =
           documentScanner ??
           ServiceLocator.tryGet<DocumentScanService>() ??
           DocumentScanService.withFlags(
             ServiceLocator.tryGet<FeatureFlagService>(),
           ) {
    initDraftPersistence(manager: draftManager);
    _initializeOCRService();
  }

  /// Initialize OCR service for universal device compatibility
  Future<void> _initializeOCRService() async {
    try {
      await OCRExtractionService.instance.initialize();
    } catch (e) {
      // OCR service initialization failed - will be handled when OCR is attempted
    }
  }

  static const int maxPages = kPhotoImportMaxPages;

  /// Opens the native document scanner for the camera button when the
  /// `enable_document_scanner` flag is on; otherwise reports itself unavailable.
  final DocumentScanService _documentScanner;

  @override
  DocumentScanService get documentScanner => _documentScanner;

  @override
  Uint8List? get imageBytes => photoBytes;

  /// BUT-1171: test-only seams that populate the REAL backing fields the
  /// production import pipeline reads (`photoOcrText`, `photoBytes`). Tests now
  /// set the real fields, exercising the production code.
  @visibleForTesting
  void setOcrTextForTesting(String text) {
    photoOcrText = text;
    notifyListeners();
  }

  @visibleForTesting
  void setImageBytesForTesting(Uint8List? bytes) {
    photoBytes = bytes;
    notifyListeners();
  }

  /// Drives the real multi-recipe auto-parse path (normally fired inside the
  /// OCR pipeline) so tests can verify single vs. multi routing without a
  /// camera/OCR round-trip.
  @visibleForTesting
  Future<void> parseOcrTextForTesting(String text) => autoParseOcrText(text);

  /// BUT-903: append a page with pre-extracted OCR text (skipping the
  /// camera/OCR round-trip) and run the real combine+parse path, so tests can
  /// exercise multi-page ordering, removal, reordering, and the cap without a
  /// platform image picker. Mirrors what [readPages] does after a successful
  /// OCR.
  ///
  /// [layout] is what the free on-device tier measured for this page, when the
  /// geometry flag is on. Omitting it models every other provenance — a paid
  /// tier, the handwriting path, a restored draft — and one such page makes the
  /// whole document decline, which is the behaviour worth testing.
  @visibleForTesting
  Future<void> addPageForTesting(
    Uint8List bytes,
    String text, {
    PageLayout? layout,
  }) async {
    if (!canAddPage) return;
    photoPages.add(
      PhotoPage(bytes: bytes, text: text, layout: layout, isRead: true),
    );
    await recombineAndParse();
  }

  /// Q4-04: stages a picked page without reading it, exactly as a capture
  /// does, so tests can prove that nothing is read until [readPages].
  @visibleForTesting
  void stagePageForTesting(Uint8List bytes) => stagePage(bytes);

  /// Import readiness indicator based on OCR results availability.
  /// Determines whether photo import can proceed based on OCR text availability
  /// enabling proper import workflow validation and user guidance.
  /// **Override Implementation**: Extends ImportBaseViewModel canImport with OCR-specific validation.
  @override
  bool get canImport => hasOcrResult;

  /// Photo import type identifier for analytics tracking and logging coordination.
  /// Provides import type classification for analytics tracking, logging coordination,
  /// and import workflow identification throughout photo import operations.
  /// **Override Implementation**: Implements ImportBaseViewModel importType interface.
  @override
  String get importType => 'photo';

  @override
  void clearImportData() {
    importMeasured = false;
    aiReadingUsed = false;
    clearAiOffer();
    super.clearImportData();
  }

  // BUT-410 heirloom getters/setters live in PhotoImportHeirloomFormMixin.

  /// Clears all photo + OCR state. Call sites are explicit user actions only
  /// (preview X button, post-save cleanup) — see the draft note below.
  @override
  void clearPhoto() {
    if (isDisposed) return;

    photoBytes = null;
    photoOcrText = '';
    photoPages.clear();
    lastQualityScore = null;
    lastRecommendations = null;
    lastConfidence = null;
    parsedRecipeList.clear();
    permissionNoticeState = null;
    // BUT-684: the handwritten opt-in is per-import. Reset it here (the
    // explicit X-button / post-save cleanup) so it isn't sticky across imports
    // and doesn't silently keep the next fresh import on the costlier LLM path.
    // NOT reset in clearImportData(): that runs mid-pick (fresh capture) BEFORE
    // the handwritten branch reads the flag, so resetting there would wipe the
    // toggle the user just set and break the feature.
    handwrittenMode = false;
    // Heirloom form clears with the photo — they belong to the same capture.
    clearHeirloomForm();
    clearImportData();

    // BUT-910: both clearPhoto call sites are explicit user actions (the
    // preview's X button, post-save cleanup) — the persisted draft goes too.
    // Nav-away does NOT come through here, so drafts survive navigation.
    unawaited(discardPersistedDraft());

    // NB: the OCR result cache is intentionally NOT cleared here. It is keyed by
    // image content, so persisting it across photo clears lets a re-import of
    // the same image hit the cache instead of re-spending OCR provider quota
    // (CLAUDE.md cost principles). Tests that need a clean cache call
    // OCRExtractionService.clearCacheForTesting() in their teardown.
  }

  /// BUT-910: restores the persisted draft into live state — staged image (when
  /// available; web and purged-temp degrade to text-only), OCR text, and a
  /// fresh auto-parse so the parsed-recipe state matches what the user saw.
  /// Returns false when there is no draft to restore.
  Future<bool> restoreDraft() async {
    final draft = await loadPersistedDraft();
    if (draft == null || isDisposed) return false;
    final bytes = await readDraftImage(draft);
    if (isDisposed) return false;
    photoBytes = bytes;
    photoOcrText = draft.ocrText;
    // BUT-903: the draft schema stages one image + the combined OCR text, so a
    // restore rebuilds a single-page set. The user can add more pages on top.
    photoPages
      ..clear()
      ..add(
        PhotoPage(
          bytes: bytes ?? Uint8List(0),
          text: draft.ocrText,
          isRead: true,
        ),
      );
    notifyListeners();
    // The draft's import was measured when it was first read.
    importMeasured = true;
    await autoParseOcrText(photoOcrText, reflow: true);
    return true;
  }

  @override
  void clearAll() => clearPhoto();

  /// Test seam for a pick followed by "Läs av": stages [bytes] as the real
  /// pick does (a fresh pick replaces the pages), then reads them through
  /// [readPages], so a unit test reaches the real routing — handwritten
  /// vision path vs the char-OCR quality gate (BUT-1460) — without a
  /// platform image picker.
  @visibleForTesting
  Future<void> processPickedImageForTesting(
    Uint8List bytes,
    ImageSource source, {
    bool addAsPage = false,
  }) async {
    if (!addAsPage || handwrittenMode) {
      clearImportData();
      photoPages.clear();
    }
    lastPickSource = source;
    stagePage(bytes);
    await readPages();
  }

  /// BUT-684: run the picked image through the LLM-vision import path with the
  /// handwriting flag set, then feed the result into the same
  /// OCR-text→review→parse pipeline every other photo import uses.
  ///
  /// A structured recipe (the common success shape) is rendered to a readable
  /// text block so the interpreted-text preview + "proceed to edit" handoff
  /// work unchanged; a raw-text/assistance shape flows straight in as OCR text.
  @visibleForTesting
  Future<void> extractHandwrittenForTesting(
    Uint8List bytes, {
    ImageSource source = ImageSource.gallery,
  }) => extractWithAi(bytes, source);

  /// Save the recipes the user ticked in the multi-recipe picker. Uses the
  /// import-layer save per recipe.
  int _lastSaveFailureCount = 0;

  /// How many recipes failed in the most recent [saveSelectedRecipes] batch.
  /// Lets the view show a partial-failure summary ("X saved, Y failed").
  int get lastSaveFailureCount => _lastSaveFailureCount;

  Future<bool> saveSelectedRecipes(List<Recipe> recipes) async {
    if (recipes.isEmpty) {
      setError(AppLocale.current.errorNoRecipeToSave);
      return false;
    }
    return executeAsyncVoid(() async {
      // Save every recipe, continuing past individual failures so one bad
      // recipe doesn't drop the rest. Only a total failure is a hard error;
      // a partial one keeps the saved recipes and reports the failed count.
      _lastSaveFailureCount = 0;
      for (final recipe in recipes) {
        final toSave = await withHeirloomScan(recipe);
        final result = toSave == null
            ? null
            // These skip the editor, which writes an import's amounts as fractions.
            : await importManager.saveImportedRecipe(
                ImportFractions.recipe(toSave),
              );
        if (result?.isSuccess != true) _lastSaveFailureCount++;
      }
      if (_lastSaveFailureCount == recipes.length) {
        throw Exception(AppLocale.current.errorGeneric);
      }
    });
  }

  @override
  Map<String, dynamic> get debugState => {
    ...super.debugState,
    'hasImage': hasImage,
    'hasOcrResult': hasOcrResult,
    'pageCount': pageCount,
    'ocrTextLength': photoOcrText.length,
    'isProcessing': isProcessing,
    'imageBytesSize': photoBytes?.length ?? 0,
    'ocrServiceStatus': OCRExtractionService.instance.getServiceStatus(),
  };

  @override
  void dispose() {
    // BUT-910: dispose the manager, do NOT discard the draft — surviving
    // disposal (the view disposes this VM on nav-away) is the feature.
    disposeDraftPersistence();
    photoBytes = null;
    photoOcrText = '';
    photoPages.clear();
    lastQualityScore = null;
    lastRecommendations = null;
    lastConfidence = null;
    parsedRecipeList.clear();
    super.dispose();
  }
}
