import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/buttons/butlery_text_button.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
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
                          horizontal: AppDimensions.space8,
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
                            const SizedBox(width: AppDimensions.space4),
                            ButleryChevron(color: color),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (report != null)
              AppIconButton(
                icon: ButleryIcons.flag,
                color: color,
                semanticLabel: l10n.menuDishReportTooltip,
                onPressed: report,
              ),
          ],
        ),
        if (notMine != null)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.space4,
            ),
            child: ButleryTextButton(
              label: l10n.menuDishNotMine,
              onPressed: notMine,
            ),
          ),
      ],
    );
  }
}
