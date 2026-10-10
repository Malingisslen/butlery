import 'package:flutter/material.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/press_fill.dart';

/// BUT-2221: "Recept av {name}" under a dish on a shared menu. Opens the
/// creator's public profile.
class DishCreditLine extends StatelessWidget {
  const DishCreditLine({
    super.key,
    required this.userId,
    required this.displayName,
    this.onReport,
    this.onNotMine,
  });

  final String userId;
  final String displayName;

  /// BUT-2339: shows the flag button when set.
  final VoidCallback? onReport;

  /// BUT-2339: shows the "not my dish" button when set; only the named viewer
  /// gets one.
  final VoidCallback? onNotMine;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    final l10n = context.l10n;
    final report = onReport;
    final notMine = onNotMine;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Semantics(
                button: true,
                label: l10n.a11yOpenCreatorProfile,
                child: PressFill(
                  surface: PressSurface.base,
                  child: InkWell(
                    onTap: () => Navigator.pushNamed(
                      context,
                      Routes.publicProfile,
                      arguments: userId,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: AppDimensions.minTouchTarget,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.spacingSm,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                l10n.menuDishCreatorCredit(displayName),
                                style: AppTextStyles.labelMedium.copyWith(
                                  color: color,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: AppDimensions.spacingXs),
                            ButleryIcon(
                              ButleryIcons.chevronRight,
                              color: color,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (report != null)
              IconButton(
                onPressed: report,
                tooltip: l10n.menuDishReportTooltip,
                constraints: const BoxConstraints(
                  minWidth: AppDimensions.minTouchTarget,
                  minHeight: AppDimensions.minTouchTarget,
                ),
                icon: ButleryIcon(ButleryIcons.flag, color: color),
              ),
          ],
        ),
        if (notMine != null)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacingXs,
            ),
            child: TextButton(
              onPressed: notMine,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, AppDimensions.minTouchTarget),
              ),
              child: Text(l10n.menuDishNotMine),
            ),
          ),
      ],
    );
  }
}
