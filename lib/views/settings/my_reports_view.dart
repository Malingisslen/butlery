import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/appeal_mail.dart';
import 'package:butlery/core/utils/contextual_time_formatter.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/social/content_report.dart';
import 'package:butlery/models/social/content_type.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/settings/my_reports_viewmodel.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/scaffolds/base_scaffold.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/social/report_outcome_labels.dart';
import 'package:butlery/widgets/social/report_reason_labels.dart';

/// "Mina rapporter" — surfaces user-submitted moderation reports + their
/// lifecycle status. Required by Google Play UGC appeal policy.
class MyReportsView extends StatefulWidget {
  const MyReportsView({super.key});

  @override
  State<MyReportsView> createState() => _MyReportsViewState();
}

class _MyReportsViewState extends State<MyReportsView> {
  late final MyReportsViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = ServiceLocator.get<MyReportsViewModel>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _vm.load();
    });
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<MyReportsViewModel>.value(value: _vm),
      ],
      child: const _MyReportsContent(),
    );
  }
}

class _MyReportsContent extends StatelessWidget {
  const _MyReportsContent();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final vm = context.watch<MyReportsViewModel>();
    return BaseScaffold(
      title: l10n.myReportsTitle,
      // Reached from Kontosäkerhet only (account_security_view).
      backTo: l10n.accountSecurityTitle,
      body: _body(context, vm),
    );
  }

  Widget _body(BuildContext context, MyReportsViewModel vm) {
    if (vm.isLoading && !vm.hasReports) {
      return StateWidget.loading(message: context.l10n.loadingMyReports);
    }
    if (vm.hasError) {
      return StateWidget.error(
        message: context.l10n.myReportsLoadFailed,
        actionLabel: context.l10n.myReportsRetry,
        onAction: vm.refresh,
      );
    }
    if (!vm.hasReports) {
      return StateWidget.empty(
        title: context.l10n.myReportsEmpty,
        icon: ButleryIcons.flag,
      );
    }
    return RefreshIndicator(
      onRefresh: vm.refresh,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(
          vertical: AppDimensions.spacingSm,
        ),
        itemCount: vm.reports.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) => _ReportTile(
          report: vm.reports[i],
          decision: vm.decisionFor(vm.reports[i]),
        ),
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({required this.report, required this.decision});

  final ContentReport report;
  final ModeratorDecision? decision;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final localeName = Localizations.localeOf(context).toLanguageTag();
    final reason = reportReasonDisplay(l10n, report.reason);
    final date = ContextualTimeFormatter.dateTime(
      report.createdAt.toLocal(),
      localeName: localeName,
    );
    final outcome = reportOutcomeText(l10n, report.status, decision);

    return ListTile(
      leading: ButleryIcon(_iconForType(report.contentType)),
      title: Text(
        reason,
        style: AppTextStyles.titleSmall,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(date, style: AppTextStyles.bodySmall),
          Text(outcome, style: AppTextStyles.bodySmall),
          if (report.status == ReportStatus.closed)
            TextButton(
              onPressed: () => launchAppealMail(
                context,
                buildAppealMailUri(
                  subject: l10n.myReportsAppealSubject,
                  body: buildReportAppealBody(
                    l10n,
                    reportId: report.id,
                    date: date,
                    reason: reason,
                    outcome: outcome,
                  ),
                ),
              ),
              child: Text(l10n.myReportsAppealButton),
            ),
        ],
      ),
      trailing: _StatusBadge(status: report.status, l10n: l10n),
    );
  }

  IconData _iconForType(ContentType type) {
    switch (type) {
      case ContentType.recipe:
        return ButleryIcons.utensils;
      case ContentType.comment:
        return ButleryIcons.messageSquare;
      case ContentType.message:
        return ButleryIcons.messageSquare;
      case ContentType.profile:
        return ButleryIcons.user;
      case ContentType.cookSnap:
        return ButleryIcons.camera;
      case ContentType.group:
        return ButleryIcons.users;
      case ContentType.menuDish:
        return ButleryIcons.utensils;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.l10n});

  final ReportStatus status;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (label, color, glyph) = _resolve(cs);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space4,
        vertical: AppDimensions.spacingXs,
      ),
      color: color,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ButleryIcon(glyph, size: 14, color: cs.onPrimary),
          const SizedBox(width: AppDimensions.spacingXs),
          Text(
            label,
            style: AppTextStyles.badge.copyWith(color: cs.onPrimary),
          ),
        ],
      ),
    );
  }

  (String, Color, IconData) _resolve(ColorScheme cs) {
    switch (status) {
      case ReportStatus.newReport:
        return (l10n.myReportsStatusPending, cs.primary, ButleryIcons.inbox);
      case ReportStatus.inReview:
      case ReportStatus.actioned:
        return (l10n.myReportsStatusReviewed, cs.tertiary, ButleryIcons.search);
      case ReportStatus.closed:
        return (
          l10n.myReportsStatusClosed,
          cs.outline,
          ButleryIcons.circleCheck,
        );
    }
  }
}
