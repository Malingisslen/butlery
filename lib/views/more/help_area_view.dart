// lib/views/more/help_area_view.dart
//
// Hjälp & om under Mer: help, rules and reports in one place, and what
// version this is (Mer, omtänkt, 2026-10-10). Took over Om Butlery, and
// '/settings/about' opens this page.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/appeal_mail.dart';
import 'package:butlery/core/utils/version_info.dart';
import 'package:butlery/services/moderation/report_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/views/more/more_area_scaffold.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';

class HelpAreaView extends StatefulWidget {
  const HelpAreaView({super.key});

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
                  trailing: const _AdminPill(),
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

class _AdminPill extends StatelessWidget {
  const _AdminPill();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingSm,
          vertical: AppDimensions.badgePaddingY,
        ),
        child: Text(
          context.l10n.settingsAdminOnly.toUpperCase(),
          style: AppTextStyles.overline.copyWith(color: cs.onSurfaceVariant),
        ),
      ),
    );
  }
}
