// lib/widgets/menu/menu_placement_footer.dart
//
// BUT-1241: pinned footer under the lista-mode generation result. Offers
// the two placement paths — auto-distribute onto the calendar, or open the
// manual placement mode — and the way on to the shopping list. Replaces the
// old silent distribute-on-mode-toggle bridge with an explicit choice.
//
// The calendar's own footer (one "Till inköpslista" button) shares the frame.

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

/// The strip every week-menu footer stands in: paper, a hairline above, and
/// room for the home indicator.
class VeckomenyFooterFrame extends StatelessWidget {
  const VeckomenyFooterFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.space16,
        AppDimensions.space12,
        AppDimensions.space16,
        AppDimensions.space12,
      ),
      // BUT-2275: the bottom slot runs under the home indicator.
      child: SafeArea(top: false, child: child),
    );
  }
}

/// The calendar's footer: the one way from the week to the shopping list
class VeckomenyShoppingFooter extends StatelessWidget {
  const VeckomenyShoppingFooter({
    super.key,
    required this.onPressed,
    this.isBusy = false,
  });

  final VoidCallback onPressed;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    return VeckomenyFooterFrame(
      child: ActionButtons.primaryButton(
        context,
        label: context.l10n.menuToShoppingList,
        icon: ButleryIcons.shoppingCart,
        onPressed: onPressed,
        isLoading: isBusy,
        isExpanded: true,
      ),
    );
  }
}

class MenuPlacementChoiceFooter extends StatelessWidget {
  final VoidCallback onPlaceAuto;
  final VoidCallback onPlaceManual;
  final VoidCallback onToShopping;

  /// BUT-1987: a distribution is being placed. The viewmodel refuses a second
  /// tap and says nothing — this surface ranks error above data, so a message
  /// would replace the calendar the first tap placed — so the button carries
  /// the state instead. `isLoading` is what disables it; it also draws the
  /// spinner, which a bare disabled control would not.
  final bool isPlacing;
  final bool isShoppingBusy;

  const MenuPlacementChoiceFooter({
    super.key,
    required this.onPlaceAuto,
    required this.onPlaceManual,
    required this.onToShopping,
    this.isPlacing = false,
    this.isShoppingBusy = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final manual = ActionButtons.outlinedButton(
      context,
      label: l10n.menuPlaceManualButton,
      icon: ButleryIcons.hand,
      onPressed: onPlaceManual,
      isExpanded: true,
    );
    final shopping = ActionButtons.outlinedButton(
      context,
      label: l10n.menuToShoppingList,
      icon: ButleryIcons.shoppingCart,
      onPressed: onToShopping,
      isLoading: isShoppingBusy,
      isExpanded: true,
    );
    // Two outlined buttons side by side; stacked above this text scale.
    final stacked = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    return VeckomenyFooterFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ActionButtons.primaryButton(
            context,
            label: l10n.menuPlaceAutoButton,
            icon: ButleryIcons.calendar,
            onPressed: onPlaceAuto,
            isLoading: isPlacing,
          ),
          const SizedBox(height: AppDimensions.space8),
          if (stacked) ...[
            manual,
            const SizedBox(height: AppDimensions.space8),
            shopping,
          ] else
            Row(
              spacing: AppDimensions.space8,
              children: [
                Expanded(child: manual),
                Expanded(child: shopping),
              ],
            ),
        ],
      ),
    );
  }
}
