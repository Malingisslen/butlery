/// Structured output of [MenuConstraintParser]. Carries the user's intent
/// from a free-form Swedish prompt into [MenuService] selection logic.
library;

/// Parsed menu request: slot intentions + global filters + day pins + trace.
class ParsedMenuRequest {
  final List<SlotRequest> slotRequests;
  final Set<String> globalAllergenAvoid;
  final Set<String> globalDietaryRequire;
  final Set<String> globalExcludedTags;
  final List<DayPin> dayPins;
  final ExtractionTrace trace;
  final String rawPrompt;

  const ParsedMenuRequest({
    required this.slotRequests,
    required this.globalAllergenAvoid,
    required this.globalDietaryRequire,
    this.globalExcludedTags = const {},
    required this.dayPins,
    required this.trace,
    required this.rawPrompt,
  });

  factory ParsedMenuRequest.empty(String rawPrompt) => ParsedMenuRequest(
    slotRequests: const [],
    globalAllergenAvoid: const {},
    globalDietaryRequire: const {},
    dayPins: const [],
    trace: const ExtractionTrace(),
    rawPrompt: rawPrompt,
  );

  bool get isEmpty => slotRequests.isEmpty && dayPins.isEmpty;
}

/// One meal-type slot request. May contain multiple sub-requests when the
/// user wrote a subdivision ("3 middagar varav 1 vegansk").
class SlotRequest {
  final String mealType;
  final List<RecipeConstraint> subRequests;

  const SlotRequest({required this.mealType, required this.subRequests});

  int get totalCount => subRequests.fold(0, (a, b) => a + b.count);
}

/// A constrained sub-request inside a slot. Empty constraints (all sets empty,
/// no time bound) match any recipe in the slot — that's how legacy "3 middagar"
/// flows through unchanged.
class RecipeConstraint {
  final int count;
  final Set<String> dietaryFree;
  final Set<String> allergenFree;
  final Set<String> requiredTags;
  final Set<String> excludedTags;
  final Set<String> requiredCuisines;
  final int? maxTimeMinutes;

  /// A `ProteinCategory` value ("fish", "poultry"); a saved weekly rule's
  /// Fisk and Kyckling (BUT-2490). The prompt parser never sets it.
  final String? proteinCategory;
  final bool isSoft;

  const RecipeConstraint({
    required this.count,
    this.dietaryFree = const {},
    this.allergenFree = const {},
    this.requiredTags = const {},
    this.excludedTags = const {},
    this.requiredCuisines = const {},
    this.maxTimeMinutes,
    this.proteinCategory,
    this.isSoft = false,
  });

  bool get isUnconstrained =>
      dietaryFree.isEmpty &&
      allergenFree.isEmpty &&
      requiredTags.isEmpty &&
      excludedTags.isEmpty &&
      requiredCuisines.isEmpty &&
      maxTimeMinutes == null &&
      proteinCategory == null;
}

/// A recipe that should land on a specific weekday slot regardless of the
/// generic distribution. tacofredag → DayPin(weekdayIndex: 5, mealType: 'middag').
class DayPin {
  /// ISO weekday: Mon=1..Sun=7.
  final int weekdayIndex;
  final String mealType;
  final RecipeConstraint constraint;

  /// True for a pin made from a saved weekly rule (BUT-2490), false for one
  /// the user typed. A rule pin that cannot be placed is dropped, never
  /// moved to another day: the rule is about that day.
  final bool fromRule;

  /// The rule's id when [fromRule].
  final String? ruleId;

  const DayPin({
    required this.weekdayIndex,
    required this.mealType,
    required this.constraint,
    this.fromRule = false,
    this.ruleId,
  });
}

/// What the parser understood and didn't. Drives the chip strip UI.
class ExtractionTrace {
  final List<TraceEntry> understood;
  final List<String> notUnderstood;
  final List<String> warnings;

  const ExtractionTrace({
    this.understood = const [],
    this.notUnderstood = const [],
    this.warnings = const [],
  });

  bool get hasGaps => notUnderstood.isNotEmpty || warnings.isNotEmpty;
}

/// One understood fragment, ready to render as a chip.
class TraceEntry {
  final String label;
  final TraceCategory category;

  const TraceEntry({required this.label, required this.category});
}

/// Category drives the chip icon in the UI.
enum TraceCategory {
  count,
  mealType,
  dietary,
  allergen,
  cuisine,
  format,
  theme,
  time,
  day,
}
