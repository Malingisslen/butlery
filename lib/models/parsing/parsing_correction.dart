import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import 'package:butlery/core/utils/serialization_utils.dart';
import 'package:butlery/models/parsing/field_correction.dart';
import 'package:butlery/models/parsing/ingredient_correction.dart';
import 'package:butlery/models/parsing/instruction_correction.dart';
import 'package:butlery/models/parsing/parse_metadata.dart';

/// Aggregate record of all corrections made to a parsed recipe.
/// Captures the diff between parser output and user's final version.
///
/// Used for:
/// - Analyzing parser failure patterns
/// - Improving parsing heuristics
/// - Training ML models
/// - Updating SiteConfig selectors
class ParsingCorrection {
  /// Unique identifier
  final String id;

  /// ID of the recipe that was corrected
  final String recipeId;

  /// ID of user who made corrections (for GDPR deletion)
  final String userId;

  /// When corrections were saved
  final DateTime timestamp;

  // === Context about the parse ===

  /// Import source (url, instagram, tiktok, etc.)
  final ImportSource source;

  /// Domain if URL source (e.g., "ica.se")
  final String? domain;

  /// Which tier produced the result (SchemaOrg, SiteConfig, RuleBased, LLM)
  final String? successfulTier;

  /// Original quality score from parser (0.0-1.0)
  final double originalQuality;

  // === Corrections ===

  /// Title correction (null if no change)
  final FieldCorrection? titleCorrection;

  /// Portions correction (null if no change)
  final FieldCorrection? portionsCorrection;

  /// Time correction (null if no change)
  final FieldCorrection? timeCorrection;

  /// List of ingredient corrections
  final List<IngredientCorrection> ingredientCorrections;

  /// List of instruction corrections
  final List<InstructionCorrection> instructionCorrections;

  // === Summary ===

  /// Total number of corrections made
  final int totalCorrections;

  const ParsingCorrection({
    required this.id,
    required this.recipeId,
    required this.userId,
    required this.timestamp,
    required this.source,
    this.domain,
    this.successfulTier,
    required this.originalQuality,
    this.titleCorrection,
    this.portionsCorrection,
    this.timeCorrection,
    this.ingredientCorrections = const [],
    this.instructionCorrections = const [],
    required this.totalCorrections,
  });

  /// Factory to create a new correction record
  factory ParsingCorrection.create({
    required String recipeId,
    required String userId,
    required ImportSource source,
    String? domain,
    String? successfulTier,
    required double originalQuality,
    FieldCorrection? titleCorrection,
    FieldCorrection? portionsCorrection,
    FieldCorrection? timeCorrection,
    List<IngredientCorrection> ingredientCorrections = const [],
    List<InstructionCorrection> instructionCorrections = const [],
  }) {
    final totalCorrections = (titleCorrection != null ? 1 : 0) +
        (portionsCorrection != null ? 1 : 0) +
        (timeCorrection != null ? 1 : 0) +
        ingredientCorrections.length +
        instructionCorrections.length;

    return ParsingCorrection(
      id: const Uuid().v4(),
      recipeId: recipeId,
      userId: userId,
      timestamp: DateTime.now(),
      source: source,
      domain: domain,
      successfulTier: successfulTier,
      originalQuality: originalQuality,
      titleCorrection: titleCorrection,
      portionsCorrection: portionsCorrection,
      timeCorrection: timeCorrection,
      ingredientCorrections: ingredientCorrections,
      instructionCorrections: instructionCorrections,
      totalCorrections: totalCorrections,
    );
  }

  /// Returns true if there are any meaningful corrections
  bool get hasCorrections => totalCorrections > 0;

  /// Returns true if only reordering was done (low priority for training)
  bool get isReorderingOnly {
    if (titleCorrection != null ||
        portionsCorrection != null ||
        timeCorrection != null) {
      return false;
    }

    final nonReorderIngredients = ingredientCorrections
        .where((c) => c.type != IngredientCorrectionType.reordered)
        .toList();
    final nonReorderInstructions = instructionCorrections
        .where((c) => c.type != InstructionCorrectionType.reordered)
        .toList();

    return nonReorderIngredients.isEmpty && nonReorderInstructions.isEmpty;
  }

  /// Summary of correction types for analytics
  Map<String, int> get correctionTypeSummary {
    final summary = <String, int>{};

    if (titleCorrection != null) {
      summary['title'] = 1;
    }
    if (portionsCorrection != null) {
      summary['portions'] = 1;
    }
    if (timeCorrection != null) {
      summary['time'] = 1;
    }

    for (final c in ingredientCorrections) {
      final key = 'ingredient_${c.type.name}';
      summary[key] = (summary[key] ?? 0) + 1;
    }

    for (final c in instructionCorrections) {
      final key = 'instruction_${c.type.name}';
      summary[key] = (summary[key] ?? 0) + 1;
    }

    return summary;
  }

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'recipeId': recipeId,
        'userId': userId,
        'timestamp': Timestamp.fromDate(timestamp),
        'source': source.name,
        if (domain != null) 'domain': domain,
        if (successfulTier != null) 'successfulTier': successfulTier,
        'originalQuality': originalQuality,
        if (titleCorrection != null) 'titleCorrection': titleCorrection!.toJson(),
        if (portionsCorrection != null)
          'portionsCorrection': portionsCorrection!.toJson(),
        if (timeCorrection != null) 'timeCorrection': timeCorrection!.toJson(),
        'ingredientCorrections':
            ingredientCorrections.map((c) => c.toJson()).toList(),
        'instructionCorrections':
            instructionCorrections.map((c) => c.toJson()).toList(),
        'totalCorrections': totalCorrections,
      };

  factory ParsingCorrection.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ParsingCorrection.fromJson(data);
  }

  factory ParsingCorrection.fromJson(Map<String, dynamic> json) {
    final titleCorrectionData = SerializationUtils.safeNullableMap(json, 'titleCorrection');
    final portionsCorrectionData = SerializationUtils.safeNullableMap(json, 'portionsCorrection');
    final timeCorrectionData = SerializationUtils.safeNullableMap(json, 'timeCorrection');

    return ParsingCorrection(
      id: SerializationUtils.safeString(json, 'id'),
      recipeId: SerializationUtils.safeString(json, 'recipeId'),
      userId: SerializationUtils.safeString(json, 'userId'),
      timestamp: json['timestamp'] is Timestamp
          ? (json['timestamp'] as Timestamp).toDate()
          : DateTime.parse(SerializationUtils.safeString(json, 'timestamp')),
      source: ImportSource.values.firstWhere(
        (s) => s.name == SerializationUtils.safeString(json, 'source'),
        orElse: () => ImportSource.unknown,
      ),
      domain: SerializationUtils.safeNullableString(json, 'domain'),
      successfulTier: SerializationUtils.safeNullableString(json, 'successfulTier'),
      originalQuality: SerializationUtils.safeDouble(json, 'originalQuality'),
      titleCorrection: titleCorrectionData != null
          ? FieldCorrection.fromJson(titleCorrectionData)
          : null,
      portionsCorrection: portionsCorrectionData != null
          ? FieldCorrection.fromJson(portionsCorrectionData)
          : null,
      timeCorrection: timeCorrectionData != null
          ? FieldCorrection.fromJson(timeCorrectionData)
          : null,
      ingredientCorrections: SerializationUtils.safeObjectList(
        json,
        'ingredientCorrections',
        IngredientCorrection.fromJson,
      ),
      instructionCorrections: SerializationUtils.safeObjectList(
        json,
        'instructionCorrections',
        InstructionCorrection.fromJson,
      ),
      totalCorrections: SerializationUtils.safeInt(json, 'totalCorrections'),
    );
  }

  @override
  String toString() => 'ParsingCorrection('
      'id: $id, '
      'recipeId: $recipeId, '
      'source: ${source.name}, '
      'domain: $domain, '
      'totalCorrections: $totalCorrections'
      ')';
}
