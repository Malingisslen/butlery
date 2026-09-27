// lib/widgets/menu/menu_new_badge.dart
//
// BUT-1241: "NY" badge marking weekly-menu entries placed by the latest
// generation/placement session. One shared widget so the calendar grid and
// the manual placement grid can't drift visually.

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

class MenuNewBadge extends StatelessWidget {
  const MenuNewBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: AppDimensions.badgePadding,
      color: cs.secondary,
      child: Text(
        context.l10n.weeklyMenuNewBadge,
        // A system label: overline, 10,5/700, the floor for a calendar
        // cell (tokens.json typography.rules, B-41).
        style: AppTextStyles.overline.copyWith(color: cs.onSecondary),
      ),
    );
  }
}
