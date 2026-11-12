import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/admin/overview_status.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/admin/overview_loader.dart';
import 'package:butlery/views/admin/widgets/admin_tab_header.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/buttons/butlery_text_button.dart';
import 'package:butlery/widgets/common/cards/styled_card.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/state_widget.dart';

/// First admin tab: one row per tab saying whether it needs a look and what to
/// do, with a button that opens it.
class OverviewView extends StatefulWidget {
  final void Function(OverviewTarget) onOpenTarget;
  const OverviewView({required this.onOpenTarget, super.key});

  @override
  State<OverviewView> createState() => _OverviewViewState();
}

class _OverviewViewState extends State<OverviewView> {
  List<OverviewRow>? _rows;
  bool _loading = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _load();
    }
  }

  Future<void> _load({bool force = false}) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _loading = true);
    final rows = await loadOverviewRows(l10n, force: force);
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rows = _rows;
    return AdminTabPage(
      title: l10n.adminOverviewTitle,
      actions: [
        AppIconButton(
          icon: ButleryIcons.refreshCw,
          semanticLabel: l10n.adminRefresh,
          onPressed: _loading ? null : () => _load(force: true),
        ),
      ],
      body: rows == null
          ? StateWidget.loading(message: l10n.loadingMetrics)
          : ListView(
              padding: const EdgeInsets.all(AppDimensions.space16),
              children: [
                _StatusBox(rows: rows),
                for (final row in rows) ...[
                  const SizedBox(height: AppDimensions.space12),
                  _TabRow(
                    row: row,
                    onOpen: () => widget.onOpenTarget(row.target),
                  ),
                ],
              ],
            ),
    );
  }
}

class _StatusBox extends StatelessWidget {
  final List<OverviewRow> rows;
  const _StatusBox({required this.rows});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final needsLook = rows
        .where((r) => r.status == OverviewStatus.needsLook)
        .length;
    final unavailable = rows.any((r) => r.status == OverviewStatus.unavailable);
    final String title;
    final Color background;
    final Color foreground;
    if (needsLook > 0) {
      title = l10n.adminOverviewNeedsAction(needsLook);
      background = cs.errorContainer;
      foreground = cs.onErrorContainer;
    } else if (unavailable) {
      title = l10n.adminOverviewSomeUnavailable;
      background = cs.surfaceContainerHighest;
      foreground = cs.onSurface;
    } else {
      title = l10n.adminOverviewAllClearTitle;
      background = cs.primaryContainer;
      foreground = cs.onPrimaryContainer;
    }
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(AppDimensions.space8),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTextStyles.titleLarge.copyWith(color: foreground),
            ),
            if (needsLook == 0 && !unavailable) ...[
              const SizedBox(height: AppDimensions.space8),
              Text(
                l10n.adminOverviewAllClearBody,
                style: AppTextStyles.bodyMedium.copyWith(color: foreground),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TabRow extends StatelessWidget {
  final OverviewRow row;
  final VoidCallback onOpen;
  const _TabRow({required this.row, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final (statusLabel, statusColor) = switch (row.status) {
      OverviewStatus.ok => (l10n.adminOverviewStatusOk, cs.primary),
      OverviewStatus.needsLook => (l10n.adminOverviewStatusNeedsLook, cs.error),
      OverviewStatus.unavailable => (
        l10n.adminOverviewStatusUnavailable,
        cs.error,
      ),
      OverviewStatus.noSignal => (
        l10n.adminOverviewStatusNoSignal,
        cs.onSurfaceVariant,
      ),
    };
    return StyledCard(
      padding: const EdgeInsets.all(AppDimensions.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppDimensions.space12,
            runSpacing: AppDimensions.space8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                _tabName(l10n, row.target),
                style: AppTextStyles.titleMedium,
              ),
              Text(
                statusLabel,
                style: AppTextStyles.bodyMedium.copyWith(color: statusColor),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.space8),
          Text(_advice(l10n, row), style: AppTextStyles.bodyMedium),
          const SizedBox(height: AppDimensions.space8),
          ButleryTextButton(label: l10n.adminOverviewOpen, onPressed: onOpen),
        ],
      ),
    );
  }
}

String _tabName(AppLocalizations l10n, OverviewTarget target) =>
    switch (target) {
      OverviewTarget.feedback => l10n.adminNavFeedback,
      OverviewTarget.proposals => l10n.adminNavProposals,
      OverviewTarget.import => l10n.adminNavImport,
      OverviewTarget.parsing => l10n.adminNavParsing,
      OverviewTarget.ops => l10n.adminNavOps,
      OverviewTarget.engagement => l10n.adminNavEngagement,
      OverviewTarget.recipes => l10n.adminNavRecipes,
      OverviewTarget.ingredients => l10n.adminNavIngredients,
      OverviewTarget.tagRules => l10n.adminNavTagRules,
      OverviewTarget.guestList => l10n.adminNavGuestList,
    };

String _advice(AppLocalizations l10n, OverviewRow row) => switch (row.advice) {
  OverviewAdvice.feedbackNew =>
    row.atLeast
        ? l10n.adminOverviewFeedbackManyAdvice(row.number)
        : l10n.adminOverviewFeedbackAdvice(row.number),
  OverviewAdvice.feedbackOk => l10n.adminOverviewFeedbackOk,
  OverviewAdvice.proposalsOpen =>
    row.atLeast
        ? l10n.adminOverviewProposalsManyAdvice(row.number)
        : l10n.adminOverviewProposalsAdvice(row.number),
  OverviewAdvice.proposalsOk => l10n.adminOverviewProposalsOk,
  OverviewAdvice.importFailures => l10n.adminOverviewImportFailuresAdvice(
    row.number,
  ),
  OverviewAdvice.importAnomalies => l10n.adminOverviewAnomaliesAdvice,
  OverviewAdvice.importOk => l10n.adminOverviewImportOk,
  OverviewAdvice.opsStale => l10n.adminOverviewOpsStaleAdvice(row.number),
  OverviewAdvice.opsNone => l10n.adminOverviewOpsNoneAdvice,
  OverviewAdvice.opsOk => l10n.adminOverviewOpsOk,
  OverviewAdvice.guestPending => l10n.adminOverviewGuestPendingAdvice(
    row.number,
  ),
  OverviewAdvice.guestNone => l10n.adminOverviewGuestNone,
  OverviewAdvice.noSignal => l10n.adminOverviewNoSignalAdvice,
  OverviewAdvice.unavailable => l10n.adminOverviewUnavailableAdvice,
};
