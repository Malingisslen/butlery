import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/admin/ops_event.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/admin/ops_log_viewmodel.dart';
import 'package:butlery/views/admin/widgets/admin_help_text.dart';
import 'package:butlery/views/admin/widgets/admin_stat_card.dart';
import 'package:butlery/widgets/common/state_widget.dart';

/// Admin-only ops-log tab: recent scheduled-job runs from `system_events`.
/// Sparse pre-launch — only the cleanup jobs write here yet.
class OpsLogView extends StatefulWidget {
  const OpsLogView({super.key});

  @override
  State<OpsLogView> createState() => _OpsLogViewState();
}

class _OpsLogViewState extends State<OpsLogView> {
  late final OpsLogViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = OpsLogViewModel();
    _vm.load();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<OpsLogViewModel>.value(
      value: _vm,
      child: const _OpsLogContent(),
    );
  }
}

class _OpsLogContent extends StatelessWidget {
  const _OpsLogContent();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<OpsLogViewModel>();
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.adminOpsTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: context.l10n.adminRefresh,
            onPressed: vm.isLoading ? null : vm.refresh,
          ),
        ],
      ),
      body: _body(context, vm),
    );
  }

  Widget _body(BuildContext context, OpsLogViewModel vm) {
    final l10n = context.l10n;
    if (vm.isLoading && vm.events.isEmpty) {
      return StateWidget.loading();
    }
    if (vm.error != null && vm.events.isEmpty) {
      return StateWidget.error(message: vm.error!, onAction: vm.refresh);
    }
    if (vm.events.isEmpty) {
      return StateWidget.empty(
        title: l10n.adminOpsEmpty,
        icon: Icons.dns_outlined,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdminHelpText(text: l10n.adminOpsHelp),
        Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingM),
          child: Wrap(
            spacing: AppDimensions.spacingSm,
            runSpacing: AppDimensions.spacingSm,
            children: [
              AdminStatCard(
                label: l10n.adminOpsLastRun,
                value: _formatDateTime(vm.lastRun),
              ),
              AdminStatCard(
                label: l10n.adminOpsEventCount,
                value: '${vm.eventCount}',
              ),
            ],
          ),
        ),
        const _HeaderRow(),
        Expanded(
          child: ListView.separated(
            itemCount: vm.events.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) => _EventRow(event: vm.events[i]),
          ),
        ),
      ],
    );
  }
}

String _formatDateTime(DateTime? d) {
  if (d == null) return '—';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)} '
      '${two(d.hour)}:${two(d.minute)}';
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Container(
      color: cs.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingS,
      ),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text(l10n.adminOpsColType, style: _h)),
          Expanded(
            flex: 4,
            child: Text(l10n.adminOpsColTime, style: _h),
          ),
          Expanded(
            flex: 2,
            child: Text(l10n.adminOpsColDeleted,
                style: _h, textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }

  static final TextStyle _h = AppTextStyles.metadataEmphasized;
}

class _EventRow extends StatelessWidget {
  final OpsEvent event;
  const _EventRow({required this.event});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingS,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              event.type,
              style: AppTextStyles.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              _formatDateTime(event.executedAt),
              style: AppTextStyles.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              event.deletedCount != null ? '${event.deletedCount}' : '—',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
