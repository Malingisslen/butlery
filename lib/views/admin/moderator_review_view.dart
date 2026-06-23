import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/social/content_report.dart';
import 'package:butlery/services/moderation/report_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/admin/moderator_review_viewmodel.dart';
import 'package:butlery/widgets/common/adaptive_app_bar.dart';
import 'package:butlery/widgets/common/dialogs/confirmation_dialogs.dart';
import 'package:butlery/widgets/common/state_widget.dart';
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
      appBar: AdaptiveAppBar(
        title: context.l10n.moderatorReviewTitle,
        centerTitle: true,
      ),
      body: StreamBuilder<bool>(
        stream: _reportService.watchIsAdmin(),
        builder: (context, snapshot) {
          final isAdmin = snapshot.data ?? false;
          if (snapshot.connectionState == ConnectionState.waiting) {
            return StateWidget.loading();
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
        padding: const EdgeInsets.all(AppDimensions.paddingXl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 64, color: cs.outline),
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
      return StateWidget.loading();
    }
    if (vm.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingL),
          child: Text(vm.error!, textAlign: TextAlign.center),
        ),
      );
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
      separatorBuilder: (_, __) =>
          const SizedBox(height: AppDimensions.spacingS),
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
                    '${report.contentType.wireName.toUpperCase()} · ${report.contentId}',
                    style: AppTextStyles.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _StatusPill(status: report.status),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingXs),
            Text(
              '${context.l10n.moderatorReasonLabel}: ${report.reason}',
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
              '${context.l10n.moderatorReporterLabel}: ${report.reporterId}',
              style: AppTextStyles.metadataEmphasized.copyWith(
                color: cs.outline,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            Wrap(
              spacing: AppDimensions.spacingSm,
              runSpacing: AppDimensions.spacingXs,
              children: [
                if (report.status != ReportStatus.closed)
                  OutlinedButton(
                    onPressed: () => vm.advance(report),
                    child: Text(context.l10n.moderatorActionAdvance),
                  ),
                OutlinedButton(
                  onPressed: () => _confirmTakeDown(context, vm),
                  child: Text(
                    vm.isReversibleAction(report)
                        ? context.l10n.moderatorActionHide
                        : context.l10n.moderatorActionDelete,
                  ),
                ),
                if (report.status != ReportStatus.closed)
                  TextButton(
                    onPressed: () => vm.close(report),
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
    final title = reversible
        ? l10n.moderatorHideConfirmTitle
        : l10n.moderatorDeleteConfirmTitle;
    final body = reversible
        ? l10n.moderatorHideConfirmBody
        : l10n.moderatorDeleteConfirmBody;
    final confirm = reversible
        ? l10n.moderatorActionHide
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
    if (ok == true) {
      await vm.takeDown(report);
    }
  }
}

class _StatusPill extends StatelessWidget {
  final ReportStatus status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingS,
        vertical: AppDimensions.paddingXxs,
      ),
      color: cs.secondaryContainer,
      child: Text(
        status.wireName,
        style: AppTextStyles.metadataEmphasized,
      ),
    );
  }
}
