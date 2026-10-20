import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/social/content_report.dart';
import 'package:butlery/models/social/moderation_motivation.dart';
import 'package:butlery/services/moderation/moderation_appeals_service.dart';
import 'package:butlery/models/social/content_type.dart';
import 'package:butlery/views/admin/moderator_labels.dart';
import 'package:butlery/viewmodels/admin/moderator_appeals_viewmodel.dart';
import 'package:butlery/viewmodels/admin/moderator_closed_viewmodel.dart';
import 'package:butlery/views/admin/moderator_close_sheet.dart';
import 'package:butlery/views/admin/moderator_evidence_section.dart';
import 'package:butlery/views/admin/moderator_reopened_section.dart';
import 'package:butlery/views/admin/moderator_review_tabs.dart';
import 'package:butlery/services/moderation/report_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/admin/moderator_review_viewmodel.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/indicators/admin_badge.dart';
import 'package:butlery/widgets/common/indicators/status_pill.dart';
import 'package:butlery/widgets/common/dialogs/confirmation_dialogs.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/common/cards/styled_card.dart';
import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/layout/butlery_page.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/layout/word_fit.dart';
import 'package:butlery/widgets/common/buttons/button_row.dart';
import 'package:provider/provider.dart';

/// Admin-only screen listing open moderation reports and exposing the
/// state-machine actions (advance, close, delete target content).
///
/// Route guarded by a StreamBuilder on `admins/{uid}` existence. Non-admins
/// see a "not authorised" scaffold — the underlying Firestore query would
/// otherwise fail with permission-denied.
class ModeratorReviewView extends StatefulWidget {
  const ModeratorReviewView({super.key});

  @override
  State<ModeratorReviewView> createState() => _ModeratorReviewViewState();
}

class _ModeratorReviewViewState extends State<ModeratorReviewView> {
  late final ModeratorReviewViewModel _vm;
  late final ModeratorAppealsViewModel _appealsVm;
  late final ModeratorClosedViewModel _closedVm;
  late final ReportService _reportService;
  bool _appealsRequested = false;

  @override
  void initState() {
    super.initState();
    _vm = ModeratorReviewViewModel();
    _appealsVm = ModeratorAppealsViewModel(
      service: ServiceLocator.get<ModerationAppealsService>(),
    );
    _closedVm = ModeratorClosedViewModel(
      service: ServiceLocator.get<ModerationAppealsService>(),
    );
    _reportService = ServiceLocator.get<ReportService>();
  }

  @override
  void dispose() {
    _vm.dispose();
    _appealsVm.dispose();
    _closedVm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ButleryPage.undersida(
      title: context.l10n.moderatorReviewTitle,
      width: PageWidth.wide,
      body: StreamBuilder<bool>(
        stream: _reportService.watchIsAdmin(),
        builder: (context, snapshot) {
          final isAdmin = snapshot.data ?? false;
          if (snapshot.connectionState == ConnectionState.waiting) {
            return StateWidget.loading(
              message: context.l10n.loadingAdminAccess,
            );
          }
          if (!isAdmin) {
            return _NotAuthorized();
          }
          // The appeals callable is admin-only, so it is asked only now.
          if (!_appealsRequested) {
            _appealsRequested = true;
            _appealsVm.load();
          }
          return MultiProvider(
            providers: [
              ChangeNotifierProvider<ModeratorReviewViewModel>.value(
                value: _vm..startListening(),
              ),
              ChangeNotifierProvider<ModeratorAppealsViewModel>.value(
                value: _appealsVm,
              ),
              ChangeNotifierProvider<ModeratorClosedViewModel>.value(
                value: _closedVm,
              ),
            ],
            child: const ModeratorReviewTabs(reports: _ReportsList()),
          );
        },
      ),
    );
  }
}

class _NotAuthorized extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppDimensions.layoutMarginOf(context),
          vertical: AppDimensions.space16,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ButleryIcon(
              ButleryIcons.lock,
              size: AppDimensions.iconSizeXXXl,
              color: cs.outline,
            ),
            const SizedBox(height: AppDimensions.space16),
            Text(
              context.l10n.moderatorNotAuthorized,
              style: AppTextStyles.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportsList extends StatelessWidget {
  const _ReportsList();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ModeratorReviewViewModel>();
    if (vm.isLoading && vm.reports.isEmpty) {
      return StateWidget.loading(message: context.l10n.loadingReports);
    }
    if (vm.error != null) {
      // The standard error state: what failed, then Försök igen
      // (content-style-guide.md:89-94; state_widget.dart default action).
      return StateWidget.error(message: vm.error!, onAction: vm.retry);
    }
    if (vm.reports.isEmpty) {
      return Center(
        child: Text(
          context.l10n.moderatorNoOpenReports,
          style: AppTextStyles.bodyMedium,
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        vertical: AppDimensions.space12,
        horizontal: AppDimensions.space12,
      ),
      itemCount: vm.reports.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppDimensions.space4),
      itemBuilder: (_, i) => _ReportCard(report: vm.reports[i]),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final ContentReport report;
  const _ReportCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final vm = context.read<ModeratorReviewViewModel>();
    final evidence = context
        .select<ModeratorReviewViewModel, ReportEvidenceState>(
          (m) => m.evidenceFor(report),
        );
    final cs = Theme.of(context).colorScheme;

    final l10n = context.l10n;
    return StyledCard(
      padding: const EdgeInsets.all(AppDimensions.space12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_contentTypeLabel(l10n)} · ${report.contentId}',
                  style: AppTextStyles.labelLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (report.isReopened) ...[
                const ReopenedPill(),
                const SizedBox(width: AppDimensions.space4),
              ],
              StatusPill(label: _statusLabel(l10n).toUpperCase()),
            ],
          ),
          const SizedBox(height: AppDimensions.space8),
          WholeWordText(
            moderatorReasonLabel(l10n, report.reason),
            style: AppTextStyles.titleMedium,
          ),
          if (report.isReopened)
            PreviousDecisionLine(decision: vm.decisionFor(report)),
          if (report.description != null && report.description!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppDimensions.space4),
              child: Text(
                report.description!,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: AppDimensions.space4),
          Text(
            report.reporterErased
                ? l10n.moderatorReporterErased
                : '${l10n.moderatorReporterLabel} ${report.reporterId}',
            style: AppTextStyles.labelMedium.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          if (report.contentType == ContentType.menuDish)
            _MenuDishNotes(
              claimedCreatorIsReporter: evidence is ReportEvidenceLoaded
                  ? evidence.evidence.claimedCreatorIsReporter
                  : null,
            ),
          if (evidence is! ReportEvidenceLoading) ...[
            const SizedBox(height: AppDimensions.space8),
            ModeratorEvidenceSection(
              state: evidence,
              reopened: report.isReopened,
            ),
          ],
          // BUT-1609: moderation on a minor's account carries extra care
          // (GDPR/child-safety) — surface it before any action is taken.
          if (vm.isMinorOwner(report)) ...[
            const SizedBox(height: AppDimensions.space8),
            AdminBadge(
              label: l10n.moderatorMinorAccountBadge,
              icon: ButleryIcons.shield,
            ),
          ],
          const SizedBox(height: AppDimensions.space12),
          _actions(context, vm, l10n),
        ],
      ),
    );
  }

  Widget _actions(
    BuildContext context,
    ModeratorReviewViewModel vm,
    AppLocalizations l10n,
  ) {
    if (report.isReopened && report.moderatorAction != null) {
      return ReopenedActions(report: report, vm: vm);
    }
    final open = report.status != ReportStatus.closed;
    final advance = ActionButtons.outlinedButton(
      context,
      label: l10n.moderatorActionAdvance,
      onPressed: () => _advance(context, vm),
      isExpanded: true,
    );
    final takeDown = ActionButtons.dangerButton(
      context,
      label: vm.isReversibleAction(report)
          ? l10n.moderatorActionHide
          : report.contentType == ContentType.menuDish
          ? l10n.moderatorActionRemoveDish
          : l10n.moderatorActionDelete,
      onPressed: () => _confirmTakeDown(context, vm),
      isExpanded: true,
    );
    final close = AppIconButton(
      icon: ButleryIcons.x,
      semanticLabel: l10n.moderatorCloseTooltip,
      onPressed: () => _close(context, vm),
    );
    return Row(
      children: [
        Expanded(
          child: ButtonRow(
            children: [if (open) advance, takeDown],
          ),
        ),
        if (open) close,
      ],
    );
  }

  String _contentTypeLabel(AppLocalizations l10n) =>
      moderatorContentTypeLabel(l10n, report.contentType).toUpperCase();

  String _statusLabel(AppLocalizations l10n) => switch (report.status) {
    ReportStatus.newReport => l10n.moderatorStatusNew,
    ReportStatus.inReview => l10n.moderatorStatusInReview,
    ReportStatus.actioned => l10n.moderatorStatusActioned,
    ReportStatus.closed => l10n.moderatorStatusClosed,
  };

  Future<void> _confirmTakeDown(
    BuildContext context,
    ModeratorReviewViewModel vm,
  ) async {
    final reversible = vm.isReversibleAction(report);
    final l10n = context.l10n;
    final isDish = report.contentType == ContentType.menuDish;
    final title = reversible
        ? l10n.moderatorHideConfirmTitle
        : isDish
        ? l10n.moderatorRemoveDishConfirmTitle
        : l10n.moderatorDeleteConfirmTitle;
    final body = reversible
        ? l10n.moderatorHideConfirmBody
        : isDish
        ? l10n.moderatorRemoveDishConfirmBody
        : l10n.moderatorDeleteConfirmBody;
    final confirm = reversible
        ? l10n.moderatorActionHide
        : isDish
        ? l10n.moderatorActionRemoveDish
        : l10n.moderatorActionDelete;
    final cancel = l10n.commonCancel;

    // Construct the Future synchronously so the analyzer doesn't flag the
    // `context` argument as being used across an async gap.
    final dialogFuture = reversible
        ? ConfirmationDialogs.showConfirmationDialog(
            context,
            title: title,
            message: body,
            confirmText: confirm,
            cancelText: cancel,
          )
        : ConfirmationDialogs.showDestructiveConfirmationDialog(
            context,
            title: title,
            message: body,
            confirmText: confirm,
            cancelText: cancel,
          );
    final ok = await dialogFuture;
    if (ok == true && context.mounted) {
      await _takeDown(context, vm, reversible: reversible);
    }
  }

  // A refused action is a failure snackbar with Försök igen, never the
  // queue's load-error state and never the method name
  // (content-style-guide.md:87-97; Komponentark v1:750, never OK).
  Future<void> _advance(
    BuildContext context,
    ModeratorReviewViewModel vm,
  ) async {
    if (await vm.advance(report) || !context.mounted) return;
    SnackBarUtils.showFailure(
      context,
      what: context.l10n.moderatorAdvanceFailed,
      preserved: context.l10n.moderatorReportUnchanged,
      action: FailureAction.retry(() => _advance(context, vm)),
    );
  }

  Future<void> _close(
    BuildContext context,
    ModeratorReviewViewModel vm, {
    ModerationMotivation? motivation,
    bool chosen = false,
  }) async {
    // A misattribution close has nothing to choose; the server forces its key.
    if (!chosen && vm.needsMotivation(report)) {
      final picked = await showModeratorCloseSheet(
        context,
        decision: vm.decisionFor(report),
      );
      if (picked == null || !context.mounted) return;
      return _close(context, vm, motivation: picked, chosen: true);
    }
    if (await vm.close(report, motivation: motivation) || !context.mounted) {
      return;
    }
    SnackBarUtils.showFailure(
      context,
      what: context.l10n.moderatorCloseFailed,
      preserved: context.l10n.moderatorReportUnchanged,
      action: FailureAction.retry(
        () => _close(context, vm, motivation: motivation, chosen: true),
      ),
    );
  }

  /// The retry repeats the action the moderator already confirmed.
  Future<void> _takeDown(
    BuildContext context,
    ModeratorReviewViewModel vm, {
    required bool reversible,
  }) async {
    if (await vm.takeDown(report) || !context.mounted) return;
    final l10n = context.l10n;
    SnackBarUtils.showFailure(
      context,
      what: reversible ? l10n.moderatorHideFailed : l10n.moderatorDeleteFailed,
      preserved: reversible
          ? l10n.moderatorHidePreserved
          : l10n.moderatorDeletePreserved,
      action: FailureAction.retry(
        () => _takeDown(context, vm, reversible: reversible),
      ),
    );
  }
}

class _MenuDishNotes extends StatelessWidget {
  final bool? claimedCreatorIsReporter;
  const _MenuDishNotes({required this.claimedCreatorIsReporter});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final muted = AppTextStyles.bodySmall.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    final claimed = claimedCreatorIsReporter;
    return Padding(
      padding: const EdgeInsets.only(top: AppDimensions.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.moderatorMenuDishSharerNote, style: muted),
          if (claimed != null)
            Text(
              claimed
                  ? l10n.moderatorMenuDishClaimedReporter
                  : l10n.moderatorMenuDishNotClaimedReporter,
              style: muted,
            ),
        ],
      ),
    );
  }
}
