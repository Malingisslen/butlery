/// BUT-1241: the tray's dish chip for the manual placement mode.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/menu/menu_placement_viewmodel.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/press_fill.dart';

/// One dish in the tray, a pill: the chosen one filled with ink and a check,
/// the others outlined (approved picture 78-menu-placement). A placed dish is
/// struck through, never faded. Tap to choose (unplaced) or un-place (placed).
class PlacementTrayCard extends StatelessWidget {
  final MenuPlacementViewModel vm;
  final int index;

  const PlacementTrayCard({super.key, required this.vm, required this.index});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final item = vm.items[index];
    final isSelected = vm.selectedIndex == index;
    final textColor = isSelected
        ? cs.surface
        : item.isPlaced
        ? cs.onSurfaceVariant
        : cs.onSurface;
    return Semantics(
      label: context.l10n.a11yPlacementTrayCard,
      button: true,
      selected: isSelected,
      child: Material(
        type: MaterialType.transparency,
        child: PressFill(
          surface: isSelected ? PressSurface.ink : PressSurface.raised,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
            onTap: () => vm.tapItem(index),
            child: Ink(
              decoration: BoxDecoration(
                color: isSelected ? cs.onSurface : null,
                borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
              ),
              // The border is a box above the ink, so a press shows beneath it.
              child: Container(
                constraints: const BoxConstraints(
                  minHeight: AppDimensions.minTouchTarget,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.space16,
                  vertical: AppDimensions.space8,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isSelected ? cs.onSurface : cs.outline,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusPill,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected || item.isPlaced) ...[
                      ButleryIcon(
                        ButleryIcons.check,
                        size: AppDimensions.iconSizeS,
                        color: textColor,
                      ),
                      const SizedBox(width: AppDimensions.space8),
                    ],
                    Flexible(
                      child: Text(
                        item.recipe.title,
                        style: AppTextStyles.labelLargeBold.copyWith(
                          color: textColor,
                          decoration: item.isPlaced
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
