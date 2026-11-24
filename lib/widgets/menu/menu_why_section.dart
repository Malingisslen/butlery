/// "Varför?" under a suggested dish, and the note when a wish found nothing
/// (BUT-2523). Reasons come from the generator's own signals; nothing here
/// decides or reads anything.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/services/menu/menu_pick_reasons.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

String menuPickReasonLabel(BuildContext context, MenuPickReason reason) {
  final l10n = context.l10n;
  return switch (reason) {
    MenuPickReason.notRecent => l10n.menuWhyReasonNotRecent,
    MenuPickReason.seasonal => l10n.menuWhyReasonSeasonal,
    MenuPickReason.familyFavourite => l10n.menuWhyReasonFamilyFavourite,
    MenuPickReason.pantry => l10n.menuWhyReasonPantry,
  };
}

class MenuWhyToggle extends StatefulWidget {
  const MenuWhyToggle({super.key, required this.reasons});

  final List<MenuPickReason> reasons;

  @override
  State<MenuWhyToggle> createState() => _MenuWhyToggleState();
}

class _MenuWhyToggleState extends State<MenuWhyToggle> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: context.l10n.a11yMenuWhyToggle,
          button: true,
          expanded: _open,
          excludeSemantics: true,
          child: InkWell(
            onTap: () => setState(() => _open = !_open),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppDimensions.minTouchTarget,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ButleryIcon(
                    _open ? ButleryIcons.chevronUp : ButleryIcons.info,
                    size: AppDimensions.iconSizeS,
                    color: cs.onSurface,
                  ),
                  const SizedBox(width: AppDimensions.space4),
                  Text(
                    context.l10n.menuWhyAction,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: cs.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_open)
          widget.reasons.isEmpty
              ? Text(
                  context.l10n.menuWhyChance,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                )
              : Wrap(
                  spacing: AppDimensions.space8,
                  runSpacing: AppDimensions.space4,
                  children: [
                    for (final r in widget.reasons)
                      _ReasonChip(label: menuPickReasonLabel(context, r)),
                  ],
                ),
      ],
    );
  }
}

class MenuUnmetWishNote extends StatelessWidget {
  const MenuUnmetWishNote({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: AppDimensions.space8),
      padding: const EdgeInsets.all(AppDimensions.space12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
      ),
      child: Row(
        children: [
          ButleryIcon(
            ButleryIcons.info,
            size: AppDimensions.iconSizeM,
            color: cs.onSurface,
          ),
          const SizedBox(width: AppDimensions.space12),
          Expanded(
            child: Text(
              context.l10n.menuUnmetWishNotice,
              style: AppTextStyles.bodySmall.copyWith(color: cs.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReasonChip extends StatelessWidget {
  const _ReasonChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space12,
          vertical: AppDimensions.space4,
        ),
        child: Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(color: cs.onSurface),
        ),
      ),
    );
  }
}
