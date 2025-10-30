import 'package:flutter/material.dart';
import 'package:butlery/core/constants/app_strings.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Scaffold templates eliminating duplicate patterns across 30+ view files (AppBar, FAB, drawer, loading, error, empty states).
class BaseScaffold extends StatelessWidget {
  final String? title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? drawer;
  final Widget? endDrawer;
  final Widget? bottomNavigationBar;
  final Widget? bottomSheet;
  final Color? backgroundColor;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final bool centerTitle;
  final Widget? leading;
  final PreferredSizeWidget? bottom;
  final bool extendBodyBehindAppBar;
  final bool resizeToAvoidBottomInset;

  const BaseScaffold({
    super.key,
    this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.drawer,
    this.endDrawer,
    this.bottomNavigationBar,
    this.bottomSheet,
    this.backgroundColor,
    this.showBackButton = true,
    this.onBackPressed,
    this.centerTitle = true,
    this.leading,
    this.bottom,
    this.extendBodyBehindAppBar = false,
    this.resizeToAvoidBottomInset = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: title != null ? _buildAppBar(context) : null,
      body: body,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      drawer: drawer,
      endDrawer: endDrawer,
      bottomNavigationBar: bottomNavigationBar,
      bottomSheet: bottomSheet,
      backgroundColor: backgroundColor,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      title: Text(title!),
      centerTitle: centerTitle,
      actions: actions,
      leading: _buildLeading(context),
      bottom: bottom,
      backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
      elevation: Theme.of(context).appBarTheme.elevation,
    );
  }

  Widget? _buildLeading(BuildContext context) {
    if (leading != null) return leading;
    if (showBackButton && Navigator.canPop(context)) {
      return IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: onBackPressed ?? () => Navigator.pop(context),
        tooltip: AppStrings.backButton,
      );
    }
    return null;
  }
}

/// Loading scaffold consolidating patterns from 25+ files
class LoadingScaffold extends StatelessWidget {
  final String? title;
  final String loadingMessage;
  final bool showBackButton;
  final List<Widget>? actions;

  const LoadingScaffold({
    super.key,
    this.title,
    this.loadingMessage = AppStrings.loading,
    this.showBackButton = true,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: title,
      showBackButton: showBackButton,
      actions: actions,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppDimensions.spacingMd),
            Text(
              loadingMessage,
              style: AppTextStyles.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

/// Error scaffold consolidating patterns from 15+ files
class ErrorScaffold extends StatelessWidget {
  final String? title;
  final String errorMessage;
  final VoidCallback? onRetry;
  final bool showBackButton;
  final List<Widget>? actions;

  const ErrorScaffold({
    super.key,
    this.title,
    this.errorMessage = AppStrings.genericError,
    this.onRetry,
    this.showBackButton = true,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: title,
      showBackButton: showBackButton,
      actions: actions,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacingMd),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: AppDimensions.spacingMd),
              Text(
                errorMessage,
                style: AppTextStyles.bodyLarge,
                textAlign: TextAlign.center,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: AppDimensions.spacingLg),
                ElevatedButton(
                  onPressed: onRetry,
                  child: const Text(AppStrings.retry),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Empty state scaffold consolidating patterns from 20+ files
class EmptyStateScaffold extends StatelessWidget {
  final String? title;
  final String emptyMessage;
  final IconData? emptyIcon;
  final VoidCallback? onAction;
  final String? actionText;
  final bool showBackButton;
  final List<Widget>? actions;

  const EmptyStateScaffold({
    super.key,
    this.title,
    this.emptyMessage = AppStrings.noItemsFound,
    this.emptyIcon = Icons.inbox_outlined,
    this.onAction,
    this.actionText,
    this.showBackButton = true,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: title,
      showBackButton: showBackButton,
      actions: actions,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacingMd),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (emptyIcon != null) ...[
                Icon(
                  emptyIcon,
                  size: 64,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(height: AppDimensions.spacingMd),
              ],
              Text(
                emptyMessage,
                style: AppTextStyles.bodyLarge,
                textAlign: TextAlign.center,
              ),
              if (onAction != null && actionText != null) ...[
                const SizedBox(height: AppDimensions.spacingLg),
                ElevatedButton(
                  onPressed: onAction,
                  child: Text(actionText!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Form scaffold consolidating patterns from 18+ files
class FormScaffold extends StatelessWidget {
  final String? title;
  final Widget form;
  final VoidCallback? onSave;
  final VoidCallback? onCancel;
  final bool showSaveButton;
  final bool showCancelButton;
  final bool isLoading;
  final bool showBackButton;
  final List<Widget>? additionalActions;

  const FormScaffold({
    super.key,
    this.title,
    required this.form,
    this.onSave,
    this.onCancel,
    this.showSaveButton = true,
    this.showCancelButton = false,
    this.isLoading = false,
    this.showBackButton = true,
    this.additionalActions,
  });

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: title,
      showBackButton: showBackButton,
      actions: _buildActions(context),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimensions.spacingMd),
              child: form,
            ),
          ),
          if (showSaveButton || showCancelButton) _buildBottomButtons(context),
        ],
      ),
    );
  }

  List<Widget>? _buildActions(BuildContext context) {
    final actions = <Widget>[];
    if (additionalActions != null) {
      actions.addAll(additionalActions!);
    }
    if (showSaveButton && onSave != null) {
      actions.add(
        IconButton(
          onPressed: isLoading ? null : onSave,
          icon: isLoading
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save),
          tooltip: AppStrings.save,
        ),
      );
    }
    return actions.isEmpty ? null : actions;
  }

  Widget _buildBottomButtons(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingMd),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          if (showCancelButton) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: isLoading ? null : (onCancel ?? () => Navigator.pop(context)),
                child: const Text(AppStrings.cancel),
              ),
            ),
            if (showSaveButton) const SizedBox(width: AppDimensions.spacingMd),
          ],
          if (showSaveButton) ...[
            Expanded(
              child: ElevatedButton(
                onPressed: isLoading ? null : onSave,
                child: isLoading 
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(AppStrings.save),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

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
        emptyMessage: emptyMessage ?? AppStrings.noItemsFound,
        emptyIcon: emptyIcon,
        onAction: onAdd,
        actionText: onAdd != null ? AppStrings.add : null,
        showBackButton: showBackButton,
        actions: actions,
      );
    }

    Widget body = ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) => itemBuilder(context, items[index], index),
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
      floatingActionButton: floatingActionButton ?? 
          (onAdd != null 
              ? FloatingActionButton(
                  onPressed: onAdd,
                  child: const Icon(Icons.add),
                )
              : null),
    );
  }
}

/// Tabbed scaffold consolidating patterns from 8+ files
class TabbedScaffold extends StatelessWidget {
  final String? title;
  final List<Tab> tabs;
  final List<Widget> tabViews;
  final TabController? controller;
  final bool showBackButton;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  const TabbedScaffold({
    super.key,
    this.title,
    required this.tabs,
    required this.tabViews,
    this.controller,
    this.showBackButton = true,
    this.actions,
    this.floatingActionButton,
  }) : assert(tabs.length == tabViews.length);

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: title,
      showBackButton: showBackButton,
      actions: actions,
      floatingActionButton: floatingActionButton,
      bottom: TabBar(
        controller: controller,
        tabs: tabs,
      ),
      body: TabBarView(
        controller: controller,
        children: tabViews,
      ),
    );
  }
}

/// Responsive scaffold helper consolidating responsive patterns
class ResponsiveScaffoldBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, bool isMobile) builder;
  final double breakpoint;

  const ResponsiveScaffoldBuilder({
    super.key,
    required this.builder,
    this.breakpoint = 600,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < breakpoint;
        return builder(context, isMobile);
      },
    );
  }
}