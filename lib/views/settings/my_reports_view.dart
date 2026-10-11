import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/social/content_report.dart';
import 'package:butlery/models/social/decision_detail_args.dart';
import 'package:butlery/models/social/moderation_outcome.dart';
import 'package:butlery/viewmodels/settings/my_reports_viewmodel.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/widgets/social/decision_labels.dart';
import 'package:butlery/widgets/social/decision_list_scaffold.dart';
import 'package:butlery/widgets/social/decision_status_badge.dart';
import 'package:butlery/widgets/social/report_outcome_labels.dart';
import 'package:butlery/widgets/social/report_reason_labels.dart';

/// "Mina rapporter" — the user's submitted moderation reports and their
/// lifecycle status. A row opens the decision, where a closed report can be
/// appealed. Required by Google Play UGC appeal policy.
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
    return DecisionListScaffold(
      title: l10n.myReportsTitle,
      isLoading: vm.isLoading,
      hasError: vm.hasError,
      loadingMessage: l10n.loadingMyReports,
      errorMessage: l10n.myReportsLoadFailed,
      retryLabel: l10n.myReportsRetry,
      emptyTitle: l10n.myReportsEmpty,
      onRefresh: vm.refresh,
      rows: [
        for (final report in vm.reports) _reportRow(context, vm, report),
      ],
    );
  }

  Widget _reportRow(
    BuildContext context,
    MyReportsViewModel vm,
    ContentReport report,
  ) {
    final l10n = context.l10n;
    final outcome = vm.outcomeFor(report);
    final date = formatDecisionDate(l10n, report.createdAt);
    final text = reportOutcomeText(l10n, report.status, vm.decisionFor(report));
    return ButleryListRow(
      key: ValueKey('report-${report.id}'),
      label: reportReasonDisplay(l10n, report.reason),
      subtitle: '$date\n$text',
      trailing: _badge(context, report, outcome),
      onTap: () async {
        await Navigator.pushNamed(
          context,
          Routes.decisionDetail,
          arguments: DecisionDetailArgs(
            role: AppealRole.reporter,
            reportId: report.id,
            outcome: outcome,
            report: report,
          ),
        );
        if (context.mounted) await vm.refresh();
      },
    );
  }

  Widget _badge(
    BuildContext context,
    ContentReport report,
    ModerationOutcome? outcome,
  ) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    if (outcome?.appeal?.status == AppealStatus.open) {
      return DecisionStatusBadge(
        label: l10n.decisionStatusAppealed,
        glyph: ButleryIcons.search,
        color: cs.tertiary,
      );
    }
    return switch (report.status) {
      ReportStatus.newReport => DecisionStatusBadge(
        label: l10n.myReportsStatusPending,
        glyph: ButleryIcons.inbox,
        color: cs.primary,
      ),
      ReportStatus.inReview || ReportStatus.actioned => DecisionStatusBadge(
        label: l10n.myReportsStatusReviewed,
        glyph: ButleryIcons.search,
        color: cs.tertiary,
      ),
      ReportStatus.closed => DecisionStatusBadge(
        label: l10n.myReportsStatusClosed,
        glyph: ButleryIcons.circleCheck,
        color: cs.outline,
      ),
    };
  }
}
