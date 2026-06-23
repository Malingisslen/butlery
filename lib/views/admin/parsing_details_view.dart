import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/admin/parsing_domain_stat.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/admin/parsing_details_viewmodel.dart';
import 'package:butlery/views/admin/widgets/admin_help_text.dart';
import 'package:butlery/views/admin/widgets/admin_stat_card.dart';
import 'package:butlery/widgets/common/adaptive_app_bar.dart';
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
    return Scaffold(
      appBar: AdaptiveAppBar(
        title: context.l10n.adminParsingTitle,
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

  Widget _body(BuildContext context, ParsingDetailsViewModel vm) {
    final l10n = context.l10n;
    if (vm.isLoading && vm.stats.isEmpty) {
      return StateWidget.loading();
    }
    if (vm.error != null && vm.stats.isEmpty) {
      return StateWidget.error(message: vm.error!, onAction: vm.refresh);
    }
    if (vm.stats.isEmpty) {
      return StateWidget.empty(
        title: l10n.adminParsingEmpty,
        icon: Icons.rule,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdminHelpText(text: l10n.adminParsingHelp),
        Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingM),
          child: Wrap(
            spacing: AppDimensions.spacingSm,
            runSpacing: AppDimensions.spacingSm,
            children: [
              AdminStatCard(
                label: l10n.adminParsingTotal,
                value: '${vm.totalCorrections}',
              ),
              AdminStatCard(
                label: l10n.adminParsingDomains,
                value: '${vm.domainCount}',
              ),
              AdminStatCard(
                label: l10n.adminParsingTopDomain,
                value: vm.topDomain ?? '—',
              ),
            ],
          ),
        ),
        const _HeaderRow(),
        Expanded(
          child: ListView.separated(
            itemCount: vm.stats.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) => _DomainRow(stat: vm.stats[i]),
          ),
        ),
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
            flex: 4,
            child: Text(l10n.adminParsingColDomain, style: _h),
          ),
          Expanded(
            flex: 2,
            child: Text(l10n.adminParsingColCount,
                style: _h, textAlign: TextAlign.end),
          ),
          Expanded(
            flex: 3,
            child: Text(l10n.adminParsingColIssue,
                style: _h, textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }

  static final TextStyle _h = AppTextStyles.metadataEmphasized;
}

class _DomainRow extends StatelessWidget {
  final ParsingDomainStat stat;
  const _DomainRow({required this.stat});

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
              stat.domain,
              style: AppTextStyles.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text('${stat.corrections}',
                style: AppTextStyles.bodyMedium, textAlign: TextAlign.end),
          ),
          Expanded(
            flex: 3,
            child: Text(
              _issueLabel(context, stat.topIssue),
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _issueLabel(BuildContext context, ParsingIssue issue) {
    final l10n = context.l10n;
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
}
