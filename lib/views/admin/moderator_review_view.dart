import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/contextual_time_formatter.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/social/content_report.dart';
import 'package:butlery/models/social/content_type.dart';
import 'package:butlery/models/social/report_evidence.dart';
import 'package:butlery/services/moderation/report_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/admin/moderator_review_viewmodel.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/indicators/admin_badge.dart';
import 'package:butlery/widgets/common/dialogs/confirmation_dialogs.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/social/report_reason_labels.dart';
import 'package:flutter/material.dart';
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
  late final ReportService _reportService;

  @override
  void initState() {
    super.initState();
    _vm = ModeratorReviewViewModel();
    _reportService = ServiceLocator.get<ReportService>();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ButleryTopBar.undersida(
        title: context.l10n.moderatorReviewTitle,
      ),
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
          return ChangeNotifierProvider<ModeratorReviewViewModel>.value(
            value: _vm..startListening(),
            child: const _ReportsList(),
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
            ButleryIcon(ButleryIcons.lock, size: 64, color: cs.outline),
            const SizedBox(height: AppDimensions.spacingMd),
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
        vertical: AppDimensions.paddingM,
        horizontal: AppDimensions.paddingM,
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

    return Card(
      margin: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${report.contentType == ContentType.menuDish ? context.l10n.moderatorContentTypeMenuDish : report.contentType.wireName.toUpperCase()} · ${report.contentId}',
                    style: AppTextStyles.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _StatusPill(status: report.status),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingXs),
            Text(
              '${context.l10n.moderatorReasonLabel}: '
              '${reportReasonDisplay(context.l10n, report.reason)}',
              style: AppTextStyles.bodySmall.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            if (report.description != null && report.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppDimensions.spacingXs),
                child: Text(
                  report.description!,
                  style: AppTextStyles.bodySmall,
                ),
              ),
            const SizedBox(height: AppDimensions.spacingXs),
            Text(
              report.reporterErased
                  ? context.l10n.moderatorReporterErased
                  : '${context.l10n.moderatorReporterLabel}: ${report.reporterId}',
              style: AppTextStyles.metadataEmphasized.copyWith(
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
              const SizedBox(height: AppDimensions.spacingSm),
              _EvidenceSection(state: evidence),
            ],
            // BUT-1609: moderation on a minor's account carries extra care
            // (GDPR/child-safety) — surface it before any action is taken.
            if (vm.isMinorOwner(report)) ...[
              const SizedBox(height: AppDimensions.spacingXs),
              AdminBadge(
                label: context.l10n.moderatorMinorAccountBadge,
                icon: ButleryIcons.shield,
              ),
            ],
            const SizedBox(height: AppDimensions.spacingSm),
            Wrap(
              spacing: AppDimensions.spacingSm,
              runSpacing: AppDimensions.spacingXs,
              children: [
                if (report.status != ReportStatus.closed)
                  OutlinedButton(
                    onPressed: () => _advance(context, vm),
                    child: Text(context.l10n.moderatorActionAdvance),
                  ),
                OutlinedButton(
                  onPressed: () => _confirmTakeDown(context, vm),
                  child: Text(
                    vm.isReversibleAction(report)
                        ? context.l10n.moderatorActionHide
                        : report.contentType == ContentType.menuDish
                        ? context.l10n.moderatorActionRemoveDish
                        : context.l10n.moderatorActionDelete,
                  ),
                ),
                if (report.status != ReportStatus.closed)
                  TextButton(
                    onPressed: () => _close(context, vm),
                    child: Text(context.l10n.moderatorActionClose),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

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

  Future<void> _close(BuildContext context, ModeratorReviewViewModel vm) async {
    if (await vm.close(report) || !context.mounted) return;
    SnackBarUtils.showFailure(
      context,
      what: context.l10n.moderatorCloseFailed,
      preserved: context.l10n.moderatorReportUnchanged,
      action: FailureAction.retry(() => _close(context, vm)),
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
      padding: const EdgeInsets.only(top: AppDimensions.spacingXs),
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

/// Shows the saved copy as plain `Text` only: it is untrusted user content,
/// so no markdown and no link detection.
class _EvidenceSection extends StatelessWidget {
  final ReportEvidenceState state;
  const _EvidenceSection({required this.state});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final muted = AppTextStyles.bodySmall.copyWith(color: cs.onSurfaceVariant);

    final evidence = state is ReportEvidenceLoaded
        ? (state as ReportEvidenceLoaded).evidence
        : null;
    if (evidence == null) {
      return Text(l10n.moderatorEvidenceNone, style: muted);
    }

    final capturedAt = evidence.capturedAt;
    final heading = capturedAt == null
        ? l10n.moderatorEvidenceHeading
        : l10n.moderatorEvidenceHeadingAt(
            ContextualTimeFormatter.dateTime(
              capturedAt,
              localeName: l10n.localeName,
            ),
          );

    final String? outcomeLine = switch (evidence.outcome) {
      EvidenceOutcome.captured => null,
      EvidenceOutcome.missing => l10n.moderatorEvidenceMissing,
      EvidenceOutcome.notVisibleToReporter => l10n.moderatorEvidenceNotVisible,
      EvidenceOutcome.ownerMismatch => l10n.moderatorEvidenceOwnerMismatch,
      EvidenceOutcome.unsupportedType ||
      EvidenceOutcome.invalidRef => l10n.moderatorEvidenceUnsupported,
      EvidenceOutcome.captureFailed ||
      EvidenceOutcome.unknown => l10n.moderatorEvidenceFailed,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          heading,
          style: AppTextStyles.metadataEmphasized.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
        if (outcomeLine != null)
          Text(outcomeLine, style: muted)
        else ...[
          for (final (field, value) in evidence.text)
            Padding(
              padding: const EdgeInsets.only(top: AppDimensions.spacingXs),
              child: Text(
                value,
                key: ValueKey('evidence-$field'),
                style: AppTextStyles.bodySmall,
              ),
            ),
          if (evidence.truncated)
            Padding(
              padding: const EdgeInsets.only(top: AppDimensions.spacingXs),
              child: Text(l10n.moderatorEvidenceTruncated, style: muted),
            ),
          Padding(
            padding: const EdgeInsets.only(top: AppDimensions.spacingXs),
            child: Text(l10n.moderatorEvidenceTextOnly, style: muted),
          ),
        ],
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  final ReportStatus status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: AppDimensions.statusPillPadding,
      // tokens.json controls.statusPill: radius pill, 10.5/700; Komponentark
      // v1:297 draws the pill text at 0.5 px tracking.
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
      ),
      child: Text(
        status.wireName,
        style: AppTextStyles.overline.copyWith(letterSpacing: 0.5),
      ),
    );
  }
}
