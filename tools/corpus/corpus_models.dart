/// Cookbook gold-corpus data contract.
///
/// Pure Dart — NO `package:butlery` / Flutter imports — so the metric layer
/// and these models run under plain `dart test`. The heavy prelabel/eval
/// harnesses (which DO touch the real parser) map their domain objects onto
/// these structs at the boundary.
///
/// On-disk layout (one corpus root, sibling to the app repo):
///
/// ```
///   butlery-corpus/
///     <book-slug>/
///       book.json           BookMeta
///       inbox/*.jpg          unprocessed scans (consumed by prelabel)
///       <recipe-id>/
///         page-01.jpg        source scan(s)
///         ocr.txt            raw OCR text (OCR-eval input)
///         ocr.meta.json      OcrMeta
///         draft.json         parser pre-label seed/history (GoldRecipe)
///         gold.json          verified facit (GoldRecipe, verified=true)
/// ```
library;

import 'dart:convert';

/// Provenance for a single source cookbook. Never shipped into the app —
/// kept only so the corpus is auditable and copyright-traceable.
class BookMeta {
  final String slug;
  final String title;
  final String? author;
  final int? year;
  final String? publisher;
  final String? notes;

  const BookMeta({
    required this.slug,
    required this.title,
    this.author,
    this.year,
    this.publisher,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'slug': slug,
        'title': title,
        if (author != null) 'author': author,
        if (year != null) 'year': year,
        if (publisher != null) 'publisher': publisher,
        if (notes != null) 'notes': notes,
      };

  factory BookMeta.fromJson(Map<String, dynamic> json) => BookMeta(
        slug: json['slug']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        author: json['author']?.toString(),
        year: (json['year'] as num?)?.toInt(),
        publisher: json['publisher']?.toString(),
        notes: json['notes']?.toString(),
      );
}

/// Metadata captured when OCR ran on a page. Lets eval know which provider
/// produced `ocr.txt` and how confident it was, and records a failure so the
/// page can be retried without crashing the batch.
class OcrMeta {
  final String provider;
  final double? confidence;
  final String? engineVersion;
  final String timestampIso;
  final String? error;

  const OcrMeta({
    required this.provider,
    required this.timestampIso,
    this.confidence,
    this.engineVersion,
    this.error,
  });

  bool get isFailure => error != null && error!.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'provider': provider,
        'timestamp': timestampIso,
        if (confidence != null) 'confidence': confidence,
        if (engineVersion != null) 'engineVersion': engineVersion,
        if (error != null) 'error': error,
      };

  factory OcrMeta.fromJson(Map<String, dynamic> json) => OcrMeta(
        provider: json['provider']?.toString() ?? 'unknown',
        timestampIso: json['timestamp']?.toString() ?? '',
        confidence: (json['confidence'] as num?)?.toDouble(),
        engineVersion: json['engineVersion']?.toString(),
        error: json['error']?.toString(),
      );
}

/// A single structured ingredient in the facit. Mirrors the importable subset
/// of `package:butlery`'s `ParsedIngredient` (name/quantity/unit/size/
/// preparation/originalLine) so eval can compare parser output 1:1 — but is
/// declared standalone to keep this file Flutter-free.
class GoldIngredient {
  final String name;
  final String? quantity;
  final String? unit;
  final String? size;
  final String? preparation;
  final String originalLine;

  const GoldIngredient({
    required this.name,
    required this.originalLine,
    this.quantity,
    this.unit,
    this.size,
    this.preparation,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'originalLine': originalLine,
        if (quantity != null) 'quantity': quantity,
        if (unit != null) 'unit': unit,
        if (size != null) 'size': size,
        if (preparation != null) 'preparation': preparation,
      };

  /// Accepts both this schema and `ParsedIngredient.toJson()` (same keys),
  /// so the eval adapter can deserialize parser output without a translation
  /// table.
  factory GoldIngredient.fromJson(Map<String, dynamic> json) {
    final name = json['name']?.toString() ?? '';
    return GoldIngredient(
      name: name,
      originalLine: json['originalLine']?.toString() ?? name,
      quantity: _emptyToNull(json['quantity']),
      unit: _emptyToNull(json['unit']),
      size: _emptyToNull(json['size']),
      preparation: _emptyToNull(json['preparation']),
    );
  }

  static String? _emptyToNull(Object? v) {
    final s = v?.toString();
    return (s == null || s.isEmpty) ? null : s;
  }
}

/// A verified (or draft) structured recipe — the facit eval scores against.
class GoldRecipe {
  /// False until a human has reviewed the prelabel draft. Eval skips
  /// unverified entries (counts them as "unlabeled").
  final bool verified;
  final String title;
  final String? portions;
  final int? timeMinutes;
  final List<GoldIngredient> ingredients;
  final List<String> instructions;

  /// Page image filenames this recipe was transcribed from (relative to the
  /// recipe dir), e.g. `['page-01.jpg', 'page-02.jpg']`.
  final List<String> sourcePages;

  const GoldRecipe({
    required this.verified,
    required this.title,
    required this.ingredients,
    required this.instructions,
    this.portions,
    this.timeMinutes,
    this.sourcePages = const [],
  });

  GoldRecipe copyWith({bool? verified}) => GoldRecipe(
        verified: verified ?? this.verified,
        title: title,
        portions: portions,
        timeMinutes: timeMinutes,
        ingredients: ingredients,
        instructions: instructions,
        sourcePages: sourcePages,
      );

  Map<String, dynamic> toJson() => {
        'verified': verified,
        'title': title,
        if (portions != null) 'portions': portions,
        if (timeMinutes != null) 'timeMinutes': timeMinutes,
        'ingredients': ingredients.map((i) => i.toJson()).toList(),
        'instructions': instructions,
        if (sourcePages.isNotEmpty) 'sourcePages': sourcePages,
      };

  factory GoldRecipe.fromJson(Map<String, dynamic> json) => GoldRecipe(
        verified: json['verified'] == true,
        title: json['title']?.toString() ?? '',
        portions: GoldIngredient._emptyToNull(json['portions']),
        timeMinutes: (json['timeMinutes'] as num?)?.toInt(),
        ingredients: (json['ingredients'] as List?)
                ?.whereType<Map>()
                .map((m) => GoldIngredient.fromJson(m.cast<String, dynamic>()))
                .toList() ??
            const [],
        instructions: (json['instructions'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        sourcePages:
            (json['sourcePages'] as List?)?.map((e) => e.toString()).toList() ??
                const [],
      );
}

/// Pretty-print helper so hand-edited `gold.json` files stay diff-friendly.
String encodeJsonPretty(Map<String, dynamic> json) =>
    const JsonEncoder.withIndent('  ').convert(json);
