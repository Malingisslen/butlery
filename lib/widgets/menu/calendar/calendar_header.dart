/// Week navigation header + overflow tray for the weekly-menu calendar.
///
/// Extracted from `calendar_cells.dart` (BUT-542) to keep that file under
/// the 500-line ceiling. Both widgets are stateless and agnostic to the
/// orchestrator's Provider/routing concerns — nav callbacks + overflow
/// payload are injected.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/widgets/menu/calendar/calendar_drag.dart';

class WeekNavHeader extends StatelessWidget {
  final String label;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  /// Optional "Rensa veckan" callback. When provided, a trash icon button
  /// is shown on the trailing side so the user can clear the visible week.
  final VoidCallback? onClearWeek;

  const WeekNavHeader({
    super.key,
    required this.label,
    required this.onPrev,
    required this.onNext,
    this.onClearWeek,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingMd,
        vertical: AppDimensions.spacingSm,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            color: cs.onPrimaryContainer,
            onPressed: onPrev,
            tooltip: context.l10n.weeklyMenuPrevWeek,
          ),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.titleSmall.copyWith(
                color: cs.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          if (onClearWeek != null)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              color: cs.onPrimaryContainer,
              onPressed: onClearWeek,
              tooltip: context.l10n.weeklyMenuClearWeekAction,
            ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            color: cs.onPrimaryContainer,
            onPressed: onNext,
            tooltip: context.l10n.weeklyMenuNextWeek,
          ),
        ],
      ),
    );
  }
}

class OverflowTray extends StatelessWidget {
  final List<Recipe> overflow;

  const OverflowTray({
    super.key,
    required this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    final butleryColors = context.butleryColors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingMd,
        vertical: AppDimensions.spacingSm,
      ),
      decoration: BoxDecoration(
        color: butleryColors.warningContainer,
        border: Border(
          bottom: BorderSide(color: butleryColors.warning, width: 2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 14, color: butleryColors.warning),
              const SizedBox(width: AppDimensions.spacingXs),
              Text(
                context.l10n.weeklyMenuOverflowTitle,
                style: AppTextStyles.labelSmall.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingXs),
          Wrap(
            spacing: AppDimensions.spacingXs,
            runSpacing: AppDimensions.spacingXs,
            children: [
              for (final recipe in overflow) _OverflowChip(recipe: recipe),
            ],
          ),
        ],
      ),
    );
  }
}

class _OverflowChip extends StatelessWidget {
  final Recipe recipe;

  const _OverflowChip({required this.recipe});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final chip = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingSm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          left: BorderSide(color: context.butleryColors.warning, width: 2),
          bottom: const BorderSide(color: AppColors.rustLight, width: 2),
        ),
      ),
      child: Text(
        recipe.title.toLowerCase(),
        style: AppTextStyles.labelSmall.copyWith(color: cs.onSurface),
      ),
    );
    return wrapAsDraggable(
      context: context,
      payload: OverflowPayload(recipe),
      child: chip,
    );
  }
}
