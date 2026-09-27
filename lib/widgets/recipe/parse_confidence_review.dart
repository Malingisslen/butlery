// lib/widgets/recipe/parse_confidence_review.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/parsing/parsed_ingredient.dart';
import 'package:butlery/models/parsing/field_result.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_mode_colors.dart';

/// Review widget that surfaces per-ingredient parse confidence (BUT-925).
///
/// Shown in the recipe editor immediately after import. Low-confidence items
/// are sorted first. Each row has a thin coloured left bar (no visible text
/// label) that encodes confidence: green = high, amber = medium, grey =
/// low/failed. Screen readers announce the confidence word via Semantics so
/// the widget meets WCAG 2.1 (colour is not the only signal).
///
/// P6-U03 (flow 03): a low or failed row must be confirmed before Spara
/// (flows-roles-budget.md:61). Such a row carries "Stämmer" until it is
/// confirmed. A line the reader could not interpret ([ParseConfidence.failed])
/// is shown empty and marked, never as guessed text, and one tap shows the
/// original line (flows-roles-budget.md:63; produktregler.md:566).
class ParseConfidenceReview extends StatefulWidget {
  /// Parsed ingredients with confidence — from [RecipeFormViewModel.parsedIngredients].
  final List<ParsedIngredient> ingredients;

  /// Rows the user has confirmed, by object identity (never by position or
  /// text). Null hides the confirm affordance.
  final bool Function(ParsedIngredient row)? isConfirmed;

  /// Called when the user confirms a row.
  final ValueChanged<ParsedIngredient>? onConfirm;

  const ParseConfidenceReview({
    super.key,
    required this.ingredients,
    this.isConfirmed,
    this.onConfirm,
  });

  /// Whether [row] must be confirmed before the recipe can be saved: low
  /// and failed rows (flows-roles-budget.md:61).
  static bool needsConfirmation(ParsedIngredient row) =>
      isShown(row) &&
      (row.confidence == ParseConfidence.low ||
          row.confidence == ParseConfidence.failed);

  /// Whether [row] appears in the review. A failed row with no name still
  /// appears when there is an original line to show: it is the empty,
  /// marked row of flow 03.
  static bool isShown(ParsedIngredient row) =>
      row.name.isNotEmpty ||
      (row.confidence == ParseConfidence.failed &&
          row.originalLine.trim().isNotEmpty);

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
        .where((e) => ParseConfidenceReview.isShown(e.value))
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
              key: ObjectKey(item.ingredient),
              ingredient: item.ingredient,
              confirmed: widget.isConfirmed?.call(item.ingredient) ?? false,
              onConfirm:
                  widget.onConfirm != null &&
                      ParseConfidenceReview.needsConfirmation(item.ingredient)
                  ? () => widget.onConfirm!(item.ingredient)
                  : null,
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
                          color: context.modeColors.warning,
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

  /// The user has confirmed this row.
  final bool confirmed;

  /// Confirms the row. Null when the row needs no confirmation.
  final VoidCallback? onConfirm;

  const _IngredientConfidenceRow({
    super.key,
    required this.ingredient,
    this.confirmed = false,
    this.onConfirm,
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
    if (original.trim().isEmpty) return false;
    // An unread line shows no text, so its original always differs.
    if (_unread) return true;
    return _stripped(original) != _stripped(widget.ingredient.displayString);
  }

  /// A line the reader could not interpret: shown empty and marked, never
  /// as guessed text (flows-roles-budget.md:63).
  bool get _unread => widget.ingredient.confidence == ParseConfidence.failed;

  static String _stripped(String s) => s.replaceAll(RegExp(r'\s+'), '');

  @override
  Widget build(BuildContext context) {
    final colors = context.modeColors;
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
                        child: _unread
                            // The text slot stays empty; the mark says why.
                            ? Text(
                                context.l10n.parseConfidenceUnreadLine,
                                key: const ValueKey('parse-row-unread-mark'),
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontStyle: FontStyle.italic,
                                ),
                              )
                            : Text(
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
        if (widget.onConfirm != null || widget.confirmed)
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: _barWidth + AppDimensions.spacingS,
            ),
            child: widget.confirmed
                ? Semantics(
                    label: context.l10n.parseConfidenceConfirmed,
                    excludeSemantics: true,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check,
                          size: AppDimensions.iconSizeS,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        const SizedBox(width: AppDimensions.spacingXs),
                        Text(
                          context.l10n.parseConfidenceConfirmed,
                          style: AppTextStyles.bodySmall,
                        ),
                      ],
                    ),
                  )
                : Semantics(
                    button: true,
                    label: context.l10n.a11yParseConfidenceConfirm(
                      _unread
                          ? context.l10n.a11yParseConfidenceUnreadLine
                          : widget.ingredient.name,
                    ),
                    excludeSemantics: true,
                    child: TextButton(
                      key: const ValueKey('parse-row-confirm'),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(
                          AppDimensions.minTouchTarget,
                          AppDimensions.minTouchTarget,
                        ),
                      ),
                      onPressed: widget.onConfirm,
                      child: Text(context.l10n.parseConfidenceConfirm),
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
    // A failed row has no text to read out; the label says it could not be
    // read, and the confidence word stays (produktregler.md:564).
    final name = ingredient.confidence == ParseConfidence.failed
        ? l10n.a11yParseConfidenceUnreadLine
        : ingredient.name;
    return l10n.a11yIngredientWithConfidence(name, confidenceWord);
  }
}

/// Fixed width of the left accent bar in logical pixels.
const double _barWidth = 4.0;

/// Returns the bar colour for a given confidence level.
///
/// Exported for widget tests via [confidenceColorFor] so tests can assert the
/// correct color token without depending on hard-coded hex values.
@visibleForTesting
Color confidenceColorFor(ParseConfidence confidence, ModeColors colors) =>
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
