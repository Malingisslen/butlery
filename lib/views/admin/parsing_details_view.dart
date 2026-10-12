import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/admin/metrics/metric_descriptor.dart';
import 'package:butlery/models/admin/parsing_domain_stat.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/viewmodels/admin/parsing_details_viewmodel.dart';
import 'package:butlery/views/admin/widgets/metric_drilldown.dart';
import 'package:butlery/views/admin/widgets/admin_tab_header.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/admin/admin_table.dart';
import 'package:butlery/widgets/common/layout/tinted_note.dart';
import 'package:butlery/widgets/common/section_heading.dart';
import 'package:butlery/widgets/common/state_widget.dart';

/// Admin-only parsing-details tab: per-domain correction counts + the field the
/// parser most often gets wrong there. Complements the import-health tab.
class ParsingDetailsView extends StatefulWidget {
  const ParsingDetailsView({super.key});

  @override
  State<ParsingDetailsView> createState() => _ParsingDetailsViewState();
}

class _ParsingDetailsViewState extends State<ParsingDetailsView> {
  late final ParsingDetailsViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = ParsingDetailsViewModel();
    _vm.load();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ParsingDetailsViewModel>.value(
      value: _vm,
      child: const _ParsingDetailsContent(),
    );
  }
}

class _ParsingDetailsContent extends StatelessWidget {
  const _ParsingDetailsContent();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ParsingDetailsViewModel>();
    return AdminTabPage(
      title: context.l10n.adminParsingTitle,
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

  Widget _body(BuildContext context, ParsingDetailsViewModel vm) {
    final l10n = context.l10n;
    if (vm.isLoading && vm.stats.isEmpty) {
      return StateWidget.loading(message: l10n.loadingParsingStats);
    }
    if (vm.error != null && vm.stats.isEmpty) {
      return StateWidget.error(message: vm.error!, onAction: vm.refresh);
    }
    if (vm.stats.isEmpty) {
      return StateWidget.empty(
        title: l10n.adminParsingEmpty,
        icon: ButleryIcons.file,
      );
    }
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(AppDimensions.space16),
      children: [
        SectionHeading(l10n.adminParsingSectionTitle),
        const SizedBox(height: AppDimensions.space8),
        AdminTable(
          columns: [
            AdminTableColumn(label: l10n.adminParsingColDomain, flex: 3),
            AdminTableColumn(
              label: l10n.adminParsingColSuccess,
              alignEnd: true,
            ),
            AdminTableColumn(label: l10n.adminParsingColStuck, alignEnd: true),
          ],
          rows: [
            for (final s in vm.stats)
              AdminTableRow(
                onTap: () => handleMetricDrilldown(
                  context,
                  MetricDrilldownKind.parseEventsByDomain,
                  s.domain,
                ),
                cells: [
                  s.domain,
                  s.successPercent == null ? '—' : '${s.successPercent} %',
                  _issueLabel(l10n, s.topIssue),
                ],
                cellColors: [
                  null,
                  null,
                  s.topIssue == ParsingIssue.none ? null : cs.error,
                ],
              ),
          ],
        ),
        const SizedBox(height: AppDimensions.space16),
        TintedNote(
          child: Text(
            l10n.adminParsingTableNote,
            style: TintedNote.textStyle(context),
          ),
        ),
      ],
    );
  }
}

String _issueLabel(AppLocalizations l10n, ParsingIssue issue) {
  switch (issue) {
    case ParsingIssue.title:
      return l10n.adminParsingIssueTitle;
    case ParsingIssue.portions:
      return l10n.adminParsingIssuePortions;
    case ParsingIssue.time:
      return l10n.adminParsingIssueTime;
    case ParsingIssue.ingredients:
      return l10n.adminParsingIssueIngredients;
    case ParsingIssue.instructions:
      return l10n.adminParsingIssueInstructions;
    case ParsingIssue.none:
      return '—';
  }
}
