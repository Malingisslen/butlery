import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/social/closed_report.dart';
import 'package:butlery/viewmodels/admin/moderator_closed_viewmodel.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/views/admin/moderator_closed_sheet.dart';
import 'package:butlery/views/admin/moderator_labels.dart';
import 'package:butlery/widgets/common/badges/unified_badge.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/dialogs/confirmation_dialogs.dart';
import 'package:butlery/widgets/common/layout/butlery_page_body.dart';
import 'package:butlery/widgets/common/list/butlery_item_row.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/widgets/common/sheets/butlery_sheet.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/social/revised_pill.dart';

/// The "Stängda" tab: decided reports, newest decision first, with a way to
/// open one again. Loads when it is first shown.
class ModeratorClosedTab extends StatefulWidget {
  const ModeratorClosedTab({super.key});

  @override
  State<ModeratorClosedTab> createState() => _ModeratorClosedTabState();
}

class _ModeratorClosedTabState extends State<ModeratorClosedTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ModeratorClosedViewModel>().ensureLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final vm = context.watch<ModeratorClosedViewModel>();
    if (vm.hasError) {
      return StateWidget.error(
        message: l10n.moderatorClosedLoadFailed,
        onAction: vm.load,
      );
    }
    if (!vm.hasLoaded) {
      return StateWidget.loading(message: l10n.loadingClosedReports);
    }
    if (vm.reports.isEmpty) {
      return StateWidget.empty(title: l10n.moderatorClosedEmpty);
    }
    final recent = vm.thisWeek;
    final earlier = vm.earlier;
    return ListView(
      padding: ButleryPageBody.margin(
        context,
        bottom: AppDimensions.space24,
      ),
      children: [
        if (recent.isNotEmpty)
          ButleryListSection(
            title: l10n.moderatorClosedThisWeek,
            rows: [for (final r in recent) _row(r)],
          ),
        if (earlier.isNotEmpty)
          ButleryListSection(
            title: l10n.moderatorClosedEarlier,
            rows: [for (final r in earlier) _row(r)],
          ),
        if (vm.hasMore)
          Padding(
            padding: const EdgeInsets.only(top: AppDimensions.space16),
            child: ActionButtons.outlinedButton(
              context,
              key: const ValueKey('closed-show-more'),
              label: l10n.moderatorClosedShowMore,
              isLoading: vm.isLoadingMore,
              isExpanded: true,
              onPressed: _loadMore,
            ),
          ),
      ],
    );
  }

  Widget _row(ClosedReport report) {
    final l10n = context.l10n;
    return ButleryItemRow(
      key: ValueKey('closed-${report.reportId}'),
      title: moderatorDecisionLabel(l10n, report.decision),
      subtitle: pastDecisionLine(l10n, report, type: report.contentType),
      trailing: report.appealed || report.wasRevised
          ? Row(
              mainAxisSize: MainAxisSize.min,
              spacing: AppDimensions.space4,
              children: [
                if (report.appealed)
                  UnifiedBadge.status(
                    label: l10n.moderatorPillAppealed,
                    tone: BadgeTone.warning,
                  ),
                if (report.wasRevised) const RevisedPill(),
              ],
            )
          : null,
      showChevron: true,
      onTap: () => _open(report),
    );
  }

  Future<void> _loadMore() async {
    final vm = context.read<ModeratorClosedViewModel>();
    if (await vm.loadMore() || !mounted) return;
    final l10n = context.l10n;
    SnackBarUtils.showFailure(
      context,
      what: l10n.moderatorClosedMoreFailed,
      preserved: l10n.moderatorClosedListUnchanged,
      action: FailureAction.retry(_loadMore),
    );
  }

  // Runs from the tab's own context: the row is gone once the report is
  // reopened, and its context with it.
  Future<void> _open(ClosedReport report) async {
    final vm = context.read<ModeratorClosedViewModel>();
    final l10n = context.l10n;
    final reopen = await showButlerySheet<bool>(
      context: context,
      builder: (_) => ModeratorClosedSheet(report: report),
    );
    if (reopen != true || !mounted) return;
    final confirmed = await ConfirmationDialogs.showConfirmationDialog(
      context,
      title: l10n.moderatorReopenConfirmTitle,
      message: l10n.moderatorReopenConfirmBody,
      confirmText: l10n.moderatorClosedReopen,
      cancelText: l10n.commonCancel,
    );
    if (!confirmed || !mounted) return;
    final result = await vm.reopen(report);
    if (!mounted) return;
    switch (result) {
      case ReopenSucceeded():
        SnackBarUtils.showSuccess(context, l10n.moderatorReopened);
        DefaultTabController.maybeOf(context)?.animateTo(0);
      case ReopenBlocked(:final block):
        SnackBarUtils.showInfo(context, reopenBlockText(l10n, block));
      case ReopenFailed():
        SnackBarUtils.showFailure(
          context,
          what: l10n.moderatorReopenFailed,
          preserved: l10n.moderatorReopenFailedKept,
          action: FailureAction.retry(() => _open(report)),
        );
    }
  }
}
