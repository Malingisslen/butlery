// lib/views/more/help_area_view.dart
//
// Hjälp & om under Mer: help, rules and reports in one place, and what
// version this is (Mer, omtänkt, 2026-10-10). Took over Om Butlery, and
// '/settings/about' opens this page.
library;

import 'package:flutter/material.dart';

import 'package:butlery/widgets/common/badges/unified_badge.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/appeal_mail.dart';
import 'package:butlery/core/utils/version_info.dart';
import 'package:butlery/services/moderation/report_service.dart';
import 'package:butlery/services/whats_new/whats_new_catalog.dart';
import 'package:butlery/services/whats_new/whats_new_service.dart';
import 'package:butlery/views/more/more_area_scaffold.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/widgets/whats_new/whats_new_sheet.dart';

class HelpAreaView extends StatefulWidget {
  const HelpAreaView({
    super.key,
    this.catalog = whatsNewReleases,
    this.currentVersion,
  });

  /// Overridable so tests can supply entries; production uses the real catalog.
  final List<WhatsNewRelease> catalog;
  final String? currentVersion;

  @override
  State<HelpAreaView> createState() => _HelpAreaViewState();
}

class _HelpAreaViewState extends State<HelpAreaView> {
  late final Stream<bool> _isAdmin;

  @override
  void initState() {
    super.initState();
    _isAdmin = ServiceLocator.get<ReportService>().watchIsAdmin();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final version = VersionInfo.appVersion;
    final latest = WhatsNewService.latestReleaseUpTo(
      widget.catalog,
      widget.currentVersion ?? version,
    );
    void open(String route) => Navigator.pushNamed(context, route);
    return MoreAreaScaffold(
      title: l10n.settingsHelpTitle,
      sections: [
        ButleryListSection(
          title: l10n.settingsHelpSection,
          rows: [
            ButleryListRow(
              label: l10n.profileFaq,
              onTap: () => open(Routes.faq),
            ),
          ],
        ),
        // Granska rapporter is there only for admins (admins/{uid} exists).
        StreamBuilder<bool>(
          stream: _isAdmin,
          builder: (context, snap) => ButleryListSection(
            title: l10n.settingsRulesSection,
            rows: [
              ButleryListRow(
                label: l10n.legalTermsOfService,
                onTap: () => open(Routes.termsOfService),
              ),
              ButleryListRow(
                label: l10n.legalCommunityGuidelines,
                onTap: () => open(Routes.communityGuidelines),
              ),
              ButleryListRow(
                label: l10n.myReportsTitle,
                subtitle: l10n.settingsMyReportsSubtitle,
                onTap: () => open(Routes.myReports),
              ),
              ButleryListRow(
                label: l10n.myContentDecisionsTitle,
                subtitle: l10n.settingsMyContentDecisionsSubtitle,
                onTap: () => open(Routes.myContentDecisions),
              ),
              ButleryListRow(
                label: l10n.appealEmailLinkLabel,
                onTap: () => launchAppealMail(
                  context,
                  buildAppealMailUri(
                    subject: l10n.appealEmailSubject,
                    body: l10n.appealEmailBodyTemplate,
                  ),
                ),
              ),
              if (snap.data == true)
                ButleryListRow(
                  label: l10n.moderatorReviewTitle,
                  trailing: UnifiedBadge.status(
                    label: context.l10n.settingsAdminOnly,
                  ),
                  onTap: () => open(Routes.moderatorReview),
                ),
            ],
          ),
        ),
        ButleryListSection(
          title: l10n.settingsAboutTitle,
          rows: [
            // VersionInfo keeps 'unknown' when the platform call fails; a
            // version row that says so helps nobody.
            if (version != 'unknown')
              ButleryListRow.info(
                label: l10n.settingsVersionLabel,
                value: version,
              ),
            if (latest != null)
              ButleryListRow(
                label: l10n.whatsNewAboutTitle,
                subtitle: l10n.settingsAboutVersion(latest.version),
                onTap: () => showWhatsNewSheet(context, [latest]),
              ),
            ButleryListRow(
              label: l10n.settingsLicensesTitle,
              subtitle: l10n.settingsLicensesSubtitle,
              onTap: () => open(Routes.settingsLicenses),
            ),
          ],
        ),
      ],
    );
  }
}
