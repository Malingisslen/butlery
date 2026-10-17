// lib/widgets/shopping/shopping_row.dart
//
// The one row of a shopping list (Skarmar v12 del 2 #inkop): a square box,
// the name with its amount in the muted tone beside it, whatever the list
// needs at the right, and a hairline under. The personal list and the shared
// list both draw it; neither sets its own box, type or rule.
library;

import 'package:flutter/material.dart';

import 'package:butlery/widgets/common/surfaces/butlery_outlined_box.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/reduced_motion.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_motion.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/layout/word_fit.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/input/butlery_checkbox.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/press_fill.dart';
import 'package:butlery/widgets/common/menus/butlery_menu.dart';

/// One entry of [ShoppingRowMenu].
class ShoppingRowAction {
  const ShoppingRowAction({
    required this.label,
    required this.icon,
    required this.onSelected,
  });

  final String label;
  final IconData icon;
  final VoidCallback onSelected;
}

class ShoppingRow extends StatefulWidget {
  const ShoppingRow({
    required this.name,
    required this.checked,
    this.amount,
    this.note,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.selectionMode = false,
    this.selected = false,
    this.muted = false,
    this.semanticIdentifier,
    this.semanticLabel,
    this.tapKey,
    super.key,
  });

  final String name;

  /// "3 dl", set after the name in the secondary tone. Empty or null when
  /// the name says it all.
  final String? amount;

  final String? note;
  final bool checked;

  /// Whatever the list puts at the right: a claim, a name badge, the menu.
  final Widget? trailing;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// A row that is being picked draws the pick mark in front of the box and
  /// a selected one the selected surface.
  final bool selectionMode;
  final bool selected;

  /// Somebody else's row on a shared list: the text in the secondary tone.
  final bool muted;

  final String? semanticIdentifier;

  /// Overrides the node name; by default the screen reader hears what a tap
  /// does ("Bocka av", "Ta bort bocken", "Markera").
  final String? semanticLabel;

  /// Key of the tappable area, for tests.
  final Key? tapKey;

  @override
  State<ShoppingRow> createState() => _ShoppingRowState();
}

class _ShoppingRowState extends State<ShoppingRow>
    with SingleTickerProviderStateMixin {
  static const double _boxSize = ButleryCheckbox.boxSize;
  static const double _pulseScale = 1.2;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: AppMotion.micro,
  );
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: _pulseScale,
      ).chain(CurveTween(curve: AppMotion.curve)),
      weight: 50,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: _pulseScale,
        end: 1.0,
      ).chain(CurveTween(curve: AppMotion.curve)),
      weight: 50,
    ),
  ]).animate(_pulse);

  @override
  void didUpdateWidget(ShoppingRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The fill still changes under reduced motion, just without the pulse.
    if (oldWidget.checked != widget.checked && !isReducedMotion(context)) {
      _pulse.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final selected = widget.selected;
    final quiet = widget.checked || widget.muted;
    final nameColor = quiet ? cs.onSurfaceVariant : cs.onSurface;
    final decoration = widget.checked
        ? TextDecoration.lineThrough
        : TextDecoration.none;
    final amount = widget.amount;
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1;

    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          // A chosen row is surface.selected with a 1.5 px text.primary edge
          // (Skarmar v12 etapp 9 #flerbar); primaryContainer is
          // surface.selected in both schemes.
          color: selected ? cs.primaryContainer : null,
          border: selected
              ? Border.all(
                  color: cs.onSurface,
                  width: AppDimensions.borderWidthOutlinedEdge,
                )
              : Border(bottom: BorderSide(color: cs.outlineVariant)),
        ),
        child: Semantics(
          identifier: widget.semanticIdentifier,
          label:
              widget.semanticLabel ??
              (widget.selectionMode
                  ? context.l10n.a11yShoppingSelectItem
                  : (widget.checked
                        ? context.l10n.a11yShoppingItemChecked
                        : context.l10n.a11yShoppingItemUnchecked)),
          button: true,
          checked: widget.selectionMode ? null : widget.checked,
          selected: widget.selectionMode ? selected : null,
          enabled: widget.onTap != null,
          child: Material(
            type: MaterialType.transparency,
            child: PressFill(
              surface: PressSurface.base,
              child: InkWell(
                key: widget.tapKey,
                onTap: widget.onTap,
                onLongPress: widget.onLongPress,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: AppDimensions.minTouchTarget,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppDimensions.space8,
                    ),
                    child: Row(
                      children: [
                        if (widget.selectionMode) ...[
                          ButleryIcon(
                            selected
                                ? ButleryIcons.circleCheck
                                : ButleryIcons.circle,
                            color: selected
                                ? cs.onSurface
                                : cs.onSurfaceVariant,
                            size: AppDimensions.iconSizeM,
                          ),
                          const SizedBox(width: AppDimensions.space12),
                        ],
                        _box(context, cs),
                        const SizedBox(width: AppDimensions.space12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              WholeWordText.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(text: widget.name),
                                    if (amount != null && amount.isNotEmpty)
                                      TextSpan(
                                        text: ' $amount',
                                        style: TextStyle(
                                          color: cs.onSurfaceVariant,
                                        ),
                                      ),
                                  ],
                                ),
                                style: AppTextStyles.contentTitle.copyWith(
                                  color: nameColor,
                                  decoration: decoration,
                                ),
                                // BUT-2193 (Malin, 2026-10-03): a row may cut a
                                // long name at the normal text size.
                                maxLines: largeText ? null : 2,
                              ),
                              if (widget.note?.isNotEmpty == true) ...[
                                const SizedBox(height: AppDimensions.space4),
                                Text(
                                  widget.note!,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: cs.onSurfaceVariant,
                                    decoration: decoration,
                                  ),
                                  maxLines: largeText ? null : 1,
                                  overflow: largeText
                                      ? null
                                      : TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (widget.trailing != null) widget.trailing!,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _box(BuildContext context, ColorScheme cs) {
    final checked = widget.checked;
    return ScaleTransition(
      scale: _scale,
      child: ButleryAnimatedOutlinedBox(
        duration: AppMotion.micro.respectingMotion(context),
        curve: AppMotion.curve,
        width: _boxSize,
        height: _boxSize,
        radius: AppDimensions.checkboxRadius,
        // Ticked: control.checked.background, ink in both modes. Unticked:
        // the control edge, as the sketch draws the box.
        borderColor: checked ? cs.primary : cs.outline,
        borderWidth: AppDimensions.borderWidthOutlinedEdge,
        color: checked ? cs.primary : null,
        child: AnimatedSwitcher(
          duration: AppMotion.micro.respectingMotion(context),
          switchInCurve: AppMotion.curve,
          switchOutCurve: AppMotion.curve,
          child: checked
              ? ButleryIcon(
                  ButleryIcons.check,
                  key: const ValueKey('check-icon'),
                  size: AppDimensions.iconSizeS,
                  color: cs.onPrimary,
                )
              : const SizedBox.shrink(key: ValueKey('empty-icon')),
        ),
      ),
    );
  }
}

/// The row's ⋮ menu: what the old row showed as three icon buttons.
class ShoppingRowMenu extends StatelessWidget {
  const ShoppingRowMenu({
    required this.itemName,
    required this.actions,
    super.key,
  });

  final String itemName;
  final List<ShoppingRowAction> actions;

  @override
  Widget build(BuildContext context) {
    return ButleryMenu<int>(
      iconColor: Theme.of(context).colorScheme.onSurfaceVariant,
      semanticLabel: context.l10n.a11yShoppingItemMoreOptions(itemName),
      onSelected: (i) => actions[i].onSelected(),
      choices: [
        for (final (i, action) in actions.indexed)
          ButleryMenuChoice<int>(
            value: i,
            label: action.label,
            icon: action.icon,
          ),
      ],
    );
  }
}
