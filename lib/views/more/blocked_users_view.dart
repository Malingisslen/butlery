// lib/views/more/blocked_users_view.dart
//
// Blockerade personer, opened from Integritet & data (Mer, omtänkt,
// 2026-10-10). It used to sit as a collapsed card at the foot of Samtycken.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/widgets/common/layout/layout_scaffolds.dart';
import 'package:butlery/widgets/common/settings/blocked_users_section.dart';

class BlockedUsersView extends StatelessWidget {
  const BlockedUsersView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final margin = ButleryTopBar.sideMargin(context);
    return Scaffold(
      appBar: ButleryTopBar.undersida(
        title: l10n.settingsBlockedPeople,
        backTo: l10n.settingsPrivacyAreaTitle,
      ),
      bottomNavigationBar: LayoutScaffolds.detailBottomNav(context),
      body: SafeArea(
        child: Align(
          alignment: AlignmentDirectional.topStart,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: EdgeInsetsDirectional.only(
                start: margin,
                end: margin,
                bottom: AppDimensions.spacingLg,
              ),
              children: const [BlockedUsersSection()],
            ),
          ),
        ),
      ),
    );
  }
}
