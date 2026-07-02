/// Photo Import Strategy - Extracts recipes from images using OCR technology.
/// Implements a comprehensive OCR-to-recipe workflow:
/// 1. Extract image bytes from input or options parameter
/// 2. Perform OCR text extraction (multi-provider fallback)
/// 3. Parse extracted text to recipe structure using TextImportStrategy
/// 4. Return recipe with OCR metadata and confidence tracking
/// **Multi-Provider OCR:**
/// - Primary: OCR.space (free tier 25,000/month)
/// - Secondary: Google Vision API (premium quality)
/// - Tertiary: Tesseract (self-hosted fallback)
/// **HEIC handling (BUT-662):** iOS HEIC inputs are detected by magic
/// bytes and converted to JPEG via flutter_image_compress before OCR.
/// The original format is preserved as `image_format` on analytics
/// events; the format actually sent to OCR is `image_format_sent`.
/// **Swedish Recipe Optimization:**
/// - Swedish language hints enabled
/// - Swedish keyword detection (ingredienser, portioner, etc.)
/// - Swedish measurement units preserved (dl, msk, tsk, krm)
/// **Usage Examples:**
/// ```dart
/// // From PhotoImportViewModel
/// final result = await importManager.autoImport('photo', options: {
///   'imageBytes': imageBytes,
///   'sourceType': 'camera', // or 'gallery'
/// });
/// if (result.isSuccess) {
///   final recipe = result.recipe!;
///   final ocrConfidence = result.metadata?['ocr_confidence'];
///   final ocrMethod = result.metadata?['ocr_method'];
/// }
/// ```

import 'dart:convert';
import 'dart:typed_data';

import 'package:clock/clock.dart';

import 'package:butlery/models/recipe/source_artefact.dart';
import 'package:butlery/core/utils/image_format_utils.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/import/heic_converter.dart';
import 'package:butlery/services/import/import_strategy.dart';
import 'package:butlery/services/import/photo_llm_vision.dart';
import 'package:butlery/services/import/text_import_strategy.dart';
import 'package:butlery/services/ocr_extraction_service.dart';

/// Strategy for importing recipes from photos using OCR technology.
/// **Extraction Workflow:**
/// 1. **Image Validation**: Check image data presence and format
/// 2. **OCR Extraction**: Extract text using multi-provider system
/// 3. **Text Parsing**: Convert OCR text to recipe structure
/// 4. **Quality Assessment**: Evaluate confidence and provide warnings
/// **Supported Sources:**
/// - Camera photos (recipe cards, cookbook pages)
/// - Gallery images (saved recipes, screenshots)
/// - Handwritten recipes (with decent quality)
/// - Printed recipe cards
class PhotoImportStrategy extends ImportStrategy with ImportValidationMixin {
  final OCRExtractionService _ocrService;
  final TextImportStrategy _textStrategy;
  final HeicConverter _heicConverter;

  // Confidence thresholds for quality assessment
  static const double _highConfidenceThreshold = 0.85;
  static const double _mediumConfidenceThreshold = 0.70;
  static const double _lowConfidenceThreshold = 0.50;

  PhotoImportStrategy({
    OCRExtractionService? ocrService,
    TextImportStrategy? textStrategy,
    HeicConverter? heicConverter,
  }) : _ocrService = ocrService ?? OCRExtractionService.instance,
       _textStrategy = textStrategy ?? TextImportStrategy(),
       _heicConverter = heicConverter ?? HeicConverter();

  /// BUT-1460: both LLM-vision routes (printed Tier-4 fallback + handwritten
  /// opt-in) live in [PhotoLlmVision] — extracted to keep this file under the
  /// 500-line limit and to share one result conversion between the routes.
  late final PhotoLlmVision _llmVision = PhotoLlmVision(
    strategyName: strategyName,
  );

  @override
  String get strategyName => 'Photo Import';

  @override
  String get description =>
      'Import recipes from photos using OCR (recipe cards, cookbook pages, handwritten recipes)';

  @override
  String get inputExample => 'photo (with imageBytes in options parameter)';

  @override
  bool canHandle(String input) {
    // Accept 'photo' input or any non-empty string when used with options
    final trimmed = input.trim().toLowerCase();
    return trimmed == 'photo' || trimmed.isNotEmpty;
  }

  @override
  bool validateInput(String input) {
    return canHandle(input);
  }

  @override
  Future<ImportResult> import(
    String input, {
    Map<String, dynamic>? options,
  }) async {
    // NOTE (BUT-903 cleanup): multi-page combine lives entirely in
    // PhotoImportViewModel, which OCRs each page itself and feeds the combined
    // text to ImportManager.autoParseMulti. The strategy only ever sees a
    // single image, so there is no `imageBytesList` routing here.
    try {
      // Step 1: Extract image bytes from options parameter
      final imageBytes = _extractImageBytes(options);

      if (imageBytes == null) {
        return ImportResult.failure(
          'No image data provided. Please include imageBytes in options parameter.',
          metadata: {
            'strategy': strategyName,
            'error_type': 'missing_image_data',
          },
        );
      }

      // Validate image size
      if (imageBytes.isEmpty) {
        return ImportResult.failure(
          'Image data is empty',
          metadata: {
            'strategy': strategyName,
            'error_type': 'empty_image_data',
          },
        );
      }

      // Step 1.5 (BUT-662): magic-byte format detection + HEIC→JPEG
      // conversion. We tag analytics with both the original format
      // (`image_format`) and what actually reached OCR (`image_format_sent`)
      // so HEIC prevalence + conversion success rate is measurable.
      final formatBefore = ImageFormatUtils.detectFormat(imageBytes);
      Uint8List bytesToOcr = imageBytes;
      ImageFormat formatAfter = formatBefore;

      if (formatBefore == ImageFormat.heic) {
        final converted = await _heicConverter.convertToJpegIfHeic(imageBytes);
        if (converted != null && !identical(converted, imageBytes)) {
          bytesToOcr = converted;
          formatAfter = ImageFormat.jpeg;
        }
        // If conversion failed (converted == null), proceed with the
        // original HEIC bytes — Vertex may still parse them. The point
        // is to remove the silent-failure class, not introduce a new
        // error path.
      }

      // BUT-684: handwritten recipes are LLM-vision-only — the char-OCR
      // providers (OCR.space / Google Vision / Tesseract) reliably produce
      // garbage on handwriting, so trying them first would only burn quota.
      // The handwriting-tuned Cloud Function prompt is the only path with a
      // real chance, gated behind an explicit user opt-in (so the extra LLM
      // cost is intentional). We ALWAYS return the vision result here —
      // success, assistance, OR failure — and never fall through to the
      // char-OCR cascade. Falling through would re-enter the Tier-4 LLM
      // fallback with the PRINTED prompt: a second billed vision call that
      // also drops the handwriting tuning (review BUG 1).
      final isHandwritten = options?['isHandwritten'] == true;
      if (isHandwritten) {
        return await _llmVision.handwrittenImport(
          bytesToOcr,
          options?['sourceType'] as String?,
          formatBefore: formatBefore,
          formatAfter: formatAfter,
        );
      }

      // Step 2: Initialize OCR service
      await _ocrService.initialize();

      // Step 3: Perform OCR text extraction
      final ocrResult = await _ocrService.extractText(bytesToOcr);

      if (!ocrResult.isSuccessful) {
        // OCR failed - try LLM vision as Tier 4 fallback
        final llmResult = await _llmVision.tryFallback(
          bytesToOcr,
          options?['sourceType'] as String?,
          formatBefore: formatBefore,
          formatAfter: formatAfter,
        );
        if (llmResult != null) {
          return llmResult;
        }

        // LLM also unavailable or failed
        return ImportResult.failure(
          ocrResult.errorMessage ?? 'OCR extraction failed',
          metadata: _buildMetadata(
            ocrResult: ocrResult,
            imageBytes: imageBytes,
            sourceType: options?['sourceType'] as String?,
            formatBefore: formatBefore,
            formatAfter: formatAfter,
          ),
        );
      }

      // Check if OCR extracted any text
      if (ocrResult.text.isEmpty) {
        // No text extracted - try LLM vision as Tier 4 fallback
        final llmResult = await _llmVision.tryFallback(
          bytesToOcr,
          options?['sourceType'] as String?,
          formatBefore: formatBefore,
          formatAfter: formatAfter,
        );
        if (llmResult != null) {
          return llmResult;
        }

        // LLM also unavailable or failed
        return ImportResult.failure(
          'No text could be extracted from the image. Please ensure the image is clear and contains readable text.',
          metadata: _buildMetadata(
            ocrResult: ocrResult,
            imageBytes: imageBytes,
            sourceType: options?['sourceType'] as String?,
            formatBefore: formatBefore,
            formatAfter: formatAfter,
          ),
        );
      }

      // Step 4: Parse OCR text to recipe using TextImportStrategy
      final textResult = await _textStrategy.import(ocrResult.text);

      if (!textResult.isSuccess || textResult.recipe == null) {
        // Text parsing failed - try LLM vision as Tier 4 fallback
        final llmResult = await _llmVision.tryFallback(
          bytesToOcr,
          options?['sourceType'] as String?,
          formatBefore: formatBefore,
          formatAfter: formatAfter,
        );
        if (llmResult != null) {
          return llmResult;
        }

        // LLM also unavailable or failed
        return ImportResult.failure(
          'Could not parse recipe from extracted text. ${textResult.errorMessage ?? "The text may not contain a valid recipe structure."}',
          warnings: _buildWarnings(
            ocrResult: ocrResult,
            textResult: textResult,
          ),
          metadata: _buildMetadata(
            ocrResult: ocrResult,
            imageBytes: imageBytes,
            textResult: textResult,
            sourceType: options?['sourceType'] as String?,
            formatBefore: formatBefore,
            formatAfter: formatAfter,
          ),
        );
      }

      // Step 5: Return success with comprehensive metadata and warnings.
      // BUT-922: override the text-strategy's textPaste artefact with the
      // photoOcr artefact so re-extract knows to feed the OCR output
      // (re-OCR'ing the original image would need raw bytes which we
      // don't store — see source_artefact.dart docstring).
      final recipeWithArtefact = textResult.recipe!.copyWith(
        sourceArtefact: SourceArtefact(
          type: SourceArtefactType.photoOcr,
          payload: ocrResult.text,
          fetchedAt: clock.now(),
        ),
      );
      return ImportResult.success(
        recipeWithArtefact,
        warnings: _buildWarnings(
          ocrResult: ocrResult,
          textResult: textResult,
        ),
        metadata: _buildMetadata(
          ocrResult: ocrResult,
          imageBytes: imageBytes,
          textResult: textResult,
          sourceType: options?['sourceType'] as String?,
          formatBefore: formatBefore,
          formatAfter: formatAfter,
        ),
      );
    } catch (e) {
      AppLogger.error('Photo import failed', e);
      return ImportResult.failure(
        'Could not extract recipe from photo. Please try again.',
        metadata: {
          'strategy': strategyName,
        },
      );
    }
  }

  /// Extract image bytes from options parameter
  Uint8List? _extractImageBytes(Map<String, dynamic>? options) {
    if (options == null) return null;

    // Try direct imageBytes parameter
    final imageBytes = options['imageBytes'];
    if (imageBytes is Uint8List) {
      return imageBytes;
    }

    // Try base64 encoded string (fallback)
    final base64Image = options['base64Image'];
    if (base64Image is String) {
      try {
        return base64Decode(base64Image);
      } catch (e) {
        // Invalid base64 - return null
        return null;
      }
    }

    return null;
  }

  /// Build comprehensive metadata for import result
  Map<String, dynamic> _buildMetadata({
    required OCRResult ocrResult,
    required Uint8List imageBytes,
    ImportResult? textResult,
    String? sourceType,
    ImageFormat formatBefore = ImageFormat.unknown,
    ImageFormat formatAfter = ImageFormat.unknown,
  }) {
    final metadata = <String, dynamic>{
      'strategy': strategyName,
      'image_size_bytes': imageBytes.length,
      'image_size_kb': (imageBytes.length / 1024).toStringAsFixed(1),
      // BUT-662: original format vs format sent to OCR. Both fields ride on
      // the import result so downstream analytics callers can tag events.
      'image_format': ImageFormatUtils.wireName(formatBefore),
      'image_format_sent': ImageFormatUtils.wireName(formatAfter),
    };

    // Add source type if available
    if (sourceType != null) {
      metadata['source_type'] = sourceType; // 'camera' or 'gallery'
    }

    // Add OCR metadata
    if (ocrResult.isSuccessful) {
      metadata['ocr_method'] = ocrResult.processingMethod;
      metadata['ocr_confidence'] = ocrResult.confidence;
      metadata['ocr_confidence_level'] = _getConfidenceLevel(
        ocrResult.confidence,
      );
      metadata['swedish_optimized'] = true;

      // Add extracted text length
      metadata['extracted_text_length'] = ocrResult.text.length;

      // Add OCR metadata if available
      if (ocrResult.metadata.isNotEmpty) {
        metadata['ocr_details'] = ocrResult.metadata;
      }
    }

    // Add text parsing metadata if available
    if (textResult != null && textResult.metadata != null) {
      metadata['text_parsing'] = textResult.metadata;
    }

    return metadata;
  }

  /// Build warnings list based on OCR and parsing results
  List<String> _buildWarnings({
    required OCRResult ocrResult,
    ImportResult? textResult,
  }) {
    final warnings = <String>[];

    // Add OCR quality warnings
    if (ocrResult.isSuccessful) {
      final confidence = ocrResult.confidence;

      if (confidence < _lowConfidenceThreshold) {
        warnings.add(
          'Very low OCR confidence (${(confidence * 100).toInt()}%). '
          'Please verify all recipe details carefully.',
        );
      } else if (confidence < _mediumConfidenceThreshold) {
        warnings.add(
          'Low OCR confidence (${(confidence * 100).toInt()}%). '
          'Some details may need correction.',
        );
      } else if (confidence < _highConfidenceThreshold) {
        warnings.add(
          'Medium OCR confidence (${(confidence * 100).toInt()}%). '
          'Review recipe for accuracy.',
        );
      }

      // Add OCR method warning if using fallback
      if (ocrResult.processingMethod != 'ocr_space') {
        warnings.add(
          'Used ${ocrResult.processingMethod} OCR provider (primary unavailable).',
        );
      }
    }

    // Add text parsing warnings if available
    if (textResult != null && textResult.warnings != null) {
      warnings.addAll(textResult.warnings!);
    }

    // Add image quality suggestions
    if (ocrResult.isSuccessful &&
        ocrResult.confidence < _mediumConfidenceThreshold) {
      warnings.add(
        'Tip: For better results, use good lighting, clear focus, and avoid shadows.',
      );
    }

    return warnings;
  }

  /// Get human-readable confidence level
  String _getConfidenceLevel(double confidence) {
    if (confidence >= _highConfidenceThreshold) {
      return 'high';
    } else if (confidence >= _mediumConfidenceThreshold) {
      return 'medium';
    } else if (confidence >= _lowConfidenceThreshold) {
      return 'low';
    } else {
      return 'very_low';
    }
  }
}
