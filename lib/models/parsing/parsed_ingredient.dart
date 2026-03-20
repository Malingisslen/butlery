import 'package:butlery/models/parsing/field_result.dart';

/// A parsed ingredient with structured data and confidence tracking.
///
/// This model captures the parsed components of an ingredient line
/// along with the original text for reference.
class ParsedIngredient {
  /// The ingredient name (core identifier).
  final String name;

  /// The original line as it appeared in the source.
  final String originalLine;

  /// Quantity as a string (e.g., "2", "1.5", "1-2").
  final String? quantity;

  /// Measurement unit (e.g., "dl", "msk", "g", "st").
  final String? unit;

  /// Size descriptor (e.g., "stor", "liten", "små", "medelstora").
  final String? size;

  /// Preparation instructions (e.g., "hackad", "skivad", "rumstempererad").
  final String? preparation;

  /// Confidence level of the parsing.
  final ParseConfidence confidence;

  /// Parsing notes or warnings.
  final String? notes;

  const ParsedIngredient({
    required this.name,
    required this.originalLine,
    required this.confidence,
    this.quantity,
    this.unit,
    this.size,
    this.preparation,
    this.notes,
  });

  /// Creates from a simple ingredient string with medium confidence.
  factory ParsedIngredient.simple(String text) => ParsedIngredient(
        name: text.trim(),
        originalLine: text,
        confidence: ParseConfidence.medium,
      );

  /// Creates a fully structured ingredient with high confidence.
  factory ParsedIngredient.structured({
    required String name,
    required String originalLine,
    String? quantity,
    String? unit,
    String? size,
    String? preparation,
  }) =>
      ParsedIngredient(
        name: name,
        originalLine: originalLine,
        quantity: quantity,
        unit: unit,
        size: size,
        preparation: preparation,
        confidence: ParseConfidence.high,
      );

  /// Whether this ingredient has quantity information.
  bool get hasQuantity => quantity != null && quantity!.isNotEmpty;

  /// Whether this ingredient has unit information.
  bool get hasUnit => unit != null && unit!.isNotEmpty;

  /// Whether this ingredient is fully structured.
  bool get isStructured => hasQuantity || hasUnit;

  /// Returns a formatted display string.
  String get displayString {
    final parts = <String>[];
    if (hasQuantity) parts.add(quantity!);
    if (hasUnit) parts.add(unit!);
    if (size != null && size!.isNotEmpty) parts.add(size!);
    parts.add(name);
    if (preparation != null && preparation!.isNotEmpty) {
      parts.add('($preparation)');
    }
    return parts.join(' ');
  }

  /// Creates a copy with updated fields.
  ParsedIngredient copyWith({
    String? name,
    String? originalLine,
    String? quantity,
    String? unit,
    String? size,
    String? preparation,
    ParseConfidence? confidence,
    String? notes,
  }) =>
      ParsedIngredient(
        name: name ?? this.name,
        originalLine: originalLine ?? this.originalLine,
        quantity: quantity ?? this.quantity,
        unit: unit ?? this.unit,
        size: size ?? this.size,
        preparation: preparation ?? this.preparation,
        confidence: confidence ?? this.confidence,
        notes: notes ?? this.notes,
      );

  /// Converts to JSON.
  Map<String, dynamic> toJson() => {
        'name': name,
        'originalLine': originalLine,
        'confidence': confidence.name,
        if (quantity != null) 'quantity': quantity,
        if (unit != null) 'unit': unit,
        if (size != null) 'size': size,
        if (preparation != null) 'preparation': preparation,
        if (notes != null) 'notes': notes,
      };

  /// Creates from JSON.
  factory ParsedIngredient.fromJson(Map<String, dynamic> json) {
    final name = json['name']?.toString() ?? '';
    return ParsedIngredient(
      name: name,
      originalLine: json['originalLine']?.toString() ?? name,
      confidence: ParseConfidence.values
          .byName(json['confidence']?.toString() ?? 'medium'),
      quantity: json['quantity']?.toString(),
      unit: json['unit']?.toString(),
      size: json['size']?.toString(),
      preparation: json['preparation']?.toString(),
      notes: json['notes']?.toString(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ParsedIngredient &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          originalLine == other.originalLine &&
          confidence == other.confidence;

  @override
  int get hashCode => Object.hash(name, originalLine, confidence);

  @override
  String toString() => 'ParsedIngredient($displayString, ${confidence.name})';
}
