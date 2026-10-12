import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/butlery_control_focus.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

/// The admin panel's one dark bar: the name, the tabs and who is signed in
/// (Skarmar v12 del 3 #29). The tabs are a [TabBar] of [ButleryTab]s, so they
/// carry the canonical focus ring and scroll sideways when the window is narrow.
class AdminTopBar extends StatelessWidget {
  const AdminTopBar({
    required this.controller,
    required this.labels,
    required this.onSignOut,
    this.email,
    super.key,
  });

  final TabController controller;
  final List<String> labels;
  final String? email;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Material(
      color: cs.primary,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.space16,
            ),
            child: Text(
              l10n.adminBarTitle,
              style: AppTextStyles.headlineSmall.copyWith(color: cs.onPrimary),
            ),
          ),
          Expanded(
            child: Theme(
              data: ButleryControlFocus.themeWithoutFocusTint(
                Theme.of(context),
              ),
              child: TabBar(
                controller: controller,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                dividerColor: Colors.transparent,
                overlayColor: ButleryControlFocus.withoutFocusTint(null),
                labelColor: cs.onPrimary,
                unselectedLabelColor: AppModeColors.textDisabledOnInk(),
                indicatorColor: context.modeColors.accentOnInk,
                indicatorWeight: AppDimensions.borderWidthThick,
                tabs: [for (final label in labels) ButleryTab(text: label)],
              ),
            ),
          ),
          if (email != null)
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.space8,
                ),
                child: Text(
                  l10n.adminBarSignedIn(email!),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppModeColors.textDisabledOnInk(),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          IconButton(
            icon: ButleryIcon(ButleryIcons.logOut, color: cs.onPrimary),
            tooltip: l10n.adminSignOut,
            onPressed: onSignOut,
          ),
        ],
      ),
    );
  }
}
