import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/feedback_entry.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/viewmodels/admin/feedback_inbox_viewmodel.dart';
import 'package:butlery/views/admin/feedback_inbox_rows.dart';
import 'package:butlery/views/admin/widgets/admin_stat_card.dart';
import 'package:butlery/views/admin/widgets/admin_tab_header.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/chips/butlery_action_chip.dart';

/// Admin-only inbox listing beta feedback newest-first, with the screenshot,
/// interaction trail and device info captured at submission, plus a triage
/// status control. Reached only after the admin gate in `admin_main.dart`.
class FeedbackInboxView extends StatefulWidget {
  const FeedbackInboxView({super.key});

  @override
  State<FeedbackInboxView> createState() => _FeedbackInboxViewState();
}

class _FeedbackInboxViewState extends State<FeedbackInboxView> {
  late final FeedbackInboxViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = FeedbackInboxViewModel()..start();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<FeedbackInboxViewModel>.value(
      value: _vm,
      child: const _FeedbackInboxContent(),
    );
  }
}

class _FeedbackInboxContent extends StatelessWidget {
  const _FeedbackInboxContent();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FeedbackInboxViewModel>();
    return AdminTabPage(
      title: context.l10n.adminFeedbackInboxTitle,
      below: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusTiles(vm: vm),
          _StatusFilterBar(vm: vm),
        ],
      ),
      body: _body(context, vm),
    );
  }

  Widget _body(BuildContext context, FeedbackInboxViewModel vm) {
    if (vm.isLoading && vm.entries.isEmpty) {
      return StateWidget.loading(message: context.l10n.loadingFeedbackEntries);
    }
    if (vm.error != null && vm.entries.isEmpty) {
      return StateWidget.error(message: vm.error!, onAction: vm.start);
    }
    if (vm.entries.isEmpty) {
      return StateWidget.empty(
        title: context.l10n.adminFeedbackEmpty,
        icon: ButleryIcons.inbox,
      );
    }
    return ListView.builder(
      itemCount: vm.entries.length + (vm.canLoadMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (i >= vm.entries.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppDimensions.space12,
            ),
            child: Center(
              child: ActionButtons.outlinedButton(
                context,
                label: context.l10n.adminFeedbackLoadMore,
                onPressed: vm.loadMore,
              ),
            ),
          );
        }
        final entry = vm.entries[i];
        return FeedbackRow(key: ValueKey(entry.id), entry: entry);
      },
    );
  }
}

/// Counts per triage status among the entries loaded so far.
class _StatusTiles extends StatelessWidget {
  final FeedbackInboxViewModel vm;
  const _StatusTiles({required this.vm});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    int count(FeedbackStatus s) =>
        vm.entries.where((e) => e.status == s).length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space12),
      child: Wrap(
        spacing: AppDimensions.space8,
        runSpacing: AppDimensions.space8,
        children: [
          AdminStatCard(
            label: l10n.adminFeedbackStatusNew,
            value: '${count(FeedbackStatus.newReport)}',
          ),
          AdminStatCard(
            label: l10n.adminFeedbackStatusTriaged,
            value: '${count(FeedbackStatus.triaged)}',
          ),
          AdminStatCard(
            label: l10n.adminFeedbackStatusResolved,
            value: '${count(FeedbackStatus.resolved)}',
          ),
        ],
      ),
    );
  }
}

class _StatusFilterBar extends StatelessWidget {
  final FeedbackInboxViewModel vm;
  const _StatusFilterBar({required this.vm});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final options = <(String, FeedbackStatus?)>[
      (l10n.adminFeedbackFilterAll, null),
      (l10n.adminFeedbackStatusNew, FeedbackStatus.newReport),
      (l10n.adminFeedbackStatusTriaged, FeedbackStatus.triaged),
      (l10n.adminFeedbackStatusResolved, FeedbackStatus.resolved),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space12,
        vertical: AppDimensions.space8,
      ),
      child: Row(
        children: [
          for (final (label, status) in options)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                end: AppDimensions.space8,
              ),
              child: ButleryChoiceChip(
                label: label,
                selected: vm.statusFilter == status,
                onSelected: (_) => vm.setStatusFilter(status),
              ),
            ),
        ],
      ),
    );
  }
}
