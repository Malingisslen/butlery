/// Request and response models for LLM Cloud Functions.
///
/// These models map to the TypeScript interfaces in:
/// - functions/src/llm/structure-recipe.ts
/// - functions/src/llm/ocr-recipe-image.ts

import 'dart:typed_data';

import 'package:butlery/core/l10n/app_locale.dart';

/// Mode for structuring recipe text.
enum StructureMode {
  /// Full extraction from raw text
  extract,

  /// Improve partial extraction with original text
  enhance,

  /// Extract from video transcript (YouTube, TikTok)
  spoken,
}

/// Request for structureRecipe Cloud Function.
class StructureRecipeRequest {
  /// Raw text to extract recipe from
  final String text;

  /// Optional partial data to enhance (for enhancement mode)
  final Map<String, dynamic>? partialData;

  /// Extraction mode
  final StructureMode mode;

  /// Source URL for reference
  final String? sourceUrl;

  const StructureRecipeRequest({
    required this.text,
    this.partialData,
    this.mode = StructureMode.extract,
    this.sourceUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      if (partialData != null) 'partialData': partialData,
      'mode': mode.name,
      if (sourceUrl != null) 'sourceUrl': sourceUrl,
    };
  }
}

/// Request for ocrRecipeImage Cloud Function.
class OcrRecipeImageRequest {
  /// Base64-encoded image data
  final String? imageBase64;

  /// Image URL (alternative to base64)
  final String? imageUrl;

  /// MIME type of the image
  final String? mimeType;

  /// Additional context (e.g., recipe title from filename)
  final String? context;

  const OcrRecipeImageRequest({
    this.imageBase64,
    this.imageUrl,
    this.mimeType,
    this.context,
  }) : assert(imageBase64 != null || imageUrl != null,
            'Either imageBase64 or imageUrl must be provided');

  /// Create from image bytes.
  factory OcrRecipeImageRequest.fromBytes(
    Uint8List bytes, {
    String? mimeType,
    String? context,
  }) {
    return OcrRecipeImageRequest(
      imageBase64: _encodeBase64(bytes),
      mimeType: mimeType ?? _detectMimeType(bytes),
      context: context,
    );
  }

  /// Create from image URL.
  factory OcrRecipeImageRequest.fromUrl(
    String url, {
    String? context,
  }) {
    return OcrRecipeImageRequest(
      imageUrl: url,
      context: context,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (imageBase64 != null) 'imageBase64': imageBase64,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (mimeType != null) 'mimeType': mimeType,
      if (context != null) 'context': context,
    };
  }

  static String _encodeBase64(Uint8List bytes) {
    // Use standard base64 encoding
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    final buffer = StringBuffer();
    int i = 0;
    while (i < bytes.length) {
      final b1 = bytes[i++];
      final b2 = i < bytes.length ? bytes[i++] : 0;
      final b3 = i < bytes.length ? bytes[i++] : 0;

      buffer.write(chars[(b1 >> 2) & 0x3F]);
      buffer.write(chars[((b1 << 4) | (b2 >> 4)) & 0x3F]);
      buffer.write(
          i - 1 < bytes.length ? chars[((b2 << 2) | (b3 >> 6)) & 0x3F] : '=');
      buffer.write(i < bytes.length ? chars[b3 & 0x3F] : '=');
    }
    return buffer.toString();
  }

  static String _detectMimeType(Uint8List bytes) {
    if (bytes.length < 4) return 'image/jpeg';

    // Check magic bytes
    if (bytes[0] == 0xFF && bytes[1] == 0xD8) return 'image/jpeg';
    if (bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) {
      return 'image/gif';
    }
    if (bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46) {
      return 'image/webp';
    }

    return 'image/jpeg'; // Default
  }
}

/// Extracted ingredient from LLM.
class ExtractedIngredient {
  final double? amount;
  final String? unit;
  final String name;
  final String? preparation;

  const ExtractedIngredient({
    this.amount,
    this.unit,
    required this.name,
    this.preparation,
  });

  factory ExtractedIngredient.fromJson(Map<String, dynamic> json) {
    return ExtractedIngredient(
      amount: (json['amount'] as num?)?.toDouble(),
      unit: json['unit'] as String?,
      name: json['name'] as String? ?? '',
      preparation: json['preparation'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'unit': unit,
      'name': name,
      'preparation': preparation,
    };
  }

  /// Format as readable string (e.g., "2 dl mjölk, rumstempererad")
  String get formatted {
    final parts = <String>[];
    if (amount != null) {
      // Format amount nicely (1.0 -> "1", 1.5 -> "1.5")
      parts.add(
          amount! % 1 == 0 ? amount!.toInt().toString() : amount.toString());
    }
    if (unit != null && unit!.isNotEmpty) {
      parts.add(unit!);
    }
    parts.add(name);
    if (preparation != null && preparation!.isNotEmpty) {
      parts.add('($preparation)');
    }
    return parts.join(' ');
  }
}

/// Extracted recipe from LLM.
class ExtractedRecipe {
  final String title;
  final String? description;
  final int? portions;
  final int? prepTimeMinutes;
  final int? cookTimeMinutes;
  final List<ExtractedIngredient> ingredients;
  final List<String> instructions;
  final List<String> tags;
  final String? difficulty;
  final String? source;

  const ExtractedRecipe({
    required this.title,
    this.description,
    this.portions,
    this.prepTimeMinutes,
    this.cookTimeMinutes,
    required this.ingredients,
    required this.instructions,
    this.tags = const [],
    this.difficulty,
    this.source,
  });

  factory ExtractedRecipe.fromJson(Map<String, dynamic> json) {
    return ExtractedRecipe(
      title: json['title'] as String? ?? AppLocale.current.llmUnknownRecipe,
      description: json['description'] as String?,
      portions: json['portions'] as int?,
      prepTimeMinutes: json['prepTimeMinutes'] as int?,
      cookTimeMinutes: json['cookTimeMinutes'] as int?,
      ingredients: (json['ingredients'] as List<dynamic>?)
              ?.map((e) =>
                  ExtractedIngredient.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      instructions: (json['instructions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
              [],
      difficulty: json['difficulty'] as String?,
      source: json['source'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'portions': portions,
      'prepTimeMinutes': prepTimeMinutes,
      'cookTimeMinutes': cookTimeMinutes,
      'ingredients': ingredients.map((e) => e.toJson()).toList(),
      'instructions': instructions,
      'tags': tags,
      'difficulty': difficulty,
      'source': source,
    };
  }

  /// Total time in minutes (prep + cook)
  int? get totalTimeMinutes {
    if (prepTimeMinutes == null && cookTimeMinutes == null) return null;
    return (prepTimeMinutes ?? 0) + (cookTimeMinutes ?? 0);
  }
}

/// Response from structureRecipe Cloud Function.
class StructureRecipeResponse {
  final bool success;
  final ExtractedRecipe? recipe;
  final String? error;
  final double estimatedCost;

  const StructureRecipeResponse({
    required this.success,
    this.recipe,
    this.error,
    required this.estimatedCost,
  });

  factory StructureRecipeResponse.fromJson(Map<String, dynamic> json) {
    return StructureRecipeResponse(
      success: json['success'] as bool? ?? false,
      recipe: json['recipe'] != null
          ? ExtractedRecipe.fromJson(json['recipe'] as Map<String, dynamic>)
          : null,
      error: json['error'] as String?,
      estimatedCost: (json['estimatedCost'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Response from ocrRecipeImage Cloud Function.
class OcrRecipeImageResponse {
  final bool success;
  final ExtractedRecipe? recipe;
  final String? rawText;
  final String? error;
  final double estimatedCost;

  const OcrRecipeImageResponse({
    required this.success,
    this.recipe,
    this.rawText,
    this.error,
    required this.estimatedCost,
  });

  factory OcrRecipeImageResponse.fromJson(Map<String, dynamic> json) {
    return OcrRecipeImageResponse(
      success: json['success'] as bool? ?? false,
      recipe: json['recipe'] != null
          ? ExtractedRecipe.fromJson(json['recipe'] as Map<String, dynamic>)
          : null,
      rawText: json['rawText'] as String?,
      error: json['error'] as String?,
      estimatedCost: (json['estimatedCost'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Exception thrown by LLM service operations.
class LlmException implements Exception {
  final String message;
  final String? code;
  final bool isRateLimited;
  final Duration? retryAfter;

  const LlmException(
    this.message, {
    this.code,
    this.isRateLimited = false,
    this.retryAfter,
  });

  @override
  String toString() => 'LlmException: $message';

  /// Create from Firebase Functions error.
  factory LlmException.fromFirebase(Object error) {
    final errorStr = error.toString();
    final l = AppLocale.current;

    if (errorStr.contains('unauthenticated')) {
      return LlmException(
        l.llmMustBeLoggedIn,
        code: 'unauthenticated',
      );
    }

    if (errorStr.contains('resource-exhausted')) {
      return LlmException(
        l.llmServiceOverloaded,
        code: 'resource-exhausted',
        isRateLimited: true,
        retryAfter: const Duration(minutes: 1),
      );
    }

    if (errorStr.contains('invalid-argument')) {
      return LlmException(
        l.llmInvalidArgument(errorStr),
        code: 'invalid-argument',
      );
    }

    return LlmException(
      l.llmGenericError(errorStr),
      code: 'unknown',
    );
  }
}
