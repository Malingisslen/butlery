import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/cooking/ingredient_substitution.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// BUT-202: Bottom sheet shown on long-press of an ingredient row in cooking
/// mode. Square corners, cream bg, greenDark text per design system.
///
/// Kept pure-UI so it can be widget-tested without touching the cooking
/// view graph — callers inject the suggestions list + a replace callback.
class SubstitutionBottomSheet extends StatelessWidget {
  final String ingredientName;
  final List<IngredientSubstitution> suggestions;

  /// Invoked when the user taps "Byt i receptet" on a chosen substitute.
  /// Receives the selected suggestion. The sheet pops itself before the
  /// callback runs, so callers don't need to manage dismissal.
  final ValueChanged<IngredientSubstitution>? onReplace;

  const SubstitutionBottomSheet({
    super.key,
    required this.ingredientName,
    required this.suggestions,
    this.onReplace,
  });

  /// Convenience helper: opens the sheet with the project-standard chrome
  /// (square, cream bg, no drag handle). Returns the selected substitute
  /// if the user tapped "Byt i receptet", otherwise null.
  static Future<IngredientSubstitution?> show({
    required BuildContext context,
    required String ingredientName,
    required List<IngredientSubstitution> suggestions,
  }) {
    return showModalBottomSheet<IngredientSubstitution>(
      context: context,
      backgroundColor: AppColors.creamDarker,
      // Square corners everywhere — design-system rule.
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      ),
      builder: (ctx) => SubstitutionBottomSheet(
        ingredientName: ingredientName,
        suggestions: suggestions,
        onReplace: (chosen) => Navigator.of(ctx).pop(chosen),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.outOfIngredientTitle(ingredientName),
              style: AppTextStyles.titleLarge.copyWith(
                color: AppColors.forestGreenDark,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            if (suggestions.isEmpty)
              const _EmptyState()
            else
              ...suggestions.map(
                (s) => Padding(
                  padding: const EdgeInsets.only(
                    bottom: AppDimensions.spacingSm,
                  ),
                  child: _SuggestionRow(
                    suggestion: s,
                    onReplace: () => onReplace?.call(s),
                  ),
                ),
              ),
            const SizedBox(height: AppDimensions.spacingSm),
            _CancelButton(
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  final IngredientSubstitution suggestion;
  final VoidCallback onReplace;

  const _SuggestionRow({
    required this.suggestion,
    required this.onReplace,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.cream,
      padding: const EdgeInsets.all(AppDimensions.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  suggestion.name,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.forestGreenDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.spacingSm),
              _RatioBadge(ratio: suggestion.ratio),
            ],
          ),
          if (suggestion.context != null && suggestion.context!.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.spacingXs),
            Text(
              suggestion.context!,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.greenMuted,
              ),
            ),
          ],
          const SizedBox(height: AppDimensions.spacingSm),
          SizedBox(
            height: AppDimensions.minTouchTarget,
            child: Material(
              color: AppColors.forestGreen,
              // Square — sharp corners everywhere.
              borderRadius: BorderRadius.zero,
              child: InkWell(
                onTap: onReplace,
                child: Center(
                  child: Text(
                    context.l10n.replaceInRecipe,
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.textOnPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RatioBadge extends StatelessWidget {
  final double ratio;

  const _RatioBadge({required this.ratio});

  @override
  Widget build(BuildContext context) {
    // Human-friendly formatting: 1:1 for unity, integer % otherwise.
    // Rationale: mixed ratios surface the numeric value; an exact 1.0 reads
    // more naturally as "1:1" on a recipe card than "100%".
    final label = ratio == 1.0 ? '1:1' : '${(ratio * 100).round()}%';
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingSm,
        vertical: AppDimensions.spacingXs,
      ),
      color: AppColors.forestGreenLight,
      child: Text(
        label,
        style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.textOnPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: AppColors.cream,
          padding: const EdgeInsets.all(AppDimensions.spacingLg),
          alignment: Alignment.center,
          child: Text(
            context.l10n.noSubstitutionSuggestions,
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.greenMuted,
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.spacingSm),
        // Disabled — future feature (user-submitted substitutes).
        SizedBox(
          height: AppDimensions.minTouchTarget,
          child: Material(
            color: AppColors.creamDark,
            borderRadius: BorderRadius.zero,
            child: InkWell(
              // null onTap = disabled; kept as a visual placeholder.
              onTap: null,
              child: Center(
                child: Text(
                  context.l10n.suggestAlternative,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.textLight,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CancelButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _CancelButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppDimensions.minTouchTarget,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          child: Container(
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              border: Border.fromBorderSide(
                BorderSide(color: AppColors.greenMuted, width: 1),
              ),
            ),
            child: Text(
              context.l10n.commonCancel,
              style: AppTextStyles.titleMedium.copyWith(
                color: AppColors.forestGreenDark,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
