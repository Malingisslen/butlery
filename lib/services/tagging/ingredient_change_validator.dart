import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/models/tagging/ingredient_allergen_impact.dart';
import 'package:butlery/models/tagging/ingredient_column.dart';
import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/services/tagging/config/valid_properties.dart';

/// Vocabulary of the ingredient sync (`sync-ingredients-core.ts`): a value
/// the sync rejects must not be proposable. A drift test pins it against the
/// TypeScript source.
final Set<String> kProposableProperties = kValidIngredientProperties;

const List<String> kProposableGroupPrefixes = [
  'protein',
  'vegetable',
  'fruit',
  'grain',
  'fat',
  'other',
  'spice',
];

const List<String> kProposableStatuses = [
  'draft',
  'validated',
  'verified',
  'needs-review',
];

const List<String> kProposablePriceCategories = [
  'budget',
  'standard',
  'medium',
  'premium',
];

const List<String> kProposableCarbonCategories = ['low', 'medium', 'high'];

const int kMaxTextLength = 300;
const int kMaxListElements = 30;

enum IngredientIssueCode {
  tooLong,
  controlCharacter,
  empty,
  unknownProperty,
  invalidGroup,
  invalidStatus,
  invalidPriceCategory,
  invalidCarbonCategory,
  separatorInElement,
  tooManyElements,
  invalidPrice,
}

class IngredientFieldIssue {
  const IngredientFieldIssue(this.code, [this.detail]);

  final IngredientIssueCode code;

  /// The offending value or the limit, for the message.
  final String? detail;

  @override
  bool operator ==(Object other) =>
      other is IngredientFieldIssue &&
      other.code == code &&
      other.detail == detail;

  @override
  int get hashCode => Object.hash(code, detail);

  @override
  String toString() => '$code${detail == null ? '' : '($detail)'}';
}

class IngredientChangeValidation {
  const IngredientChangeValidation({
    required this.issues,
    required this.affectsAllergens,
  });

  final Map<IngredientColumn, List<IngredientFieldIssue>> issues;
  final bool affectsAllergens;

  bool get isValid => issues.isEmpty;
}

final RegExp _controlCharacters = RegExp(r'[\u0000-\u001F\u007F-\u009F]');
// A comma before a digit is not a separator for the sync's alias split, so
// "lättmjölk 0,5%" is accepted.
final RegExp _listSeparators = RegExp(r'[;|]|,(?!\d)');

/// Checks [proposed] (the new value per column, in the shapes of
/// [IngredientColumn.oldValueOf]) against the sync's rules. The rules are
/// the safety net behind clear messages; Firestore rules enforce sizes again.
IngredientChangeValidation validateIngredientChanges(
  IngredientData ingredient,
  Map<IngredientColumn, Object?> proposed,
) {
  final issues = <IngredientColumn, List<IngredientFieldIssue>>{};
  for (final entry in proposed.entries) {
    final found = switch (entry.key.kind) {
      IngredientColumnKind.text => _text(entry.key, entry.value),
      IngredientColumnKind.list => _list(entry.key, entry.value),
      IngredientColumnKind.number => _price(entry.value),
    };
    if (found.isNotEmpty) issues[entry.key] = found;
  }
  final newProperties = proposed[IngredientColumn.properties];
  final affects =
      newProperties is Iterable &&
      propertyChangeAffectsAllergens(
        ingredient.properties,
        [for (final p in newProperties) p.toString()],
      );
  return IngredientChangeValidation(issues: issues, affectsAllergens: affects);
}

List<IngredientFieldIssue> _text(IngredientColumn column, Object? raw) {
  final value = (raw?.toString()).orEmpty();
  final found = <IngredientFieldIssue>[
    if (value.length > kMaxTextLength)
      const IngredientFieldIssue(
        IngredientIssueCode.tooLong,
        '$kMaxTextLength',
      ),
    if (_controlCharacters.hasMatch(value))
      const IngredientFieldIssue(IngredientIssueCode.controlCharacter),
  ];
  final trimmed = value.trim();
  switch (column) {
    case IngredientColumn.swedish:
      if (trimmed.isEmpty) {
        found.add(const IngredientFieldIssue(IngredientIssueCode.empty));
      }
    case IngredientColumn.group:
      final valid = kProposableGroupPrefixes.any(
        (p) => trimmed == p || trimmed.startsWith('$p/'),
      );
      if (!valid) {
        found.add(
          IngredientFieldIssue(IngredientIssueCode.invalidGroup, value),
        );
      }
    case IngredientColumn.status:
      if (!kProposableStatuses.contains(trimmed)) {
        found.add(
          IngredientFieldIssue(IngredientIssueCode.invalidStatus, value),
        );
      }
    case IngredientColumn.priceCategory:
      if (trimmed.isNotEmpty && !kProposablePriceCategories.contains(trimmed)) {
        found.add(
          IngredientFieldIssue(IngredientIssueCode.invalidPriceCategory, value),
        );
      }
    case IngredientColumn.carbonFootprintCategory:
      if (trimmed.isNotEmpty &&
          !kProposableCarbonCategories.contains(trimmed)) {
        found.add(
          IngredientFieldIssue(
            IngredientIssueCode.invalidCarbonCategory,
            value,
          ),
        );
      }
    default:
      break;
  }
  return found;
}

List<IngredientFieldIssue> _list(IngredientColumn column, Object? raw) {
  final items = raw is Iterable
      ? [for (final e in raw) e.toString()]
      : <String>[];
  final found = <IngredientFieldIssue>[];
  if (items.length > kMaxListElements) {
    found.add(
      const IngredientFieldIssue(
        IngredientIssueCode.tooManyElements,
        '$kMaxListElements',
      ),
    );
  }
  for (final item in items) {
    final trimmed = item.trim();
    if (trimmed.isEmpty) {
      found.add(const IngredientFieldIssue(IngredientIssueCode.empty));
      continue;
    }
    if (item.length > kMaxTextLength) {
      found.add(
        const IngredientFieldIssue(
          IngredientIssueCode.tooLong,
          '$kMaxTextLength',
        ),
      );
    }
    if (_controlCharacters.hasMatch(item)) {
      found.add(
        IngredientFieldIssue(IngredientIssueCode.controlCharacter, item),
      );
    }
    if (_listSeparators.hasMatch(item)) {
      found.add(
        IngredientFieldIssue(IngredientIssueCode.separatorInElement, item),
      );
    }
    if (column == IngredientColumn.properties &&
        !kProposableProperties.contains(trimmed)) {
      found.add(
        IngredientFieldIssue(IngredientIssueCode.unknownProperty, item),
      );
    }
  }
  return found;
}

List<IngredientFieldIssue> _price(Object? raw) {
  if (raw == null) return const [];
  if (raw is num && raw.isFinite && raw >= 0) return const [];
  return [IngredientFieldIssue(IngredientIssueCode.invalidPrice, '$raw')];
}
