import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/social/content_report.dart';
import 'package:butlery/models/social/decision_detail_args.dart';
import 'package:butlery/models/social/moderation_outcome.dart';
import 'package:butlery/services/moderation/report_outcomes_service.dart';
import 'package:butlery/services/moderation/report_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/settings/decision_detail_viewmodel.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/layout/butlery_page.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/common/butlery_link.dart';
import 'package:butlery/widgets/common/layout/tinted_note.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/widgets/social/decision_labels.dart';
import 'package:butlery/widgets/social/decision_row.dart';
import 'package:butlery/widgets/social/report_outcome_labels.dart';

/// One decision: what it was about, what was decided and why, and the appeal
/// (offer, own text, or the final answer). Reporter and owner share this view.
class DecisionDetailView extends StatefulWidget {
  const DecisionDetailView({required this.args, super.key});

  final DecisionDetailArgs args;

  @override
  State<DecisionDetailView> createState() => _DecisionDetailViewState();
}

class _DecisionDetailViewState extends State<DecisionDetailView> {
  late final DecisionDetailViewModel _vm;

  @override
  void initState() {
    super.initState();
    final args = widget.args;
    _vm = DecisionDetailViewModel(
      role: args.role,
      reportId: args.reportId,
      outcome: args.outcome,
      report: args.report,
      reportService: ServiceLocator.get<ReportService>(),
      outcomesService: ServiceLocator.get<ReportOutcomesService>(),
    );
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
    return ChangeNotifierProvider<DecisionDetailViewModel>.value(
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
    final vm = context.watch<DecisionDetailViewModel>();
    final owner = vm.role == AppealRole.owner;
    return ButleryPage.undersida(
      title: owner
          ? l10n.decisionDetailOwnerTitle
          : l10n.decisionDetailReporterTitle,
      body: _body(context, vm),
    );
  }

  Widget _body(BuildContext context, DecisionDetailViewModel vm) {
    final l10n = context.l10n;
    if (vm.isLoading && !vm.isReady) {
      return StateWidget.loading(message: l10n.loadingMyReports);
    }
    if (vm.hasError) {
      return StateWidget.error(
        message: l10n.decisionDetailLoadFailed,
        actionLabel: l10n.myReportsRetry,
        onAction: vm.reload,
      );
    }
    if (vm.notFound || !vm.isReady) {
      return StateWidget.empty(
        title: l10n.decisionDetailNotFound,
        icon: ButleryIcons.flag,
      );
    }
    return ListView(
      padding: EdgeInsets.symmetric(
        horizontal: ButleryTopBar.sideMargin(context),
        vertical: AppDimensions.space16,
      ),
      children: [
        _SubjectBlock(vm: vm),
        const SizedBox(height: AppDimensions.space16),
        _DecisionBlock(vm: vm),
        if (vm.outcome != null) ...[
          const SizedBox(height: AppDimensions.space16),
          _AppealBlock(vm: vm),
        ],
      ],
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.children, this.emphasis = false});

  final List<Widget> children;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppDimensions.space12),
      decoration: BoxDecoration(
        color: emphasis ? cs.secondaryContainer : null,
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: AppDimensions.space4),
            children[i],
          ],
        ],
      ),
    );
  }
}

Widget _label(BuildContext context, String text) => Text(
  text,
  style: AppTextStyles.overline.copyWith(
    color: Theme.of(context).colorScheme.onSurfaceVariant,
  ),
);

class _SubjectBlock extends StatelessWidget {
  const _SubjectBlock({required this.vm});

  final DecisionDetailViewModel vm;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final owner = vm.role == AppealRole.owner;
    final type = vm.contentType;
    final reason = vm.reason;
    final reportedAt = vm.reportedAt;
    final subject = type == null
        ? null
        : decisionSubject(l10n, type, owner: owner);
    final reasonText = reason == null ? null : reasonInSentence(l10n, reason);
    final big = owner
        ? subject
        : subject == null || reasonText == null
        ? subject
        : l10n.decisionReporterLine(subject, reasonText);
    final small = owner && reasonText != null
        ? l10n.decisionOwnerReportedFor(reasonText)
        : reportedAt == null
        ? null
        : l10n.decisionReportedOnLabel(formatDecisionDate(l10n, reportedAt));
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(
          context,
          owner ? l10n.decisionConcernsLabel : l10n.decisionYouReportedLabel,
        ),
        const SizedBox(height: AppDimensions.space8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: ButleryIcon(
                DecisionRow.glyphFor(type),
                size: AppDimensions.iconSizeM,
              ),
            ),
            const SizedBox(width: AppDimensions.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (big != null) Text(big, style: AppTextStyles.bodyBold),
                  if (small != null)
                    Text(
                      small,
                      style: AppTextStyles.captionBase.copyWith(color: muted),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DecisionBlock extends StatelessWidget {
  const _DecisionBlock({required this.vm});

  final DecisionDetailViewModel vm;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final outcome = vm.outcome;
    final report = vm.report;
    if (outcome == null) {
      return TintedNote.labelled(
        label: l10n.decisionOutcomeLabel,
        text: reportOutcomeText(
          l10n,
          report?.status ?? ReportStatus.closed,
          report?.moderatorAction,
        ),
      );
    }
    final decidedAt = outcome.decidedAt;
    final motivation = outcome.motivation;
    return TintedNote.labelled(
      label: l10n.decisionOutcomeLabel,
      text: [
        if (decidedAt != null) formatDecisionDate(l10n, decidedAt),
        decisionHeadline(l10n, outcome.decision),
        if (motivation != null) motivationText(l10n, motivation),
      ].join('. '),
    );
  }
}

class _AppealBlock extends StatelessWidget {
  const _AppealBlock({required this.vm});

  final DecisionDetailViewModel vm;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final outcome = vm.outcome!;
    final appeal = outcome.appeal;
    if (appeal == null) return _offer(context, l10n, outcome);

    final submitted = appeal.submittedAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Block(
          children: [
            if (submitted != null)
              _label(
                context,
                l10n.appealYourLabel(formatDecisionDate(l10n, submitted)),
              ),
            Text(appeal.text, style: AppTextStyles.bodyMedium),
            if (appeal.status == AppealStatus.open)
              _note(context, ButleryIcons.search, l10n.appealUnderReview),
          ],
        ),
        if (appeal.status != AppealStatus.open) ...[
          const SizedBox(height: AppDimensions.space16),
          _answer(context, l10n, outcome, appeal),
        ],
      ],
    );
  }

  Widget _offer(
    BuildContext context,
    AppLocalizations l10n,
    ModerationOutcome outcome,
  ) {
    if (!outcome.canAppeal(DateTime.now())) {
      return _note(context, ButleryIcons.info, l10n.appealWindowClosedInfo);
    }
    final deadline = outcome.appealDeadline;
    final linkStyle = AppTextStyles.bodyMedium.copyWith(
      color: ModeColors.of(Theme.of(context).brightness).textLink,
      decoration: TextDecoration.underline,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: AppDimensions.space32),
        Text(l10n.appealPromptTitle, style: AppTextStyles.titleBold),
        if (deadline != null) ...[
          const SizedBox(height: AppDimensions.space4),
          Text(
            l10n.appealPromptBody(formatDecisionDate(l10n, deadline)),
            style: AppTextStyles.bodyMedium,
          ),
        ],
        ButleryLink(
          semanticLabel: l10n.decisionAppealLink,
          onTap: () async {
            final sent = await Navigator.pushNamed(
              context,
              Routes.appealForm,
              arguments: AppealFormArgs(role: vm.role, outcome: outcome),
            );
            if (sent == true) await vm.reload();
          },
          child: Text(l10n.decisionAppealLink, style: linkStyle),
        ),
      ],
    );
  }

  Widget _answer(
    BuildContext context,
    AppLocalizations l10n,
    ModerationOutcome outcome,
    ModerationAppeal appeal,
  ) {
    final upheld = appeal.status == AppealStatus.upheld;
    final answered = appeal.answeredAt;
    final restoreNote =
        !upheld &&
        vm.role == AppealRole.owner &&
        outcome.decision == ModeratorDecision.contentRemoved;
    return _Block(
      emphasis: true,
      children: [
        if (answered != null)
          _label(
            context,
            l10n.appealAnswerLabel(formatDecisionDate(l10n, answered)),
          ),
        Text(
          upheld
              ? l10n.appealAnswerUpheldHeadline
              : l10n.appealAnswerReversedHeadline,
          style: AppTextStyles.titleSmall,
        ),
        Text(
          upheld ? l10n.appealAnswerUpheldBody : l10n.appealAnswerReversedBody,
          style: AppTextStyles.bodyMedium,
        ),
        if (restoreNote)
          Text(
            l10n.appealAnswerReversedOwnerRemoved,
            style: AppTextStyles.bodyMedium,
          ),
        _note(context, ButleryIcons.info, l10n.appealAnswerFinal),
      ],
    );
  }

  Widget _note(BuildContext context, IconData glyph, String text) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: AppDimensions.space4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ButleryIcon(glyph, size: AppDimensions.iconSizeS, color: muted),
          const SizedBox(width: AppDimensions.space4),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.captionBase.copyWith(color: muted),
            ),
          ),
        ],
      ),
    );
  }
}
