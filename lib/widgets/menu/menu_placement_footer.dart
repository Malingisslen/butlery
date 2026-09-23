// lib/widgets/menu/menu_placement_footer.dart
//
// BUT-1241: pinned footer under the lista-mode generation result. Offers
// the two placement paths — auto-distribute onto the calendar, or open the
// manual placement mode. Replaces the old silent distribute-on-mode-toggle
// bridge with an explicit choice.

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';

class MenuPlacementChoiceFooter extends StatelessWidget {
  final VoidCallback onPlaceAuto;
  final VoidCallback onPlaceManual;

  /// BUT-1987: a distribution is being placed. The viewmodel refuses a second
  /// tap and says nothing — this surface ranks error above data, so a message
  /// would replace the calendar the first tap placed — so the button carries
  /// the state instead. `isLoading` is what disables it; it also draws the
  /// spinner, which a bare disabled control would not.
  final bool isPlacing;

  const MenuPlacementChoiceFooter({
    super.key,
    required this.onPlaceAuto,
    required this.onPlaceManual,
    this.isPlacing = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        // text.primary (onSurface): ink on light, paper on dark. cs.primary
        // is ink in both modes and would vanish on the dark surface.
        border: Border(top: BorderSide(color: cs.onSurface, width: 2)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.spacingMd,
        AppDimensions.spacingSm,
        AppDimensions.spacingMd,
        AppDimensions.spacingMd,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ActionButtons.primaryButton(
            context,
            label: context.l10n.menuPlaceAutoButton,
            icon: Icons.calendar_month_outlined,
            onPressed: onPlaceAuto,
            isLoading: isPlacing,
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          ActionButtons.outlinedButton(
            context,
            label: context.l10n.menuPlaceManualButton,
            icon: Icons.touch_app_outlined,
            onPressed: onPlaceManual,
          ),
        ],
      ),
    );
  }
}
