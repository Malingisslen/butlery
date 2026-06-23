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
/// Shown in the recipe editor immediately after import. Low-confidence items
/// are sorted first. Each row has a thin coloured left bar (no visible text
/// label) that encodes confidence: green = high, amber = medium, grey =
/// low/failed. Screen readers announce the confidence word via Semantics so
/// the widget meets WCAG 2.1 (colour is not the only signal).
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

  /// Sort copy: low/failed first, then medium, then high.
  late List<_IndexedIngredient> _sorted;

  @override
  void initState() {
    super.initState();
    _sorted = _sortedIngredients(widget.ingredients);
  }

  @override
  void didUpdateWidget(ParseConfidenceReview oldWidget) {
    super.didUpdateWidget(oldWidget);
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
      return a.ingredient.confidence.score.compareTo(
        b.ingredient.confidence.score,
      );
    });

    return indexed;
  }

  @override
  Widget build(BuildContext context) {
    // Count rows that may need a look: everything that is NOT high confidence.
    final reviewCount = _sorted
        .where((i) => i.ingredient.confidence != ParseConfidence.high)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context, reviewCount),
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

  Widget _buildHeader(BuildContext context, int reviewCount) {
    return Semantics(
      label: context.l10n.a11yToggleConfidenceSection,
      button: true,
      toggled: _expanded,
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppDimensions.spacingXs,
          ),
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
                    if (reviewCount > 0)
                      Text(
                        context.l10n.parseConfidenceReviewCountSubtitle(
                          reviewCount,
                        ),
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

/// A single row showing one ingredient with a colour-coded left accent bar.
///
/// The bar width is fixed at [_barWidth] so ingredient names align in a clean
/// column regardless of confidence level. No visible text label is shown; the
/// confidence is conveyed to screen readers via [Semantics.label].
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

  /// Returns true when the original line is meaningfully different from the
  /// display string — whitespace-only differences are ignored because they
  /// are invisible to users and cause pointless expand noise (e.g. "100g smör"
  /// vs "100 g smör" should NOT trigger the reveal).
  bool get _hasOriginal {
    final original = widget.ingredient.originalLine;
    if (original.isEmpty) return false;
    return _stripped(original) != _stripped(widget.ingredient.displayString);
  }

  static String _stripped(String s) => s.replaceAll(RegExp(r'\s+'), '');

  @override
  Widget build(BuildContext context) {
    final colors = context.butleryColors;
    final barColor = confidenceColorFor(widget.ingredient.confidence, colors);
    final a11yLabel = _a11yLabel(context, widget.ingredient);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: a11yLabel,
          button: _hasOriginal,
          toggled: _hasOriginal ? _showOriginal : null,
          child: InkWell(
            onTap: _hasOriginal
                ? () => setState(() => _showOriginal = !_showOriginal)
                : null,
            onLongPress: _hasOriginal
                ? () => setState(() => _showOriginal = !_showOriginal)
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppDimensions.spacingXs,
              ),
              // IntrinsicHeight lets the bar stretch to match the text row
              // height even though the parent is unconstrained (scrollview).
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Thin colour accent bar — 4 px wide, full row height, square.
                    Container(
                      key: ValueKey(
                        'confidence-bar-${widget.ingredient.confidence.name}',
                      ),
                      width: _barWidth,
                      color: barColor,
                    ),
                    const SizedBox(width: AppDimensions.spacingS),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppDimensions.spacingXs,
                        ),
                        child: Text(
                          widget.ingredient.displayString,
                          style: AppTextStyles.bodyMedium,
                        ),
                      ),
                    ),
                    if (_hasOriginal)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppDimensions.spacingXs,
                        ),
                        child: Icon(
                          _showOriginal
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          size: AppDimensions.iconSizeS,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_showOriginal && _hasOriginal)
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: _barWidth + AppDimensions.spacingS,
              bottom: AppDimensions.spacingXs,
            ),
            child: Text(
              context.l10n.parseConfidenceOriginalPrefix(
                widget.ingredient.originalLine,
              ),
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

  String _a11yLabel(BuildContext context, ParsedIngredient ingredient) {
    final l10n = context.l10n;
    final confidenceWord = switch (ingredient.confidence) {
      ParseConfidence.high => l10n.a11yConfidenceHigh,
      ParseConfidence.medium => l10n.a11yConfidenceMedium,
      ParseConfidence.low => l10n.a11yConfidenceLow,
      ParseConfidence.failed => l10n.a11yConfidenceFailed,
    };
    return l10n.a11yIngredientWithConfidence(ingredient.name, confidenceWord);
  }
}

/// Fixed width of the left accent bar in logical pixels.
const double _barWidth = 4.0;

/// Returns the bar colour for a given confidence level.
///
/// Exported for widget tests via [confidenceColorFor] so tests can assert the
/// correct color token without depending on hard-coded hex values.
@visibleForTesting
Color confidenceColorFor(ParseConfidence confidence, ButleryColors colors) =>
    switch (confidence) {
      ParseConfidence.high => colors.success,
      ParseConfidence.medium => colors.warning,
      ParseConfidence.low || ParseConfidence.failed => colors.neutral,
    };

/// Internal record for index-preserving sort.
class _IndexedIngredient {
  final int index;
  final ParsedIngredient ingredient;

  const _IndexedIngredient({required this.index, required this.ingredient});
}
