import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/admin/ops_log_viewmodel.dart';
import 'package:butlery/views/admin/ops_event_label.dart';
import 'package:butlery/views/admin/widgets/admin_tab_header.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/admin/admin_table.dart';
import 'package:butlery/widgets/common/layout/tinted_note.dart';
import 'package:butlery/widgets/common/section_heading.dart';
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
    return AdminTabPage(
      title: context.l10n.adminOpsTitle,
      actions: [
        IconButton(
          icon: const ButleryIcon(ButleryIcons.refreshCw),
          tooltip: context.l10n.adminRefresh,
          onPressed: vm.isLoading ? null : vm.refresh,
        ),
      ],
      body: _body(context, vm),
    );
  }

  Widget _body(BuildContext context, OpsLogViewModel vm) {
    final l10n = context.l10n;
    if (vm.isLoading && vm.events.isEmpty) {
      return StateWidget.loading(message: l10n.loadingOpsLog);
    }
    if (vm.error != null && vm.events.isEmpty) {
      return StateWidget.error(message: vm.error!, onAction: vm.refresh);
    }
    if (vm.events.isEmpty) {
      return StateWidget.empty(
        title: l10n.adminOpsEmpty,
        icon: ButleryIcons.server,
      );
    }
    final now = DateTime.now();
    return ListView(
      padding: const EdgeInsets.all(AppDimensions.space16),
      children: [
        SectionHeading(l10n.adminOpsSectionTitle),
        const SizedBox(height: AppDimensions.space8),
        AdminTable(
          columns: [
            AdminTableColumn(label: l10n.adminOpsColTime, flex: 3),
            AdminTableColumn(label: l10n.adminOpsColType, flex: 4),
            AdminTableColumn(
              label: l10n.adminOpsColDeleted,
              flex: 3,
              alignEnd: true,
            ),
          ],
          rows: [
            for (final e in vm.events)
              AdminTableRow(
                cells: [
                  _formatTime(e.executedAt, now),
                  opsEventLabel(l10n, e.type),
                  e.deletedCount != null ? '${e.deletedCount}' : '—',
                ],
              ),
          ],
          footer: const _SparseNote(),
        ),
      ],
    );
  }
}

class _SparseNote extends StatelessWidget {
  const _SparseNote();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final base = TintedNote.textStyle(context);
    return TintedNote.band(
      child: Text.rich(
        TextSpan(
          style: base,
          children: [
            TextSpan(
              text: '${l10n.adminOpsSparseTitle} ',
              style: AppTextStyles.labelLarge.copyWith(color: base.color),
            ),
            TextSpan(text: l10n.adminOpsSparseBody),
          ],
        ),
      ),
    );
  }
}

/// Clock time for today's runs, day and month for older ones, so the column
/// stays short.
String _formatTime(DateTime? d, DateTime now) {
  if (d == null) return '—';
  String two(int n) => n.toString().padLeft(2, '0');
  final clock = '${two(d.hour)}:${two(d.minute)}';
  final today = d.year == now.year && d.month == now.month && d.day == now.day;
  return today ? clock : '${d.day}/${d.month} $clock';
}
