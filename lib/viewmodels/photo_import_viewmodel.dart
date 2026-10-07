// lib/viewmodels/photo_import_viewmodel.dart

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/viewmodels/import_base_viewmodel.dart';
import 'package:butlery/viewmodels/photo_import/photo_import_heirloom_form_mixin.dart';
import 'package:butlery/viewmodels/photo_import/photo_import_draft.dart';
import 'package:butlery/viewmodels/photo_import/photo_import_draft_mixin.dart';
import 'package:butlery/viewmodels/photo_import/ocr_error_message_builder.dart';
import 'package:butlery/services/import/import_event.dart';
import 'package:butlery/services/ocr_extraction_service.dart';
import 'package:butlery/services/ocr/text_layout.dart';
import 'package:butlery/services/persistence/auto_save_manager.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/utils/os_permission_helper.dart';

/// Resolves the camera or photo-library permission for a pick (flow 07).
/// The view supplies it, because our explanation before the system prompt
/// needs a BuildContext (Skarmar v12 etapp 3 #behkamera).
///
/// [askAgain] is true after an explicit "Fråga igen": the user has just asked
/// for the system prompt, so our explanation is not repeated
/// (produktregler.md:683).
typedef PhotoPermissionResolver =
    Future<OsPermissionOutcome> Function(ImageSource source, bool askAgain);

/// The permission state the photo-import view explains inline: which source
/// was asked for and what the OS answered (flows-roles-budget.md:98-106).
@immutable
class PhotoPermissionNotice {
  const PhotoPermissionNotice({
    required this.source,
    required this.outcome,
    this.addAsPage = false,
  });

  final ImageSource source;
  final OsPermissionOutcome outcome;

  /// The refused pick was "add a page", so "Fråga igen" adds one too.
  final bool addAsPage;
}

/// Photo-import ViewModel: camera/gallery capture → multi-provider OCR →
/// auto-parse to a Recipe. Extends [ImportBaseViewModel] for the shared
/// import lifecycle; heirloom form state lives in
/// [PhotoImportHeirloomFormMixin].
class PhotoImportViewModel extends ImportBaseViewModel
    with PhotoImportHeirloomFormMixin, PhotoImportDraftMixin {
  /// Raw image bytes from the selected photo (OCR input + preview).
  /// In multi-page mode (BUT-903) this mirrors the FIRST page so every existing
  /// single-image consumer — preview thumbnail, heirloom scan, draft staging —
  /// keeps working unchanged. The full ordered set lives in [_pages].
  Uint8List? _imageBytes;

  /// Extracted OCR text awaiting parse/review. In multi-page mode this is the
  /// per-page OCR text concatenated in page order, so the single downstream
  /// parse sees the whole recipe spread as one document.
  String _ocrText = '';

  /// BUT-903: ordered photo pages (max [maxPages]) combined into ONE recipe.
  /// A long recipe split across several cookbook pages OCRs each page then
  /// concatenates the text in this order before a single parse. The single-page
  /// flow is simply the `length == 1` case — [_imageBytes]/[_ocrText] stay the
  /// live combined state so no existing consumer changes.
  final List<_PhotoPage> _pages = [];

  /// This import has written its one parse event (BUT-2238). Adding, removing
  /// or reordering a page re-parses the same import, so it writes no second.
  bool _measured = false;

  /// BUT-684: user opted in to handwritten-recipe mode. When true the pick
  /// pipeline routes the image through the LLM-vision path (which uses a
  /// handwriting-tuned Cloud Function prompt) instead of the char-OCR cascade,
  /// which reliably fails on handwriting. Opt-in because the LLM call costs
  /// more than OCR.space.
  bool _isHandwritten = false;

  /// Last OCR quality score from image assessment (0.0-1.0).
  /// Enables quality-based error messaging and user guidance on image quality.
  double? _lastQualityScore;

  /// Last OCR quality recommendations from image assessment.
  /// Provides actionable suggestions for improving OCR success (lighting, focus, etc.).
  List<String>? _lastRecommendations;

  /// Last OCR confidence score from successful extraction (0.0-1.0).
  /// Indicates reliability of extracted text for user confidence and retry decisions.
  double? _lastConfidence;

  /// All recipes detected on the page. A cookbook spread can hold several;
  /// when >1 the view shows a picker instead of the single "edit" CTA. For a
  /// single recipe this holds one item AND [parsedRecipe] is set, so every
  /// existing single-recipe consumer behaves exactly as before.
  final List<Recipe> _parsedRecipes = [];

  /// Flow 07: resolves the permission before a pick. Null (tests, and any
  /// caller without a view) lets the picker ask the OS itself, as before.
  PhotoPermissionResolver? permissionResolver;

  PhotoPermissionNotice? _permissionNotice;

  /// Where the last page came from; the handwriting path reports it.
  ImageSource _lastPickSource = ImageSource.gallery;

  /// What the view should explain about the last permission answer: a no, a
  /// permanent no, a device block, or the limited "valda bilder" state.
  /// Null when there is nothing to say.
  PhotoPermissionNotice? get permissionNotice => _permissionNotice;

  /// "Fråga igen" after a no (flows-roles-budget.md:102): asks the OS again
  /// for the same source, without repeating our explanation, and picks on a
  /// yes.
  Future<void> askPermissionAgain() async {
    final notice = _permissionNotice;
    if (notice == null) return;
    await _pickImageAndProcess(
      notice.source,
      addAsPage: notice.addAsPage,
      askAgain: true,
    );
  }

  /// "Välj ur bildbiblioteket" after the camera was refused
  /// (flows-roles-budget.md:102). Keeps what the refused pick was for: a
  /// refused add-page leads to adding a page from the library, so the pages
  /// already taken stay; a refused fresh import starts a fresh one.
  Future<void> chooseFromGalleryInstead() async {
    final addAsPage = _permissionNotice?.addAsPage ?? false;
    clearPermissionNotice();
    if (addAsPage) {
      await addPageFromGallery();
    } else {
      await pickImageFromGallery();
    }
  }

  /// Clears the permission notice (the user chose a fallback).
  void clearPermissionNotice() {
    if (_permissionNotice == null) return;
    _permissionNotice = null;
    notifyListeners();
  }

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
  }) {
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

  /// BUT-903: hard cap on combinable pages. A single recipe rarely spans more
  /// than a few cookbook pages; the cap also bounds OCR quota per import.
  static const int maxPages = 5;

  /// BUT-941: per-page byte ceiling for shared photos (matches the 15 MB
  /// validation `_pickImageAndProcess` applies to picked images).
  static const int maxPageSizeMb = 15;

  Uint8List? get imageBytes => _imageBytes;

  /// BUT-684: whether the user marked the current import as a handwritten
  /// recipe (drives the toggle on the photo-import screen).
  bool get isHandwritten => _isHandwritten;

  /// BUT-1460: the toggle is freely switchable except while an import is in
  /// flight. Handwritten mode is a single-image REPLACE flow — a fresh pick
  /// clears the previous capture — so there is no multi-page data-loss to guard
  /// against and no reason to lock the toggle once a capture exists (the old
  /// `_pages.isEmpty` lock trapped the user ON after a handwritten capture). We
  /// only block mid-processing, where flipping would race the running pipeline.
  ///
  /// Q4-04 stages pages before reading, and the handwriting path reads one
  /// image. So handwritten mode cannot be switched on while more than one
  /// page is staged: "Läs av N sidor" would otherwise read the first page and
  /// drop the rest without a word. Switching it off is always allowed.
  bool get canToggleHandwritten =>
      !isProcessing && (_isHandwritten || _pages.length <= 1);

  /// BUT-684: flip handwritten mode. Applies to the NEXT capture — the toggle
  /// sits next to the pick action so the user sets it before choosing a photo.
  /// Ignored while an import is processing (see [canToggleHandwritten]).
  void setHandwritten(bool value) {
    if (isDisposed || _isHandwritten == value || !canToggleHandwritten) return;
    _isHandwritten = value;
    notifyListeners();
  }

  String get ocrText => _ocrText;

  bool get hasImage => _imageBytes != null;

  bool get hasOcrResult => _ocrText.isNotEmpty;

  /// Q4-04 = A (produktbeslut-2026-09-24.json): pages are taken or chosen
  /// first, and the text is read only when the user presses "Läs av N
  /// sidor" (Skarmar v12 del 2 #fotoimport). This counts the pages still
  /// waiting to be read.
  int get unreadPageCount => _pages.where((p) => !p.isRead).length;

  /// The "Läs av N sidor" button can run.
  bool get canReadPages => unreadPageCount > 0 && !isProcessing;

  /// BUT-903: the ordered image bytes for every added page (for the page-strip
  /// thumbnails). One entry per page; index 0 is the first/cover page.
  List<Uint8List> get pageImages =>
      List.unmodifiable(_pages.map((p) => p.bytes));

  /// Number of pages currently combined into the import.
  int get pageCount => _pages.length;

  /// True once a second page exists — the view shows the page strip + reorder
  /// affordances only then, keeping the single-photo flow visually unchanged.
  bool get hasMultiplePages => _pages.length > 1;

  /// False once the page cap is reached, so the "add page" CTA can disable.
  bool get canAddPage => _pages.length < maxPages;

  /// Last OCR quality score for error messaging and user guidance (Phase 2 Enhancement).
  /// Returns quality score from image assessment (0.0-1.0) enabling quality-based
  /// error messages and recommendations display in UI.
  double? get qualityScore => _lastQualityScore;

  /// Last OCR quality recommendations for user guidance (Phase 2 Enhancement).
  /// Returns actionable suggestions from quality assessment for improving OCR success.
  List<String>? get recommendations => _lastRecommendations;

  /// Last OCR confidence score for user confidence indication (Phase 2 Enhancement).
  /// Returns confidence of extracted text (0.0-1.0) enabling reliability display in UI.
  double? get confidence => _lastConfidence;

  /// All recipes detected on the current page (≥1 when parsing succeeded).
  List<Recipe> get parsedRecipes => List.unmodifiable(_parsedRecipes);

  /// True when the page held more than one recipe → show the picker.
  bool get hasMultipleRecipes => _parsedRecipes.length > 1;

  /// BUT-1171: test-only seams that populate the REAL backing fields the
  /// production import pipeline reads (`_ocrText`, `_imageBytes`). Tests now
  /// set the real fields, exercising the production code.
  @visibleForTesting
  void setOcrTextForTesting(String text) {
    _ocrText = text;
    notifyListeners();
  }

  @visibleForTesting
  void setImageBytesForTesting(Uint8List? bytes) {
    _imageBytes = bytes;
    notifyListeners();
  }

  /// Drives the real multi-recipe auto-parse path (normally fired inside the
  /// OCR pipeline) so tests can verify single vs. multi routing without a
  /// camera/OCR round-trip.
  @visibleForTesting
  Future<void> parseOcrTextForTesting(String text) => _autoParseOcrText(text);

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
    _pages.add(
      _PhotoPage(bytes: bytes, text: text, layout: layout, isRead: true),
    );
    await _recombineAndParse();
  }

  /// Q4-04: stages a picked page without reading it, exactly as a capture
  /// does, so tests can prove that nothing is read until [readPages].
  @visibleForTesting
  void stagePageForTesting(Uint8List bytes) => _stagePage(bytes);

  /// OCR processing state indicator for UI progress indication and interaction control.
  /// Indicates active OCR processing operations for loading indicators
  /// and user interaction management during photo processing.
  bool get isProcessing => isLoading;

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
    _measured = false;
    super.clearImportData();
  }

  /// Captures a photo from the camera and runs the OCR + auto-parse pipeline.
  /// Starts a fresh import — replaces any existing pages.
  Future<void> pickImageFromCamera() async {
    await _pickImageAndProcess(ImageSource.camera);
  }

  /// Selects an image from the gallery and runs the OCR + auto-parse pipeline.
  /// Starts a fresh import — replaces any existing pages.
  Future<void> pickImageFromGallery() async {
    await _pickImageAndProcess(ImageSource.gallery);
  }

  /// BUT-903: append a camera photo as the next page of the SAME recipe, then
  /// re-OCR-combine + re-parse. No-op (with an error) once the cap is hit.
  Future<void> addPageFromCamera() async {
    await _pickImageAndProcess(ImageSource.camera, addAsPage: true);
  }

  /// BUT-903: append a gallery photo as the next page of the same recipe.
  Future<void> addPageFromGallery() async {
    await _pickImageAndProcess(ImageSource.gallery, addAsPage: true);
  }

  /// BUT-941: non-fatal note from the last [loadImagesFromPaths] run (e.g. the
  /// over-cap message). Consumed once by the view to show a snackbar so a
  /// truncated share is never silent.
  String? _infoMessage;
  String? consumeInfoMessage() {
    final msg = _infoMessage;
    _infoMessage = null;
    return msg;
  }

  /// BUT-941: seed the import with photos shared from the OS share sheet.
  /// Single- and multi-photo share reuse the multi-page OCR pipeline. Each
  /// page is OCR'd, then the whole set is combined + parsed ONCE (not once
  /// per page) to bound LLM parse cost on a batch share.
  ///
  /// Resilient by design: a corrupt, oversized, or blank page is skipped;
  /// only a batch where every page failed surfaces an error.
  Future<void> loadImagesFromPaths(List<String> paths) async {
    if (isDisposed || paths.isEmpty) return;
    if (!isOnline) {
      setError(AppLocale.current.importOfflineMessage);
      return;
    }

    final overCap = paths.length > maxPages;
    final selected = overCap ? paths.sublist(0, maxPages) : paths;

    clearImportData();
    _pages.clear();

    await executeAsyncVoid(() async {
      var staged = 0;
      for (final path in selected) {
        try {
          final bytes = await XFile(path).readAsBytes();
          final sizeInMB = bytes.length / (1024 * 1024);
          if (sizeInMB > maxPageSizeMb || bytes.isEmpty) continue;
          // Q4-04: shared photos become pages; the text is read when the
          // user presses "Läs av N sidor", as for pages taken in the app.
          _stagePage(bytes, notify: false);
          staged++;
        } catch (_) {
          // Skip this page; a single bad attachment must not abort the batch.
        }
      }
      if (staged == 0) {
        throw Exception(AppLocale.current.shareImportUnreadable);
      }
      notifyListeners();
      // Flag truncation only on a SUCCESSFUL staging — never staple a
      // "max N pages" note onto the all-failed error banner.
      if (overCap) {
        _infoMessage = AppLocale.current.importPhotoPagesMaxReached(maxPages);
      }
    }, errorPrefix: AppLocale.current.errorGeneric);
  }

  /// Q4-04: reads every page not yet read — OCR (or the handwriting path)
  /// page by page in page order — then combines and parses the recipe once.
  /// A page that cannot be read stops the run with its error; the pages
  /// read before it keep their text, and Försök igen continues from there.
  Future<void> readPages() async {
    if (isDisposed || unreadPageCount == 0) return;
    // BUT-610: OCR is a cloud cascade that spins on provider timeouts when
    // offline. Fail fast.
    if (!isOnline) {
      setError(AppLocale.current.importOfflineMessage);
      return;
    }
    await executeAsyncVoid(() async {
      clearError();
      if (_isHandwritten && _pages.length == 1) {
        // Handwritten mode is a single-image flow (BUT-1460). With more than
        // one page (not reachable through the toggle, see
        // canToggleHandwritten) every page goes through the printed path
        // below rather than being dropped.
        final page = _pages.first;
        _lastQualityScore = null;
        _lastRecommendations = null;
        _lastConfidence = null;
        await _extractHandwritten(page.bytes, _lastPickSource);
        return;
      }
      for (var i = 0; i < _pages.length; i++) {
        final page = _pages[i];
        if (page.isRead) continue;
        await _assessQuality(page.bytes);
        final ocrResult = await OCRExtractionService.instance.extractText(
          page.bytes,
        );
        if (!ocrResult.isSuccessful || ocrResult.text.isEmpty) {
          throw Exception(_buildEnhancedErrorMessage(ocrResult));
        }
        _pages[i] = _PhotoPage(
          bytes: page.bytes,
          text: ocrResult.text,
          layout: ocrResult.layout,
          isRead: true,
        );
        _lastConfidence = ocrResult.confidence;
      }
      await _recombineAndParse();
    }, errorPrefix: AppLocale.current.errorGeneric);
  }

  /// BUT-903: drop the page at [index] and recombine. Removing the last page
  /// clears the whole import (same as [clearPhoto]).
  Future<void> removePage(int index) async {
    if (isDisposed || index < 0 || index >= _pages.length) return;
    _pages.removeAt(index);
    if (_pages.isEmpty) {
      clearPhoto();
      return;
    }
    await _recombineAndParse();
  }

  /// BUT-903: move the page at [oldIndex] to [newIndex] (drag-to-reorder) and
  /// recombine — page order is the OCR concatenation order, so reordering can
  /// fix an out-of-sequence capture without re-shooting.
  Future<void> reorderPage(int oldIndex, int newIndex) async {
    if (isDisposed) return;
    if (oldIndex < 0 || oldIndex >= _pages.length) return;
    var target = newIndex;
    // ReorderableListView reports an index past the end when dropping last.
    if (target > oldIndex) target -= 1;
    target = target.clamp(0, _pages.length - 1);
    if (target == oldIndex) return;
    final page = _pages.removeAt(oldIndex);
    _pages.insert(target, page);
    await _recombineAndParse();
  }

  /// Re-runs OCR on the current image after a failure — without this the user
  /// is stuck in a navigation trap (failed OCR, no recovery besides re-shoot).
  Future<void> retryOcr() async {
    if (_imageBytes == null) {
      setError(AppLocale.current.errorNoImageToProcess);
      return;
    }

    // BUT-610: same offline pre-check — a retry re-runs the OCR cloud cascade.
    if (!isOnline) {
      setError(AppLocale.current.importOfflineMessage);
      return;
    }

    // Q4-04: a failed read leaves its page unread, so a retry reads the
    // pages still waiting — the ones already read keep their text.
    if (_pages.isEmpty) _stagePage(_imageBytes!, notify: false);
    if (unreadPageCount == 0) {
      // Nothing waits (a restored draft): read every page again.
      for (var i = 0; i < _pages.length; i++) {
        _pages[i] = _PhotoPage(bytes: _pages[i].bytes, text: '');
      }
    }
    await readPages();
  }

  /// Whether the retry button should show (image still in memory).
  bool get canRetryOcr => _imageBytes != null;

  // BUT-410 heirloom getters/setters live in PhotoImportHeirloomFormMixin.

  /// Clears all photo + OCR state. Call sites are explicit user actions only
  /// (preview X button, post-save cleanup) — see the draft note below.
  void clearPhoto() {
    if (isDisposed) return;

    _imageBytes = null;
    _ocrText = '';
    _pages.clear();
    _lastQualityScore = null;
    _lastRecommendations = null;
    _lastConfidence = null;
    _parsedRecipes.clear();
    _permissionNotice = null;
    // BUT-684: the handwritten opt-in is per-import. Reset it here (the
    // explicit X-button / post-save cleanup) so it isn't sticky across imports
    // and doesn't silently keep the next fresh import on the costlier LLM path.
    // NOT reset in clearImportData(): that runs mid-pick (fresh capture) BEFORE
    // the handwritten branch reads the flag, so resetting there would wipe the
    // toggle the user just set and break the feature.
    _isHandwritten = false;
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
    _imageBytes = bytes;
    _ocrText = draft.ocrText;
    // BUT-903: the draft schema stages one image + the combined OCR text, so a
    // restore rebuilds a single-page set. The user can add more pages on top.
    _pages
      ..clear()
      ..add(
        _PhotoPage(
          bytes: bytes ?? Uint8List(0),
          text: draft.ocrText,
          isRead: true,
        ),
      );
    notifyListeners();
    // The draft's import was measured when it was first read.
    _measured = true;
    await _autoParseOcrText(_ocrText);
    return true;
  }

  @override
  void clearAll() => clearPhoto();

  /// Shared camera/gallery pipeline: pick → validate (format, ≤15MB) →
  /// quality gate → OCR → combine → auto-parse.
  ///
  /// [addAsPage] = false starts a fresh import (replaces all pages); true
  /// (BUT-903) appends the picked image as the next page of the current recipe
  /// and re-runs the combine+parse over every page in order.
  Future<void> _pickImageAndProcess(
    ImageSource source, {
    bool addAsPage = false,
    bool askAgain = false,
  }) async {
    // BUT-610: offline pre-check — OCR runs a multi-provider cloud cascade
    // (OCR.space → Google Vision → Tesseract) that spins 30–90s on provider
    // timeouts when offline. Fail fast before opening the picker.
    if (!isOnline) {
      setError(AppLocale.current.importOfflineMessage);
      return;
    }
    if (addAsPage && !canAddPage) {
      setError(AppLocale.current.importPhotoPagesMaxReached(maxPages));
      return;
    }
    // Flow 07: camera and photos go through the permission contract — our
    // explanation before the system prompt, and a typed answer the view
    // explains (produktregler.md:680-687).
    final resolver = permissionResolver;
    if (resolver != null) {
      final outcome = await resolver(source, askAgain);
      if (isDisposed) return;
      if (!outcome.isUsable) {
        _permissionNotice = PhotoPermissionNotice(
          source: source,
          outcome: outcome,
          addAsPage: addAsPage,
        );
        notifyListeners();
        return;
      }
      // Limited photo access is its own state with a way to choose more
      // (produktregler.md:684); anything else clears the notice.
      _permissionNotice = outcome == OsPermissionOutcome.limited
          ? PhotoPermissionNotice(source: source, outcome: outcome)
          : null;
    }

    if (!addAsPage) {
      clearImportData();
      _pages.clear();
    }

    await executeAsyncVoid(() async {
      // Pick image
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: source,
        maxWidth: 2048, // Limit width to reduce file size
        maxHeight: 2048, // Limit height to reduce file size
        imageQuality:
            85, // Compress image to reduce file size while maintaining OCR quality
      );

      if (picked == null) {
        throw Exception(AppLocale.current.errorNoImageSelected);
      }

      // Validate image format
      final fileName = picked.name.toLowerCase();
      if (!fileName.endsWith('.jpg') &&
          !fileName.endsWith('.jpeg') &&
          !fileName.endsWith('.png')) {
        throw Exception(AppLocale.current.errorImageFormatUnsupported);
      }

      // Read image bytes
      final bytes = await picked.readAsBytes();

      // Validate image size (max maxPageSizeMb after compression)
      final sizeInMB = bytes.length / (1024 * 1024);
      if (sizeInMB > maxPageSizeMb) {
        throw Exception(
          AppLocale.current.errorImageTooLarge(sizeInMB.toStringAsFixed(1)),
        );
      }

      // Q4-04: the page waits here until "Läs av N sidor". Handwritten mode
      // is a single-image flow, so a new pick replaces the page (BUT-1460).
      if (_isHandwritten) _pages.clear();
      _lastPickSource = source;
      _stagePage(bytes);
    }, errorPrefix: AppLocale.current.errorGeneric);
  }

  /// Adds [bytes] as the next page, unread, and drops any combined text and
  /// parse — they no longer describe every page.
  void _stagePage(Uint8List bytes, {bool notify = true}) {
    _pages.add(_PhotoPage(bytes: bytes, text: ''));
    _imageBytes = _pages.first.bytes;
    _ocrText = '';
    _parsedRecipes.clear();
    if (notify) notifyListeners();
  }

  /// BUT-660 pre-flight quality assessment on the printed-text path. A
  /// rejected image throws before any OCR quota is spent.
  Future<void> _assessQuality(Uint8List bytes) async {
    final qualityAssessment = await OCRExtractionService.instance
        .assessImageQuality(bytes);
    _lastQualityScore = qualityAssessment.qualityScore;
    _lastRecommendations = qualityAssessment.recommendations;
    if (qualityAssessment.isRejected) {
      throw Exception(
        qualityAssessment.rejectionReason ?? AppLocale.current.ocrImageRejected,
      );
    }
  }

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
    if (!addAsPage || _isHandwritten) {
      clearImportData();
      _pages.clear();
    }
    _lastPickSource = source;
    _stagePage(bytes);
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
  }) => _extractHandwritten(bytes, source);

  Future<void> _extractHandwritten(Uint8List bytes, ImageSource source) async {
    // BUT-1460: use importSinglePhoto, NOT autoImport. The handwritten LLM-vision
    // result is terminal — autoImport's multi-strategy fallback loop would
    // swallow a terminal failure (or rate-limit denial) into a generic English
    // "No import strategy could handle" message. importSinglePhoto returns the
    // strategy's own result so the setError block below surfaces the real text.
    final result = await importManager.importSinglePhoto(
      'photo',
      options: {
        'imageBytes': bytes,
        'sourceType': source == ImageSource.camera ? 'camera' : 'gallery',
        'isHandwritten': _isHandwritten,
      },
    );
    _measured = result.rateLimitDenied == null;

    if (result.isSuccess && result.recipe != null) {
      final recipe = result.recipe!;
      final reviewText = _recipeToReviewText(recipe);
      // _imageBytes was already set by the caller (_pickImageAndProcess) before
      // routing here — no need to reassign.
      _ocrText = reviewText;
      _lastConfidence = null;
      _pages
        ..clear()
        ..add(_PhotoPage(bytes: bytes, text: reviewText, isRead: true));
      _parsedRecipes
        ..clear()
        ..add(recipe);
      setParsedRecipe(recipe);
      unawaited(persistPhotoDraft(imageBytes: bytes, ocrText: _ocrText));
      return;
    }

    if (result.needsAssistance &&
        result.extractedText.orEmpty().trim().isNotEmpty) {
      final text = result.extractedText!;
      _ocrText = text;
      _lastConfidence = null; // vision path carries no char-OCR confidence
      _pages
        ..clear()
        ..add(_PhotoPage(bytes: bytes, text: text, isRead: true));
      notifyListeners();
      unawaited(persistPhotoDraft(imageBytes: bytes, ocrText: _ocrText));
      await _autoParseOcrText(text);
      return;
    }

    // BUT-684 (review BUG 2): surface the structured rate-limit message the
    // normal import path shows (BUT-1144) — and otherwise the failure's own
    // message — instead of collapsing everything to a generic error. We call
    // setError directly rather than throwing: executeAsyncVoid only shows its
    // errorPrefix on a throw, which would discard this detail (the user would
    // see "something went wrong" instead of "try again in N minutes").
    final denied = result.rateLimitDenied;
    setError(
      denied != null
          ? denied.swedishMessage
          : (result.errorMessage ?? AppLocale.current.errorGeneric),
    );
  }

  /// Render a parsed recipe back to a plain-text block for the interpreted-text
  /// preview. The handwriting vision path returns a structured recipe directly;
  /// this keeps the text-review UX identical to the char-OCR path.
  String _recipeToReviewText(Recipe recipe) {
    final buffer = StringBuffer()..writeln(recipe.title);
    if (recipe.ingredients.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln(recipe.ingredients.join('\n'));
    }
    if (recipe.instructions.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln(recipe.instructions.join('\n'));
    }
    return buffer.toString().trim();
  }

  /// BUT-903: rebuild the combined OCR text from every page in order, keep the
  /// first page as the live preview/heirloom image, persist the draft, then run
  /// ONE auto-parse over the joined text. Shared by add/remove/reorder so all
  /// page mutations converge on the same combine+parse path.
  Future<void> _recombineAndParse() async {
    if (_pages.isEmpty) return;
    _imageBytes = _pages.first.bytes;
    // Q4-04: while a page waits to be read, the combined text would describe
    // only some of the pages. Show none until "Läs av N sidor" runs.
    if (_pages.any((p) => !p.isRead)) {
      _ocrText = '';
      _parsedRecipes.clear();
      notifyListeners();
      return;
    }
    // Blank-line separator so the parser/splitter treats page boundaries the
    // same as the blank lines that already delimit sections within a page.
    _ocrText = _pages.map((p) => p.text).join('\n\n');

    // Built from the SAME list, in the same order, with the same separator the
    // join above uses — `DocumentLayout` joins its pages with '\n\n' too, so
    // the two strings agree row for row and the splitter's precondition can
    // confirm it rather than assume it.
    //
    // Any page without geometry makes this incomplete, and the splitter then
    // falls back to the text rules for the whole import. That is deliberate
    // and it is checked there, not here: this method's job is to build the
    // pair, never to decide whether it is trustworthy.
    final layout = DocumentLayout([for (final p in _pages) p.layout]);

    notifyListeners();

    // BUT-910: OCR is the expensive step — persist as soon as combined text
    // exists so nav-away can't lose it. Fire-and-forget; persist the first
    // page's bytes (the draft schema stages one image) alongside the full text.
    unawaited(persistPhotoDraft(imageBytes: _imageBytes!, ocrText: _ocrText));

    await _autoParseOcrText(_ocrText, layout: layout);
  }

  /// Parse-only auto-parse: recipes exist in memory until the user explicitly
  /// saves (no silent persistence). Failures degrade to the manual-parse path.
  ///
  /// [layout] is omitted by every caller that has no geometry to offer. In
  /// production that is [restoreDraft] — the draft schema stages text and one
  /// image, never per-line boxes — and the handwriting path's
  /// needs-assistance branch, which never went near an OCR tier. Omitting it
  /// is not a degraded path; it is the path that ships today.
  Future<void> _autoParseOcrText(String text, {DocumentLayout? layout}) async {
    try {
      final channel = _measured ? null : ImportChannel.photo;
      _measured = true;
      final result = await importManager.autoParseMulti(
        text,
        layout: layout,
        channel: channel,
      );
      final recipes = result.successfulRecipes;
      _parsedRecipes
        ..clear()
        ..addAll(recipes);
      if (recipes.length == 1) {
        // Single recipe → keep the existing single-recipe behaviour exactly:
        // setParsedRecipe drives every current getter/consumer unchanged.
        setParsedRecipe(recipes.first);
      } else if (recipes.length > 1) {
        notifyListeners();
      }
    } catch (e) {
      // Don't throw error for auto-parsing failures
      // User can still manually parse the OCR text
    }
  }

  /// Save the recipes the user ticked in the multi-recipe picker. Uses the
  /// import-layer save per recipe; heirloom attachment is intentionally NOT
  /// applied here — a multi-recipe page is not a single heirloom scan.
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
        final result = await importManager.saveImportedRecipe(recipe);
        if (!result.isSuccess) _lastSaveFailureCount++;
      }
      if (_lastSaveFailureCount == recipes.length) {
        throw Exception(AppLocale.current.errorGeneric);
      }
    });
  }

  /// BUT-1022: testing seam — the metadata→Swedish-copy contract is load-bearing
  /// for the error the user sees, so it gets direct unit coverage without mocking
  /// the OCR singleton. Build logic lives in [OcrErrorMessageBuilder].
  @visibleForTesting
  String buildEnhancedErrorMessageForTesting(OCRResult result) =>
      _buildEnhancedErrorMessage(result);

  /// BUT-1154: message construction moved to [OcrErrorMessageBuilder]; the VM
  /// keeps the quality-field side effects that the `qualityScore` /
  /// `recommendations` / `confidence` getters expose.
  String _buildEnhancedErrorMessage(OCRResult result) {
    final built = OcrErrorMessageBuilder.build(result);
    _lastQualityScore = built.qualityScore;
    _lastRecommendations = built.recommendations;
    _lastConfidence = built.confidence;
    return built.message;
  }

  @override
  Map<String, dynamic> get debugState => {
    ...super.debugState,
    'hasImage': hasImage,
    'hasOcrResult': hasOcrResult,
    'pageCount': pageCount,
    'ocrTextLength': _ocrText.length,
    'isProcessing': isProcessing,
    'imageBytesSize': _imageBytes?.length ?? 0,
    'ocrServiceStatus': OCRExtractionService.instance.getServiceStatus(),
  };

  @override
  void dispose() {
    // BUT-910: dispose the manager, do NOT discard the draft — surviving
    // disposal (the view disposes this VM on nav-away) is the feature.
    disposeDraftPersistence();
    _imageBytes = null;
    _ocrText = '';
    _pages.clear();
    _lastQualityScore = null;
    _lastRecommendations = null;
    _lastConfidence = null;
    _parsedRecipes.clear();
    super.dispose();
  }
}

/// BUT-903: one captured page of a multi-page photo import — the raw bytes and
/// the OCR text extracted from just that page. Pages are concatenated in list
/// order to form the combined recipe text.
class _PhotoPage {
  final Uint8List bytes;
  final String text;

  /// Where the words sat on this page, when the reader measured them.
  ///
  /// Null unless the free on-device tier read it AND
  /// `enable_layout_recipe_split` is on. A page from a paid tier, from the
  /// handwriting path, or restored from a draft has none — and one such page
  /// makes the whole document decline, by design: `DocumentLayout.isComplete`
  /// is false, its text is null, and the splitter's row-count precondition
  /// refuses it. Mixed provenance means mixed engines, whose type sizes are
  /// not comparable in the first place.
  final PageLayout? layout;

  /// Q4-04: false while the page waits for "Läs av N sidor".
  final bool isRead;

  const _PhotoPage({
    required this.bytes,
    required this.text,
    this.layout,
    this.isRead = false,
  });
}
