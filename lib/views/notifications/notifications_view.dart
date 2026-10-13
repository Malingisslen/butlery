import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/press_fill.dart';
import 'package:butlery/widgets/common/layout/butlery_page.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/contextual_time_formatter.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/notification_history_entry.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/services/notifications/notification_service.dart';
import 'package:butlery/viewmodels/notifications_viewmodel.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/layout/tinted_note.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';

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

  // Class 1 (BUT-2225): the entries disappear at once, and the delete is
  // sent only when the snackbar closes without Ångra.
  void _dismissSelected(NotificationsViewModel vm) {
    if (_selectedIds.isEmpty) return;
    final hidden = vm.hideSelected(Set.of(_selectedIds));
    _cancelSelection();
    if (hidden.isEmpty) return;
    SnackBarUtils.showUndoDeferred(
      context,
      context.l10n.notificationsDismissed(hidden.length),
      onUndo: () => vm.undoDismiss(hidden),
      onCommit: () => vm.commitDismiss(hidden),
    );
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

    final count = _selectedIds.length;
    // Same bar, other content while choosing: the count replaces the title and
    // the close action replaces the back arrow.
    return ButleryPage.undersida(
      title: _selectionMode
          ? context.l10n.notificationsSelectedCount(count)
          : context.l10n.notificationsTitle,
      leading: _selectionMode
          ? IconButton(
              icon: const ButleryIcon(ButleryIcons.x),
              tooltip: context.l10n.commonClose,
              onPressed: _cancelSelection,
            )
          : null,
      actions: [
        if (_selectionMode)
          IconButton(
            icon: const ButleryIcon(ButleryIcons.trash2),
            tooltip: context.l10n.commonDismiss,
            onPressed: count > 0 ? () => _dismissSelected(vm) : null,
          ),
      ],
      body: _buildBody(context, vm),
    );
  }

  Widget _buildBody(BuildContext context, NotificationsViewModel vm) {
    if (vm.isLoading && vm.entries.isEmpty) {
      return StateWidget.loading(message: context.l10n.loadingNotifications);
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
          padding: const EdgeInsets.only(bottom: AppDimensions.space24),
          // The band first, then one row per entry, the next page's plate
          // line while it loads, and the note last.
          itemCount: 2 + vm.entries.length + (vm.isLoadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == 0) return _MarkAllReadBand(vm: vm);
            final entryIndex = index - 1;
            if (entryIndex == vm.entries.length && vm.isLoadingMore) {
              // Loading the next page: the plate line with what is fetched.
              return Padding(
                padding: const EdgeInsets.all(AppDimensions.space16),
                child: Center(
                  child: PlateLineMessage(
                    message: context.l10n.loadingNotifications,
                  ),
                ),
              );
            }
            if (entryIndex >= vm.entries.length) {
              return const _InboxNote();
            }
            final entry = vm.entries[entryIndex];
            return Column(
              key: ValueKey(entry.id),
              mainAxisSize: MainAxisSize.min,
              children: [
                _NotificationTile(
                  entry: entry,
                  isSelectionMode: _selectionMode,
                  isSelected: _selectedIds.contains(entry.id),
                  onTap: _selectionMode
                      ? () => _toggle(entry.id)
                      : () => _handleEntryTap(vm, entry),
                  onLongPress: _selectionMode
                      ? null
                      : () => _enterSelection(entry.id),
                ),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// "Markera alla lästa" with the count of unread, on the green band above
/// the list. Without anything unread it reads as information, not a control.
class _MarkAllReadBand extends StatelessWidget {
  const _MarkAllReadBand({required this.vm});

  final NotificationsViewModel vm;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final unread = vm.entries.where((e) => !e.opened).length;
    final hasUnread = unread > 0;
    final color = hasUnread ? cs.onSurface : cs.onSurfaceVariant;
    return Semantics(
      button: true,
      enabled: hasUnread,
      child: PressFill(
        surface: PressSurface.base,
        child: InkWell(
          onTap: hasUnread ? vm.markAllAsOpened : null,
          child: TintedNote.band(
            child: Row(
              children: [
                ExcludeSemantics(
                  child: ButleryIcon(
                    ButleryIcons.listCheck,
                    color: color,
                    size: AppDimensions.iconSizeS,
                  ),
                ),
                const SizedBox(width: AppDimensions.space12),
                Expanded(
                  child: Text(
                    l10n.notificationsMarkAllReadShort,
                    style: AppTextStyles.bodyBold.copyWith(color: color),
                  ),
                ),
                Text(
                  l10n.notificationsUnreadCount(unread),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The note under the list: how many load at a time and how to pick several.
class _InboxNote extends StatelessWidget {
  const _InboxNote();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: ButleryPageBody.margin(context, top: AppDimensions.space16),
      child: TintedNote(
        child: Text(
          context.l10n.notificationsNote,
          style: TintedNote.textStyle(context),
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
    required this.entry,
    required this.onTap,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final chosen = isSelectionMode && isSelected;
    return ListTile(
      selected: chosen,
      // A row on the page's paper with a hairline under it, as the sketch
      // draws it; the theme's raised tile is for cards.
      tileColor: Colors.transparent,
      // Chosen is surface.selected with a real border, never a tint
      // (Grafisk manual v6:209 "Vald = riktig border"; tokens.json:40-53,
      // :108-119). surfaceContainerHighest is surface.raised, which
      // carries surface.selected's values in both modes; the border is
      // text.primary (onSurface): ink on light, paper on dark.
      selectedTileColor: cs.surfaceContainerHighest,
      // The chosen row's title and icons stay text.primary; ListTile would
      // otherwise paint them colorScheme.primary, which is ink in dark mode
      // too and vanishes on surface.selected (#2F4437).
      selectedColor: cs.onSurface,
      shape: chosen
          ? Border.all(color: cs.onSurface, width: 1.5)
          : const RoundedRectangleBorder(),
      leading: isSelectionMode
          ? ButleryIcon(
              isSelected ? ButleryIcons.circleCheck : ButleryIcons.circle,
              color: isSelected ? cs.onSurface : cs.outline,
              size: AppDimensions.iconSizeM,
            )
          : ButleryIcon(
              _categoryIcon(entry.category),
              color: entry.opened ? cs.onSurfaceVariant : cs.onSurface,
              size: AppDimensions.iconSizeM,
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
        return ButleryIcons.users;
      case 'recipe':
        return ButleryIcons.utensils;
      case 'shopping':
        return ButleryIcons.shoppingCart;
      case 'menu':
        return ButleryIcons.calendar;
      case 'system':
        return ButleryIcons.info;
      default:
        return ButleryIcons.bell;
    }
  }
}
