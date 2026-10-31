import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/tagging/tag_decision.dart';
import 'package:butlery/models/tagging/tag_overrides.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/services/tagging/config/dietary_config.dart';
import 'package:butlery/widgets/common/feedback/inline_warning.dart';
import 'package:butlery/widgets/tagging/allergen_status_badge.dart';
import 'package:butlery/widgets/tagging/dietary_status_badge.dart';
import 'package:butlery/widgets/common/butlery_tap_target.dart';
import 'package:butlery/widgets/common/sheets/butlery_sheet.dart';
import 'package:butlery/widgets/common/buttons/butlery_text_button.dart';

/// Priority-ordered list of dietary keys used by TagResultDisplay.
/// Derived from DietaryConfig to prevent key drift.
final _defaultDietaryOrder = DietaryConfig.allKeys;

/// Resolves the status a screen should show for an allergen, so the badges
/// agree with the menu and sharing (see `AllergenVerdict`) rather than reading
/// the tagger's raw answer. Null means the raw answer.
typedef AllergenStatusOf = TriState Function(String allergenKey);

/// The tracked allergens the tagger has not settled.
///
/// A recipe with no tag result has settled none of them. A null or empty
/// [prefs] reads as "every allergen the tagger settled".
bool hasUncheckedAllergens(
  TagResult? tagResult,
  Set<String>? prefs, {
  AllergenStatusOf? statusOf,
}) {
  if (tagResult == null) return true;
  final keys = prefs != null && prefs.isNotEmpty
      ? prefs
      : tagResult.allergenStatus.keys.toSet();
  // A result that settled no allergen at all has checked nothing.
  if (keys.isEmpty) return true;
  final status = statusOf ?? tagResult.getAllergenStatus;
  return keys.any((a) => status(a) == TriState.unknown);
}

/// Displays the full tag result from the tagging system.
///
/// Shows allergen status, dietary status, and coverage information.
/// Can be filtered by user preferences to only show relevant allergens.
class TagResultDisplay extends StatelessWidget {
  /// The tag result to display.
  final TagResult tagResult;

  /// Allergen keys the user wants to track (considers only these).
  /// Null — and, here, an EMPTY set — mean every allergen the tagger settled.
  /// UNKNOWN is dropped, so a tracked allergen is no guarantee of a badge.
  final Set<String>? userAllergenPrefs;

  /// Dietary keys the user wants to track.
  /// If null, shows all dietary statuses with non-unknown status.
  final Set<String>? userDietaryPrefs;

  /// Whether to show coverage information.
  final bool showCoverage;

  /// Callback when unknown ingredients are tapped.
  final VoidCallback? onUnknownIngredientsTap;

  /// Callback to trigger retagging when version is outdated.
  final VoidCallback? onRetagRequested;

  /// Use compact mode for space-constrained layouts.
  final bool compact;

  /// Whether the tagging system is in degraded mode (config validation failed).
  final bool isDegraded;

  /// Status to show per allergen. Null shows the tagger's raw answer.
  final AllergenStatusOf? allergenStatusOf;

  /// The user's manual corrections. Each one that changes the tagger's answer
  /// gets a line saying so, so a correction is never invisible.
  final TagOverrides? tagOverrides;

  /// Removes the user's override for one allergen. Null hides the button.
  final ValueChanged<String>? onResetAllergenOverride;

  const TagResultDisplay({
    super.key,
    required this.tagResult,
    this.userAllergenPrefs,
    this.userDietaryPrefs,
    this.showCoverage = true,
    this.onUnknownIngredientsTap,
    this.onRetagRequested,
    this.compact = false,
    this.isDegraded = false,
    this.allergenStatusOf,
    this.tagOverrides,
    this.onResetAllergenOverride,
  });

  TriState _allergenStatus(String allergen) =>
      (allergenStatusOf ?? tagResult.getAllergenStatus)(allergen);

  bool get _hasUnchecked => hasUncheckedAllergens(
    tagResult,
    userAllergenPrefs,
    statusOf: allergenStatusOf,
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Degraded mode warning when tag config validation failed
        if (isDegraded) ...[
          _buildDegradedWarning(context),
          const SizedBox(height: AppDimensions.space8),
        ],

        // Version mismatch indicator (if outdated)
        if (tagResult.needsRetagging && !tagResult.hasFailed) ...[
          _buildRetagIndicator(context),
          const SizedBox(height: AppDimensions.space8),
        ],

        // All badges inline in a single Wrap
        _buildInlineBadges(context),
        if (!compact) ..._buildOverrideLines(context),
        if (!compact && _hasUnchecked) ...[
          const SizedBox(height: AppDimensions.space4),
          Text(
            context.l10n.allergenUncheckedDetail,
            style: AppTextStyles.bodySmall.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],

        // Draft ingredient warning
        if (tagResult.hasDraftIngredients) ...[
          const SizedBox(height: AppDimensions.space8),
          _buildDraftWarning(context),
        ],

        // Coverage section
        if (showCoverage) ...[
          const SizedBox(height: AppDimensions.space12),
          _buildCoverageSection(context),
        ],

        const SizedBox(height: AppDimensions.space12),
        const Padding(
          padding: EdgeInsets.only(top: AppDimensions.space4),
          child: AllergenDisclaimer(),
        ),
      ],
    );
  }

  List<Widget> _buildOverrideLines(BuildContext context) {
    final overrides = tagOverrides?.allergenOverrides;
    if (overrides == null || overrides.isEmpty) return const [];
    final cs = Theme.of(context).colorScheme;
    final lines = <Widget>[];
    for (final entry in overrides.entries) {
      final auto = tagResult.getAllergenStatus(entry.key);
      final String text;
      if (auto == TriState.contains && entry.value == TriState.free) {
        text = context.l10n.allergenOverrideOk(entry.key);
      } else if (entry.value == TriState.contains &&
          auto != TriState.contains) {
        text = context.l10n.allergenOverrideContains(entry.key);
      } else {
        continue;
      }
      lines.add(
        Padding(
          padding: const EdgeInsets.only(top: AppDimensions.space4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  text,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
              if (onResetAllergenOverride != null)
                ButleryTextButton(
                  label: context.l10n.allergenOverrideReset,
                  onPressed: () => onResetAllergenOverride!(entry.key),
                ),
            ],
          ),
        ),
      );
    }
    return lines;
  }

  /// Renders allergen and dietary badges inline without card wrapper.
  Widget _buildInlineBadges(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final allergens = _getAllergensToShow();
    final diets = _getDietaryToShow();

    final unchecked = _hasUnchecked;

    if (allergens.isEmpty && diets.isEmpty && !unchecked) {
      return Text(
        context.l10n.tagResultNoAllergens,
        style: AppTextStyles.bodySmall.copyWith(
          color: cs.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return Wrap(
      spacing: AppDimensions.space4,
      runSpacing: AppDimensions.space4,
      children: [
        if (unchecked) AllergenUncheckedMark(compact: compact),
        // Allergen badges
        ...allergens.map((allergen) {
          final status = _allergenStatus(allergen);
          final decision = tagResult.getAllergenDecision(allergen);
          return AllergenStatusBadge(
            allergen: allergen,
            status: status,
            compact: compact,
            onInfoTap: decision != null && !compact
                ? () => _showDecisionSheet(context, decision)
                : null,
          );
        }),
        // Dietary badges
        ...diets.map((diet) {
          final status = tagResult.getDietaryStatus(diet);
          final decision = tagResult.getDietaryDecision(diet);
          return DietaryStatusBadge(
            diet: diet,
            status: status,
            compact: compact,
            onInfoTap: decision != null && !compact
                ? () => _showDecisionSheet(context, decision)
                : null,
          );
        }),
      ],
    );
  }

  static void _showDecisionSheet(BuildContext context, TagDecision decision) {
    final cs = Theme.of(context).colorScheme;
    showButlerySheet<void>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(AppDimensions.space16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.tagDecisionWhyTitle,
              style: AppTextStyles.titleMedium,
            ),
            const SizedBox(height: AppDimensions.space12),
            Text(
              context.l10n.tagDecisionReason,
              style: AppTextStyles.labelMedium.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppDimensions.space4),
            Text(
              decision.reason,
              style: AppTextStyles.bodyMedium,
            ),
            if (decision.triggeringIngredients != null &&
                decision.triggeringIngredients!.isNotEmpty) ...[
              const SizedBox(height: AppDimensions.space12),
              Text(
                context.l10n.tagDecisionIngredients,
                style: AppTextStyles.labelMedium.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppDimensions.space4),
              ...decision.triggeringIngredients!.map(
                (ingredient) => Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: AppDimensions.space12,
                    bottom: AppDimensions.space4,
                  ),
                  child: Row(
                    children: [
                      Text('·  ', style: AppTextStyles.bodyMedium),
                      Text(ingredient, style: AppTextStyles.bodyMedium),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppDimensions.space12),
          ],
        ),
      ),
    );
  }

  Widget _buildRetagIndicator(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final warningColor = AppModeColors.textWarning(cs.brightness);
    return Container(
      padding: const EdgeInsets.all(AppDimensions.space8),
      decoration: BoxDecoration(
        color: context.modeColors.surfaceTintWarning,
        borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
      ),
      child: Row(
        children: [
          ButleryIcon(
            ButleryIcons.refreshCw,
            color: warningColor,
            size: AppDimensions.iconSize18,
          ),
          const SizedBox(width: AppDimensions.space4),
          Expanded(
            child: Text(
              context.l10n.tagResultOutdated,
              style: AppTextStyles.bodySmall.copyWith(
                color: warningColor,
              ),
            ),
          ),
          if (onRetagRequested != null)
            ButleryTextButton(
              onPressed: onRetagRequested,
              label: context.l10n.commonUpdate,
              dense: true,
            ),
        ],
      ),
    );
  }

  Widget _buildDraftWarning(BuildContext context) {
    return InlineWarning(
      icon: ButleryIcons.info,
      color: context.modeColors.warning,
      textColor: AppModeColors.textWarning(Theme.of(context).brightness),
      text: context.l10n.ingredientDataUnverified,
    );
  }

  Widget _buildDegradedWarning(BuildContext context) {
    return InlineWarning(
      icon: ButleryIcons.triangleAlert,
      color: Theme.of(context).colorScheme.error,
      text: context.l10n.taggingDegradedWarning,
    );
  }

  Widget _buildCoverageSection(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final coveragePercent = (tagResult.coverage * 100).round();
    final hasUnknowns = tagResult.hasUnknowns;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ButleryIcon(
              ButleryIcons.barChart,
              color: cs.onSurface,
              size: compact ? AppDimensions.iconSizeS : AppDimensions.iconSizeM,
            ),
            const SizedBox(width: AppDimensions.space4),
            Text(
              context.l10n.tagResultCoverage,
              style: compact
                  ? AppTextStyles.titleSmall
                  : AppTextStyles.titleMedium,
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.space4),
        Row(
          children: [
            Expanded(
              // The percentage beside it keeps its status colour, so
              // colour is never the only signal; the line is not read out
              // on its own.
              child: ExcludeSemantics(
                child: PlateLine(value: tagResult.coverage),
              ),
            ),
            const SizedBox(width: AppDimensions.space8),
            Text(
              '$coveragePercent%',
              style: AppTextStyles.bodyBold.copyWith(
                color: _getCoverageColor(context),
              ),
            ),
          ],
        ),
        if (hasUnknowns) ...[
          const SizedBox(height: AppDimensions.space4),
          _buildUnknownIngredientsRow(context),
        ],
      ],
    );
  }

  Widget _buildUnknownIngredientsRow(BuildContext context) {
    final onTap = onUnknownIngredientsTap;
    final label = context.l10n.tagResultUnknownIngredientsA11y(
      tagResult.unknownIngredients.length,
    );
    final row = Row(
      children: [
        ButleryIcon(
          ButleryIcons.triangleAlert,
          size: AppDimensions.iconSizeS,
          color: context.modeColors.warning,
        ),
        const SizedBox(width: AppDimensions.space4),
        Expanded(
          child: Text(
            context.l10n.tagResultUnknownIngredients(
              tagResult.unknownIngredients.length,
            ),
            style: AppTextStyles.bodySmall.copyWith(
              color: AppModeColors.textWarning(Theme.of(context).brightness),
            ),
          ),
        ),
        if (onTap != null) ButleryChevron(color: context.modeColors.warning),
      ],
    );
    // The label says what the visible text says; reading both would announce
    // the count twice.
    final quiet = ExcludeSemantics(child: row);
    if (onTap == null) return Semantics(label: label, child: quiet);
    return ButleryTapTarget(semanticLabel: label, onTap: onTap, child: quiet);
  }

  Color _getCoverageColor(BuildContext context) {
    // Mostly-full bar should read as "positive" visually, so we grade
    // generously: 80%+ is green, 40%+ amber, rust-red only for genuinely
    // incomplete coverage. Previously 80–99% showed as amber and anything
    // below 80% rendered rust-red — a nearly-full red bar misleads.
    if (tagResult.coverage >= 0.8) return context.modeColors.success;
    if (tagResult.coverage >= 0.4) {
      return AppModeColors.textWarning(Theme.of(context).brightness);
    }
    return Theme.of(context).colorScheme.error;
  }

  List<String> _getAllergensToShow() {
    if (userAllergenPrefs != null && userAllergenPrefs!.isNotEmpty) {
      // UI Redesign: Filter out unknown status even from user prefs
      return userAllergenPrefs!.where((allergen) {
        return _allergenStatus(allergen) != TriState.unknown;
      }).toList();
    }

    // Show allergens with known status (not unknown)
    return tagResult.allergenStatus.keys
        .where((key) => _allergenStatus(key) != TriState.unknown)
        .toList();
  }

  List<String> _getDietaryToShow() {
    if (userDietaryPrefs != null && userDietaryPrefs!.isNotEmpty) {
      return userDietaryPrefs!.toList();
    }

    return _defaultDietaryOrder.where((diet) {
      final status = tagResult.getDietaryStatus(diet);
      return status == TriState.free;
    }).toList();
  }
}

class AllergenDisclaimer extends StatelessWidget {
  const AllergenDisclaimer({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ButleryIcon(
          ButleryIcons.info,
          size: AppDimensions.iconSize14,
          color: cs.onSurfaceVariant,
        ),
        const SizedBox(width: AppDimensions.space4),
        Expanded(
          child: Text(
            context.l10n.allergenDisclaimer,
            style: AppTextStyles.bodySmall.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
