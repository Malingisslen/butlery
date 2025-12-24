/// Types of corrections that can be made to instructions.
enum InstructionCorrectionType {
  /// New instruction added by user
  added,

  /// Instruction removed by user
  removed,

  /// Instruction text was modified
  textModified,

  /// Only order changed (low priority)
  reordered,
}

/// Correction record for a single instruction step.
/// Captures what the parser extracted vs what the user corrected.
class InstructionCorrection {
  /// Type of correction made
  final InstructionCorrectionType type;

  /// Index in original parsed list (null if added)
  final int? originalIndex;

  /// Index in corrected list (null if removed)
  final int? correctedIndex;

  /// Original instruction text (truncated to 200 chars)
  final String? originalText;

  /// Corrected instruction text (truncated to 200 chars)
  final String? correctedText;

  const InstructionCorrection({
    required this.type,
    this.originalIndex,
    this.correctedIndex,
    this.originalText,
    this.correctedText,
  });

  /// Factory for when user adds a new instruction
  factory InstructionCorrection.added({
    required int correctedIndex,
    required String correctedText,
  }) {
    return InstructionCorrection(
      type: InstructionCorrectionType.added,
      correctedIndex: correctedIndex,
      correctedText: _truncate(correctedText),
    );
  }

  /// Factory for when user removes an instruction
  factory InstructionCorrection.removed({
    required int originalIndex,
    required String originalText,
  }) {
    return InstructionCorrection(
      type: InstructionCorrectionType.removed,
      originalIndex: originalIndex,
      originalText: _truncate(originalText),
    );
  }

  /// Factory for when user modifies an instruction
  factory InstructionCorrection.modified({
    required int originalIndex,
    required int correctedIndex,
    required String originalText,
    required String correctedText,
  }) {
    return InstructionCorrection(
      type: InstructionCorrectionType.textModified,
      originalIndex: originalIndex,
      correctedIndex: correctedIndex,
      originalText: _truncate(originalText),
      correctedText: _truncate(correctedText),
    );
  }

  /// Factory for when instruction only changed position
  factory InstructionCorrection.reordered({
    required int originalIndex,
    required int correctedIndex,
    required String text,
  }) {
    return InstructionCorrection(
      type: InstructionCorrectionType.reordered,
      originalIndex: originalIndex,
      correctedIndex: correctedIndex,
      originalText: _truncate(text),
      correctedText: _truncate(text),
    );
  }

  /// Truncate string to max 200 characters
  static String? _truncate(String? text, [int maxLength = 200]) {
    if (text == null) return null;
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - 3)}...';
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        if (originalIndex != null) 'originalIndex': originalIndex,
        if (correctedIndex != null) 'correctedIndex': correctedIndex,
        if (originalText != null) 'originalText': originalText,
        if (correctedText != null) 'correctedText': correctedText,
      };

  factory InstructionCorrection.fromJson(Map<String, dynamic> json) {
    return InstructionCorrection(
      type: InstructionCorrectionType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => InstructionCorrectionType.textModified,
      ),
      originalIndex: json['originalIndex'] as int?,
      correctedIndex: json['correctedIndex'] as int?,
      originalText: json['originalText'] as String?,
      correctedText: json['correctedText'] as String?,
    );
  }

  @override
  String toString() =>
      'InstructionCorrection(type: $type, original: $originalText, corrected: $correctedText)';
}
