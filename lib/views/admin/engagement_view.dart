import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/admin/engagement_stats.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/admin/engagement_viewmodel.dart';
import 'package:butlery/views/admin/widgets/admin_stat_card.dart';
import 'package:butlery/widgets/common/state_widget.dart';

/// Admin-only engagement tab: total users + recent daily active-user counts per
/// feature, read from the `analytics/feature_retention` rollups. Pre-launch the
/// numbers are ~0 by design.
class EngagementView extends StatefulWidget {
  const EngagementView({super.key});

  @override
  State<EngagementView> createState() => _EngagementViewState();
}

class _EngagementViewState extends State<EngagementView> {
  late final EngagementViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = EngagementViewModel();
    _vm.load();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<EngagementViewModel>.value(
      value: _vm,
      child: const _EngagementContent(),
    );
  }
}

class _EngagementContent extends StatelessWidget {
  const _EngagementContent();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<EngagementViewModel>();
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.adminEngagementTitle),
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

  Widget _body(BuildContext context, EngagementViewModel vm) {
    final l10n = context.l10n;
    if (vm.isLoading && vm.days.isEmpty && vm.userCount == 0) {
      return StateWidget.loading();
    }
    if (vm.error != null && vm.days.isEmpty && vm.userCount == 0) {
      return StateWidget.error(message: vm.error!, onAction: vm.refresh);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingM),
          child: Wrap(
            spacing: AppDimensions.spacingSm,
            runSpacing: AppDimensions.spacingSm,
            children: [
              AdminStatCard(
                label: l10n.adminEngagementUsers,
                value: '${vm.userCount}',
              ),
              AdminStatCard(
                label: l10n.adminEngagementActiveToday,
                value: '${vm.activeToday}',
              ),
              AdminStatCard(
                label: l10n.adminEngagementActive7d,
                value: '${vm.active7d}',
              ),
              AdminStatCard(
                label: l10n.adminEngagementActive28d,
                value: '${vm.active28d}',
              ),
            ],
          ),
        ),
        if (vm.days.isEmpty)
          Expanded(
            child: StateWidget.empty(
              title: l10n.adminEngagementEmpty,
              icon: Icons.show_chart,
            ),
          )
        else ...[
          const _HeaderRow(),
          Expanded(
            child: ListView.separated(
              itemCount: vm.days.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) => _DayRow(day: vm.days[i]),
            ),
          ),
        ],
      ],
    );
  }
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
          Expanded(
              flex: 3, child: Text(l10n.adminEngagementColDate, style: _h)),
          _num(l10n.adminEngagementColCooked),
          _num(l10n.adminEngagementColImported),
          _num(l10n.adminEngagementColShared),
          _num(l10n.adminEngagementColPlanned),
          _num(l10n.adminEngagementColShopped),
        ],
      ),
    );
  }

  Widget _num(String label) => Expanded(
        flex: 2,
        child: Text(label, style: _h, textAlign: TextAlign.end),
      );

  static final TextStyle _h = AppTextStyles.metadataEmphasized;
}

class _DayRow extends StatelessWidget {
  final DailyEngagement day;
  const _DayRow({required this.day});

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
            flex: 3,
            child: Text(
              day.date,
              style: AppTextStyles.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _num(day.dau.cooked),
          _num(day.dau.imported),
          _num(day.dau.shared),
          _num(day.dau.mealPlanned),
          _num(day.dau.shopped),
        ],
      ),
    );
  }

  Widget _num(int value) => Expanded(
        flex: 2,
        child: Text(
          '$value',
          style: AppTextStyles.bodyMedium,
          textAlign: TextAlign.end,
        ),
      );
}
