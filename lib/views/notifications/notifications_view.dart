import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/time_ago_formatter.dart';
import 'package:butlery/models/notification_history_entry.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
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

class _NotificationsContent extends StatelessWidget {
  const _NotificationsContent();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NotificationsViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.notificationsTitle),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: _buildBody(context, vm),
        ),
      ),
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
            return _NotificationTile(
              key: ValueKey(vm.entries[index].id),
              entry: vm.entries[index],
              onTap: () => vm.markAsOpened(vm.entries[index].notificationId),
            );
          },
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationHistoryEntry entry;
  final VoidCallback onTap;

  const _NotificationTile({
    super.key,
    required this.entry,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListTile(
      leading: Icon(
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
        TimeAgoFormatter.compact(entry.sentAt),
        style: AppTextStyles.bodySmall.copyWith(
          color: cs.onSurfaceVariant,
        ),
      ),
      onTap: onTap,
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
