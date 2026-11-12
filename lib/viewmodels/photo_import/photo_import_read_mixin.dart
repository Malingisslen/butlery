import 'package:butlery/viewmodels/photo_import/photo_page.dart';
import 'package:butlery/viewmodels/photo_import/photo_import_state_mixin.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/viewmodels/import_base_viewmodel.dart';
import 'package:butlery/viewmodels/photo_import/photo_import_draft_mixin.dart';
import 'package:butlery/viewmodels/photo_import/photo_import_ai_offer_mixin.dart';
import 'package:butlery/viewmodels/photo_import/ocr_error_message_builder.dart';
import 'package:butlery/services/import/import_event.dart';
import 'package:butlery/services/import/import_manager_result.dart';
import 'package:butlery/services/import/layout/page_reflow.dart';
import 'package:butlery/services/ocr_extraction_service.dart';
import 'package:butlery/services/ocr/text_layout.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/l10n/app_locale.dart';

/// Reading the staged pages: OCR, the AI reading offer, combining the pages
/// and the auto-parse.
mixin PhotoImportReadMixin
    on
        ImportBaseViewModel,
        PhotoImportAiOfferMixin,
        PhotoImportDraftMixin,
        PhotoImportStateMixin {
  @protected
  void clearPhoto();

  /// Q4-04: reads every page not yet read — OCR (or the handwriting path)
  /// page by page in page order — then combines and parses the recipe once.
  Future<void> readPages() async {
    if (isDisposed || unreadPageCount == 0) return;
    await executeAsyncVoid(() async {
      clearError();
      clearAiOffer();
      if (handwrittenMode && photoPages.length == 1) {
        // Handwritten mode is a single-image flow (BUT-1460). With more than
        // one page (not reachable through the toggle, see
        // canToggleHandwritten) every page goes through the printed path
        // below rather than being dropped.
        // No phone reading exists for handwriting, so offline there is
        // nothing to try and no point asking for consent.
        if (!isOnline) {
          setError(AppLocale.current.importOfflineMessage);
          return;
        }
        final page = photoPages.first;
        lastQualityScore = null;
        lastRecommendations = null;
        lastConfidence = null;
        // The phone cannot read handwriting, so the photo would have to be
        // sent; without consent that is asked first.
        if (!await hasAiConsent()) {
          await offerAi(PhotoAiOfferReason.handwriting);
          return;
        }
        aiReadingUsed = true;
        await extractWithAi(page.bytes, lastPickSource);
        return;
      }
      var phoneMissedAPage = false;
      for (var i = 0; i < photoPages.length; i++) {
        final page = photoPages[i];
        if (page.isRead) continue;
        await assessQuality(page.bytes);
        final ocrResult = await OCRExtractionService.instance.extractText(
          page.bytes,
        );
        if (!ocrResult.isSuccessful || ocrResult.text.isEmpty) {
          final message = buildEnhancedErrorMessage(ocrResult);
          // A photo the quality gate refused is too small or blurred for the
          // AI reading too, so its own advice is shown instead of the offer.
          if (ocrResult.processingMethod == 'pre_ocr_quality_gate') {
            throw Exception(message);
          }
          phoneMissedAPage = true;
          continue;
        }
        photoPages[i] = PhotoPage(
          bytes: page.bytes,
          text: ocrResult.text,
          layout: ocrResult.layout,
          isRead: true,
        );
        lastConfidence = ocrResult.confidence;
      }
      // Every page gets the phone's try first, so only the pages it missed
      // are offered to the AI reading.
      if (phoneMissedAPage) {
        await offerAi(PhotoAiOfferReason.phoneCouldNotRead);
        return;
      }
      await recombineAndParse();
      if (parsedRecipeList.isEmpty && !aiReadingUsed) {
        await offerAi(PhotoAiOfferReason.noRecipeFound);
      }
    }, errorPrefix: AppLocale.current.errorGeneric);
  }

  /// "Ja, skicka fotot": records the consent if it is not given yet, then lets
  /// the AI reading read the photo. With one page the AI's recipe is used as
  /// it comes; with several, each page the phone could not read (or every
  /// page, when the phone's text held no recipe) is read and the text joined.
  Future<void> acceptAiOffer() async {
    if (isDisposed || aiOffer == null) return;
    if (!isOnline) {
      setError(AppLocale.current.importOfflineMessage);
      return;
    }
    final reason = takeAiOffer();
    await executeAsyncVoid(() async {
      clearError();
      if (!await ensureAiConsent()) {
        if (reason != null) await offerAi(reason);
        return;
      }
      aiReadingUsed = true;
      if (photoPages.length == 1) {
        await extractWithAi(photoPages.first.bytes, lastPickSource);
        return;
      }
      for (var i = 0; i < photoPages.length; i++) {
        final page = photoPages[i];
        if (page.isRead && reason != PhotoAiOfferReason.noRecipeFound) continue;
        final result = await readWithAi(page.bytes, lastPickSource);
        final text = result.isSuccess && result.recipe != null
            ? recipeToReviewText(result.recipe!)
            : result.extractedText.orEmpty().trim();
        if (text.isEmpty) {
          final denied = result.rateLimitDenied;
          setError(
            denied != null
                ? denied.swedishMessage
                : (result.errorMessage ?? AppLocale.current.errorGeneric),
          );
          return;
        }
        photoPages[i] = PhotoPage(bytes: page.bytes, text: text, isRead: true);
      }
      await recombineAndParse();
    }, errorPrefix: AppLocale.current.errorGeneric);
  }

  /// "Nej, jag skriver själv": nothing is sent. What the phone read stays as
  /// editable text, and a page it could not read counts as read with no text.
  Future<void> declineAiOffer() async {
    if (isDisposed || aiOffer == null) return;
    takeAiOffer();
    for (var i = 0; i < photoPages.length; i++) {
      if (!photoPages[i].isRead) {
        photoPages[i] = PhotoPage(
          bytes: photoPages[i].bytes,
          text: '',
          isRead: true,
        );
      }
    }
    await recombineAndParse();
  }

  /// BUT-903: drop the page at [index] and recombine. Removing the last page
  /// clears the whole import (same as [clearPhoto]).
  Future<void> removePage(int index) async {
    if (isDisposed || index < 0 || index >= photoPages.length) return;
    photoPages.removeAt(index);
    clearAiOffer();
    if (photoPages.isEmpty) {
      clearPhoto();
      return;
    }
    await recombineAndParse();
  }

  /// BUT-903: move the page at [oldIndex] to [newIndex] (drag-to-reorder) and
  /// recombine — page order is the OCR concatenation order, so reordering can
  /// fix an out-of-sequence capture without re-shooting.
  Future<void> reorderPage(int oldIndex, int newIndex) async {
    if (isDisposed) return;
    if (oldIndex < 0 || oldIndex >= photoPages.length) return;
    var target = newIndex;
    // ReorderableListView reports an index past the end when dropping last.
    if (target > oldIndex) target -= 1;
    target = target.clamp(0, photoPages.length - 1);
    if (target == oldIndex) return;
    final page = photoPages.removeAt(oldIndex);
    photoPages.insert(target, page);
    clearAiOffer();
    await recombineAndParse();
  }

  /// Re-runs OCR on the current image after a failure — without this the user
  /// is stuck in a navigation trap (failed OCR, no recovery besides re-shoot).
  Future<void> retryOcr() async {
    if (photoBytes == null) {
      setError(AppLocale.current.errorNoImageToProcess);
      return;
    }

    // Q4-04: a failed read leaves its page unread, so a retry reads the
    // pages still waiting — the ones already read keep their text.
    if (photoPages.isEmpty) stagePage(photoBytes!, notify: false);
    if (unreadPageCount == 0) {
      // Nothing waits (a restored draft): read every page again.
      for (var i = 0; i < photoPages.length; i++) {
        photoPages[i] = PhotoPage(bytes: photoPages[i].bytes, text: '');
      }
    }
    await readPages();
  }

  /// Whether the retry button should show (image still in memory).
  bool get canRetryOcr => photoBytes != null;

  /// BUT-660 pre-flight quality assessment on the printed-text path. A
  /// rejected image throws before any OCR quota is spent.
  @protected
  Future<void> assessQuality(Uint8List bytes) async {
    final qualityAssessment = await OCRExtractionService.instance
        .assessImageQuality(bytes);
    lastQualityScore = qualityAssessment.qualityScore;
    lastRecommendations = qualityAssessment.recommendations;
    if (qualityAssessment.isRejected) {
      throw Exception(
        qualityAssessment.rejectionReason ?? AppLocale.current.ocrImageRejected,
      );
    }
  }

  /// BUT-1460: importSinglePhoto, NOT autoImport. The LLM-vision result is
  /// terminal — autoImport's multi-strategy fallback loop would swallow a
  /// terminal failure (or rate-limit denial) into a generic English "No import
  /// strategy could handle" message. importSinglePhoto returns the strategy's
  /// own result so the caller surfaces the real text.
  @protected
  Future<ImportManagerResult> readWithAi(
    Uint8List bytes,
    ImageSource source,
  ) async {
    final result = await importManager.importSinglePhoto(
      'photo',
      options: {
        'imageBytes': bytes,
        'sourceType': source == ImageSource.camera ? 'camera' : 'gallery',
        'isHandwritten': handwrittenMode,
        'visionOnly': true,
      },
    );
    importMeasured = result.rateLimitDenied == null;
    return result;
  }

  @protected
  Future<void> extractWithAi(Uint8List bytes, ImageSource source) async {
    final result = await readWithAi(bytes, source);

    if (result.isSuccess && result.recipe != null) {
      final recipe = result.recipe!;
      final reviewText = recipeToReviewText(recipe);
      // photoBytes was already set by the caller (pickImageAndProcess) before
      // routing here — no need to reassign.
      photoOcrText = reviewText;
      lastConfidence = null;
      photoPages
        ..clear()
        ..add(PhotoPage(bytes: bytes, text: reviewText, isRead: true));
      parsedRecipeList
        ..clear()
        ..add(recipe);
      setParsedRecipe(recipe);
      unawaited(persistPhotoDraft(imageBytes: bytes, ocrText: photoOcrText));
      return;
    }

    if (result.needsAssistance &&
        result.extractedText.orEmpty().trim().isNotEmpty) {
      final text = result.extractedText!;
      photoOcrText = text;
      lastConfidence = null; // vision path carries no char-OCR confidence
      photoPages
        ..clear()
        ..add(PhotoPage(bytes: bytes, text: text, isRead: true));
      notifyListeners();
      unawaited(persistPhotoDraft(imageBytes: bytes, ocrText: photoOcrText));
      await autoParseOcrText(text);
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
  @protected
  String recipeToReviewText(Recipe recipe) {
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
  @protected
  Future<void> recombineAndParse() async {
    if (photoPages.isEmpty) return;
    photoBytes = photoPages.first.bytes;
    // Q4-04: while a page waits to be read, the combined text would describe
    // only some of the pages. Show none until "Läs av N sidor" runs.
    if (photoPages.any((p) => !p.isRead)) {
      photoOcrText = '';
      parsedRecipeList.clear();
      notifyListeners();
      return;
    }
    // BUT-2455: each page loses its screenshot chrome, a page loses the lines
    // it shares with the page before it, and the pages are joined — with a
    // blank line at every boundary when every page has geometry, so the text
    // and `DocumentLayout` agree row for row and the splitter's precondition
    // can confirm it rather than assume it.
    //
    // Any page without geometry makes the layout incomplete, and the splitter
    // then falls back to the text rules for the whole import. That is
    // deliberate and it is checked there, not here: this method's job is to
    // build the pair, never to decide whether it is trustworthy.
    final prepared = prepareScreenPages([
      for (final p in photoPages) PageText(p.text, layout: p.layout),
    ]);
    photoOcrText = prepared.text;
    final layout = DocumentLayout(prepared.layouts);

    notifyListeners();

    // BUT-910: OCR is the expensive step — persist as soon as combined text
    // exists so nav-away can't lose it. Fire-and-forget; persist the first
    // page's bytes (the draft schema stages one image) alongside the full text.
    unawaited(
      persistPhotoDraft(imageBytes: photoBytes!, ocrText: photoOcrText),
    );

    await autoParseOcrText(photoOcrText, layout: layout, reflow: true);
  }

  /// Parse-only auto-parse: recipes exist in memory until the user explicitly
  /// saves (no silent persistence). Failures degrade to the manual-parse path.
  ///
  /// [layout] is omitted by every caller that has no geometry to offer. In
  /// production that is [restoreDraft] — the draft schema stages text and one
  /// image, never per-line boxes — and the handwriting path's
  /// needs-assistance branch, which never went near an OCR tier. Omitting it
  /// is not a degraded path; it is the path that ships today.
  ///
  /// [reflow] rejoins OCR-wrapped lines. The page paths ask for it; the
  /// text behind a handwritten photo never had OCR line breaks and does not.
  @protected
  Future<void> autoParseOcrText(
    String text, {
    DocumentLayout? layout,
    bool reflow = false,
  }) async {
    try {
      final channel = importMeasured ? null : ImportChannel.photo;
      importMeasured = true;
      final result = await importManager.autoParseMulti(
        text,
        layout: layout,
        channel: channel,
        reflow: reflow,
      );
      final recipes = result.successfulRecipes;
      parsedRecipeList
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

  /// BUT-1022: testing seam — the metadata→Swedish-copy contract is load-bearing
  /// for the error the user sees, so it gets direct unit coverage without mocking
  /// the OCR singleton. Build logic lives in [OcrErrorMessageBuilder].
  @visibleForTesting
  String buildEnhancedErrorMessageForTesting(OCRResult result) =>
      buildEnhancedErrorMessage(result);

  /// BUT-1154: message construction moved to [OcrErrorMessageBuilder]; the VM
  /// keeps the quality-field side effects that the `qualityScore` /
  /// `recommendations` / `confidence` getters expose.
  @protected
  String buildEnhancedErrorMessage(OCRResult result) {
    final built = OcrErrorMessageBuilder.build(result);
    lastQualityScore = built.qualityScore;
    lastRecommendations = built.recommendations;
    lastConfidence = built.confidence;
    return built.message;
  }
}
