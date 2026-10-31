import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/services/tagging/allergen_verdict.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/butlery_segment_switch.dart';

/// Allergens worth offering a manual choice for: what the tagger found, what
/// is already overridden, and what the user tracks. Sorted for a stable order.
List<String> editableAllergenKeys(
  Recipe recipe, {
  required Map<String, TriState> overrides,
  required Set<String> tracked,
}) {
  final found =
      recipe.tagResult?.allergenStatus.entries
          .where((e) => e.value == TriState.contains)
          .map((e) => e.key) ??
      const <String>[];
  return {...found, ...overrides.keys, ...tracked}.toList()..sort();
}

/// Three-way choice per allergen: no override, CONTAINS or FREE.
class TagEditorAllergenSection extends StatelessWidget {
  /// The recipe as stored, so the "Appen:" line shows the tagger's own verdict
  /// whatever the user picks here.
  final Recipe recipe;
  final List<String> allergenKeys;
  final Map<String, TriState> overrides;
  final void Function(String key, TriState? choice) onChanged;

  const TagEditorAllergenSection({
    super.key,
    required this.recipe,
    required this.allergenKeys,
    required this.overrides,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.tagAllergenSection, style: AppTextStyles.titleSmall),
        ),
        const SizedBox(height: AppDimensions.space4),
        Text(
          l10n.tagAllergenHint,
          style: AppTextStyles.bodySmall.copyWith(color: cs.onSurfaceVariant),
        ),
        for (final key in allergenKeys) ...[
          const SizedBox(height: AppDimensions.space12),
          Text(key, style: AppTextStyles.bodyBold),
          Text(
            _autoLine(context, key),
            style: AppTextStyles.bodySmall.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: AppDimensions.space4),
          ButlerySegmentSwitch<TriState?>(
            key: ValueKey('allergen-choice-$key'),
            choices: [
              (null, l10n.tagAllergenChoiceAuto),
              (TriState.contains, l10n.tagAllergenChoiceContains),
              (TriState.free, l10n.tagAllergenChoiceFree),
            ],
            selected: overrides[key],
            onChanged: (choice) => onChanged(key, choice),
          ),
        ],
        const SizedBox(height: AppDimensions.space12),
      ],
    );
  }

  String _autoLine(BuildContext context, String key) {
    final l10n = context.l10n;
    return switch (AllergenVerdict.forAllergen(recipe, key).trusted) {
      TriState.contains => l10n.tagAllergenAutoContains,
      TriState.free => l10n.tagAllergenAutoFree,
      TriState.unknown => l10n.tagAllergenAutoUnknown,
    };
  }
}
