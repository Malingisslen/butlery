import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/contextual_time_formatter.dart';
import 'package:butlery/models/notification_history_entry.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/services/notifications/notification_service.dart';
import 'package:butlery/viewmodels/notifications_viewmodel.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/common/indicators/loading_indicator.dart';

/// In-app notification inbox showing notification history.
class NotificationsView extends StatelessWidget {
  const NotificationsView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => NotificationsViewModel()..loadHistory(),
      child: const _NotificationsContent(),
    );
  }
}

class _NotificationsContent extends StatefulWidget {
  const _NotificationsContent();

  @override
  State<_NotificationsContent> createState() => _NotificationsContentState();
}

class _NotificationsContentState extends State<_NotificationsContent> {
  // BUT-1080: long-press multi-select + bulk dismiss. Selection keys on the
  // entry doc id (what the dismiss primitive deletes by).
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  void _enterSelection(String id) {
    setState(() {
      _selectionMode = true;
      _selectedIds.add(id);
    });
  }

  void _toggle(String id) {
    setState(() {
      if (!_selectedIds.remove(id)) _selectedIds.add(id);
    });
  }

  void _cancelSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  Future<void> _dismissSelected(NotificationsViewModel vm) async {
    if (_selectedIds.isEmpty) return;
    await vm.dismissSelected(Set.of(_selectedIds));
    if (!mounted) return;
    _cancelSelection();
  }

  /// Marks the entry read and routes to its target by reusing the exact same
  /// deep-link path an FCM tap takes ([NotificationService.onNotificationTapped]
  /// → NotificationDeepLinkRouter). Tolerant of legacy entries with no route —
  /// the router falls back to home in that case.
  void _handleEntryTap(
    NotificationsViewModel vm,
    NotificationHistoryEntry entry,
  ) {
    vm.markAsOpened(entry.notificationId);
    // entry.data values are dynamic — coerce defensively so a legacy non-String
    // id/route (e.g. an int) can't throw a TypeError on a routine tap.
    final route = (entry.data['route']?.toString()).orEmpty();
    final targetId = (entry.data['targetId'] ?? entry.data['id'])?.toString();
    NotificationService.onNotificationTapped?.call(route, <String, String?>{
      'id': targetId,
      'notificationType': entry.type,
      'notificationId': entry.notificationId,
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NotificationsViewModel>();

    return Scaffold(
      appBar: _selectionMode
          ? _buildSelectionAppBar(context, vm)
          : _buildDefaultAppBar(context, vm),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: _buildBody(context, vm),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildDefaultAppBar(
    BuildContext context,
    NotificationsViewModel vm,
  ) {
    final hasUnread = vm.entries.any((e) => !e.opened);
    return AppBar(
      title: Text(context.l10n.notificationsTitle),
      actions: [
        // BUT-952: bulk mark-all-as-read. Disabled when nothing unread —
        // the action would be a no-op and shouldn't suggest otherwise.
        PopupMenuButton<String>(
          enabled: hasUnread,
          onSelected: (value) {
            if (value == 'mark_all_read') {
              vm.markAllAsOpened();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem<String>(
              value: 'mark_all_read',
              child: Text(context.l10n.notificationsMarkAllRead),
            ),
          ],
        ),
      ],
    );
  }

  PreferredSizeWidget _buildSelectionAppBar(
    BuildContext context,
    NotificationsViewModel vm,
  ) {
    final count = _selectedIds.length;
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        tooltip: context.l10n.commonClose,
        onPressed: _cancelSelection,
      ),
      title: Text(context.l10n.notificationsSelectedCount(count)),
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: context.l10n.commonDismiss,
          onPressed: count > 0 ? () => _dismissSelected(vm) : null,
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, NotificationsViewModel vm) {
    if (vm.isLoading && vm.entries.isEmpty) {
      return StateWidget.loading();
    }

    if (vm.hasError && vm.entries.isEmpty) {
      return StateWidget.error(
        message: vm.error ?? context.l10n.notificationsErrorLoad,
        onAction: vm.refresh,
      );
    }

    if (vm.isEmpty) {
      // BUT-986: branded peaPod illustration; title comes from the variant.
      return StateWidget.noNotifications();
    }

    return RefreshIndicator(
      onRefresh: vm.refresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollEndNotification &&
              notification.metrics.extentAfter < 200) {
            vm.loadMore();
          }
          return false;
        },
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(
            vertical: AppDimensions.paddingM,
          ),
          itemCount: vm.entries.length + (vm.isLoadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == vm.entries.length) {
              return const Padding(
                padding: EdgeInsets.all(AppDimensions.paddingL),
                child: Center(child: LoadingIndicator()),
              );
            }
            final entry = vm.entries[index];
            return _NotificationTile(
              key: ValueKey(entry.id),
              entry: entry,
              isSelectionMode: _selectionMode,
              isSelected: _selectedIds.contains(entry.id),
              onTap: _selectionMode
                  ? () => _toggle(entry.id)
                  : () => _handleEntryTap(vm, entry),
              onLongPress: _selectionMode
                  ? null
                  : () => _enterSelection(entry.id),
            );
          },
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationHistoryEntry entry;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _NotificationTile({
    super.key,
    required this.entry,
    required this.onTap,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListTile(
      selected: isSelectionMode && isSelected,
      selectedTileColor: cs.primary.withValues(alpha: 0.08),
      leading: isSelectionMode
          ? Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              color: isSelected ? cs.primary : cs.outline,
              size: AppDimensions.iconSizeAction,
            )
          : Icon(
              _categoryIcon(entry.category),
              color: entry.opened ? cs.onSurfaceVariant : cs.primary,
              size: AppDimensions.iconSizeAction,
            ),
      title: Text(
        entry.displayTitle,
        style: entry.opened ? AppTextStyles.bodyMedium : AppTextStyles.bodyBold,
      ),
      subtitle: entry.displayBody.isNotEmpty
          ? Text(
              entry.displayBody,
              style: AppTextStyles.bodySmall.copyWith(
                color: cs.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: Text(
        ContextualTimeFormatter.compact(entry.sentAt),
        style: AppTextStyles.bodySmall.copyWith(
          color: cs.onSurfaceVariant,
        ),
      ),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }

  static IconData _categoryIcon(String category) {
    switch (category) {
      case 'social':
        return Icons.people_outline;
      case 'recipe':
        return Icons.restaurant_outlined;
      case 'shopping':
        return Icons.shopping_cart_outlined;
      case 'menu':
        return Icons.calendar_today_outlined;
      case 'system':
        return Icons.info_outline;
      default:
        return Icons.notifications_outlined;
    }
  }
}
