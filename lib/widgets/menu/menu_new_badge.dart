// lib/widgets/menu/menu_new_badge.dart
//
// BUT-1241: "NY" badge marking weekly-menu entries placed by the latest
// generation/placement session. One shared widget so the calendar grid and
// the manual placement grid can't drift visually.

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_text_styles.dart';

class MenuNewBadge extends StatelessWidget {
  const MenuNewBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      color: cs.secondary,
      child: Text(
        context.l10n.weeklyMenuNewBadge,
        style: AppTextStyles.labelSmall.copyWith(
          // 7px: fits inside the 8-9px slot-label rows of the dense grids.
          fontSize: 7,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: cs.onSecondary,
        ),
      ),
    );
  }
}
