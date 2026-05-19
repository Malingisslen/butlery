/// Bottom sheet for side-by-side recipe duplicate comparison and merge.
///
/// Shows similarity percentage, field-by-field comparison of two recipes,
/// and four action choices: keep existing, replace, save as new, or merge.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/firebase_url_utils.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';

/// Actions the user can take when a duplicate is detected.
enum DuplicateMergeChoice {
  keepExisting,
  replaceWithNew,
  saveAsNew,
  mergeBestFields,
}

/// Result returned from [showDuplicateMergeSheet].
class DuplicateMergeResult {
  final DuplicateMergeChoice choice;
  final Recipe existingRecipe;
  final Recipe newRecipe;
  final double similarityScore;

  const DuplicateMergeResult({
    required this.choice,
    required this.existingRecipe,
    required this.newRecipe,
    required this.similarityScore,
  });

  /// Build a merged recipe preferring the version with more/better data.
  Recipe buildMergedRecipe() {
    return existingRecipe.copyWith(
      title: _preferNonEmpty(newRecipe.title, existingRecipe.title),
      description:
          _preferLonger(newRecipe.description, existingRecipe.description),
      ingredients:
          newRecipe.ingredients.length >= existingRecipe.ingredients.length
              ? newRecipe.ingredients
              : existingRecipe.ingredients,
      instructions:
          newRecipe.instructions.length >= existingRecipe.instructions.length
              ? newRecipe.instructions
              : existingRecipe.instructions,
      timeMinutes: newRecipe.timeMinutes ?? existingRecipe.timeMinutes,
      portions: newRecipe.portions ?? existingRecipe.portions,
      imageUrls:
          newRecipe.hasImages ? newRecipe.imageUrls : existingRecipe.imageUrls,
      sourceUrl: newRecipe.sourceUrl ?? existingRecipe.sourceUrl,
    );
  }

  String _preferNonEmpty(String a, String b) => a.trim().isEmpty ? b : a;

  String _preferLonger(String a, String b) {
    if (a.trim().isEmpty) return b;
    if (b.trim().isEmpty) return a;
    return a.length >= b.length ? a : b;
  }
}

/// Shows the duplicate merge bottom sheet.
///
/// Returns null if dismissed, otherwise a [DuplicateMergeResult].
Future<DuplicateMergeResult?> showDuplicateMergeSheet({
  required BuildContext context,
  required Recipe existingRecipe,
  required Recipe newRecipe,
  required double similarityScore,
}) {
  return showModalBottomSheet<DuplicateMergeResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _DuplicateMergeSheetContent(
      existingRecipe: existingRecipe,
      newRecipe: newRecipe,
      similarityScore: similarityScore,
    ),
  );
}

// Label column width used throughout comparison rows
const double _labelWidth = 80;

class _DuplicateMergeSheetContent extends StatelessWidget {
  final Recipe existingRecipe;
  final Recipe newRecipe;
  final double similarityScore;

  const _DuplicateMergeSheetContent({
    required this.existingRecipe,
    required this.newRecipe,
    required this.similarityScore,
  });

  DuplicateMergeResult _result(DuplicateMergeChoice choice) =>
      DuplicateMergeResult(
        choice: choice,
        existingRecipe: existingRecipe,
        newRecipe: newRecipe,
        similarityScore: similarityScore,
      );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final percent = (similarityScore * 100).round();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: AppDimensions.spacingSm),
            child: Container(
              width: 40,
              height: 4,
              color: cs.onSurfaceVariant
                  .withValues(alpha: AppDimensions.opacityMediumLight),
            ),
          ),
          // Header
          Padding(
            padding: AppDimensions.paddingSymmetric16x8,
            child: Row(
              children: [
                Expanded(
                  child: Text(l10n.duplicateMergeTitle,
                      style: AppTextStyles.titleLarge),
                ),
                _SimilarityBadge(percent: percent),
              ],
            ),
          ),
          const Divider(height: AppDimensions.dividerHeight),
          // Comparison
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: AppDimensions.paddingSymmetric16x8,
              children: [
                // Column headers
                _threeColumnRow(
                  label: '',
                  existing: Text(l10n.duplicateMergeExisting,
                      style:
                          AppTextStyles.labelMedium.copyWith(color: cs.primary),
                      textAlign: TextAlign.center),
                  incoming: Text(l10n.duplicateMergeNew,
                      style: AppTextStyles.labelMedium
                          .copyWith(color: cs.secondary),
                      textAlign: TextAlign.center),
                ),
                const SizedBox(height: AppDimensions.spacingSm),
                // Images
                _threeColumnRow(
                  label: '',
                  existing:
                      _buildImage(existingRecipe.displayThumbnailUrl, cs, l10n),
                  incoming:
                      _buildImage(newRecipe.displayThumbnailUrl, cs, l10n),
                ),
                const SizedBox(height: AppDimensions.spacingSm),
                // Field rows
                _FieldRow(
                  label: l10n.duplicateMergeFieldTitle,
                  existingValue: existingRecipe.title,
                  newValue: newRecipe.title,
                ),
                _FieldRow(
                  label: l10n.duplicateMergeFieldTime,
                  existingValue: existingRecipe.timeMinutes != null
                      ? l10n.duplicateMergeMinutes(existingRecipe.timeMinutes!)
                      : l10n.duplicateMergeNoTime,
                  newValue: newRecipe.timeMinutes != null
                      ? l10n.duplicateMergeMinutes(newRecipe.timeMinutes!)
                      : l10n.duplicateMergeNoTime,
                ),
                _FieldRow(
                  label: l10n.duplicateMergeFieldPortions,
                  existingValue: existingRecipe.portions?.toString() ?? '-',
                  newValue: newRecipe.portions?.toString() ?? '-',
                ),
                _FieldRow(
                  label: l10n.duplicateMergeFieldIngredients,
                  existingValue: l10n.duplicateMergeItemCount(
                      existingRecipe.ingredients.length),
                  newValue: l10n
                      .duplicateMergeItemCount(newRecipe.ingredients.length),
                  highlightNew: newRecipe.ingredients.length >
                      existingRecipe.ingredients.length,
                  highlightExisting: existingRecipe.ingredients.length >
                      newRecipe.ingredients.length,
                ),
                _FieldRow(
                  label: l10n.duplicateMergeFieldSteps,
                  existingValue: l10n.duplicateMergeItemCount(
                      existingRecipe.instructions.length),
                  newValue: l10n
                      .duplicateMergeItemCount(newRecipe.instructions.length),
                  highlightNew: newRecipe.instructions.length >
                      existingRecipe.instructions.length,
                  highlightExisting: existingRecipe.instructions.length >
                      newRecipe.instructions.length,
                ),
                _FieldRow(
                  label: l10n.duplicateMergeFieldSource,
                  existingValue: _formatUrl(existingRecipe.sourceUrl, l10n),
                  newValue: _formatUrl(newRecipe.sourceUrl, l10n),
                ),
              ],
            ),
          ),
          const Divider(height: AppDimensions.dividerHeight),
          _ActionButtons(
            onChoice: (c) => Navigator.of(context).pop(_result(c)),
          ),
        ],
      ),
    );
  }

  Widget _buildImage(String? url, ColorScheme cs, AppLocalizations l10n) {
    if (url == null || url.isEmpty) {
      return Container(
        height: AppDimensions.heightThumbnail,
        color: cs.surfaceContainerHighest,
        alignment: Alignment.center,
        child: Text(l10n.duplicateMergeNoImage,
            style: AppTextStyles.bodySmall.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center),
      );
    }
    return SizedBox(
      height: AppDimensions.heightThumbnail,
      child: CachedNetworkImage(
        imageUrl: url,
        cacheKey: FirebaseUrlUtils.stableCacheKey(url),
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          height: AppDimensions.heightThumbnail,
          color: cs.surfaceContainerHighest,
        ),
        errorWidget: (_, __, ___) => Container(
          height: AppDimensions.heightThumbnail,
          color: cs.surfaceContainerHighest,
          alignment: Alignment.center,
          child: Icon(Icons.broken_image_outlined, color: cs.onSurfaceVariant),
        ),
      ),
    );
  }

  String _formatUrl(String? url, AppLocalizations l10n) {
    if (url == null || url.isEmpty) return l10n.duplicateMergeNoSource;
    final s =
        url.replaceFirst(RegExp(r'https?://'), '').replaceFirst('www.', '');
    return s.length <= 35 ? s : '${s.substring(0, 32)}...';
  }

  static Widget _threeColumnRow({
    required String label,
    required Widget existing,
    required Widget incoming,
  }) {
    return Row(
      children: [
        SizedBox(
            width: _labelWidth,
            child: label.isNotEmpty
                ? Text(label, style: AppTextStyles.labelMedium)
                : const SizedBox.shrink()),
        Expanded(child: existing),
        const SizedBox(width: AppDimensions.spacingSm),
        Expanded(child: incoming),
      ],
    );
  }
}

class _SimilarityBadge extends StatelessWidget {
  final int percent;
  const _SimilarityBadge({required this.percent});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = percent >= 80 ? cs.primary : context.butleryColors.warning;
    final textColor = percent >= 80 ? cs.onPrimary : cs.onSurface;
    return Container(
      padding: AppDimensions.paddingSymmetric8x2,
      color: color,
      child: Text(
        context.l10n.duplicateMergeSimilarity(percent),
        style: AppTextStyles.labelMedium.copyWith(color: textColor),
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  final String label;
  final String existingValue;
  final String newValue;
  final bool highlightExisting;
  final bool highlightNew;

  const _FieldRow({
    required this.label,
    required this.existingValue,
    required this.newValue,
    this.highlightExisting = false,
    this.highlightNew = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final highlightColor = context.butleryColors.successContainer;
    final isDifferent = existingValue != newValue;

    return Padding(
      padding: AppDimensions.paddingVertical4,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _labelWidth,
            child: Text(label,
                style: AppTextStyles.labelMedium
                    .copyWith(color: cs.onSurfaceVariant)),
          ),
          Expanded(
              child: _cell(existingValue, isDifferent, highlightExisting, cs,
                  highlightColor)),
          const SizedBox(width: AppDimensions.spacingSm),
          Expanded(
              child: _cell(
                  newValue, isDifferent, highlightNew, cs, highlightColor)),
        ],
      ),
    );
  }

  Widget _cell(String value, bool isDifferent, bool highlight, ColorScheme cs,
      Color highlightColor) {
    return Container(
      padding: AppDimensions.paddingSymmetric4x2,
      color: highlight
          ? highlightColor
          : (isDifferent ? cs.surfaceContainerHighest : Colors.transparent),
      child: Text(value,
          style: AppTextStyles.bodySmall.copyWith(
              fontWeight: highlight ? FontWeight.w600 : FontWeight.normal),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final void Function(DuplicateMergeChoice) onChoice;
  const _ActionButtons({required this.onChoice});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const shape = RoundedRectangleBorder();
    const minSize = Size(0, AppDimensions.minTouchTarget);

    return SafeArea(
      child: Padding(
        padding: AppDimensions.paddingSymmetric16x8,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () =>
                      onChoice(DuplicateMergeChoice.mergeBestFields),
                  icon: const Icon(Icons.merge_type, size: 18),
                  label: Text(l10n.duplicateMergeBestFields),
                  style: FilledButton.styleFrom(
                      minimumSize: minSize, shape: shape),
                ),
              ),
              const SizedBox(width: AppDimensions.spacingSm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => onChoice(DuplicateMergeChoice.saveAsNew),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(l10n.duplicateMergeSaveAsNew),
                  style: OutlinedButton.styleFrom(
                      minimumSize: minSize, shape: shape),
                ),
              ),
            ]),
            const SizedBox(height: AppDimensions.spacingSm),
            Row(children: [
              Expanded(
                child: TextButton(
                  onPressed: () => onChoice(DuplicateMergeChoice.keepExisting),
                  style:
                      TextButton.styleFrom(minimumSize: minSize, shape: shape),
                  child: Text(l10n.duplicateMergeKeepExisting),
                ),
              ),
              const SizedBox(width: AppDimensions.spacingSm),
              Expanded(
                child: TextButton(
                  onPressed: () =>
                      onChoice(DuplicateMergeChoice.replaceWithNew),
                  style:
                      TextButton.styleFrom(minimumSize: minSize, shape: shape),
                  child: Text(l10n.duplicateMergeReplaceWithNew),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
