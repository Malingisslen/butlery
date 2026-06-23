import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/scaffolds/base_scaffold.dart';

/// List scaffold consolidating patterns from 22+ files
class ListScaffold<T> extends StatelessWidget {
  final String? title;
  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final VoidCallback? onAdd;
  final String? emptyMessage;
  final IconData? emptyIcon;
  final bool isLoading;
  final VoidCallback? onRefresh;
  final bool showBackButton;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  const ListScaffold({
    super.key,
    this.title,
    required this.items,
    required this.itemBuilder,
    this.onAdd,
    this.emptyMessage,
    this.emptyIcon,
    this.isLoading = false,
    this.onRefresh,
    this.showBackButton = true,
    this.actions,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return LoadingScaffold(
        title: title,
        showBackButton: showBackButton,
        actions: actions,
      );
    }

    if (items.isEmpty) {
      return EmptyStateScaffold(
        title: title,
        emptyMessage: emptyMessage ?? context.l10n.emptyNoItems,
        emptyIcon: emptyIcon,
        onAction: onAdd,
        actionText: onAdd != null ? context.l10n.commonAdd : null,
        showBackButton: showBackButton,
        actions: actions,
      );
    }

    Widget body = ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) =>
          itemBuilder(context, items[index], index),
    );

    if (onRefresh != null) {
      body = RefreshIndicator(
        onRefresh: () async => onRefresh!(),
        child: body,
      );
    }

    return BaseScaffold(
      title: title,
      showBackButton: showBackButton,
      actions: actions,
      body: body,
      floatingActionButton:
          floatingActionButton ??
          (onAdd != null
              ? FloatingActionButton(
                  onPressed: onAdd,
                  tooltip: context.l10n.commonAdd,
                  child: const Icon(Icons.add),
                )
              : null),
    );
  }
}
