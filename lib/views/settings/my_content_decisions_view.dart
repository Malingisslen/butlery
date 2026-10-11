import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/social/decision_detail_args.dart';
import 'package:butlery/models/social/moderation_outcome.dart';
import 'package:butlery/viewmodels/settings/my_content_decisions_viewmodel.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/widgets/social/decision_labels.dart';
import 'package:butlery/widgets/social/decision_list_scaffold.dart';
import 'package:butlery/widgets/social/decision_status_badge.dart';

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
    final cs = Theme.of(context).colorScheme;
    final type = decision.contentType;
    final reason = decision.reason;
    final decidedAt = decision.decidedAt;
    final lines = [
      if (reason != null)
        l10n.decisionOwnerReportedFor(reasonInSentence(l10n, reason)),
      if (decidedAt != null) formatDecisionDate(l10n, decidedAt),
    ];
    final appealed = decision.appeal;
    return ButleryListRow(
      key: ValueKey('decision-${decision.reportId}'),
      label: type == null
          ? l10n.decisionDetailOwnerTitle
          : decisionSubject(l10n, type, owner: true),
      subtitle: lines.isEmpty ? null : lines.join('\n'),
      trailing: appealed == null
          ? DecisionStatusBadge(
              label: l10n.decisionStatusDecided,
              glyph: ButleryIcons.circleCheck,
              color: cs.outline,
            )
          : appealed.status == AppealStatus.open
          ? DecisionStatusBadge(
              label: l10n.decisionStatusAppealed,
              glyph: ButleryIcons.search,
              color: cs.tertiary,
            )
          : DecisionStatusBadge(
              label: l10n.myReportsStatusClosed,
              glyph: ButleryIcons.circleCheck,
              color: cs.outline,
            ),
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
