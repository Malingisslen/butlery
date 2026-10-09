import 'package:clock/clock.dart';
import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/trash_item.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/trash_viewmodel.dart';
import 'package:butlery/widgets/common/press_fill.dart';
import 'package:butlery/widgets/image/image_config.dart';
import 'package:butlery/widgets/image/simple_image_widget.dart';
import 'package:butlery/widgets/recipe/recipe_initial_plate.dart';

/// One trashed recipe: checkbox, title, days left with a time-left bar, and
/// the photo. A tap anywhere on the row toggles it.
class TrashRow extends StatelessWidget {
  const TrashRow({
    required this.item,
    required this.selected,
    required this.onToggle,
    super.key,
  });

  /// Under this many days left the bar turns amber.
  static const int warnBelowDays = 3;

  static const double _thumbnailSize = AppDimensions.imageSizeThumbnail * 0.75;

  final TrashItem item;
  final bool selected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final now = clock.now();
    final days = TrashViewModel.daysLeft(item, now);
    final urgent = days < warnBelowDays;
    final barColor = urgent ? context.modeColors.warning : cs.primary;

    return Semantics(
      button: true,
      selected: selected,
      child: PressFill(
        surface: PressSurface.base,
        child: InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacingMd,
              vertical: AppDimensions.spacingSm,
            ),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Checkbox(
                    value: selected,
                    onChanged: (_) => onToggle(),
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingSm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: AppTextStyles.titleSmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppDimensions.spacingXs),
                      Text(
                        context.l10n.trashDaysLeft(days),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: urgent
                              ? AppModeColors.textWarning(cs.brightness)
                              : cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacingXs),
                      ExcludeSemantics(
                        child: _TimeLeftBar(
                          fraction: TrashViewModel.fractionLeft(item, now),
                          color: barColor,
                          track: cs.surfaceContainerHighest,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingMd),
                SizedBox.square(
                  dimension: _thumbnailSize,
                  child: ExcludeSemantics(child: _thumbnail(cs)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _thumbnail(ColorScheme cs) {
    final url = item.thumbnailUrl;
    return ColoredBox(
      color: cs.surfaceContainerHighest,
      child: url != null && url.isNotEmpty
          ? SimpleImageWidget(
              imageUrl: url,
              fit: BoxFit.cover,
              config: ImageConfig.thumbnail(),
            )
          : RecipeInitialPlate(title: item.title),
    );
  }
}

/// A static bar of how much of the 30 days is left; not a progress spinner.
class _TimeLeftBar extends StatelessWidget {
  const _TimeLeftBar({
    required this.fraction,
    required this.color,
    required this.track,
  });

  final double fraction;
  final Color color;
  final Color track;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppDimensions.space4,
      child: ColoredBox(
        color: track,
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: FractionallySizedBox(
            widthFactor: fraction,
            child: ColoredBox(
              color: color,
              key: const ValueKey('timeLeftFill'),
            ),
          ),
        ),
      ),
    );
  }
}
