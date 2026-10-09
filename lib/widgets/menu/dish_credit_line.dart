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
  });

  final String userId;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Semantics(
      button: true,
      label: context.l10n.a11yOpenCreatorProfile,
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
                      context.l10n.menuDishCreatorCredit(displayName),
                      style: AppTextStyles.labelMedium.copyWith(color: color),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacingXs),
                  ButleryIcon(ButleryIcons.chevronRight, color: color),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
