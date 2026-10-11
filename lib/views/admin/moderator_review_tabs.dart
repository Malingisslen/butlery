import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/viewmodels/admin/moderator_appeals_viewmodel.dart';
import 'package:butlery/viewmodels/admin/moderator_review_viewmodel.dart';
import 'package:butlery/views/admin/moderator_appeals_tab.dart';

/// "Rapporter" and "Överklaganden" under one top bar. Only the open tab is
/// built, so the other list does no work.
class ModeratorReviewTabs extends StatelessWidget {
  const ModeratorReviewTabs({required this.reports, super.key});

  final Widget reports;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final reportCount = context.select<ModeratorReviewViewModel, int>(
      (m) => m.reports.length,
    );
    final appealCount = context.select<ModeratorAppealsViewModel, int>(
      (m) => m.appeals.length,
    );
    return DefaultTabController(
      length: 2,
      child: Builder(
        builder: (context) {
          final controller = DefaultTabController.of(context);
          return Column(
            children: [
              TabBar(
                tabs: [
                  Tab(text: l10n.moderatorTabReports(reportCount)),
                  Tab(text: l10n.moderatorTabAppeals(appealCount)),
                ],
              ),
              Expanded(
                child: ListenableBuilder(
                  listenable: controller,
                  builder: (_, __) => controller.index == 0
                      ? reports
                      : const ModeratorAppealsTab(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
