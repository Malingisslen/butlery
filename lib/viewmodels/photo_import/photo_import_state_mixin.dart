import 'package:butlery/viewmodels/photo_import/photo_page.dart';
import 'package:butlery/viewmodels/photo_import/photo_permission_notice.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/viewmodels/import_base_viewmodel.dart';
import 'package:butlery/viewmodels/photo_import/photo_import_ai_offer_mixin.dart';

/// BUT-903: hard cap on combinable pages. A single recipe rarely spans more
/// than a few cookbook pages; the cap also bounds OCR quota per import.
const int kPhotoImportMaxPages = 5;

/// The staged pages, OCR text, parse results and the toggles the photo
/// import's pipelines share. The pipelines live in [PhotoImportPickMixin]
/// and [PhotoImportReadMixin].
mixin PhotoImportStateMixin on ImportBaseViewModel, PhotoImportAiOfferMixin {
  /// Raw image bytes from the selected photo (OCR input + preview).
  /// In multi-page mode (BUT-903) this mirrors the FIRST page so every existing
  /// single-image consumer — preview thumbnail, heirloom scan, draft staging —
  /// keeps working unchanged. The full ordered set lives in [photoPages].
  @protected
  Uint8List? photoBytes;

  /// Extracted OCR text awaiting parse/review. In multi-page mode this is the
  /// per-page OCR text concatenated in page order, so the single downstream
  /// parse sees the whole recipe spread as one document.
  @protected
  String photoOcrText = '';

  /// BUT-903: ordered photo pages (max [kPhotoImportMaxPages]) combined into ONE recipe.
  /// A long recipe split across several cookbook pages OCRs each page then
  /// concatenates the text in this order before a single parse. The single-page
  /// flow is simply the `length == 1` case — [photoBytes]/[photoOcrText] stay the
  /// live combined state so no existing consumer changes.
  @protected
  final List<PhotoPage> photoPages = [];

  /// This import has written its one parse event (BUT-2238). Adding, removing
  /// or reordering a page re-parses the same import, so it writes no second.
  @protected
  bool importMeasured = false;

  /// The AI reading has read this import, so a parse that finds nothing is
  /// not offered to it again.
  @protected
  bool aiReadingUsed = false;

  /// BUT-684: user opted in to handwritten-recipe mode. When true the pick
  /// pipeline routes the image through the LLM-vision path (which uses a
  /// handwriting-tuned Cloud Function prompt) instead of the char-OCR cascade,
  /// which reliably fails on handwriting.
  @protected
  bool handwrittenMode = false;

  /// Last OCR quality score from image assessment (0.0-1.0).
  /// Enables quality-based error messaging and user guidance on image quality.
  @protected
  double? lastQualityScore;

  /// Last OCR quality recommendations from image assessment.
  /// Provides actionable suggestions for improving OCR success (lighting, focus, etc.).
  @protected
  List<String>? lastRecommendations;

  /// Last OCR confidence score from successful extraction (0.0-1.0).
  /// Indicates reliability of extracted text for user confidence and retry decisions.
  @protected
  double? lastConfidence;

  /// All recipes detected on the page. A cookbook spread can hold several;
  /// when >1 the view shows a picker instead of the single "edit" CTA. For a
  /// single recipe this holds one item AND [parsedRecipe] is set, so every
  /// existing single-recipe consumer behaves exactly as before.
  @protected
  final List<Recipe> parsedRecipeList = [];

  @protected
  PhotoPermissionNotice? permissionNoticeState;

  /// Where the last page came from; the handwriting path reports it.
  @protected
  ImageSource lastPickSource = ImageSource.gallery;

  /// What the view should explain about the last permission answer: a no, a
  /// permanent no, a device block, or the limited "valda bilder" state.
  /// Null when there is nothing to say.
  PhotoPermissionNotice? get permissionNotice => permissionNoticeState;

  /// BUT-684: whether the user marked the current import as a handwritten
  /// recipe (drives the toggle on the photo-import screen).
  bool get isHandwritten => handwrittenMode;

  /// BUT-1460: the toggle is freely switchable except while an import is in
  /// flight. Handwritten mode is a single-image REPLACE flow — a fresh pick
  /// clears the previous capture — so there is no multi-page data-loss to guard
  /// against and no reason to lock the toggle once a capture exists (the old
  /// `photoPages.isEmpty` lock trapped the user ON after a handwritten capture). We
  /// only block mid-processing, where flipping would race the running pipeline.
  ///
  /// Q4-04 stages pages before reading, and the handwriting path reads one
  /// image. So handwritten mode cannot be switched on while more than one
  /// page is staged: "Läs av N sidor" would otherwise read the first page and
  /// drop the rest without a word. Switching it off is always allowed.
  bool get canToggleHandwritten =>
      !isProcessing && (handwrittenMode || photoPages.length <= 1);

  /// BUT-684: flip handwritten mode. Applies to the NEXT capture — the toggle
  /// sits next to the pick action so the user sets it before choosing a photo.
  /// Ignored while an import is processing (see [canToggleHandwritten]).
  void setHandwritten(bool value) {
    if (isDisposed || handwrittenMode == value || !canToggleHandwritten) return;
    handwrittenMode = value;
    notifyListeners();
  }

  String get ocrText => photoOcrText;

  bool get hasImage => photoBytes != null;

  bool get hasOcrResult => photoOcrText.isNotEmpty;

  /// Q4-04 = A: pages are taken or chosen
  /// first, and the text is read only when the user presses "Läs av N
  /// sidor". This counts the pages still
  /// waiting to be read.
  int get unreadPageCount => photoPages.where((p) => !p.isRead).length;

  /// The "Läs av N sidor" button can run.
  bool get canReadPages => unreadPageCount > 0 && !isProcessing;

  /// BUT-903: the ordered image bytes for every added page (for the page-strip
  /// thumbnails). One entry per page; index 0 is the first/cover page.
  List<Uint8List> get pageImages =>
      List.unmodifiable(photoPages.map((p) => p.bytes));

  /// Number of pages currently combined into the import.
  int get pageCount => photoPages.length;

  /// True once a second page exists — the view shows the page strip + reorder
  /// affordances only then, keeping the single-photo flow visually unchanged.
  bool get hasMultiplePages => photoPages.length > 1;

  /// False once the page cap is reached, so the "add page" CTA can disable.
  bool get canAddPage => photoPages.length < kPhotoImportMaxPages;

  /// Last OCR quality score for error messaging and user guidance (Phase 2 Enhancement).
  /// Returns quality score from image assessment (0.0-1.0) enabling quality-based
  /// error messages and recommendations display in UI.
  double? get qualityScore => lastQualityScore;

  /// Last OCR quality recommendations for user guidance (Phase 2 Enhancement).
  /// Returns actionable suggestions from quality assessment for improving OCR success.
  List<String>? get recommendations => lastRecommendations;

  /// Last OCR confidence score for user confidence indication (Phase 2 Enhancement).
  /// Returns confidence of extracted text (0.0-1.0) enabling reliability display in UI.
  double? get confidence => lastConfidence;

  /// All recipes detected on the current page (≥1 when parsing succeeded).
  List<Recipe> get parsedRecipes => List.unmodifiable(parsedRecipeList);

  /// True when the page held more than one recipe → show the picker.
  bool get hasMultipleRecipes => parsedRecipeList.length > 1;

  /// OCR processing state indicator for UI progress indication and interaction control.
  /// Indicates active OCR processing operations for loading indicators
  /// and user interaction management during photo processing.
  bool get isProcessing => isLoading;

  /// BUT-941: non-fatal note from the last [loadImagesFromPaths] run (e.g. the
  /// over-cap message). Consumed once by the view to show a snackbar so a
  /// truncated share is never silent.
  @protected
  String? infoMessageState;

  /// Adds [bytes] as the next page, unread, and drops any combined text and
  /// parse — they no longer describe every page.
  @protected
  void stagePage(Uint8List bytes, {bool notify = true}) {
    photoPages.add(PhotoPage(bytes: bytes, text: ''));
    photoBytes = photoPages.first.bytes;
    photoOcrText = '';
    parsedRecipeList.clear();
    clearAiOffer();
    if (notify) notifyListeners();
  }
}
