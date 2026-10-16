import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/social/decision_detail_args.dart';
import 'package:butlery/models/social/moderation_outcome.dart';
import 'package:butlery/viewmodels/settings/my_content_decisions_viewmodel.dart';
import 'package:butlery/widgets/common/badges/unified_badge.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/social/decision_labels.dart';
import 'package:butlery/widgets/social/decision_list_scaffold.dart';
import 'package:butlery/widgets/social/decision_row.dart';
import 'package:butlery/widgets/social/report_reason_labels.dart';

/// "Beslut om mitt innehåll" — decisions about the user's own content. The
/// server never names the reporter, and the content itself is already gone
/// or hidden, so a row says what kind of content it was and why it was
/// reported.
class MyContentDecisionsView extends StatefulWidget {
  const MyContentDecisionsView({super.key});

  @override
  State<MyContentDecisionsView> createState() => _MyContentDecisionsViewState();
}

class _MyContentDecisionsViewState extends State<MyContentDecisionsView> {
  late final MyContentDecisionsViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = ServiceLocator.get<MyContentDecisionsViewModel>();
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
    return ChangeNotifierProvider<MyContentDecisionsViewModel>.value(
      value: _vm,
      child: const _Content(),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final vm = context.watch<MyContentDecisionsViewModel>();
    return DecisionListScaffold(
      title: l10n.myContentDecisionsTitle,
      intro: l10n.myContentDecisionsIntro,
      // Reached from Hjälp & om only (help_area_view).
      backTo: l10n.settingsHelpTitle,
      isLoading: vm.isLoading,
      hasError: vm.hasError,
      loadingMessage: l10n.loadingMyContentDecisions,
      errorMessage: l10n.myContentDecisionsLoadFailed,
      retryLabel: l10n.myReportsRetry,
      emptyTitle: l10n.myContentDecisionsEmpty,
      onRefresh: vm.refresh,
      rows: [
        for (final decision in vm.decisions) _row(context, vm, decision),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    MyContentDecisionsViewModel vm,
    ModerationOutcome decision,
  ) {
    final l10n = context.l10n;
    final type = decision.contentType;
    final reason = decision.reason;
    final decidedAt = decision.decidedAt;
    final lines = [
      if (reason != null) reportReasonDisplay(l10n, reason),
      if (decidedAt != null) formatDecisionDate(l10n, decidedAt),
    ];
    final appealed = decision.appeal;
    final open = appealed?.status == AppealStatus.open;
    return DecisionRow(
      key: ValueKey('decision-${decision.reportId}'),
      contentType: type,
      title: type == null
          ? l10n.decisionDetailOwnerTitle
          : decisionSubject(l10n, type, owner: true),
      subtitle: lines.isEmpty ? null : lines.join(' · '),
      outcome: [
        l10n.decisionOutcomeSentence(decisionHeadline(l10n, decision.decision)),
        if (open) l10n.appealUnderReview,
      ].join(' '),
      status: appealed == null
          ? UnifiedBadge.status(
              label: l10n.decisionStatusDecided,
              icon: ButleryIcons.circleCheck,
              tone: BadgeTone.neutral,
            )
          : open
          ? UnifiedBadge.status(
              label: l10n.decisionStatusAppealed,
              icon: ButleryIcons.search,
              tone: BadgeTone.warning,
            )
          : UnifiedBadge.status(
              label: l10n.myReportsStatusClosed,
              icon: ButleryIcons.circleCheck,
              tone: BadgeTone.neutral,
            ),
      onAppeal: appealed == null && decision.canAppeal(DateTime.now())
          ? () async {
              final sent = await Navigator.pushNamed(
                context,
                Routes.appealForm,
                arguments: AppealFormArgs(
                  role: AppealRole.owner,
                  outcome: decision,
                ),
              );
              if (sent == true && context.mounted) await vm.refresh();
            }
          : null,
      onTap: () async {
        await Navigator.pushNamed(
          context,
          Routes.decisionDetail,
          arguments: DecisionDetailArgs(
            role: AppealRole.owner,
            reportId: decision.reportId,
            outcome: decision,
          ),
        );
        if (context.mounted) await vm.refresh();
      },
    );
  }
}
