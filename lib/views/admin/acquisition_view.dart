import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/admin/acquisition_tally.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/viewmodels/admin/acquisition_viewmodel.dart';
import 'package:butlery/views/admin/widgets/admin_tab_header.dart';
import 'package:butlery/widgets/admin/admin_table.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/layout/tinted_note.dart';
import 'package:butlery/widgets/common/section_heading.dart';
import 'package:butlery/widgets/common/state_widget.dart';

/// Admin tab: new users per campaign channel, small numbers hidden.
class AcquisitionView extends StatefulWidget {
  const AcquisitionView({super.key});

  @override
  State<AcquisitionView> createState() => _AcquisitionViewState();
}

class _AcquisitionViewState extends State<AcquisitionView> {
  late final AcquisitionViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = AcquisitionViewModel()..load();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AcquisitionViewModel>.value(
      value: _vm,
      child: const _AcquisitionContent(),
    );
  }
}

class _AcquisitionContent extends StatelessWidget {
  const _AcquisitionContent();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AcquisitionViewModel>();
    final l10n = context.l10n;
    return AdminTabPage(
      title: l10n.adminAcquisitionTitle,
      actions: [
        AppIconButton(
          icon: ButleryIcons.refreshCw,
          semanticLabel: l10n.adminRefresh,
          onPressed: vm.isLoading ? null : vm.refresh,
        ),
      ],
      body: _body(context, vm, l10n),
    );
  }

  Widget _body(
    BuildContext context,
    AcquisitionViewModel vm,
    AppLocalizations l10n,
  ) {
    final tally = vm.tally;
    if (vm.isLoading && tally == null) {
      return StateWidget.loading(message: l10n.adminAcquisitionLoading);
    }
    if (vm.error != null && tally == null) {
      return StateWidget.error(message: vm.error!, onAction: vm.refresh);
    }
    if (tally == null || tally.isEmpty) {
      return StateWidget.empty(
        title: l10n.adminAcquisitionEmpty,
        icon: ButleryIcons.server,
      );
    }
    return ListView(
      padding: const EdgeInsets.all(AppDimensions.space16),
      children: [
        SectionHeading(l10n.adminAcquisitionTitle),
        const SizedBox(height: AppDimensions.space8),
        AdminTable(
          columns: [
            AdminTableColumn(label: l10n.adminAcquisitionColSource, flex: 4),
            AdminTableColumn(
              label: l10n.adminAcquisitionColCount,
              flex: 3,
              alignEnd: true,
            ),
          ],
          rows: [
            for (final source in tally.sources)
              AdminTableRow(
                cells: [
                  source == AcquisitionTally.other
                      ? l10n.adminAcquisitionOther
                      : source,
                  AcquisitionTally.cell(tally.bySource[source] ?? 0),
                ],
              ),
            AdminTableRow(
              cells: [l10n.adminAcquisitionTotal, tally.totalLabel],
            ),
            if (tally.eligibleLabel != null)
              AdminTableRow(
                cells: [l10n.adminAcquisitionEligible, tally.eligibleLabel!],
              ),
          ],
          footer: TintedNote.band(
            child: Text(
              l10n.adminAcquisitionNote,
              style: TintedNote.textStyle(context),
            ),
          ),
        ),
      ],
    );
  }
}
