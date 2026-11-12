import 'package:butlery/viewmodels/photo_import/photo_permission_notice.dart';
import 'package:butlery/viewmodels/photo_import/photo_import_state_mixin.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:butlery/viewmodels/import_base_viewmodel.dart';
import 'package:butlery/viewmodels/photo_import/photo_import_ai_offer_mixin.dart';
import 'package:butlery/core/constants/upload_constants.dart';
import 'package:butlery/services/import/document_scan_service.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/utils/os_permission_helper.dart';

/// Taking or choosing photos: the permission contract, the camera and gallery
/// picks, document scanning and photos shared from the OS.
mixin PhotoImportPickMixin
    on ImportBaseViewModel, PhotoImportAiOfferMixin, PhotoImportStateMixin {
  @protected
  DocumentScanService get documentScanner;

  /// Flow 07: resolves the permission before a pick. Null (tests, and any
  /// caller without a view) lets the picker ask the OS itself, as before.
  PhotoPermissionResolver? permissionResolver;

  /// "Fråga igen" after a no: asks the OS again
  /// for the same source, without repeating our explanation, and picks on a
  /// yes.
  Future<void> askPermissionAgain() async {
    final notice = permissionNoticeState;
    if (notice == null) return;
    await pickImageAndProcess(
      notice.source,
      addAsPage: notice.addAsPage,
      askAgain: true,
    );
  }

  /// "Välj ur bildbiblioteket" after the camera was refused
  /// Keeps what the refused pick was for: a
  /// refused add-page leads to adding a page from the library, so the pages
  /// already taken stay; a refused fresh import starts a fresh one.
  Future<void> chooseFromGalleryInstead() async {
    final addAsPage = permissionNoticeState?.addAsPage ?? false;
    clearPermissionNotice();
    if (addAsPage) {
      await addPageFromGallery();
    } else {
      await pickImageFromGallery();
    }
  }

  /// Clears the permission notice (the user chose a fallback).
  void clearPermissionNotice() {
    if (permissionNoticeState == null) return;
    permissionNoticeState = null;
    notifyListeners();
  }

  /// Captures a photo from the camera and runs the OCR + auto-parse pipeline.
  /// Starts a fresh import — replaces any existing pages.
  Future<void> pickImageFromCamera() async {
    await pickImageAndProcess(ImageSource.camera);
  }

  /// Selects an image from the gallery and runs the OCR + auto-parse pipeline.
  /// Starts a fresh import — replaces any existing pages.
  Future<void> pickImageFromGallery() async {
    await pickImageAndProcess(ImageSource.gallery);
  }

  /// BUT-903: append a camera photo as the next page of the SAME recipe, then
  /// re-OCR-combine + re-parse. No-op (with an error) once the cap is hit.
  Future<void> addPageFromCamera() async {
    await pickImageAndProcess(ImageSource.camera, addAsPage: true);
  }

  /// BUT-903: append a gallery photo as the next page of the same recipe.
  Future<void> addPageFromGallery() async {
    await pickImageAndProcess(ImageSource.gallery, addAsPage: true);
  }

  String? consumeInfoMessage() {
    final msg = infoMessageState;
    infoMessageState = null;
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

    final overCap = paths.length > kPhotoImportMaxPages;
    final selected = overCap ? paths.sublist(0, kPhotoImportMaxPages) : paths;

    clearImportData();
    photoPages.clear();

    await executeAsyncVoid(() async {
      var staged = 0;
      for (final path in selected) {
        try {
          final bytes = await XFile(path).readAsBytes();
          if (bytes.length > UploadConstants.maxAiReaderPageBytes ||
              bytes.isEmpty) {
            continue;
          }
          // Q4-04: shared photos become pages; the text is read when the
          // user presses "Läs av N sidor", as for pages taken in the app.
          stagePage(bytes, notify: false);
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
        infoMessageState = AppLocale.current.importPhotoPagesMaxReached(
          kPhotoImportMaxPages,
        );
      }
    }, errorPrefix: AppLocale.current.errorGeneric);
  }

  /// Shared camera/gallery pipeline: pick → validate (format, size within the AI reader's limit) →
  /// quality gate → OCR → combine → auto-parse.
  ///
  /// [addAsPage] = false starts a fresh import (replaces all pages); true
  /// (BUT-903) appends the picked image as the next page of the current recipe
  /// and re-runs the combine+parse over every page in order.
  @protected
  Future<void> pickImageAndProcess(
    ImageSource source, {
    bool addAsPage = false,
    bool askAgain = false,
  }) async {
    if (addAsPage && !canAddPage) {
      setError(
        AppLocale.current.importPhotoPagesMaxReached(kPhotoImportMaxPages),
      );
      return;
    }
    // Flow 07: camera and photos go through the permission contract — our
    // explanation before the system prompt, and a typed answer the view
    // explains.
    final resolver = permissionResolver;
    if (resolver != null) {
      final outcome = await resolver(source, askAgain);
      if (isDisposed) return;
      if (!outcome.isUsable) {
        permissionNoticeState = PhotoPermissionNotice(
          source: source,
          outcome: outcome,
          addAsPage: addAsPage,
        );
        notifyListeners();
        return;
      }
      // Limited photo access is its own state with a way to choose more
      // anything else clears the notice.
      permissionNoticeState = outcome == OsPermissionOutcome.limited
          ? PhotoPermissionNotice(source: source, outcome: outcome)
          : null;
    }

    if (!addAsPage) {
      clearImportData();
      photoPages.clear();
    }

    await executeAsyncVoid(() async {
      final remaining = addAsPage
          ? kPhotoImportMaxPages - photoPages.length
          : kPhotoImportMaxPages;
      final multi =
          source == ImageSource.gallery && !handwrittenMode && remaining > 1;
      final scan = source == ImageSource.camera
          ? await documentScanner.scanPages(
              maxPages: handwrittenMode ? 1 : remaining,
            )
          : const DocumentScanUnavailable();
      if (scan is DocumentScanDenied) {
        permissionNoticeState = PhotoPermissionNotice(
          source: source,
          outcome: OsPermissionOutcome.denied,
          addAsPage: addAsPage,
        );
        notifyListeners();
        return;
      }

      // Picks arrive in selection order, which becomes the page order. The
      // cap counts valid photos, so a bad one never costs a good one its slot.
      final staged = <Uint8List>[];
      Object? firstError;
      var overCap = false;
      if (scan is DocumentScanCancelled) {
        throw Exception(AppLocale.current.errorNoImageSelected);
      } else if (scan is DocumentScanPages) {
        overCap = scan.overCap && !handwrittenMode;
        for (final page in scan.pages) {
          try {
            staged.add(checkedSize(page));
          } catch (e) {
            firstError ??= e;
          }
        }
      } else {
        final List<XFile> picked = multi
            ? await pickGalleryImages(remaining)
            : await pickSingleImage(source);

        if (picked.isEmpty) {
          throw Exception(AppLocale.current.errorNoImageSelected);
        }
        for (final file in picked) {
          if (staged.length == remaining) {
            overCap = true;
            break;
          }
          try {
            staged.add(await validatedBytes(file));
          } catch (e) {
            firstError ??= e;
          }
        }
      }
      // A single pick keeps its specific error; a batch only fails when no
      // page survived, so one bad photo never discards the others.
      if (staged.isEmpty) throw firstError!;

      // Q4-04: pages wait here until "Läs av N sidor". Handwritten mode is a
      // single-image flow, so a new pick replaces the page (BUT-1460).
      if (handwrittenMode) photoPages.clear();
      lastPickSource = source;
      for (final bytes in staged) {
        stagePage(bytes, notify: false);
      }
      notifyListeners();
      if (overCap) {
        infoMessageState = AppLocale.current.importPhotoPagesMaxReached(
          kPhotoImportMaxPages,
        );
      }
    }, errorPrefix: AppLocale.current.errorGeneric);
  }

  /// Test seam: the real gallery picker needs a platform channel.
  @visibleForTesting
  Future<List<XFile>> Function(int limit)? galleryPickerOverride;

  @protected
  Future<List<XFile>> pickGalleryImages(int limit) async {
    final override = galleryPickerOverride;
    if (override != null) return override(limit);
    return ImagePicker().pickMultiImage(
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 85,
      limit: limit,
    );
  }

  @protected
  Future<List<XFile>> pickSingleImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 85,
    );
    return picked == null ? const [] : [picked];
  }

  @protected
  Future<Uint8List> validatedBytes(XFile picked) async {
    final fileName = picked.name.toLowerCase();
    if (!fileName.endsWith('.jpg') &&
        !fileName.endsWith('.jpeg') &&
        !fileName.endsWith('.png')) {
      throw Exception(AppLocale.current.errorImageFormatUnsupported);
    }
    return checkedSize(await picked.readAsBytes());
  }

  /// A page the AI reader's server would refuse is refused here, before the
  /// user waits on an upload that cannot succeed.
  @protected
  Uint8List checkedSize(Uint8List bytes) {
    if (bytes.length > UploadConstants.maxAiReaderPageBytes) {
      throw Exception(
        AppLocale.current.errorImageTooLarge(
          (bytes.length / (1024 * 1024)).toStringAsFixed(1),
        ),
      );
    }
    return bytes;
  }
}
