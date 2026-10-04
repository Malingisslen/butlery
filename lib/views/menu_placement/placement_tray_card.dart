/// BUT-1241: the bottom tray's recipe card for the manual placement mode.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/menu/menu_placement_viewmodel.dart';
import 'package:butlery/widgets/common/press_fill.dart';

/// One recipe card in the bottom tray. Tap to select (unplaced) or
/// un-place (placed).
class PlacementTrayCard extends StatelessWidget {
  final MenuPlacementViewModel vm;
  final int index;

  const PlacementTrayCard({super.key, required this.vm, required this.index});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final item = vm.items[index];
    final isSelected = vm.selectedIndex == index;
    return Semantics(
      label: context.l10n.a11yPlacementTrayCard(item.recipe.title),
      button: true,
      selected: isSelected,
      child: Material(
        type: MaterialType.transparency,
        child: PressFill(
          surface: isSelected ? PressSurface.ink : PressSurface.raised,
          child: InkWell(
            onTap: () => vm.tapItem(index),
            // #placera draws the chosen dish in the tray as ink with paper text,
            // and the others on surface.raised with a 1 px border.control
            // (Skarmar v12 del 2). A placed dish is struck through, never
            // faded. tokens.json gives the struck text text.completed (#37453A
            // light, #93A48D dark); no scheme slot carries it, so onSurfaceVariant
            // stands in until text.completed is delivered as a member (open, D1).
            child: Ink(
              width: 132,
              decoration: BoxDecoration(
                color: isSelected ? cs.primary : cs.primaryContainer,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  border: isSelected ? null : Border.all(color: cs.outline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.slot.displayLabel.toUpperCase(),
                      style: AppTextStyles.overline.copyWith(
                        color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Expanded(
                      child: Text(
                        item.recipe.title,
                        style: AppTextStyles.labelSmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? cs.onPrimary
                              : (item.isPlaced
                                    ? cs.onSurfaceVariant
                                    : cs.onPrimaryContainer),
                          decoration: item.isPlaced
                              ? TextDecoration.lineThrough
                              : null,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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
