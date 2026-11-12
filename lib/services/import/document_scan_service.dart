/// Native document scanner (VisionKit on iOS, ML Kit on Android) for the
/// photo-import camera button.
///
/// Every failure that is not a refused camera permission is reported as
/// [DocumentScanUnavailable] so the caller can quietly fall back to the plain
/// camera: a device without Play services must still be able to take a photo.
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/feature_flags/feature_flag_service.dart';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Thin seam over the platform scanner so tests need no camera.
abstract class DocumentScanner {
  /// File paths of the scanned pages, or null when the user cancelled.
  Future<List<String>?> scan({required int maxPages});

  /// Removes the scanner's cached page files; best-effort.
  Future<void> cleanUp();
}

/// Thrown by a [DocumentScanner] when the OS camera permission is refused.
class DocumentScanPermissionDenied implements Exception {
  const DocumentScanPermissionDenied();
}

class CunningDocumentScannerAdapter implements DocumentScanner {
  const CunningDocumentScannerAdapter();

  @override
  Future<List<String>?> scan({required int maxPages}) async {
    try {
      final result = await CunningDocumentScanner.scanDocuments(
        noOfPages: maxPages,
        scannerSource: ScannerSource.camera,
        androidScannerMode: AndroidScannerMode.full,
        iosScannerOptions: IosScannerOptions(
          imageFormat: IosImageFormat.jpg,
          jpgCompressionQuality: 0.85,
        ),
      );
      return result == null ? null : List.of(result.images);
    } on CunningDocumentScannerException catch (e) {
      if (e.code == 'permission_denied') {
        throw const DocumentScanPermissionDenied();
      }
      rethrow;
    }
  }

  @override
  Future<void> cleanUp() => CunningDocumentScanner.cleanCache();
}

sealed class DocumentScanResult {
  const DocumentScanResult();
}

class DocumentScanPages extends DocumentScanResult {
  const DocumentScanPages(this.pages, {required this.overCap});
  final List<Uint8List> pages;

  /// The scanner returned more pages than there were free slots.
  final bool overCap;
}

class DocumentScanCancelled extends DocumentScanResult {
  const DocumentScanCancelled();
}

class DocumentScanDenied extends DocumentScanResult {
  const DocumentScanDenied();
}

class DocumentScanUnavailable extends DocumentScanResult {
  const DocumentScanUnavailable();
}

typedef PageResizer = Future<Uint8List> Function(Uint8List bytes);
typedef PageReader = Future<Uint8List> Function(String path);

class DocumentScanService {
  DocumentScanService({
    DocumentScanner? scanner,
    bool Function()? isEnabled,
    bool? platformSupported,
    PageResizer? resizer,
    PageReader? reader,
  }) : _scanner = scanner ?? const CunningDocumentScannerAdapter(),
       _isEnabled = isEnabled ?? (() => false),
       _platformSupported = platformSupported ?? _nativePlatform,
       _resizer = resizer ?? _resizeInBackground,
       _reader = reader ?? ((path) => File(path).readAsBytes());

  /// Reads the flag live so a Remote Config change applies without a restart.
  factory DocumentScanService.withFlags(FeatureFlagService? flags) =>
      DocumentScanService(
        isEnabled: () =>
            flags?.isEnabled(FeatureFlags.enableDocumentScanner) ?? false,
      );

  /// Same long edge as the gallery/camera picker, so both routes hand the
  /// readers equally sized pages.
  static const int maxLongEdge = 2048;
  static const int jpegQuality = 85;

  final DocumentScanner _scanner;
  final bool Function() _isEnabled;
  final bool _platformSupported;
  final PageResizer _resizer;
  final PageReader _reader;

  static bool get _nativePlatform =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  bool get isAvailable => _platformSupported && _isEnabled();

  /// Scans up to [maxPages] pages. iOS ignores the limit and returns every
  /// page the user took, so the cap is enforced here as well.
  Future<DocumentScanResult> scanPages({required int maxPages}) async {
    if (!isAvailable || maxPages <= 0) return const DocumentScanUnavailable();
    try {
      final paths = await _scanner.scan(maxPages: maxPages);
      if (paths == null || paths.isEmpty) return const DocumentScanCancelled();
      final kept = paths.take(maxPages).toList();
      final pages = <Uint8List>[];
      for (final path in kept) {
        pages.add(await _resizer(await _reader(path)));
      }
      return DocumentScanPages(pages, overCap: paths.length > maxPages);
    } on DocumentScanPermissionDenied {
      return const DocumentScanDenied();
    } catch (e) {
      AppLogger.warning(
        'DocumentScanService: scanner failed (${e.runtimeType}), '
        'falling back to the camera: $e',
      );
      return const DocumentScanUnavailable();
    } finally {
      try {
        await _scanner.cleanUp();
      } catch (_) {
        // The cache is the plugin's to clear on next launch; never surface it.
      }
    }
  }

  static Future<Uint8List> _resizeInBackground(Uint8List bytes) =>
      compute(downscaleToJpeg, bytes);

  /// Bakes EXIF orientation, caps the long edge at [maxLongEdge] and
  /// re-encodes as JPEG. Colour is kept: greyscale belongs to the reader.
  @visibleForTesting
  static Uint8List downscaleToJpeg(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw const FormatException('Undecodable page');
    var image = img.bakeOrientation(decoded);
    if (math.max(image.width, image.height) > maxLongEdge) {
      image = image.width >= image.height
          ? img.copyResize(image, width: maxLongEdge)
          : img.copyResize(image, height: maxLongEdge);
    }
    return Uint8List.fromList(img.encodeJpg(image, quality: jpegQuality));
  }
}
