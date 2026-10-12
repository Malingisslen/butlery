import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/widgets/common/scaffolds/base_scaffold.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/common/layout/layout_scaffolds.dart';

/// The page shell shared by "Mina rapporter" and "Beslut om mitt innehåll":
/// loading, error and empty states, otherwise one section of rows.
class DecisionListScaffold extends StatelessWidget {
  const DecisionListScaffold({
    required this.title,
    required this.isLoading,
    required this.hasError,
    required this.rows,
    required this.loadingMessage,
    required this.errorMessage,
    required this.retryLabel,
    required this.emptyTitle,
    required this.onRefresh,
    this.backTo,
    super.key,
  });

  final String title;
  final bool isLoading;
  final bool hasError;
  final List<Widget> rows;
  final String loadingMessage;
  final String errorMessage;
  final String retryLabel;
  final String emptyTitle;
  final Future<void> Function() onRefresh;
  final String? backTo;

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: title,
      backTo: backTo,
      bottomNavigationBar: LayoutScaffolds.detailBottomNav(context),
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    if (isLoading && rows.isEmpty) {
      return StateWidget.loading(message: loadingMessage);
    }
    if (hasError) {
      return StateWidget.error(
        message: errorMessage,
        actionLabel: retryLabel,
        onAction: onRefresh,
      );
    }
    if (rows.isEmpty) {
      return StateWidget.empty(title: emptyTitle, icon: ButleryIcons.flag);
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: EdgeInsets.symmetric(
          horizontal: ButleryTopBar.sideMargin(context),
          vertical: AppDimensions.space8,
        ),
        children: [ButleryListSection(rows: rows)],
      ),
    );
  }
}
