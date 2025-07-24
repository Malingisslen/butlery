// lib/widgets/common/social_components/invitation_actions.dart

import 'package:flutter/material.dart';
import '../../../models/invitations/invitation_target.dart';
import '../social/social_facade.dart';

/// Focused module for invitation action widgets
/// 
/// This module handles ONLY action buttons and quick operations:
/// - Quick selection buttons
/// - Action buttons for invitation workflows
/// - Bulk operations
/// 
/// ❌ DOES NOT CONTAIN: Display widgets, selectors, states, lists
class InvitationActions {

  // ===== QUICK ACTIONS =====

  /// Build quick selection buttons
  /// 
  /// Buttons for common target selection actions
  static Widget quickSelectionButtons({
    VoidCallback? onSelectAll,
    VoidCallback? onSelectNone,
    VoidCallback? onSelectFriends,
    VoidCallback? onSelectGroups,
    String? selectAllText = 'Alla',
    String? selectNoneText = 'Inga',
    String? selectFriendsText = 'Vänner',
    String? selectGroupsText = 'Grupper',
    EdgeInsets? padding,
    MainAxisAlignment alignment = MainAxisAlignment.spaceEvenly,
  }) {
    return SocialFacade.quickSelectionButtons(
      onSelectAll: onSelectAll ?? () {},
      onDeselectAll: onSelectNone ?? () {},
      onInvertSelection: () {}, // Not provided in original, using empty
    );
  }

  /// Build selection action bar
  /// 
  /// Action bar for selected targets
  static Widget selectionActionBar({
    required int selectedCount,
    VoidCallback? onSelectAll,
    VoidCallback? onDeselectAll,
    VoidCallback? onInvertSelection,
    VoidCallback? onSendInvitations,
    bool showSelectAll = true,
    bool showDeselectAll = true,
    bool showInvert = true,
    bool showSend = true,
    EdgeInsets? padding,
  }) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        border: Border(
          top: BorderSide(color: Colors.blue.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          Text(
            '$selectedCount valda',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          if (showSelectAll && onSelectAll != null)
            TextButton(
              onPressed: onSelectAll,
              child: const Text('Alla'),
            ),
          if (showDeselectAll && onDeselectAll != null)
            TextButton(
              onPressed: onDeselectAll,
              child: const Text('Inga'),
            ),
          if (showInvert && onInvertSelection != null)
            TextButton(
              onPressed: onInvertSelection,
              child: const Text('Invertera'),
            ),
          if (showSend && onSendInvitations != null)
            ElevatedButton(
              onPressed: selectedCount > 0 ? onSendInvitations : null,
              child: const Text('Skicka'),
            ),
        ],
      ),
    );
  }

  /// Build floating action buttons
  /// 
  /// FAB for primary actions
  static Widget floatingActionButtons({
    VoidCallback? onAddTarget,
    VoidCallback? onSendInvitations,
    VoidCallback? onCreateGroup,
    bool showAdd = true,
    bool showSend = true,
    bool showCreate = false,
    String? addTooltip = 'Lägg till målgrupp',
    String? sendTooltip = 'Skicka inbjudningar',
    String? createTooltip = 'Skapa grupp',
  }) {
    final buttons = <Widget>[];

    if (showAdd && onAddTarget != null) {
      buttons.add(
        FloatingActionButton(
          onPressed: onAddTarget,
          tooltip: addTooltip,
          heroTag: 'add_target',
          child: const Icon(Icons.add),
        ),
      );
    }

    if (showCreate && onCreateGroup != null) {
      buttons.add(
        FloatingActionButton(
          onPressed: onCreateGroup,
          tooltip: createTooltip,
          heroTag: 'create_group',
          child: const Icon(Icons.group_add),
        ),
      );
    }

    if (showSend && onSendInvitations != null) {
      buttons.add(
        FloatingActionButton.extended(
          onPressed: onSendInvitations,
          tooltip: sendTooltip,
          heroTag: 'send_invitations',
          icon: const Icon(Icons.send),
          label: const Text('Skicka'),
        ),
      );
    }

    if (buttons.isEmpty) return const SizedBox.shrink();
    if (buttons.length == 1) return buttons.first;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: buttons.reversed.map((button) => Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: button,
      )).toList(),
    );
  }

  // ===== BULK OPERATIONS =====

  /// Build bulk operation buttons
  /// 
  /// Buttons for bulk operations on targets
  static Widget bulkOperationButtons({
    required List<InvitationTarget> selectedTargets,
    VoidCallback? onBulkInvite,
    VoidCallback? onBulkRemove,
    VoidCallback? onBulkExport,
    bool showInvite = true,
    bool showRemove = true,
    bool showExport = false,
    String? inviteText = 'Skicka inbjudningar',
    String? removeText = 'Ta bort',
    String? exportText = 'Exportera',
    EdgeInsets? padding,
  }) {
    if (selectedTargets.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: padding ?? const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Text(
            '${selectedTargets.length} valda',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          if (showRemove && onBulkRemove != null)
            TextButton.icon(
              onPressed: onBulkRemove,
              icon: const Icon(Icons.delete, color: Colors.red),
              label: Text(removeText ?? 'Ta bort'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
          if (showExport && onBulkExport != null)
            TextButton.icon(
              onPressed: onBulkExport,
              icon: const Icon(Icons.download),
              label: Text(exportText ?? 'Exportera'),
            ),
          if (showInvite && onBulkInvite != null)
            ElevatedButton.icon(
              onPressed: onBulkInvite,
              icon: const Icon(Icons.send),
              label: Text(inviteText ?? 'Skicka inbjudningar'),
            ),
        ],
      ),
    );
  }

  /// Build batch action dialog
  /// 
  /// Dialog for confirming batch operations
  static Widget batchActionDialog({
    required BuildContext context,
    required String title,
    required String message,
    required List<InvitationTarget> targets,
    required VoidCallback onConfirm,
    VoidCallback? onCancel,
    String? confirmText = 'Fortsätt',
    String? cancelText = 'Avbryt',
    bool isDangerous = false,
  }) {
    return AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message),
          const SizedBox(height: 16),
          const Text(
            'Berörda målgrupper:',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: targets.length,
              itemBuilder: (context, index) {
                final target = targets[index];
                return ListTile(
                  dense: true,
                  leading: Icon(
                    target.type == InvitationTargetType.group 
                        ? Icons.group 
                        : Icons.person,
                    size: 20,
                  ),
                  title: Text(
                    target.displayName,
                    style: const TextStyle(fontSize: 14),
                  ),
                  subtitle: Text(
                    '${target.memberCount ?? 0} medlemmar',
                    style: const TextStyle(fontSize: 12),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: onCancel ?? () => Navigator.of(context).pop(),
          child: Text(cancelText ?? 'Avbryt'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            onConfirm();
          },
          style: isDangerous 
              ? ElevatedButton.styleFrom(backgroundColor: Colors.red)
              : null,
          child: Text(confirmText ?? 'Fortsätt'),
        ),
      ],
    );
  }

  // ===== CONTEXT ACTIONS =====

  /// Build target context menu
  /// 
  /// Context menu for individual targets
  static Widget targetContextMenu({
    required InvitationTarget target,
    VoidCallback? onView,
    VoidCallback? onEdit,
    VoidCallback? onRemove,
    VoidCallback? onInvite,
    bool showView = true,
    bool showEdit = true,
    bool showRemove = true,
    bool showInvite = true,
  }) {
    return PopupMenuButton<String>(
      onSelected: (action) {
        switch (action) {
          case 'view':
            onView?.call();
            break;
          case 'edit':
            onEdit?.call();
            break;
          case 'invite':
            onInvite?.call();
            break;
          case 'remove':
            onRemove?.call();
            break;
        }
      },
      itemBuilder: (context) => [
        if (showView && onView != null)
          const PopupMenuItem(
            value: 'view',
            child: ListTile(
              leading: Icon(Icons.visibility),
              title: Text('Visa'),
              dense: true,
            ),
          ),
        if (showEdit && onEdit != null)
          const PopupMenuItem(
            value: 'edit',
            child: ListTile(
              leading: Icon(Icons.edit),
              title: Text('Redigera'),
              dense: true,
            ),
          ),
        if (showInvite && onInvite != null)
          const PopupMenuItem(
            value: 'invite',
            child: ListTile(
              leading: Icon(Icons.send),
              title: Text('Skicka inbjudan'),
              dense: true,
            ),
          ),
        if (showRemove && onRemove != null)
          const PopupMenuItem(
            value: 'remove',
            child: ListTile(
              leading: Icon(Icons.delete, color: Colors.red),
              title: Text('Ta bort', style: TextStyle(color: Colors.red)),
              dense: true,
            ),
          ),
      ],
    );
  }

  /// Build swipe actions
  /// 
  /// Swipe actions for list items
  static Widget swipeActions({
    required Widget child,
    VoidCallback? onSwipeLeft,
    VoidCallback? onSwipeRight,
    Widget? leftAction,
    Widget? rightAction,
    String? leftLabel = 'Ta bort',
    String? rightLabel = 'Inbjud',
    Color? leftColor = Colors.red,
    Color? rightColor = Colors.blue,
  }) {
    return Dismissible(
      key: UniqueKey(),
      background: leftAction ?? Container(
        color: leftColor,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.delete, color: Colors.white),
            if (leftLabel != null)
              Text(
                leftLabel,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
          ],
        ),
      ),
      secondaryBackground: rightAction ?? Container(
        color: rightColor,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.send, color: Colors.white),
            if (rightLabel != null)
              Text(
                rightLabel,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
          ],
        ),
      ),
      onDismissed: (direction) {
        if (direction == DismissDirection.startToEnd) {
          onSwipeLeft?.call();
        } else if (direction == DismissDirection.endToStart) {
          onSwipeRight?.call();
        }
      },
      child: child,
    );
  }
}