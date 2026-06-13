// lib/widgets/recipe/parse_confidence_review.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/parsing/parsed_ingredient.dart';
import 'package:butlery/models/parsing/field_result.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';

/// Review widget that surfaces per-ingredient parse confidence (BUT-925).
///
/// Shown in the recipe editor immediately after import, when the
/// [ParsedRecipeCache] contains a live [ParsedRecipe] for this recipe.
/// Low-confidence items are sorted first so the user sees shaky parses
/// without scrolling. Each item has a square confidence pill (green/amber/grey)
/// and the original source line viewable on long-press or tap-expand.
class ParseConfidenceReview extends StatefulWidget {
  /// Parsed ingredients with confidence — from [RecipeFormViewModel.parsedIngredients].
  final List<ParsedIngredient> ingredients;

  const ParseConfidenceReview({
    super.key,
    required this.ingredients,
  });

  @override
  State<ParseConfidenceReview> createState() => _ParseConfidenceReviewState();
}

class _ParseConfidenceReviewState extends State<ParseConfidenceReview> {
  bool _expanded = true;

  /// Sort copy: low first, then medium, then high.
  late List<_IndexedIngredient> _sorted;

  @override
  void initState() {
    super.initState();
    _sorted = _sortedIngredients(widget.ingredients);
  }

  @override
  void didUpdateWidget(ParseConfidenceReview oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-sort when the parent supplies a refreshed parse (e.g. cache update);
    // _sorted is a one-shot copy so it would otherwise go stale.
    if (oldWidget.ingredients != widget.ingredients) {
      _sorted = _sortedIngredients(widget.ingredients);
    }
  }

  static List<_IndexedIngredient> _sortedIngredients(
    List<ParsedIngredient> items,
  ) {
    final indexed = items
        .asMap()
        .entries
        .where((e) => e.value.name.isNotEmpty)
        .map((e) => _IndexedIngredient(index: e.key, ingredient: e.value))
        .toList();

    indexed.sort((a, b) {
      // Lower score = higher sort priority (uncertain items first)
      return a.ingredient.confidence.score
          .compareTo(b.ingredient.confidence.score);
    });

    return indexed;
  }

  @override
  Widget build(BuildContext context) {
    // Count everything that needs review (low AND failed) — a failed item
    // renders the same grey pill, so the header warning must include it too.
    final lowCount =
        _sorted.where((i) => i.ingredient.confidence.needsReview).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context, lowCount),
        if (_expanded) ...[
          const SizedBox(height: AppDimensions.spacingS),
          ..._sorted.map(
            (item) => _IngredientConfidenceRow(
              key: ValueKey(item.index),
              ingredient: item.ingredient,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHeader(BuildContext context, int lowCount) {
    return Semantics(
      label: context.l10n.a11yToggleConfidenceSection,
      button: true,
      toggled: _expanded,
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(vertical: AppDimensions.spacingXs),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.parseConfidenceTitle,
                      style: AppTextStyles.labelLarge,
                    ),
                    if (lowCount > 0)
                      Text(
                        context.l10n.parseConfidenceLowCountSubtitle(lowCount),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: context.butleryColors.warning,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                size: AppDimensions.iconSizeM,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single row showing one ingredient with its confidence pill.
class _IngredientConfidenceRow extends StatefulWidget {
  final ParsedIngredient ingredient;

  const _IngredientConfidenceRow({
    super.key,
    required this.ingredient,
  });

  @override
  State<_IngredientConfidenceRow> createState() =>
      _IngredientConfidenceRowState();
}

class _IngredientConfidenceRowState extends State<_IngredientConfidenceRow> {
  bool _showOriginal = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: context.l10n
              .a11yToggleIngredientOriginalLine(widget.ingredient.name),
          button: true,
          toggled: _showOriginal,
          child: InkWell(
            onTap: () => setState(() => _showOriginal = !_showOriginal),
            onLongPress: () => setState(() => _showOriginal = !_showOriginal),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppDimensions.spacingXs,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _ConfidencePill(confidence: widget.ingredient.confidence),
                  const SizedBox(width: AppDimensions.spacingS),
                  Expanded(
                    child: Text(
                      widget.ingredient.displayString,
                      style: AppTextStyles.bodyMedium,
                    ),
                  ),
                  if (widget.ingredient.originalLine.isNotEmpty &&
                      widget.ingredient.originalLine !=
                          widget.ingredient.displayString)
                    Icon(
                      _showOriginal
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: AppDimensions.iconSizeS,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                ],
              ),
            ),
          ),
        ),
        if (_showOriginal &&
            widget.ingredient.originalLine.isNotEmpty &&
            widget.ingredient.originalLine != widget.ingredient.displayString)
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: AppDimensions.spacingXl + AppDimensions.spacingS,
              bottom: AppDimensions.spacingXs,
            ),
            child: Text(
              context.l10n.parseConfidenceOriginalPrefix(
                  widget.ingredient.originalLine),
              style: AppTextStyles.bodySmall.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        const Divider(height: 1, thickness: 1),
      ],
    );
  }
}

/// Square confidence pill per design rule (--radius: 0px).
///
/// Color mapping per BUT-925:
///   high   → green  (butleryColors.success = forestGreen)
///   medium → amber  (butleryColors.warning = #D4A03C)
///   low    → grey   (butleryColors.neutral = #9CA3AF)
///
/// Exported for widget tests — use [confidencePillKey] to find the container
/// and check its color via [confidenceColorFor] for the expected value.
@visibleForTesting
class ConfidencePill extends StatelessWidget {
  final ParseConfidence confidence;

  const ConfidencePill({
    super.key,
    required this.confidence,
  });

  @override
  Widget build(BuildContext context) => _ConfidencePill(confidence: confidence);

  /// Returns the canonical foreground color for a given confidence level.
  /// Used in widget tests to assert color-per-enum without depending on theme.
  static Color confidenceColorFor(
    ParseConfidence confidence,
    ButleryColors colors,
  ) =>
      _ConfidencePill._colorFor(confidence, colors);
}

class _ConfidencePill extends StatelessWidget {
  final ParseConfidence confidence;

  const _ConfidencePill({required this.confidence});

  @override
  Widget build(BuildContext context) {
    final colors = context.butleryColors;
    final color = _colorFor(confidence, colors);
    final label = _labelFor(context, confidence);

    return Container(
      key: ValueKey('confidence-pill-${confidence.name}'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingS,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color, width: 1),
        // Square — no border radius per design language
      ),
      child: Text(
        label,
        style: AppTextStyles.bodySmall.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }

  static Color _colorFor(ParseConfidence confidence, ButleryColors colors) =>
      switch (confidence) {
        ParseConfidence.high => colors.success,
        ParseConfidence.medium => colors.warning,
        ParseConfidence.low || ParseConfidence.failed => colors.neutral,
      };

  static String _labelFor(BuildContext context, ParseConfidence confidence) =>
      switch (confidence) {
        ParseConfidence.high => context.l10n.parseConfidencePillHigh,
        ParseConfidence.medium => context.l10n.parseConfidencePillMedium,
        ParseConfidence.low => context.l10n.parseConfidencePillLow,
        ParseConfidence.failed => context.l10n.parseConfidencePillFailed,
      };
}

/// Internal record for index-preserving sort.
class _IndexedIngredient {
  final int index;
  final ParsedIngredient ingredient;

  const _IndexedIngredient({required this.index, required this.ingredient});
}
